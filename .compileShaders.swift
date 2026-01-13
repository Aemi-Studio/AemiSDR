#!/usr/bin/env swift

import Foundation

/// Script to compile Metal CI kernels for the AemiSDR package
/// This script compiles .ci.metal files to .ci.metallib files and places them in the Resources folder

// MARK: - Configuration

let metalFileName = "AemiSDR.ci.metal"
let outputLibraryName = "AemiSDR.metallib"
let shadersPath = "Sources/AemiSDR/Shaders"
let resourcesPath = "Sources/AemiSDR/Resources"

// MARK: - Helper Functions

func executeCommand(_ command: String, arguments: [String]) throws -> String {
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

    guard process.terminationStatus == 0 else {
        throw CompilationError.commandFailed(command: "\(command) \(arguments.joined(separator: " "))", output: output)
    }

    return output
}

func fileExists(at path: String) -> Bool {
    return FileManager.default.fileExists(atPath: path)
}

func createDirectoryIfNeeded(at path: String) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
}

// MARK: - Error Types

enum CompilationError: Error {
    case fileNotFound(String)
    case commandFailed(command: String, output: String)
    case directoryCreationFailed(String)
}

extension CompilationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .commandFailed(let command, let output):
            return "Command failed: \(command)\nOutput: \(output)"
        case .directoryCreationFailed(let path):
            return "Failed to create directory: \(path)"
        }
    }
}

// MARK: - Main Compilation Function

func compileMetalShaders() throws {
    print("Compiling Metal CI kernels for AemiSDR...")

    // Verify source file exists
    let metalFilePath = "\(shadersPath)/\(metalFileName)"
    guard fileExists(at: metalFilePath) else {
        throw CompilationError.fileNotFound(metalFilePath)
    }

    print("[OK] Found Metal source: \(metalFilePath)")

    // Create resources directory if it doesn't exist
    try createDirectoryIfNeeded(at: resourcesPath)
    print("[OK] Resources directory ready: \(resourcesPath)")

    // Define temporary and output paths
    let tempAirFile = "AemiSDR.ci.air"
    let outputMetalLibPath = "\(resourcesPath)/\(outputLibraryName)"

    // Step 1: Compile .ci.metal to .ci.air
    print("Compiling Metal source to AIR...")

    let metalArgs = [
        "-c",
        "-fcikernel",
        metalFilePath,
        "-o",
        tempAirFile
    ]

    do {
        let metalOutput = try executeCommand("/usr/bin/xcrun", arguments: ["metal"] + metalArgs)
        if !metalOutput.isEmpty {
            print("Metal compiler output: \(metalOutput)")
        }
        print("[OK] Generated AIR file: \(tempAirFile)")
    } catch {
        // Clean up on failure
        try? FileManager.default.removeItem(atPath: tempAirFile)
        throw error
    }

    // Step 2: Create .ci.metallib from .ci.air
    print("Creating Metal library...")

    let metallibArgs = [
        "-cikernel",
        tempAirFile,
        "-o",
        outputMetalLibPath
    ]

    do {
        let metallibOutput = try executeCommand("/usr/bin/xcrun", arguments: ["metallib"] + metallibArgs)
        if !metallibOutput.isEmpty {
            print("MetalLib output: \(metallibOutput)")
        }
        print("[OK] Generated Metal library: \(outputMetalLibPath)")
    } catch {
        // Clean up on failure
        try? FileManager.default.removeItem(atPath: tempAirFile)
        throw error
    }

    // Step 3: Clean up temporary AIR file
    do {
        try FileManager.default.removeItem(atPath: tempAirFile)
        print("[OK] Cleaned up temporary file: \(tempAirFile)")
    } catch {
        print("[WARN] Could not remove temporary file \(tempAirFile): \(error)")
    }

    print("Metal shader compilation completed successfully!")
    print("Output: \(outputMetalLibPath)")
}

// MARK: - Script Entry Point

do {
    try compileMetalShaders()
} catch {
    print("[ERROR] Compilation failed: \(error)")
    exit(1)
}
