#if os(macOS)
    import Foundation

    /// What one run of the tool was asked to do.
    struct Invocation: Equatable {
        var inputPath: String
        var iosOutput: String
        var macosOutput: String
        var iosSimulatorOutput: String?
        var iosMinVersion: String
        var macosMinVersion: String
        var mode: CompilationMode

        static func parse(_ args: [String]) throws -> Invocation {
            func value(of name: String) -> String? {
                guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
                return args[index + 1]
            }
            guard let inputPath = value(of: "--input") else { throw CompilerError.missingArgument("--input") }
            guard let iosOutput = value(of: "--ios-output") else { throw CompilerError.missingArgument("--ios-output") }
            guard let macosOutput = value(of: "--macos-output") else {
                throw CompilerError.missingArgument("--macos-output")
            }
            let iosSimulatorOutput = value(of: "--ios-simulator-output")

            // Defense in depth: with `--allowed-root`, refuse any output outside it.
            if let root = value(of: "--allowed-root") {
                for path in [iosOutput, macosOutput, iosSimulatorOutput].compactMap({ $0 })
                where !OutputRoot.permits(path, within: root) {
                    throw CompilerError.outputOutsideAllowedRoot(
                        path: OutputRoot.canonicalized(path), root: OutputRoot.canonicalized(root))
                }
            }

            return Invocation(
                inputPath: inputPath, iosOutput: iosOutput, macosOutput: macosOutput,
                iosSimulatorOutput: iosSimulatorOutput,
                iosMinVersion: value(of: "--ios-min-version") ?? DeploymentFloor.ios,
                macosMinVersion: value(of: "--macos-min-version") ?? DeploymentFloor.macos,
                mode: resolveMode(inputPath: inputPath, explicit: value(of: "--mode")))
        }

        /// An explicit, recognised mode wins; otherwise the file name decides (`.ci.metal` is a Core Image kernel).
        static func resolveMode(inputPath: String, explicit: String?) -> CompilationMode {
            if let explicit, let mode = CompilationMode(rawValue: explicit) { return mode }
            return inputPath.hasSuffix(".ci.metal") ? .ci : .standard
        }
    }
#endif
