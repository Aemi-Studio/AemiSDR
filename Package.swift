// swift-tools-version:6.3

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
        // Pinned by revision, the ecosystem's mechanism (TerminalKit ADR-0005): a fresh clone resolves to the graph a
        // developer tested, and moving the pin is a reviewed commit. CI resolves; it never updates (ADR-0004).
        .package(
            url: "https://github.com/Aemi-Studio/aemi.git",
            revision: "afc1be3d578045b381e76f6b1712a81b39956ced"
        ),
        // Typed, verified private-API access (docs/adr/0002), published independently of InternedStrings.
        .package(
            url: "https://github.com/g-cqd/Abysm.git",
            revision: "368f8f7c939c42f0e0672cb859b76d48f85dd6b2"
        ),
    ],
    targets: [
        // Main library target
        .target(
            name: "AemiSDR",
            dependencies: [
                .product(name: "InternedStrings", package: "aemi"),
                .product(name: "Abysm", package: "Abysm"),
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
            name: "MetalCompilerTool",
            dependencies: ["MetalCompilerCore"]
        ),

        // The tool's logic, as a library so it can be tested (a pipe-draining regression, the deployment floor,
        // output confinement). macOS only; empty elsewhere.
        .target(
            name: "MetalCompilerCore",
            swiftSettings: swiftSettings
        ),

        // Build tool plugin that discovers `.metal` sources and schedules compiler invocations.
        .plugin(
            name: "MetalShaderBuildPlugin",
            capability: .buildTool(),
            dependencies: [
                .target(name: "MetalCompilerTool")
            ]
        ),

        .testTarget(
            name: "MetalCompilerCoreTests",
            dependencies: ["MetalCompilerCore"],
            swiftSettings: swiftSettings
        ),

        // Tests
        .testTarget(
            name: "AemiSDRTests",
            dependencies: ["AemiSDR"],
            swiftSettings: swiftSettings
        ),
    ]
)
