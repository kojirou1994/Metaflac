// swift-tools-version:5.2

import PackageDescription

let package = Package(
  name: "Metaflac",
  products: [
    // pure swift🦄️
    .library(
      name: "Metaflac",
      targets: ["Metaflac"]),
  ],
  dependencies: [
    .package(url: "https://github.com/kojirou1994/URLFileManager.git", from: "0.0.1"),
    .package(url: "https://github.com/kojirou1994/Kwift.git", .upToNextMinor(from: "0.7.1"))
  ],
  targets: [
    .target(
      name: "Metaflac",
      dependencies: [
        "URLFileManager",
        .product(name: "KwiftUtility", package: "Kwift")
      ]),
    .target(
      name: "Metaflac-Demo",
      dependencies: ["Metaflac"]),
    .testTarget(
      name: "MetaflacTests",
      dependencies: ["Metaflac"]),
  ]
)
