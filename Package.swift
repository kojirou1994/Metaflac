// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Metaflac",
    products: [
        // pure swift🦄️
        .library(
            name: "Metaflac",
            targets: ["Metaflac"]),
        // use metaflac cli
        .library(
            name: "MetaflacWrapper",
            targets: ["MetaflacWrapper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kojirou1994/Kwift.git", from: "0.3.1"),
        .package(url: "https://github.com/kojirou1994/URLFileManager.git", from: "0.0.1"),
        .package(url: "https://github.com/pointfreeco/swift-nonempty.git", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "Metaflac",
            dependencies: [
                "Kwift",
                "URLFileManager",
                "NonEmpty"]),
        .target(
            name: "MetaflacWrapper",
            dependencies: [
                "Executable"]),
        .target(
            name: "Metaflac-Demo",
            dependencies: ["Metaflac"]),
        .testTarget(
            name: "MetaflacTests",
            dependencies: ["Metaflac"]),
    ]
)
