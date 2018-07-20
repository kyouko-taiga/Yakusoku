// swift-tools-version:4.0

import PackageDescription

let package = Package(
  name: "Yakusoku",
  products: [
    .library(name: "Yakusoku", targets: ["Yakusoku"]),
  ],
  dependencies: [],
  targets: [
    .target(name: "Yakusoku", dependencies: []),
    .testTarget(name: "YakusokuTests", dependencies: ["Yakusoku"]),
  ]
)
