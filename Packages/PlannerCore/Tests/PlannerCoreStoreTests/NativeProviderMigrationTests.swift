import Foundation
import PlannerCore
import Testing

struct NativeProviderMigrationTests {
  @Test func genuineSchema17MigrationPreservesOriginsGraphAndReceipt() async throws {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: NativeProviderMigrationFixtureBundle.self)
    #endif
    let fixture = try #require(
      bundle.url(forResource: "SchemaV17", withExtension: nil, subdirectory: "Fixtures"))
    let directory = try makePlannerStoreFixtureDirectory()
    try FileManager.default.copyItem(at: fixture, to: directory)
    let metadata = try #require(
      JSONSerialization.jsonObject(
        with: Data(contentsOf: fixture.appendingPathComponent("producer.json"))) as? [String: Any])
    #expect(metadata["sourceCommit"] as? String == "0bbeb80")
    #expect(metadata["storageSchemaVersion"] as? Int == 17)
    let operationIdentifier = try #require(
      (metadata["seedOperationId"] as? String).flatMap(UUID.init(uuidString:)))
    let expected = try Data(contentsOf: fixture.appendingPathComponent("expected-portable.json"))
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let share = Planner(
      configuration: .init(
        storeURL: configuration.storeURL, controlURL: configuration.controlURL,
        recoveryDirectoryURL: configuration.recoveryDirectoryURL,
        processRole: .shareExtension, storageMode: .localOnly))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      throw CancellationError()
    }
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let migrated) = await planner.exportData(session: session),
      case .appliedRecoveryComplete(let originalResult, _) = await planner.operationStatus(
        session: session, operationId: operationIdentifier),
      case .decoded(let originalBackup) = planner.decodeImport(
        try Data(contentsOf: fixture.appendingPathComponent("seed-import.json"))),
      case .applied(let replayed, .complete) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session,
          command: .applyImport(backup: originalBackup))
      ).outcome
    else { throw CancellationError() }
    let actual = try #require(JSONSerialization.jsonObject(with: migrated) as? [String: Any])
    #expect(
      NSDictionary(dictionary: actual).isEqual(
        to: try canonicalPortableFixtureExpectations(expected)))
    #expect(replayed == originalResult)
    #expect(originalResult.importSummary?.imports.count == 7)
    guard case .decoded(let decoded) = planner.decodeImport(migrated),
      let item = decoded.backup.items.first,
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
      ).outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(namespace.acknowledgedSnapshot?.storageSchemaVersion == 21)
    let graph = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let recoveryGraph = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: graph).isEqual(to: recoveryGraph))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after)
  }
}

private final class NativeProviderMigrationFixtureBundle: NSObject {}
