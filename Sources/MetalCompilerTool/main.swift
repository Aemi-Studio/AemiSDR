#if os(macOS)
    import Foundation

    /// Metal Compiler Tool for Core Image Kernels
    ///
    /// This executable compiles Core Image Metal shader files (.ci.metal) into
    /// platform-specific Metal libraries (.metallib) for both iOS and macOS.
    ///
    /// Usage:
    ///   MetalCompilerTool --input <path> --ios-output <path> --macos-output <path>
    ///                     [--ios-simulator-output <path>]
    ///                     [--ios-min-version <version>] [--macos-min-version <version>]
    ///                     [--mode <ci|standard>]

    // MARK: - Error Types

    enum CompilerError: Error, LocalizedError {
        case missingArgument(String)
        case fileNotFound(String)
        case compilationFailed(platform: String, phase: String, output: String)
        case xcrunNotFound

        var errorDescription: String? {
            switch self {
            case .missingArgument(let arg):
                return "Missing required argument: \(arg)"
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .compilationFailed(let platform, let phase, let output):
                return "[\(platform)] \(phase) failed:\n\(output)"
            case .xcrunNotFound:
                return "xcrun not found. Ensure Xcode Command Line Tools are installed."
            }
        }
    }

    // MARK: - Compilation Mode

    enum CompilationMode: String {
        case ci
        case standard
    }

    // MARK: - Platform Configuration

    struct PlatformConfig {
        let name: String
        let sdk: String
        let minVersionFlag: String
        let minVersion: String
        let outputPath: String
        let mode: CompilationMode
    }

    // MARK: - Command Execution

    /// The environment for compiler subprocesses, with a `DEVELOPER_DIR` that
    /// `xcrun` would reject removed.
    ///
    /// Swift Build exports `DEVELOPER_DIR` pointing at the running toolchain when
    /// a build uses a standalone swift.org toolchain rather than Xcode's. `xcrun`
    /// validates the variable the same way this check does — a developer
    /// directory must hold `usr/bin/xcrun`, an app bundle
    /// `Contents/Developer/usr/bin/xcrun` — and aborts on an `.xctoolchain` path,
    /// which failed this plugin for every consumer building with such a
    /// toolchain. Dropping the invalid value lets `xcrun` fall back to the
    /// `xcode-select` path; a valid value, either shape, is left alone.
    func sanitizedEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        guard let developerDir = environment["DEVELOPER_DIR"] else { return environment }

        let isValid = ["/usr/bin/xcrun", "/Contents/Developer/usr/bin/xcrun"].contains { suffix in
            FileManager.default.isExecutableFile(atPath: developerDir + suffix)
        }
        if !isValid {
            environment["DEVELOPER_DIR"] = nil
        }
        return environment
    }

    func execute(_ command: String, arguments: [String]) throws -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.environment = sanitizedEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return (output, process.terminationStatus)
    }

    func executeXcrun(arguments: [String]) throws -> String {
        let (output, exitCode) = try execute("/usr/bin/xcrun", arguments: arguments)
        if exitCode != 0 {
            throw CompilerError.compilationFailed(
                platform: "xcrun",
                phase: arguments.first ?? "unknown",
                output: output
            )
        }
        return output
    }

    // MARK: - Metal Compilation

    func compileMetalShaders(
        inputPath: String,
        platforms: [PlatformConfig]
    ) throws {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: inputPath) else {
            throw CompilerError.fileNotFound(inputPath)
        }

        for platform in platforms {
            try compilePlatform(inputPath: inputPath, config: platform)
        }
    }

    func compilePlatform(inputPath: String, config: PlatformConfig) throws {
        let fileManager = FileManager.default

        // Create output directory if needed
        let outputDir = (config.outputPath as NSString).deletingLastPathComponent
        try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        // Temporary AIR file path
        let airPath = (config.outputPath as NSString).deletingPathExtension + ".air"

        defer {
            // Clean up temporary file
            try? fileManager.removeItem(atPath: airPath)
        }

        // Step 1: Compile .metal to .air
        print("[\(config.name)] Compiling to AIR (\(config.mode) mode)...")
        var metalArgs = [
            "--sdk", config.sdk,
            "metal",
            "-c",
        ]
        if config.mode == .ci {
            metalArgs.append("-fcikernel")
        }
        metalArgs += [
            "-fmodules=none",  // Required for Xcode Cloud compatibility
            config.minVersionFlag + config.minVersion,
            inputPath,
            "-o", airPath,
        ]

        do {
            _ = try executeXcrun(arguments: metalArgs)
        } catch let error as CompilerError {
            throw CompilerError.compilationFailed(
                platform: config.name,
                phase: "metal compilation",
                output: error.localizedDescription
            )
        }

        // Step 2: Link .air to .metallib
        print("[\(config.name)] Linking to metallib...")
        var metallibArgs = [
            "--sdk", config.sdk,
            "metallib",
        ]
        if config.mode == .ci {
            metallibArgs.append("-cikernel")
        }
        metallibArgs += [
            airPath,
            "-o", config.outputPath,
        ]

        do {
            _ = try executeXcrun(arguments: metallibArgs)
        } catch let error as CompilerError {
            throw CompilerError.compilationFailed(
                platform: config.name,
                phase: "metallib linking",
                output: error.localizedDescription
            )
        }

        print("[\(config.name)] Generated: \(config.outputPath)")
    }

    // MARK: - Argument Parsing

    func parseArguments() throws -> (
        inputPath: String,
        iosOutput: String,
        macosOutput: String,
        iosSimulatorOutput: String?,
        iosMinVersion: String,
        macosMinVersion: String,
        mode: CompilationMode
    ) {
        let args = CommandLine.arguments

        func getArg(_ name: String) -> String? {
            guard let index = args.firstIndex(of: name), index + 1 < args.count else {
                return nil
            }
            return args[index + 1]
        }

        guard let inputPath = getArg("--input") else {
            throw CompilerError.missingArgument("--input")
        }

        guard let iosOutput = getArg("--ios-output") else {
            throw CompilerError.missingArgument("--ios-output")
        }

        guard let macosOutput = getArg("--macos-output") else {
            throw CompilerError.missingArgument("--macos-output")
        }

        // Optional so existing invocations keep their two-platform behavior.
        let iosSimulatorOutput = getArg("--ios-simulator-output")

        let iosMinVersion = getArg("--ios-min-version") ?? "14.0"
        let macosMinVersion = getArg("--macos-min-version") ?? "11.0"
        let mode = resolveCompilationMode(inputPath: inputPath, explicitMode: getArg("--mode"))

        // Defense in depth: if `--allowed-root <path>` is passed, refuse to write
        // any output outside that root. SwiftPM's plugin sandbox already enforces
        // similar boundaries, but a path-confined tool is robust against
        // out-of-plugin invocations where the sandbox profile may differ.
        //
        // Both sides are canonicalized the same way because the build system
        // may hand the outputs and the root different spellings of one
        // location — `/private/tmp/…` for one and `/tmp/…` for the other —
        // and `standardizingPath` strips `/private` only from paths that
        // already exist, which outputs never do. The comparison also stops at
        // a component boundary so a sibling that merely shares the root's
        // prefix cannot pass.
        if let allowedRoot = getArg("--allowed-root") {
            func canonicalized(_ path: String) -> String {
                let standardized = (path as NSString).standardizingPath
                let privatePrefix = "/private/"
                if standardized.hasPrefix(privatePrefix) {
                    return String(standardized.dropFirst(privatePrefix.count - 1))
                }
                return standardized
            }
            let root = canonicalized(allowedRoot)
            for path in [iosOutput, macosOutput, iosSimulatorOutput].compactMap({ $0 }) {
                let standardized = canonicalized(path)
                if standardized != root, !standardized.hasPrefix(root + "/") {
                    throw CompilerError.missingArgument(
                        "output path '\(standardized)' is outside --allowed-root '\(root)'"
                    )
                }
            }
        }

        return (inputPath, iosOutput, macosOutput, iosSimulatorOutput, iosMinVersion, macosMinVersion, mode)
    }

    func resolveCompilationMode(inputPath: String, explicitMode: String?) -> CompilationMode {
        if let explicitMode, let mode = CompilationMode(rawValue: explicitMode) {
            return mode
        }

        // Prefer deriving mode from file naming convention to keep plugin and tool behavior aligned.
        if inputPath.hasSuffix(".ci.metal") {
            return .ci
        }

        return .standard
    }

    // MARK: - Main Entry Point

    do {
        let (inputPath, iosOutput, macosOutput, iosSimulatorOutput, iosMinVersion, macosMinVersion, mode) =
            try parseArguments()

        print("AemiSDR Metal Compiler (\(mode) mode)")
        print("Input: \(inputPath)")
        print("iOS Output: \(iosOutput)")
        print("macOS Output: \(macosOutput)")
        if let iosSimulatorOutput {
            print("iOS Simulator Output: \(iosSimulatorOutput)")
        }
        print("")

        var platforms = [
            PlatformConfig(
                name: "iOS",
                sdk: "iphoneos",
                minVersionFlag: "-mios-version-min=",
                minVersion: iosMinVersion,
                outputPath: iosOutput,
                mode: mode
            ),
            PlatformConfig(
                name: "macOS",
                sdk: "macosx",
                minVersionFlag: "-mmacos-version-min=",
                minVersion: macosMinVersion,
                outputPath: macosOutput,
                mode: mode
            ),
        ]
        if let iosSimulatorOutput {
            platforms.append(
                PlatformConfig(
                    name: "iOS Simulator",
                    sdk: "iphonesimulator",
                    minVersionFlag: "-mios-simulator-version-min=",
                    minVersion: iosMinVersion,
                    outputPath: iosSimulatorOutput,
                    mode: mode
                )
            )
        }

        try compileMetalShaders(inputPath: inputPath, platforms: platforms)

        print("")
        print("Metal shader compilation completed successfully!")
    } catch {
        FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
        exit(1)
    }

#else
    // This tool is only meant to run on macOS during the build process.
    // It should never be compiled or run on iOS/tvOS/watchOS.
    import Foundation

    fatalError("MetalCompilerTool can only run on macOS")
#endif
