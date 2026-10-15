// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "PlannerCalendarDistinctProbe",
  platforms: [.macOS("27.0")],
  dependencies: [
    .package(path: "/Users/dinh-van.colomban/Workspace/private/planner/Packages/PlannerCore")
  ],
  targets: [
    .executableTarget(
      name: "CalendarRetentionProbe",
      dependencies: [.product(name: "PlannerCore", package: "PlannerCore")])
  ])
