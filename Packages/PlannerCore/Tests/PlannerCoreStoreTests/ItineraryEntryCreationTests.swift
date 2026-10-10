import Foundation
import PlannerCore
import Testing

struct ItineraryEntryCreationTests {
  @Test func repeatedEntriesKeepLiveSourcesIndependentProgressAndDurableEvidence() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome
      else {
        Issue.record("Save every entry through the public durable writer.")
        throw CancellationError()
      }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Original"))).generated.first
    )
    let list = try #require(
      try await save(.createList(content: .init(name: "Stops"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    let otherItinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Another plan"))).generated.first)
    let membership = try #require(
      try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
        .generatedReferences.first)
    guard case .membership(let membershipId, _, _) = membership,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.itinerary(let originalItinerary)) = await planner.read(
        session: session, request: .source(itinerary))
    else {
      throw CancellationError()
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: membershipId)), done: true
      ))
    let firstOperation = PlannerOperation(
      operationId: UUID(), session: session,
      command: .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last))
    guard
      case .applied(let first, .complete(let firstCheckpoint)) = await planner.execute(
        firstOperation
      ).outcome
    else {
      Issue.record("Adding an Item must create a distinct live itinerary entry.")
      return
    }
    var references = [try #require(first.generatedReferences.first)]
    for source in [list, item, list] {
      references.append(
        try #require(
          try await save(
            .addItineraryEntry(
              itineraryId: itinerary.id, source: source, placement: .last)
          ).generatedReferences.first))
    }
    guard
      case .source(.itinerary(let beforeGlobal)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.list(let completedList)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    #expect(references.count == 4)
    #expect(Set(try references.map { try JSONEncoder().encode($0) }).count == 4)
    #expect(beforeGlobal.references == references)
    #expect(beforeGlobal.progress.totalCount == 4)
    #expect(beforeGlobal.progress.doneCount == 0)
    #expect(beforeGlobal.progress.state == .partial)
    #expect(completedList.progress.state == .complete)
    #expect(beforeGlobal.fieldHashes == originalItinerary.fieldHashes)
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: true))
    _ = try await save(.setArchive(source: item, archived: true))
    _ = try await save(
      .editItem(
        sourceId: item.id, changes: .init(notes: .set("Live update")),
        expectedFieldHashes: [.notes: try #require(originalItem.fieldHashes[.notes])]))
    _ = try await save(
      .editItinerary(
        sourceId: itinerary.id, changes: .init(title: .set("Updated plan")),
        expectedFieldHashes: [.title: try #require(originalItinerary.fieldHashes[.title])]))
    _ = try await save(.createItem(content: .init(title: "Unrelated")))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.itinerary(let untouched)) = await reopened.read(
        session: reopenedSession, request: .source(otherItinerary)),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: firstOperation.operationId, session: reopenedSession,
          command: firstOperation.command)
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 15))
    else { throw CancellationError() }
    #expect(retained.content.title == "Updated plan")
    #expect(retained.references == references)
    #expect(retained.progress.totalCount == 4)
    #expect(retained.progress.doneCount == 4)
    #expect(retained.progress.state == .complete)
    #expect(untouched.progress.state == .empty)
    #expect(untouched.references.isEmpty)
    #expect(replay == first)
    #expect(replayCheckpoint == firstCheckpoint)
    #expect(namespace.preparedProposals.isEmpty)
    let payload = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    let entries = try #require(payload["itineraryEntries"] as? [[String: Any]])
    #expect(entries.count == 4)
    #expect(entries.allSatisfy { $0["id"] as? String == $0["lifetimeId"] as? String })
    #expect(
      entries.filter { ($0["source"] as? [String: Any])?["kind"] as? String == "item" }.allSatisfy {
        $0["localDone"] as? Bool == false
      })
    #expect(
      entries.filter { ($0["source"] as? [String: Any])?["kind"] as? String == "list" }.allSatisfy {
        $0["localDone"] is NSNull
      })
  }
}
