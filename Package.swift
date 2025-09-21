// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "AemiSDR",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(
            name: "AemiSDR",
            targets: ["AemiSDR"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AemiSDR",
            exclude: ["Shaders/"],
            resources: [.copy("Resources/AemiSDR.metallib")],
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6),
            ]
        ),
    ],
    swiftLanguageModes: [.version("6.2")]
)
