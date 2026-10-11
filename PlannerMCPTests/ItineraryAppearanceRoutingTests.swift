import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItineraryAppearanceRoutingTests {
  @Test
  func exactDirectAndExpandedCompletionOverHTTPRetainsGlobalPrecedenceAndIndependentLocalFlags()
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
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    var entryIds: [UUID] = []
    for source in [item, item, list, list] {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      entryIds.append(identifier)
    }
    let appearances: [[String: Any]] = [
      [
        "kind": "directItineraryItem", "itineraryId": itinerary.id.uuidString,
        "entryId": entryIds[0].uuidString,
      ],
      [
        "kind": "directItineraryItem", "itineraryId": itinerary.id.uuidString,
        "entryId": entryIds[1].uuidString,
      ],
      [
        "kind": "expandedListItem", "itineraryId": itinerary.id.uuidString,
        "listEntryId": entryIds[2].uuidString, "membershipId": membershipId.uuidString,
      ],
      [
        "kind": "expandedListItem", "itineraryId": itinerary.id.uuidString,
        "listEntryId": entryIds[3].uuidString, "membershipId": membershipId.uuidString,
      ],
    ]
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      func execute(_ scope: [String: Any], done: Bool, operationId: UUID = UUID()) async throws
        -> [String: Any]
      {
        try toolValue(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_execute",
              arguments: [
                "formatVersion": 1, "operationId": operationId.uuidString,
                "command": ["type": "setCompletion", "scope": scope, "done": done],
              ])))
      }
      func read(_ appearance: [String: Any]) async throws -> [String: Any] {
        let outcome = try toolValue(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_read",
              arguments: [
                "formatVersion": 1, "request": ["kind": "appearance", "appearance": appearance],
              ])))
        return try #require(outcome["value"] as? [String: Any])
      }
      let direct = try await execute(
        ["kind": "appearance", "appearance": appearances[0]], done: true)
      guard direct["state"] as? String == "applied" else {
        Issue.record("Exact direct itinerary completion must apply over actual HTTP.")
        await listener.stop()
        return
      }
      let expandedOperationId = UUID()
      let expandedScope: [String: Any] = ["kind": "appearance", "appearance": appearances[2]]
      let expanded = try await execute(expandedScope, done: true, operationId: expandedOperationId)
      #expect(expanded["state"] as? String == "applied")
      let affected = try #require(
        (expanded["result"] as? [String: Any])?["affected"] as? [[String: Any]])
      let context = try #require(affected.first { $0["kind"] as? String == "expandedCompletion" })
      #expect(Set(context.keys) == ["kind", "appearance"])
      #expect(
        NSDictionary(dictionary: try #require(context["appearance"] as? [String: Any])).isEqual(
          to: appearances[2]))
      for (index, appearance) in appearances.enumerated() {
        let value = try await read(appearance)
        #expect(value["localDone"] as? Bool == (index == 0 || index == 2))
        #expect(value["effectiveDone"] as? Bool == (index == 0 || index == 2))
        #expect(value["globalDone"] as? Bool == false)
        #expect((value["source"] as? [String: Any])?["id"] as? String == item.id.uuidString)
        #expect(
          NSDictionary(dictionary: try #require(value["appearance"] as? [String: Any])).isEqual(
            to: appearance))
      }
      _ = try await execute(["kind": "globalItem", "itemId": item.id.uuidString], done: true)
      _ = try await execute(expandedScope, done: false)
      let inherited = try await read(appearances[2])
      #expect(inherited["globalDone"] as? Bool == true)
      #expect(inherited["localDone"] as? Bool == false)
      #expect(inherited["effectiveDone"] as? Bool == true)
      _ = try await execute(["kind": "globalItem", "itemId": item.id.uuidString], done: false)
      _ = try await execute(["kind": "appearance", "appearance": appearances[3]], done: true)
      let replay = try await execute(expandedScope, done: true, operationId: expandedOperationId)
      #expect(NSDictionary(dictionary: replay).isEqual(to: expanded))
      let retained = try await read(appearances[2])
      #expect(retained["globalDone"] as? Bool == false)
      #expect(retained["localDone"] as? Bool == false)
      #expect(retained["effectiveDone"] as? Bool == false)
      let otherWriter = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let otherSession) = await otherWriter.bootstrap(),
        case .source(.item(let originalItem)) = await otherWriter.read(
          session: otherSession, request: .source(item)),
        case .applied(_, .complete) = await otherWriter.execute(
          .init(
            operationId: UUID(), session: otherSession,
            command: .editItem(
              sourceId: item.id, changes: .init(notes: .set("Live notes")),
              expectedFieldHashes: [.notes: try #require(originalItem.fieldHashes[.notes])]))
        ).outcome
      else { throw CancellationError() }
      let live = try await read(appearances[3])
      #expect((live["content"] as? [String: Any])?["notes"] as? String == "Live notes")
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.itinerary(let current)) = await reopened.read(
          session: reopenedSession, request: .source(itinerary)),
        case .appearance(let standalone) = await reopened.read(
          session: reopenedSession,
          request: .appearance(
            .listMembership(listId: list.id, membershipId: membershipId))),
        case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(
          request: .namespaces),
        let namespace = namespaces.first,
        let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
        case .selected(let recovery) = await reopened.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      #expect(current.progress.totalCount == 4 && current.progress.doneCount == 2)
      #expect(!standalone.localDone && !standalone.effectiveDone && !standalone.globalDone)
      let contexts = recovery.decodedBackup.backup.expandedCompletions
      #expect(contexts.count == 2)
      #expect(contexts.first { $0.context.listEntryId == entryIds[2] }?.localDone == false)
      #expect(contexts.first { $0.context.listEntryId == entryIds[3] }?.localDone == true)
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

  private func toolValue(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    let response = try #require(exchange.1 as? HTTPURLResponse)
    #expect(response.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let result = try #require(envelope["result"] as? [String: Any])
    #expect(result["isError"] as? Bool == false)
    let structured = try #require(result["structuredContent"] as? [String: Any])
    let text = try #require((result["content"] as? [[String: Any]])?.first?["text"] as? String)
    let textValue = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textValue).isEqual(to: structured))
    return structured
  }
}
