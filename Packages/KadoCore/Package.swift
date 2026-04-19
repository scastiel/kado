// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KadoCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "KadoCore", targets: ["KadoCore"])
    ],
    targets: [
        .target(
            name: "KadoCore",
            resources: [.process("Resources")]
        )
    ]
)
