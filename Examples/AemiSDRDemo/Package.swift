// swift-tools-version:6.3

import PackageDescription

let package = Package(
    name: "AemiSDRDemo",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/Aemi-Studio/AemiSDR.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "AemiSDRDemo",
            dependencies: [
                .product(name: "AemiSDR", package: "AemiSDR"),
            ]
        ),
    ]
)
