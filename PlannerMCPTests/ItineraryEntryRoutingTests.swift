import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItineraryEntryRoutingTests {
  @Test func repeatedEntriesOverHTTPPreserveSourcesFlagsSavedOrderAndClosedContextAcrossReplay()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      throw CancellationError()
    }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: datasetSession, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Keep notes"))).generated
        .first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: datasetSession, request: .source(item)),
      case .source(.list(let originalList)) = await planner.read(
        session: datasetSession, request: .source(list))
    else { throw CancellationError() }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      func execute(_ command: [String: Any], operationId: UUID = UUID()) async throws -> [String:
        Any]
      {
        try toolValue(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_execute",
              arguments: [
                "formatVersion": 1, "operationId": operationId.uuidString, "command": command,
              ])), isError: false)
      }
      let originalAdditionId = UUID()
      let originalAddition: [String: Any] = [
        "type": "addItineraryEntry", "itineraryId": itinerary.id.uuidString,
        "source": ["kind": "item", "id": item.id.uuidString], "placement": ["kind": "last"],
      ]
      let first = try await execute(originalAddition, operationId: originalAdditionId)
      guard first["state"] as? String == "applied" else {
        Issue.record("The advertised itinerary entry command must apply over actual HTTP.")
        await listener.stop()
        return
      }
      func entryId(_ outcome: [String: Any]) throws -> UUID {
        #expect(outcome["state"] as? String == "applied")
        let generated = try #require(
          (outcome["result"] as? [String: Any])?["generated"] as? [[String: Any]])
        #expect(generated.count == 1)
        let entry = try #require(generated.first)
        #expect(entry["kind"] as? String == "itineraryEntry")
        #expect((entry["owner"] as? [String: Any])?["id"] as? String == itinerary.id.uuidString)
        let spelling = try #require(entry["id"] as? String)
        return try #require(UUID(uuidString: spelling))
      }
      var entryIds = [try entryId(first)]
      for source in [item, list, list] {
        let outcome = try await execute([
          "type": "addItineraryEntry", "itineraryId": itinerary.id.uuidString,
          "source": ["kind": source.kind.rawValue, "id": source.id.uuidString],
          "placement": ["kind": "last"],
        ])
        entryIds.append(try entryId(outcome))
      }
      #expect(Set(entryIds).count == 4)
      _ = try await save(
        .setCompletion(
          scope: .appearance(
            .directItineraryItem(itineraryId: itinerary.id, entryId: entryIds[0])), done: true))
      _ = try await save(
        .setCompletion(
          scope: .appearance(
            .expandedListItem(
              itineraryId: itinerary.id, listEntryId: entryIds[2], membershipId: membershipId)),
          done: true))
      let reordered = try await execute([
        "type": "reorderItineraryEntry", "itineraryId": itinerary.id.uuidString,
        "entryId": entryIds[3].uuidString, "placement": ["kind": "first"],
      ])
      #expect(reordered["state"] as? String == "applied")
      let removalId = UUID()
      let removal: [String: Any] = [
        "type": "removeItineraryEntry", "itineraryId": itinerary.id.uuidString,
        "entryId": entryIds[0].uuidString,
      ]
      let removed = try await execute(removal, operationId: removalId)
      #expect(removed["state"] as? String == "applied")
      let fresh = try entryId(try await execute(originalAddition))
      #expect(!entryIds.contains(fresh))
      let additionReplay = try await execute(originalAddition, operationId: originalAdditionId)
      let removalReplay = try await execute(removal, operationId: removalId)
      #expect(NSDictionary(dictionary: additionReplay).isEqual(to: first))
      #expect(NSDictionary(dictionary: removalReplay).isEqual(to: removed))
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.itinerary(let current)) = await reopened.read(
          session: reopenedSession, request: .source(itinerary)),
        case .source(.item(let retainedItem)) = await reopened.read(
          session: reopenedSession, request: .source(item)),
        case .source(.list(let retainedList)) = await reopened.read(
          session: reopenedSession, request: .source(list)),
        case .appearance(let freshAppearance) = await reopened.read(
          session: reopenedSession,
          request: .appearance(
            .directItineraryItem(itineraryId: itinerary.id, entryId: fresh))),
        case .appearance(let retainedExpanded) = await reopened.read(
          session: reopenedSession,
          request: .appearance(
            .expandedListItem(
              itineraryId: itinerary.id, listEntryId: entryIds[2], membershipId: membershipId))),
        case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(
          request: .namespaces),
        let namespace = namespaces.first,
        let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
        case .selected(let recovery) = await reopened.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      let ordered = current.references.compactMap { reference -> UUID? in
        if case .itineraryEntry(let identifier, _, _) = reference { return identifier }
        return nil
      }
      #expect(ordered == [entryIds[3], entryIds[1], entryIds[2], fresh])
      #expect(current.progress.totalCount == 4 && current.progress.doneCount == 1)
      #expect(!freshAppearance.localDone && !freshAppearance.effectiveDone)
      #expect(retainedExpanded.localDone && retainedExpanded.effectiveDone)
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(retainedItem.content.notes == "Keep notes")
      #expect(retainedList.updatedAt == originalList.updatedAt)
      #expect(retainedList.fieldHashes == originalList.fieldHashes)
      #expect(recovery.decodedBackup.backup.itineraryEntries.count == 4)
      #expect(recovery.decodedBackup.backup.expandedCompletions.count == 1)
      #expect(
        recovery.decodedBackup.backup.deletionMarkers.first?.target
          == .itineraryEntry(id: entryIds[0], lifetimeId: entryIds[0]))
      let sourceRead = try toolValue(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1,
              "request": [
                "kind": "source", "source": ["kind": "itinerary", "id": itinerary.id.uuidString],
              ],
            ])), isError: false)
      let serialized = try #require(sourceRead["value"] as? [String: Any])
      #expect((serialized["progress"] as? [String: Any])?["totalCount"] as? String == "4")
      #expect((serialized["progress"] as? [String: Any])?["doneCount"] as? String == "1")
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func request(endpoint: URL, name: String, arguments: [String: Any]) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 1, "method": "tools/call",
      "params": ["name": name, "arguments": arguments],
    ])
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.timeoutInterval = 5
    return request
  }

  private func toolValue(_ exchange: (Data, URLResponse), isError: Bool) throws -> [String: Any] {
    let response = try #require(exchange.1 as? HTTPURLResponse)
    #expect(response.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let result = try #require(envelope["result"] as? [String: Any])
    #expect(result["isError"] as? Bool == isError)
    let structured = try #require(result["structuredContent"] as? [String: Any])
    let content = try #require(result["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let textValue = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textValue).isEqual(to: structured))
    return structured
  }
}
