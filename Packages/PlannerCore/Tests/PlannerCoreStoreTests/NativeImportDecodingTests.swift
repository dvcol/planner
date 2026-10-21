import Foundation
import PlannerCore
import Testing

struct NativeImportDecodingTests {
  @Test func bytesOnlyDecodePreservesTheIndependentCompletePortableGraphAndLineage() throws {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeImportFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(
        forResource: "portable-backup-v1", withExtension: "json",
        subdirectory: "Fixtures/PortableImport"))
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .shareExtension, storageMode: .localOnly))
    let response = planner.decodeImport(try Data(contentsOf: fixture))
    guard case .decoded(let decoded) = response else {
      Issue.record("Decode the complete independent version-1 fixture: \(response)")
      return
    }
    let backup = decoded.backup
    #expect(backup.sources.count == 7 && backup.items.count == 2 && backup.lists.count == 2)
    #expect(backup.memberships.count == 3 && backup.itineraryEntries.count == 2)
    #expect(backup.expandedCompletions.count == 2 && backup.schedules.count == 2)
    #expect(backup.labelAssociations.count == 4 && backup.ownedLinks.count == 2)
    #expect(backup.deletionMarkers.count == 1 && backup.contextAliases.count == 1)
    #expect(backup.completionChanges.count == 1 && backup.restorationFamilies.isEmpty)
    let museum = try #require(backup.items.first { $0.id.uuidString.hasSuffix("101") })
    #expect(museum.content.title == "Nezu Museum" && museum.content.notes == "Original notes")
    #expect(museum.createdAt.timeIntervalSinceReferenceDate == 10.25)
    #expect(museum.updatedAt.timeIntervalSinceReferenceDate == 20.125)
    #expect(
      museum.content.estimate?.minutes == 120 && museum.content.estimate?.displayUnit == .hour)
    #expect(museum.content.links.map(\.linkId.uuidString).map { $0.suffix(3) } == ["751", "752"])
    #expect(backup.memberships.first?.localDone == true)
    #expect(backup.contextAliases.first?.currentChangeId?.uuidString.hasSuffix("881") == true)
    #expect(backup.completionChanges.first?.done == true)
    #expect(decoded.externalBindings.isEmpty && decoded.originPaths.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }
}
