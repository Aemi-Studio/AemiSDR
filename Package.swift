// swift-tools-version:6.2

import PackageDescription

private let swiftSettings: [SwiftSetting] = [
    .strictMemorySafety(),
    .enableExperimentalFeature("StrictConcurrency"),
    .swiftLanguageMode(.v6),
]

private let package = Package(
    name: "AemiSDR",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "AemiSDR",
            targets: ["AemiSDR"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Aemi-Studio/aemi.git", branch: "main")
    ],
    targets: [
        // Main library target
        .target(
            name: "AemiSDR",
            dependencies: [
                .product(name: "InternedStrings", package: "aemi")
            ],
            // The shader plugin compiles these into per-destination metallibs;
            // leaving them in the sources would also compile them natively
            // into a redundant default.metallib (and trips a Swift Build
            // planner warning about the bundle's executable directory).
            exclude: [
                "Shaders"
            ],
            resources: [
                .process("Previews/Assets.xcassets")
            ],
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "MetalShaderBuildPlugin")
            ]
        ),

        // Executable tool invoked by the shader plugin to run xcrun metal/metallib.
        // The plugin handles file discovery/scheduling; this tool does the compilation.
        .executableTarget(
            name: "MetalCompilerTool"
        ),

        // Build tool plugin that discovers `.metal` sources and schedules compiler invocations.
        .plugin(
            name: "MetalShaderBuildPlugin",
            capability: .buildTool(),
            dependencies: [
                .target(name: "MetalCompilerTool")
            ]
        ),

        // Tests
        .testTarget(
            name: "AemiSDRTests",
            dependencies: ["AemiSDR"],
            swiftSettings: swiftSettings
        ),
    ]
)
