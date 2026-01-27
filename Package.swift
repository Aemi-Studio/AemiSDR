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
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "AemiSDR",
            targets: ["AemiSDR"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/g-cqd/InternedStrings.git", branch: "main")
    ],
    targets: [
        // Main library target
        .target(
            name: "AemiSDR",
            dependencies: [
                .product(name: "InternedStrings", package: "InternedStrings")
            ],
            resources: [
                .process("Previews/Assets.xcassets"),
            ],
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "AemiSDRShaderPlugin")
            ]
        ),

        // Executable tool for compiling Metal shaders (runs on macOS during build)
        .executableTarget(
            name: "MetalCompilerTool"
        ),

        // Build tool plugin that compiles .ci.metal files
        .plugin(
            name: "AemiSDRShaderPlugin",
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
        )
    ]
)
