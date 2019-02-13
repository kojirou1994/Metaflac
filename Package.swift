// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Metaflac",
    products: [
        .library(
            name: "Metaflac",
            targets: ["Metaflac"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kojirou1994/Kwift", from: "0.0.5"),
        .package(url: "https://github.com/pointfreeco/swift-nonempty.git", from: "0.1.2")
    ],
    targets: [
        .target(
            name: "Metaflac",
            dependencies: ["Kwift", "NonEmpty"]),
        .target(
            name: "Metaflac-Demo",
            dependencies: ["Metaflac"]),
        .testTarget(
            name: "MetaflacTests",
            dependencies: ["Metaflac"]),
    ]
)
