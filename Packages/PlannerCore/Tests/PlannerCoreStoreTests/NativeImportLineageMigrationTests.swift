import Foundation
import PlannerCore
import Testing

struct NativeImportLineageMigrationTests {
  @Test func genuineV15MigrationPreservesGraphBudgetsRecoveryAndCreationReplay() async throws {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: NativeLineageMigrationFixtureBundle.self)
    #endif
    let fixture = try #require(
      bundle.url(forResource: "SchemaV15", withExtension: nil, subdirectory: "Fixtures"))
    let directory = try makePlannerStoreFixtureDirectory()
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      [String: String].self,
      from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    let itemIdentifier = try #require(manifest["itemId"].flatMap(UUID.init(uuidString:)))
    let operationIdentifier = try #require(
      manifest["creationOperationId"].flatMap(UUID.init(uuidString:)))
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let shareConfiguration = PlannerStorageConfiguration(
      storeURL: configuration.storeURL, controlURL: configuration.controlURL,
      recoveryDirectoryURL: configuration.recoveryDirectoryURL,
      processRole: .shareExtension, storageMode: .localOnly)
    let originalControl = try Data(contentsOf: configuration.controlURL)
    let share = Planner(configuration: shareConfiguration)
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      throw CancellationError()
    }
    #expect(try Data(contentsOf: configuration.controlURL) == originalControl)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let exported) = await planner.exportData(session: session),
      case .source(.item(let item)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: itemIdentifier))),
      let notesHash = item.fieldHashes[.notes]
    else { throw CancellationError() }
    #expect(
      exported == (try Data(contentsOf: fixture.appendingPathComponent("expected-portable.json"))))
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: itemIdentifier, changes: .init(notes: .set("Migrated note")),
            expectedFieldHashes: [.notes: notesHash]))
      ).outcome,
      case .applied(let replayed, .complete) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session,
          command: .createItem(
            content: .init(
              title: "V15 Museum", notes: "Saved on version 15",
              estimate: .init(minutes: 120, displayUnit: .hour))))
      ).outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else { throw CancellationError() }
    #expect(replayed.generated == [.init(kind: .item, id: itemIdentifier)])
    #expect(namespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 18)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let restored)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .item, id: itemIdentifier)))
    else { throw CancellationError() }
    #expect(restored.content.notes == "Migrated note")
    #expect(restored.sourceLifetimeId == item.sourceLifetimeId)
  }
}

private final class NativeLineageMigrationFixtureBundle: NSObject {}
