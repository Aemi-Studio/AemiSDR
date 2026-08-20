import Foundation
import PackagePlugin

/// Build tool plugin that automatically compiles Metal shaders into platform-specific
/// .metallib files during the build process.
///
/// Supports two compilation modes:
/// - **CI kernel mode** (`.ci.metal` files): Compiled with `-fcikernel` for Core Image kernels
/// - **Standard mode** (other `.metal` files): Compiled as standard Metal render/compute shaders
///
/// Responsibility split:
/// - Plugin: discovers `.metal` source files and schedules build commands.
/// - Tool (`MetalCompilerTool`): performs actual `xcrun metal/metallib` compilation.
@main
struct MetalShaderBuildPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard target is SourceModuleTarget else {
            return []
        }

        // Scanned from the target directory rather than taken from
        // `sourceFiles`: the shaders are excluded from the target's sources so
        // the build system does not also compile them natively into a
        // `default.metallib` this plugin's per-destination libraries replace,
        // and an excluded file no longer appears in `sourceFiles`.
        let metalFiles = Self.metalFiles(under: target.directoryURL)

        guard !metalFiles.isEmpty else {
            Diagnostics.remark("No .metal files found in target \(target.name)")
            return []
        }

        let compilerTool = try context.tool(named: "MetalCompilerTool")
        return metalFiles.map { file in
            Self.buildCommand(for: file, compilerTool: compilerTool.url, workDirectory: context.pluginWorkDirectoryURL)
        }
    }

    /// Every `.metal` file under `directory`, recursively, in a stable order.
    static func metalFiles(under directory: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        var files: [URL] = []
        while let entry = enumerator?.nextObject() as? URL {
            if entry.pathExtension == "metal" {
                files.append(entry.standardizedFileURL)
            }
        }
        return files.sorted { $0.path < $1.path }
    }
}

// MARK: - Shared Logic

extension MetalShaderBuildPlugin {
    /// Creates a build command for a single Metal file, handling both CI kernel and standard modes.
    ///
    /// Three libraries per shader — device iOS, macOS, and iOS simulator — so
    /// every destination loads a library built for it and none falls back to a
    /// natively compiled `default.metallib`.
    static func buildCommand(for inputURL: URL, compilerTool: URL, workDirectory: URL) -> Command {
        let isCIKernel = inputURL.lastPathComponent.hasSuffix(".ci.metal")

        let baseName = inputURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: ".ci", with: "")

        let iosOutputURL = workDirectory.appending(path: "\(baseName).iOS.metallib")
        let macosOutputURL = workDirectory.appending(path: "\(baseName).macOS.metallib")
        let iosSimulatorOutputURL = workDirectory.appending(path: "\(baseName).iOSSimulator.metallib")

        let displayName =
            isCIKernel
            ? "Compiling CI Metal Kernel: \(inputURL.lastPathComponent)"
            : "Compiling Metal Shader: \(inputURL.lastPathComponent)"

        return .buildCommand(
            displayName: displayName,
            executable: compilerTool,
            arguments: [
                "--input", inputURL.path(percentEncoded: false),
                "--ios-output", iosOutputURL.path(percentEncoded: false),
                "--macos-output", macosOutputURL.path(percentEncoded: false),
                "--ios-simulator-output", iosSimulatorOutputURL.path(percentEncoded: false),
                "--ios-min-version", "14.0",
                "--macos-min-version", "11.0",
                // Defense in depth — tool rejects outputs that don't live
                // under this root, in case the SwiftPM plugin sandbox is
                // ever loosened in a future invocation context.
                "--allowed-root", workDirectory.path(percentEncoded: false),
            ],
            inputFiles: [inputURL],
            outputFiles: [iosOutputURL, macosOutputURL, iosSimulatorOutputURL]
        )
    }
}

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension MetalShaderBuildPlugin: XcodeBuildToolPlugin {
        func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
            let metalFiles = target.inputFiles.filter { file in
                file.url.pathExtension == "metal"
            }

            guard !metalFiles.isEmpty else {
                Diagnostics.remark("No .metal files found in Xcode target \(target.displayName)")
                return []
            }

            let compilerTool = try context.tool(named: "MetalCompilerTool")
            return metalFiles.map { file in
                Self.buildCommand(
                    for: file.url, compilerTool: compilerTool.url, workDirectory: context.pluginWorkDirectoryURL)
            }
        }
    }
#endif
