// swift-tools-version: 6.4

import PackageDescription

let package = Package(
  name: "PlannerCore",
  platforms: [.iOS("27.0"), .macOS("27.0")],
  products: [.library(name: "PlannerCore", targets: ["PlannerCore"])],
  targets: [
    .target(name: "PlannerCore"),
    .testTarget(name: "PlannerCoreTests", dependencies: ["PlannerCore"]),
    .testTarget(name: "PlannerCoreStoreTests", dependencies: ["PlannerCore"]),
  ]
)
