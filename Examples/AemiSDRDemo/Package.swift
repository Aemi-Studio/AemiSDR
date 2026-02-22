// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "AemiSDRDemo",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    dependencies: [
        .package(path: "../.."),
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
