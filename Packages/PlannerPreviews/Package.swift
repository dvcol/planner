// swift-tools-version: 6.4

import PackageDescription

let package = Package(
  name: "PlannerPreviews",
  platforms: [.iOS("27.0"), .macOS("27.0")],
  products: [.library(name: "PlannerPreviews", targets: ["PlannerPreviews"])],
  targets: [
    .target(name: "PlannerPreviews"),
    .testTarget(name: "PlannerPreviewsTests", dependencies: ["PlannerPreviews"]),
  ]
)
