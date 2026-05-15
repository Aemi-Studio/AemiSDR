// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "CAPrivateAPIProbe",
    platforms: [
        .iOS(.v16),
    ],
    targets: [
        .executableTarget(
            name: "CAPrivateAPIProbe",
            path: ".",
            sources: ["CAPrivateAPIProbeApp.swift"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
