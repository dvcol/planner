import Foundation
import PlannerCore
import Testing

struct NativeMembershipMigrationTests {
  @Test func genuineSchema18UpgradePreservesGraphAndHistoricalRecoveryEvidence() async throws {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: NativeMembershipMigrationFixtureBundle.self)
    #endif
    let fixture = try #require(
      bundle.url(forResource: "SchemaV18", withExtension: nil, subdirectory: "Fixtures"))
    let directory = try makePlannerStoreFixtureDirectory()
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      [String: String].self,
      from: Data(contentsOf: fixture.appendingPathComponent("manifest.json")))
    let itemIdentifier = try #require(manifest["itemId"].flatMap(UUID.init(uuidString:)))
    let itemLifetime = try #require(manifest["itemLifetimeId"].flatMap(UUID.init(uuidString:)))
    let operationIdentifier = try #require(
      manifest["creationOperationId"].flatMap(UUID.init(uuidString:)))
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let originalControl = try Data(contentsOf: configuration.controlURL)
    let recoveryFiles = try historicalRecoveryFiles(in: configuration.recoveryDirectoryURL)
    let share = Planner(
      configuration: .init(
        storeURL: configuration.storeURL, controlURL: configuration.controlURL,
        recoveryDirectoryURL: configuration.recoveryDirectoryURL,
        processRole: .shareExtension, storageMode: .localOnly))
    let shareResult = await share.bootstrap()
    guard case .mainAppMigrationRequired = shareResult else {
      Issue.record("Share must leave schema 18 for the main app to migrate: \(shareResult)")
      return
    }
    #expect(try Data(contentsOf: configuration.controlURL) == originalControl)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let exported) = await planner.exportData(session: session),
      case .source(.item(let item)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: itemIdentifier))),
      case .appliedRecoveryComplete(let originalResult, let originalCheckpoint) =
        await planner.operationStatus(session: session, operationId: operationIdentifier),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session,
          command: .createItem(
            content: .init(
              title: "V15 Museum", notes: "Saved on version 15",
              estimate: .init(minutes: 120, displayUnit: .hour))))
      ).outcome
    else { throw CancellationError() }
    let expected = try canonicalPortableFixtureExpectations(
      Data(contentsOf: fixture.appendingPathComponent("expected-portable.json")))
    let actual = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
    #expect(NSDictionary(dictionary: expected).isEqual(to: actual))
    #expect(item.content.notes == "Migrated note" && item.sourceLifetimeId == itemLifetime)
    #expect(originalResult == replayed && originalCheckpoint == 1 && replayCheckpoint == 1)
    let upgradedFiles = try historicalRecoveryFiles(in: configuration.recoveryDirectoryURL)
    #expect(recoveryFiles.allSatisfy { upgradedFiles[$0.key] == $0.value })
    #expect(upgradedFiles.count == recoveryFiles.count + 1)
    guard
      case .listedNamespaces(let originalNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      let originalNamespace = originalNamespaces.first,
      case .selected(let originalSnapshot) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: originalNamespace.namespaceId, checkpointGeneration: 7))
    else { throw CancellationError() }
    #expect(originalSnapshot.decodedBackup.backup.formatVersion == 2)
    let control = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: configuration.controlURL))
        as? [String: Any])
    #expect(control["schemaVersion"] as? Int == 23)
    guard
      case .applied(_, .complete(let newCheckpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: itemIdentifier), done: true))
      ).outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      case .appliedRecoveryComplete(_, let retainedCheckpoint) = await planner.operationStatus(
        session: session, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(newCheckpoint == 9 && retainedCheckpoint == 1)
    #expect(namespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 23)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let saved)) = await reopened.read(
        session: reopenedSession, request: .source(.init(kind: .item, id: itemIdentifier)))
    else { throw CancellationError() }
    #expect(saved.state.globalDone == true && saved.sourceLifetimeId == itemLifetime)
    for (relativePath, originalData) in recoveryFiles {
      #expect(
        try Data(
          contentsOf: configuration.recoveryDirectoryURL.appendingPathComponent(relativePath))
          == originalData)
    }
  }

  private func historicalRecoveryFiles(in directory: URL) throws -> [String: Data] {
    let canonicalDirectory = directory.resolvingSymlinksInPath()
    let enumerator = try #require(
      FileManager.default.enumerator(
        at: canonicalDirectory, includingPropertiesForKeys: [.isRegularFileKey])
    )
    var files: [String: Data] = [:]
    for case let file as URL in enumerator {
      guard
        file.lastPathComponent.hasPrefix("checkpoint-")
          || file.lastPathComponent.hasPrefix("proposal-")
      else { continue }
      let components = file.resolvingSymlinksInPath().pathComponents
      let rootComponents = canonicalDirectory.pathComponents
      #expect(components.starts(with: rootComponents))
      let relativePath = components.dropFirst(rootComponents.count).joined(separator: "/")
      files[relativePath] = try Data(contentsOf: file)
    }
    return files
  }
}

private final class NativeMembershipMigrationFixtureBundle: NSObject {}
