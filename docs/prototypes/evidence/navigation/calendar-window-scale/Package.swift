// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "PlannerCalendarWindowScaleProbe",
  platforms: [.macOS("27.0")],
  dependencies: [.package(path: "/Users/dinh-van.colomban/Workspace/private/planner/Packages/PlannerCore")],
  targets: [
    .executableTarget(
      name: "CalendarWindowScaleProbe",
      dependencies: [.product(name: "PlannerCore", package: "PlannerCore")])
  ])
