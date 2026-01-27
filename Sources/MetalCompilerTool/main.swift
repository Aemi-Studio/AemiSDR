#if os(macOS)
import Foundation

/// Metal Compiler Tool for Core Image Kernels
///
/// This executable compiles Core Image Metal shader files (.ci.metal) into
/// platform-specific Metal libraries (.metallib) for both iOS and macOS.
///
/// Usage:
///   MetalCompilerTool --input <path> --ios-output <path> --macos-output <path>
///                     [--ios-min-version <version>] [--macos-min-version <version>]

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

// MARK: - Platform Configuration

struct PlatformConfig {
    let name: String
    let sdk: String
    let minVersionFlag: String
    let minVersion: String
    let outputPath: String
}

// MARK: - Command Execution

func execute(_ command: String, arguments: [String]) throws -> (output: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments

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

    // Step 1: Compile .ci.metal to .air
    print("[\(config.name)] Compiling to AIR...")
    let metalArgs = [
        "--sdk", config.sdk,
        "metal",
        "-c",
        "-fcikernel",
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
    let metallibArgs = [
        "--sdk", config.sdk,
        "metallib",
        "-cikernel",
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
    iosMinVersion: String,
    macosMinVersion: String
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

    let iosMinVersion = getArg("--ios-min-version") ?? "14.0"
    let macosMinVersion = getArg("--macos-min-version") ?? "11.0"

    return (inputPath, iosOutput, macosOutput, iosMinVersion, macosMinVersion)
}

// MARK: - Main Entry Point

do {
    let (inputPath, iosOutput, macosOutput, iosMinVersion, macosMinVersion) = try parseArguments()

    print("AemiSDR Metal Compiler")
    print("Input: \(inputPath)")
    print("iOS Output: \(iosOutput)")
    print("macOS Output: \(macosOutput)")
    print("")

    let platforms = [
        PlatformConfig(
            name: "iOS",
            sdk: "iphoneos",
            minVersionFlag: "-mios-version-min=",
            minVersion: iosMinVersion,
            outputPath: iosOutput
        ),
        PlatformConfig(
            name: "macOS",
            sdk: "macosx",
            minVersionFlag: "-mmacos-version-min=",
            minVersion: macosMinVersion,
            outputPath: macosOutput
        ),
    ]

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
