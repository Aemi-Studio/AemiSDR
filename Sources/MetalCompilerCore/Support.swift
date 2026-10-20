#if os(macOS)
    import Foundation

    /// The oldest OS releases the package supports. Shaders are compiled for exactly this floor: compiling for an older
    /// one gives up newer Metal language features and optimisations for deployments the package does not support.
    enum DeploymentFloor {
        static let ios = "18.0"
        static let macos = "15.0"
    }

    enum CompilerError: Error, LocalizedError {
        case missingArgument(String)
        case fileNotFound(String)
        case outputOutsideAllowedRoot(path: String, root: String)
        case compilationFailed(platform: String, phase: String, output: String)
        case xcrunNotFound

        var errorDescription: String? {
            switch self {
            case .missingArgument(let arg):
                return "Missing required argument: \(arg)"
            case .outputOutsideAllowedRoot(let path, let root):
                return "Output path '\(path)' is outside --allowed-root '\(root)'"
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .compilationFailed(let platform, let phase, let output):
                return "[\(platform)] \(phase) failed:\n\(output)"
            case .xcrunNotFound:
                return "xcrun not found. Ensure Xcode Command Line Tools are installed."
            }
        }
    }

    enum CompilationMode: String {
        case ci
        case standard
    }

    struct PlatformConfig {
        let name: String
        let sdk: String
        let minVersionFlag: String
        let minVersion: String
        let outputPath: String
        let mode: CompilationMode
    }

    /// Runs a subprocess and collects its combined output.
    enum ProcessRunner {
        static func execute(
            _ command: String, arguments: [String], environment: [String: String]
        ) throws -> (output: String, exitCode: Int32) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            process.environment = environment

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()

            // Drain the pipe BEFORE waiting. A pipe holds 64 KiB; a child that writes more blocks on a full pipe until
            // someone reads, so waiting first deadlocks the build on a long compiler error cascade (65,536 bytes of
            // output completes, 65,537 hangs). Reading to end of file returns when the child closes its output.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (String(data: data, encoding: .utf8) ?? "", process.terminationStatus)
        }
    }

    /// The environment for compiler subprocesses, with a `DEVELOPER_DIR` that `xcrun` would reject removed.
    ///
    /// Swift Build exports `DEVELOPER_DIR` pointing at the running toolchain when a build uses a standalone swift.org
    /// toolchain rather than Xcode's. `xcrun` aborts on an `.xctoolchain` path; a developer directory must hold
    /// `usr/bin/xcrun`, an app bundle `Contents/Developer/usr/bin/xcrun`. Dropping the invalid value lets `xcrun` fall
    /// back to the `xcode-select` path; a valid value, either shape, is left alone.
    enum DeveloperEnvironment {
        static func sanitized(
            _ environment: [String: String],
            isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
        ) -> [String: String] {
            var result = environment
            guard let developerDir = result["DEVELOPER_DIR"] else { return result }
            let isValid = ["/usr/bin/xcrun", "/Contents/Developer/usr/bin/xcrun"].contains {
                isExecutable(developerDir + $0)
            }
            if !isValid { result["DEVELOPER_DIR"] = nil }
            return result
        }
    }

    /// Confines outputs to a root. Both sides are canonicalised the same way because the build system may spell one location two
    /// ways (`/private/tmp/…` and `/tmp/…`), and the comparison stops at a component boundary so a sibling that merely
    /// shares the root's prefix cannot pass.
    enum OutputRoot {
        static func canonicalized(_ path: String) -> String {
            let standardized = (path as NSString).standardizingPath
            let privatePrefix = "/private/"
            if standardized.hasPrefix(privatePrefix) {
                return String(standardized.dropFirst(privatePrefix.count - 1))
            }
            return standardized
        }

        static func permits(_ path: String, within root: String) -> Bool {
            let target = canonicalized(path)
            let base = canonicalized(root)
            return target == base || target.hasPrefix(base + "/")
        }
    }
#endif
