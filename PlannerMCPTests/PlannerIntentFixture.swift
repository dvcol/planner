import Foundation
import PlannerCore

@testable import Planner

private struct PlannerIntentFixtureRecord: Codable {
  let formatVersion: Int
  let directory: String
  let hostProcessIdentifier: Int32
}

@MainActor
func makePlannerIntentStorage() throws -> (
  directory: URL, configuration: PlannerStorageConfiguration, store: SavedPlannerStore
) {
  let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
    .appending(path: "PlannerIntentFixtures", directoryHint: .isDirectory)
    .appending(path: UUID().uuidString, directoryHint: .isDirectory)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let record = PlannerIntentFixtureRecord(
    formatVersion: 1, directory: directory.path,
    hostProcessIdentifier: ProcessInfo.processInfo.processIdentifier)
  let encoded = try JSONEncoder().encode(record)
  try encoded.write(to: directory.appending(path: ".planner-intent-fixture.json"), options: .atomic)
  // The runner removes these directories after the host and its SQLite connections have exited.
  print("PLANNER_INTENT_FIXTURE \(String(decoding: encoded, as: UTF8.self))")
  let configuration = PlannerStorageConfiguration(
    storeURL: directory.appending(path: "store/Planner.sqlite"),
    controlURL: directory.appending(path: "control/writer"),
    recoveryDirectoryURL: directory.appending(path: "recovery"),
    processRole: .mainApplication, storageMode: .localOnly)
  return (directory, configuration, SavedPlannerStore(configuration: configuration))
}
