// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TaskomaticCore",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [.library(name: "TaskomaticCore", targets: ["TaskomaticCore"])],
  targets: [
    .target(name: "TaskomaticCore"),
    .testTarget(name: "TaskomaticCoreTests", dependencies: ["TaskomaticCore"]),
  ]
)
