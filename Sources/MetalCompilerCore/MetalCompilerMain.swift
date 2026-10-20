#if os(macOS)
    import Foundation

    /// Compiles one Metal source file into a library per destination.
    public enum MetalCompilerMain {
        public static func run(arguments: [String]) -> Int32 {
            do {
                let invocation = try Invocation.parse(arguments)
                print("AemiSDR Metal Compiler (\(invocation.mode) mode)")
                print("Input: \(invocation.inputPath)")
                var platforms = [
                    PlatformConfig(
                        name: "iOS", sdk: "iphoneos", minVersionFlag: "-mios-version-min=",
                        minVersion: invocation.iosMinVersion, outputPath: invocation.iosOutput, mode: invocation.mode),
                    PlatformConfig(
                        name: "macOS", sdk: "macosx", minVersionFlag: "-mmacos-version-min=",
                        minVersion: invocation.macosMinVersion, outputPath: invocation.macosOutput,
                        mode: invocation.mode),
                ]
                if let simulator = invocation.iosSimulatorOutput {
                    platforms.append(
                        PlatformConfig(
                            name: "iOS Simulator", sdk: "iphonesimulator",
                            minVersionFlag: "-mios-simulator-version-min=",
                            minVersion: invocation.iosMinVersion, outputPath: simulator, mode: invocation.mode))
                }
                guard FileManager.default.fileExists(atPath: invocation.inputPath) else {
                    throw CompilerError.fileNotFound(invocation.inputPath)
                }
                for platform in platforms { try compile(inputPath: invocation.inputPath, config: platform) }
                print("Metal shader compilation completed successfully!")
                return 0
            } catch {
                FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
                return 1
            }
        }

        private static func xcrun(_ arguments: [String]) throws {
            let environment = DeveloperEnvironment.sanitized(ProcessInfo.processInfo.environment)
            let (output, exitCode) = try ProcessRunner.execute(
                "/usr/bin/xcrun", arguments: arguments, environment: environment)
            if exitCode != 0 {
                throw CompilerError.compilationFailed(
                    platform: "xcrun", phase: arguments.first ?? "unknown", output: output)
            }
        }

        /// The `xcrun` arguments that compile one source to AIR for one destination. The deployment target flag is the
        /// destination's own (`-mios-version-min=`, `-mios-simulator-version-min=`, `-mmacos-version-min=`).
        static func metalArguments(_ config: PlatformConfig, inputPath: String, airPath: String) -> [String] {
            var arguments = ["--sdk", config.sdk, "metal", "-c"]
            if config.mode == .ci { arguments.append("-fcikernel") }
            // -fmodules=none is required for Xcode Cloud compatibility.
            arguments += ["-fmodules=none", config.minVersionFlag + config.minVersion, inputPath, "-o", airPath]
            return arguments
        }

        private static func compile(inputPath: String, config: PlatformConfig) throws {
            let outputDirectory = (config.outputPath as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
            let airPath = (config.outputPath as NSString).deletingPathExtension + ".air"
            defer { try? FileManager.default.removeItem(atPath: airPath) }

            print("[\(config.name)] Compiling to AIR (\(config.mode) mode)...")
            let metalArguments = Self.metalArguments(config, inputPath: inputPath, airPath: airPath)
            do { try xcrun(metalArguments) } catch let error as CompilerError {
                throw CompilerError.compilationFailed(
                    platform: config.name, phase: "metal compilation", output: error.localizedDescription)
            }

            print("[\(config.name)] Linking to metallib...")
            var linkArguments = ["--sdk", config.sdk, "metallib"]
            if config.mode == .ci { linkArguments.append("-cikernel") }
            linkArguments += [airPath, "-o", config.outputPath]
            do { try xcrun(linkArguments) } catch let error as CompilerError {
                throw CompilerError.compilationFailed(
                    platform: config.name, phase: "metallib linking", output: error.localizedDescription)
            }
            print("[\(config.name)] Generated: \(config.outputPath)")
        }
    }
#endif
