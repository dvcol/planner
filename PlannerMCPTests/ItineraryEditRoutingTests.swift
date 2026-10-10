import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItineraryEditRoutingTests {
  @Test func guardedItineraryEditsOverHTTPRetainLaterContentAndTypedConflicts() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("Open the actual Core dataset before its HTTP edit journey.")
      return
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: .init(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      func execute(
        _ command: [String: Any], operationIdentifier: UUID = UUID(), isError: Bool = false
      ) async throws -> [String: Any] {
        try toolValue(
          try await httpSession.data(
            for: toolRequest(
              endpoint: endpoint, name: "planner_execute",
              arguments: [
                "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                "command": command,
              ])), isError: isError)
      }
      func create(_ type: String, content: [String: Any], kind: String) async throws -> String {
        let outcome = try await execute(["type": type, "content": content])
        try #require(outcome["state"] as? String == "applied")
        let generated = try #require(
          (outcome["result"] as? [String: Any])?["generated"] as? [[String: Any]])
        return try #require(generated.first { $0["kind"] as? String == kind }?["id"] as? String)
      }
      func read(_ identifier: String) async throws -> [String: Any] {
        let outcome = try toolValue(
          try await httpSession.data(
            for: toolRequest(
              endpoint: endpoint, name: "planner_read",
              arguments: [
                "formatVersion": 1,
                "request": ["kind": "source", "source": ["kind": "itinerary", "id": identifier]],
              ])), isError: false)
        return try #require(outcome["value"] as? [String: Any])
      }
      let food = try await create("createCategory", content: ["name": "Food"], kind: "category")
      let culture = try await create(
        "createCategory", content: ["name": "Culture"], kind: "category")
      let rain = try await create("createTag", content: ["name": "Rain"], kind: "tag")
      let sunny = try await create("createTag", content: ["name": "Sunny"], kind: "tag")
      let itinerary = try await create(
        "createItinerary",
        content: [
          "title": "Tokyo", "notes": "Keep",
          "color": ["red": 0, "green": 0, "blue": 1, "alpha": 1],
          "iconName": "map",
          "location": [
            "displayName": "Hotel", "formattedAddress": "Tokyo", "coordinate": NSNull(),
          ],
          "links": [["originalUrl": "https://example.com/route", "label": "Route"]],
          "categoryIds": [food], "tagIds": [rain],
        ], kind: "itinerary")
      let original = try await read(itinerary)
      let originalHashes = try #require(original["fieldHashes"] as? [String: String])
      let originalContent = try #require(original["content"] as? [String: Any])
      let originalLink = try #require((originalContent["links"] as? [[String: Any]])?.first)
      let linkIdentifier = try #require(originalLink["linkId"] as? String)
      let titleOperation = UUID()
      let titleCommand: [String: Any] = [
        "type": "editItinerary", "sourceId": itinerary,
        "changes": ["title": "  Tokyo café weekend  "], "expectedFieldHashes": originalHashes,
      ]
      let titleResult = try await execute(titleCommand, operationIdentifier: titleOperation)
      try #require(titleResult["state"] as? String == "applied")
      let titleRead = try await read(itinerary)
      let titleHashes = try #require(titleRead["fieldHashes"] as? [String: String])
      let patchResult = try await execute([
        "type": "editItinerary", "sourceId": itinerary,
        "changes": [
          "notes": NSNull(), "color": NSNull(), "iconName": NSNull(), "location": NSNull(),
          "links": [
            [
              "linkId": linkIdentifier, "originalUrl": "https://example.com/friday",
              "label": NSNull(),
            ]
          ],
          "categoryIds": [culture], "tagIds": [sunny],
        ], "expectedFieldHashes": originalHashes,
      ])
      try #require(patchResult["state"] as? String == "applied")
      let current = try await read(itinerary)
      let content = try #require(current["content"] as? [String: Any])
      let hashes = try #require(current["fieldHashes"] as? [String: String])
      #expect(content["title"] as? String == "  Tokyo café weekend  ")
      for field in ["notes", "color", "iconName", "location"] { #expect(content[field] is NSNull) }
      #expect(hashes["title"] == titleHashes["title"])
      #expect(current["createdAt"] as? Double == original["createdAt"] as? Double)
      #expect(content["categoryIds"] as? [String] == [culture])
      #expect(content["tagIds"] as? [String] == [sunny])
      let links = try #require(content["links"] as? [[String: Any]])
      #expect(links.first?["linkId"] as? String == linkIdentifier)
      #expect(links.first?["originalUrl"] as? String == "https://example.com/friday")
      #expect(
        Set((current["labels"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? [])
          == ["Culture", "Sunny"])
      let staleChanges: [(String, Any)] = [
        ("title", "Must not save"), ("notes", "Must not save"),
        ("color", ["red": 1, "green": 0, "blue": 0, "alpha": 1]), ("iconName", "tram"),
        (
          "location",
          ["displayName": "Museum", "formattedAddress": NSNull(), "coordinate": NSNull()]
        ),
        (
          "links",
          [
            [
              "linkId": linkIdentifier, "originalUrl": "https://example.com/stale",
              "label": NSNull(),
            ]
          ]
        ),
        ("categoryIds", [food]), ("tagIds", [rain]),
      ]
      for (field, value) in staleChanges {
        let rejected = try await execute(
          [
            "type": "editItinerary", "sourceId": itinerary,
            "changes": [field: value], "expectedFieldHashes": originalHashes,
          ], isError: true)
        #expect(rejected["state"] as? String == "rejected")
        let reason = try #require(rejected["reason"] as? [String: Any])
        let details = try #require(reason["details"] as? [String: Any])
        #expect(reason["code"] as? String == "staleEdit")
        #expect(details["kind"] as? String == "staleEdit")
        #expect(details["conflictingFields"] as? [String] == [field])
        #expect(
          details["currentFieldHashes"] as? [String: String] == [field: try #require(hashes[field])]
        )
        let values = try #require(details["currentValues"] as? [String: Any])
        #expect(NSDictionary(dictionary: values).isEqual(to: [field: try #require(content[field])]))
        #expect(rejected["result"] == nil && rejected["recovery"] == nil)
      }
      let compound = try await execute(
        [
          "type": "editItinerary", "sourceId": itinerary,
          "changes": [
            "notes": "Must not save", "color": ["red": 1, "green": 0, "blue": 0, "alpha": 1],
          ],
          "expectedFieldHashes": originalHashes,
        ], isError: true)
      let compoundDetails = try #require(
        (compound["reason"] as? [String: Any])?["details"] as? [String: Any])
      #expect(compoundDetails["conflictingFields"] as? [String] == ["color", "notes"])
      let retained = try await read(itinerary)
      #expect(NSDictionary(dictionary: retained).isEqual(to: current))
      let replayed = try await execute(titleCommand, operationIdentifier: titleOperation)
      #expect(NSDictionary(dictionary: replayed).isEqual(to: titleResult))
      #expect(
        (titleResult["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "6")
      #expect(
        (patchResult["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "7")
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        let identifier = UUID(uuidString: itinerary),
        case .source(.itinerary(let native)) = await reopened.read(
          session: reopenedSession, request: .source(.init(kind: .itinerary, id: identifier))),
        case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(
          request: .namespaces), let namespace = namespaces.first,
        case .selected(let recovery) = await reopened.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 7))
      else {
        Issue.record("HTTP edits and their complete recovery must survive a public Core reopen.")
        await listener.stop()
        return
      }
      #expect(native.content.title == "  Tokyo café weekend  ")
      #expect(
        native.content.notes == nil && native.content.color == nil && native.content.iconName == nil
          && native.content.location == nil)
      #expect(native.content.links.first?.linkId.uuidString == linkIdentifier)
      #expect(Set(native.labels.map(\.name)) == ["Culture", "Sunny"])
      #expect(namespace.preparedProposals.isEmpty)
      #expect(recovery.decodedBackup.backup.labelAssociations.count == 2)
      #expect(recovery.decodedBackup.backup.deletionMarkers.count == 2)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func toolRequest(endpoint: URL, name: String, arguments: [String: Any]) throws
    -> URLRequest
  {
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
    let tool = try #require(envelope["result"] as? [String: Any])
    #expect(tool["isError"] as? Bool == isError)
    let value = try #require(tool["structuredContent"] as? [String: Any])
    let content = try #require(tool["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let decodedText = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: decodedText).isEqual(to: value))
    return value
  }
}
