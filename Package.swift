// swift-tools-version:6.2

import PackageDescription

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
        .target(
            name: "AemiSDR",
            dependencies: [
                .product(name: "InternedStrings", package: "InternedStrings")
            ],
            exclude: ["Shaders/"],
            resources: [.copy("Resources/AemiSDR.metallib")],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AemiSDRTests",
            dependencies: ["AemiSDR"],
            swiftSettings: swiftSettings
        )
    ]
)

private let swiftSettings: [SwiftSetting] = [
    .strictMemorySafety(),
    .enableExperimentalFeature("StrictConcurrency"),
    .swiftLanguageMode(.v6),
]
