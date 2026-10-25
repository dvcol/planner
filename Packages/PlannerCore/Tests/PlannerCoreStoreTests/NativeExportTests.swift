import Foundation
import PlannerCore
import Testing

struct NativeExportTests {
  @Test func nativeExportIncludesArchivedOwnedDataAndPreservesAcknowledgementWithoutAppState()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let emptyResponse = await planner.exportData(session: session)
    guard case .exported(let emptyData) = emptyResponse else {
      Issue.record("Export the authorized complete empty dataset: \(emptyResponse)")
      return
    }
    let empty = try #require(JSONSerialization.jsonObject(with: emptyData) as? [String: Any])
    #expect(empty["format"] as? String == "planner-data")
    #expect(empty["formatVersion"] as? Int == 4)
    #expect((empty["sources"] as? [[String: Any]])?.isEmpty == true)
    guard
      case .applied(let creation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      ).outcome,
      let source = creation.generated.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: source.id), done: true))
      ).outcome,
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setArchive(source: source, archived: true))
      ).outcome,
      case .source(.item(let before)) = await planner.read(
        session: session, request: .source(source)),
      case .status(let beforeStatus) = await planner.read(session: session, request: .status),
      case .known(let beforeCheckpoint, let beforeIncomplete, _, let beforeBlocked) = beforeStatus
        .recovery,
      case .exported(let data) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let expectedKeys: Set<String> = [
      "format", "formatVersion", "sources", "memberships", "itineraryEntries",
      "expandedCompletions",
      "schedules", "labelAssociations", "ownedLinks", "deletionMarkers", "contextAliases",
      "completionChanges", "restorationFamilies", "membershipProvenance", "membershipRemovals",
    ]
    #expect(Set(object.keys) == expectedKeys)
    #expect(String(data: data, encoding: .utf8) != nil)
    let sources = try #require(object["sources"] as? [[String: Any]])
    let item = try #require(sources.first)
    let content = try #require(item["content"] as? [String: Any])
    #expect(sources.count == 1 && item["kind"] as? String == "item")
    #expect(UUID(uuidString: try #require(item["id"] as? String)) == source.id)
    #expect(
      UUID(uuidString: try #require(item["lifetimeId"] as? String)) == before.sourceLifetimeId)
    #expect(
      content["title"] as? String == "Hotel" && content["notes"] as? String == "Original notes")
    #expect(item["globalDone"] as? Bool == true && item["archived"] as? Bool == true)
    #expect(item["createdAt"] as? Double == before.createdAt.timeIntervalSinceReferenceDate)
    #expect(item["updatedAt"] as? Double == before.updatedAt.timeIntervalSinceReferenceDate)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .source(.item(let after)) = await reopened.read(
        session: reopenedSession, request: .source(source)),
      case .status(let afterStatus) = await reopened.read(
        session: reopenedSession, request: .status),
      case .known(let afterCheckpoint, let afterIncomplete, _, let afterBlocked) = afterStatus
        .recovery
    else { throw CancellationError() }
    let reopenedObject = try #require(
      JSONSerialization.jsonObject(with: reopenedData) as? [String: Any])
    #expect(NSDictionary(dictionary: reopenedObject).isEqual(to: object))
    #expect(after.updatedAt == before.updatedAt && after.fieldHashes == before.fieldHashes)
    #expect(beforeCheckpoint == checkpoint && afterCheckpoint == checkpoint)
    #expect(beforeIncomplete.isEmpty && afterIncomplete.isEmpty && !beforeBlocked && !afterBlocked)
  }
}
