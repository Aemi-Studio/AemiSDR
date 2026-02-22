import Foundation
import PackagePlugin

/// Build tool plugin that automatically compiles Metal shaders into platform-specific
/// .metallib files during the build process.
///
/// Supports two compilation modes:
/// - **CI kernel mode** (`.ci.metal` files): Compiled with `-fcikernel` for Core Image kernels
/// - **Standard mode** (other `.metal` files): Compiled as standard Metal render/compute shaders
@main
struct AemiSDRShaderPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }

        let metalFiles = sourceTarget.sourceFiles.filter { file in
            file.url.pathExtension == "metal"
        }

        guard !metalFiles.isEmpty else {
            Diagnostics.remark("No .metal files found in target \(target.name)")
            return []
        }

        let compilerTool = try context.tool(named: "MetalCompilerTool")
        var commands: [Command] = []

        for metalFile in metalFiles {
            let inputURL = metalFile.url
            let isCIKernel = inputURL.lastPathComponent.contains(".ci.")
            let mode = isCIKernel ? "ci" : "standard"

            let baseName = inputURL.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: ".ci", with: "")

            let iosOutputURL = context.pluginWorkDirectoryURL
                .appending(path: "\(baseName).iOS.metallib")
            let macosOutputURL = context.pluginWorkDirectoryURL
                .appending(path: "\(baseName).macOS.metallib")

            let displayName = isCIKernel
                ? "Compiling CI Metal Kernel: \(inputURL.lastPathComponent)"
                : "Compiling Metal Shader: \(inputURL.lastPathComponent)"

            commands.append(
                .buildCommand(
                    displayName: displayName,
                    executable: compilerTool.url,
                    arguments: [
                        "--input", inputURL.path(percentEncoded: false),
                        "--ios-output", iosOutputURL.path(percentEncoded: false),
                        "--macos-output", macosOutputURL.path(percentEncoded: false),
                        "--ios-min-version", "14.0",
                        "--macos-min-version", "11.0",
                        "--mode", mode,
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
        let metalFiles = target.inputFiles.filter { file in
            file.url.pathExtension == "metal"
        }

        guard !metalFiles.isEmpty else {
            Diagnostics.remark("No .metal files found in Xcode target \(target.displayName)")
            return []
        }

        let compilerTool = try context.tool(named: "MetalCompilerTool")
        var commands: [Command] = []

        for metalFile in metalFiles {
            let inputURL = metalFile.url
            let isCIKernel = inputURL.lastPathComponent.contains(".ci.")
            let mode = isCIKernel ? "ci" : "standard"

            let baseName = inputURL.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: ".ci", with: "")

            let iosOutputURL = context.pluginWorkDirectoryURL
                .appending(path: "\(baseName).iOS.metallib")
            let macosOutputURL = context.pluginWorkDirectoryURL
                .appending(path: "\(baseName).macOS.metallib")

            let displayName = isCIKernel
                ? "Compiling CI Metal Kernel: \(inputURL.lastPathComponent)"
                : "Compiling Metal Shader: \(inputURL.lastPathComponent)"

            commands.append(
                .buildCommand(
                    displayName: displayName,
                    executable: compilerTool.url,
                    arguments: [
                        "--input", inputURL.path(percentEncoded: false),
                        "--ios-output", iosOutputURL.path(percentEncoded: false),
                        "--macos-output", macosOutputURL.path(percentEncoded: false),
                        "--ios-min-version", "14.0",
                        "--macos-min-version", "11.0",
                        "--mode", mode,
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
