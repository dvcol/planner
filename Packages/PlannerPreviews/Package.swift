// swift-tools-version: 6.4

import PackageDescription

let package = Package(
  name: "PlannerPreviews",
  platforms: [.iOS("27.0"), .macOS("27.0")],
  products: [.library(name: "PlannerPreviews", targets: ["PlannerPreviews"])],
  dependencies: [.package(path: "../PlannerCore")],
  targets: [
    .target(name: "PlannerPreviews", dependencies: ["PlannerCore"]),
    .testTarget(name: "PlannerPreviewsTests", dependencies: ["PlannerPreviews", "PlannerCore"]),
  ]
)
