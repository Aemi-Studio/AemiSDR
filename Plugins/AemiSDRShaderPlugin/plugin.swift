import Foundation
import PackagePlugin

/// Build tool plugin that automatically compiles Core Image Metal shaders (.ci.metal files)
/// into platform-specific .metallib files during the build process.
///
/// This plugin processes all `.ci.metal` files in the target's source directory and generates
/// both iOS and macOS Metal libraries with appropriate deployment targets.
@main
struct AemiSDRShaderPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }

        // Find all .ci.metal files in the target
        let metalFiles = sourceTarget.sourceFiles.filter { file in
            file.url.pathExtension == "metal"
        }

        guard !metalFiles.isEmpty else {
            Diagnostics.remark("No .metal files found in target \(target.name)")
            return []
        }

        var commands: [Command] = []

        for metalFile in metalFiles {
            let inputURL = metalFile.url
            let baseName = inputURL.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: ".ci", with: "")

            // Output paths in the plugin work directory
            let iosOutputURL = context.pluginWorkDirectoryURL
                .appending(path: "\(baseName).iOS.metallib")
            let macosOutputURL = context.pluginWorkDirectoryURL
                .appending(path: "\(baseName).macOS.metallib")

            // Get the compiler tool
            let compilerTool = try context.tool(named: "MetalCompilerTool")

            // Create build command for this shader file
            commands.append(
                .buildCommand(
                    displayName: "Compiling Core Image Metal Shaders: \(inputURL.lastPathComponent)",
                    executable: compilerTool.url,
                    arguments: [
                        "--input", inputURL.path(percentEncoded: false),
                        "--ios-output", iosOutputURL.path(percentEncoded: false),
                        "--macos-output", macosOutputURL.path(percentEncoded: false),
                        "--ios-min-version", "14.0",
                        "--macos-min-version", "11.0",
                    ],
                    inputFiles: [inputURL],
                    outputFiles: [iosOutputURL, macosOutputURL]
                )
            )
        }

        return commands
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension AemiSDRShaderPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        // Find .ci.metal files in the target's input files
        let metalFiles = target.inputFiles.filter { file in
            file.url.pathExtension == "metal"
        }

        guard !metalFiles.isEmpty else {
            Diagnostics.remark("No .metal files found in Xcode target \(target.displayName)")
            return []
        }

        var commands: [Command] = []

        for metalFile in metalFiles {
            let inputURL = metalFile.url
            let baseName = inputURL.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: ".ci", with: "")

            let iosOutputURL = context.pluginWorkDirectoryURL
                .appending(path: "\(baseName).iOS.metallib")
            let macosOutputURL = context.pluginWorkDirectoryURL
                .appending(path: "\(baseName).macOS.metallib")

            let compilerTool = try context.tool(named: "MetalCompilerTool")

            commands.append(
                .buildCommand(
                    displayName: "Compiling Core Image Metal Shaders: \(inputURL.lastPathComponent)",
                    executable: compilerTool.url,
                    arguments: [
                        "--input", inputURL.path(percentEncoded: false),
                        "--ios-output", iosOutputURL.path(percentEncoded: false),
                        "--macos-output", macosOutputURL.path(percentEncoded: false),
                        "--ios-min-version", "14.0",
                        "--macos-min-version", "11.0",
                    ],
                    inputFiles: [inputURL],
                    outputFiles: [iosOutputURL, macosOutputURL]
                )
            )
        }

        return commands
    }
}
#endif
