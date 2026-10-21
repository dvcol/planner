import Darwin
import Foundation

private struct PlannerStoreFixtureRecord: Codable {
  let formatVersion: Int
  let directory: String
  let hostProcessIdentifier: Int32
}

func makePlannerStoreFixtureDirectory() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
    .appending(path: "PlannerStoreFixtures", directoryHint: .isDirectory)
    .appending(path: UUID().uuidString, directoryHint: .isDirectory)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let canonicalDirectory = try directory.withUnsafeFileSystemRepresentation { fileSystemPath in
    guard let fileSystemPath, let resolvedFileSystemPath = realpath(fileSystemPath, nil) else {
      throw CocoaError(.fileReadUnknown)
    }
    defer { free(resolvedFileSystemPath) }
    return String(cString: resolvedFileSystemPath)
  }
  let record = PlannerStoreFixtureRecord(
    formatVersion: 1, directory: canonicalDirectory,
    hostProcessIdentifier: ProcessInfo.processInfo.processIdentifier)
  let encoded = try JSONEncoder().encode(record)
  try encoded.write(to: directory.appending(path: ".planner-store-fixture.json"), options: .atomic)
  // SwiftData can retain connections past test teardown; the runner cleans up after host exit.
  print("PLANNER_STORE_FIXTURE \(String(decoding: encoded, as: UTF8.self))")
  return directory.appending(path: "dataset", directoryHint: .isDirectory)
}
