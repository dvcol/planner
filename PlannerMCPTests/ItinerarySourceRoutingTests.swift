import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItinerarySourceRoutingTests {
  @Test func completeItinerarySourcesOverHTTPStayLiveAcrossReplayAnotherWriterAndReopen()
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
      Issue.record("Open the native Core dataset before its HTTP Itinerary journey.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      func execute(_ command: [String: Any], operationIdentifier: UUID = UUID()) async throws
        -> [String: Any]
      {
        try toolValue(
          try await httpSession.data(
            for: toolRequest(
              endpoint: endpoint, name: "planner_execute",
              arguments: [
                "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                "command": command,
              ])), isError: false)
      }
      func sourceIdentifier(_ outcome: [String: Any], kind: String) throws -> String {
        try #require(outcome["state"] as? String == "applied")
        let result = try #require(outcome["result"] as? [String: Any])
        let generated = try #require(result["generated"] as? [[String: Any]])
        return try #require(generated.first { $0["kind"] as? String == kind }?["id"] as? String)
      }
      func read(_ kind: String, identifier: String) async throws -> [String: Any] {
        let outcome = try toolValue(
          try await httpSession.data(
            for: toolRequest(
              endpoint: endpoint, name: "planner_read",
              arguments: [
                "formatVersion": 1,
                "request": ["kind": "source", "source": ["kind": kind, "id": identifier]],
              ])), isError: false)
        return try #require(outcome["value"] as? [String: Any])
      }
      let category = try sourceIdentifier(
        try await execute(["type": "createCategory", "content": ["name": "Food"]]), kind: "category"
      )
      let tag = try sourceIdentifier(
        try await execute(["type": "createTag", "content": ["name": "Rain"]]), kind: "tag")
      let color: [String: Double] = ["red": 0.25, "green": 0.5, "blue": 1, "alpha": 1]
      let location: [String: Any] = [
        "displayName": "Meeting point", "formattedAddress": "Tokyo, Japan",
        "coordinate": ["latitude": 35.0, "longitude": 139.0],
      ]
      let command: [String: Any] = [
        "type": "createItinerary",
        "content": [
          "title": "  Tokyo café weekend  ", "notes": "", "color": color, "iconName": "map",
          "location": location,
          "links": [["originalUrl": "https://example.com/route?day=1", "label": "Route"]],
          "categoryIds": [category], "tagIds": [tag],
        ],
      ]
      let operationIdentifier = UUID()
      let created = try await execute(command, operationIdentifier: operationIdentifier)
      let itinerary = try sourceIdentifier(created, kind: "itinerary")
      let original = try await read("itinerary", identifier: itinerary)
      let content = try #require(original["content"] as? [String: Any])
      let hashes = try #require(original["fieldHashes"] as? [String: String])
      #expect(
        Set(content.keys) == [
          "title", "notes", "color", "iconName", "location", "links", "categoryIds", "tagIds",
        ])
      #expect(Set(hashes.keys) == Set(content.keys))
      #expect(content["title"] as? String == "  Tokyo café weekend  ")
      #expect(content["notes"] as? String == "")
      #expect(content["color"] as? [String: Double] == color)
      #expect(content["iconName"] as? String == "map")
      #expect(
        NSDictionary(dictionary: try #require(content["location"] as? [String: Any])).isEqual(
          to: location))
      #expect(content["categoryIds"] as? [String] == [category])
      #expect(content["tagIds"] as? [String] == [tag])
      let links = try #require(content["links"] as? [[String: Any]])
      let link = try #require(links.first)
      let linkIdentifier = try #require(link["linkId"] as? String)
      #expect(link["originalUrl"] as? String == "https://example.com/route?day=1")
      #expect(link["label"] as? String == "Route")
      #expect(link["kind"] as? String == "website")
      #expect(link["providerReference"] is NSNull)
      let state = try #require(original["state"] as? [String: Any])
      #expect(state["globalDone"] is NSNull)
      #expect(state["archived"] as? Bool == false)
      let progress = try #require(original["progress"] as? [String: Any])
      #expect(progress["state"] as? String == "empty")
      #expect(progress["doneCount"] as? String == "0")
      #expect(progress["totalCount"] as? String == "0")
      let estimates = try #require(original["estimates"] as? [String: Any])
      for field in ["calculatedEstimate", "fullEstimate", "remainingEstimate"] {
        #expect(
          NSDictionary(dictionary: try #require(estimates[field] as? [String: Any]))
            .isEqual(to: ["kind": "exact", "minutes": "0"]))
      }
      #expect(estimates["completedExceedsTotal"] as? Bool == false)
      #expect((created["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let categoryRead = try await read("category", identifier: category)
      let categoryHashes = try #require(categoryRead["fieldHashes"] as? [String: String])
      _ = try await execute([
        "type": "editCategory", "sourceId": category, "changes": ["name": "Dining"],
        "expectedFieldHashes": ["name": try #require(categoryHashes["name"])],
      ])
      _ = try await execute([
        "type": "createItem", "content": ["title": "Hotel", "categoryIds": [category]],
      ])
      let refreshed = try await read("itinerary", identifier: itinerary)
      #expect(
        NSDictionary(dictionary: try #require(refreshed["content"] as? [String: Any])).isEqual(
          to: content))
      #expect(refreshed["fieldHashes"] as? [String: String] == hashes)
      #expect(refreshed["createdAt"] as? Double == original["createdAt"] as? Double)
      #expect(refreshed["updatedAt"] as? Double == original["updatedAt"] as? Double)
      let labels = try #require(refreshed["labels"] as? [[String: Any]])
      #expect(Set(labels.compactMap { $0["name"] as? String }) == ["Dining", "Rain"])
      #expect(labels.allSatisfy { Set($0.keys) == ["reference", "name", "color", "iconName"] })
      let replayed = try await execute(command, operationIdentifier: operationIdentifier)
      #expect(NSDictionary(dictionary: replayed).isEqual(to: created))
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        let itineraryIdentifier = UUID(uuidString: itinerary),
        case .source(.itinerary(let retained)) = await reopened.read(
          session: reopenedSession,
          request: .source(.init(kind: .itinerary, id: itineraryIdentifier))),
        case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(
          request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await reopened.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 5))
      else {
        Issue.record("Actual HTTP saves survive reopen with independent acknowledged recovery.")
        await listener.stop()
        return
      }
      #expect(retained.content.title == "  Tokyo café weekend  ")
      #expect(retained.content.notes == "")
      #expect(retained.content.links.first?.linkId.uuidString == linkIdentifier)
      #expect(Set(retained.labels.map(\.name)) == ["Dining", "Rain"])
      #expect(recovery.decodedBackup.backup.sources.filter { $0.kind == .itinerary }.count == 1)
      #expect(recovery.decodedBackup.backup.labelAssociations.count == 3)
      #expect(recovery.checkpointGeneration == 5)
      #expect(namespace.preparedProposals.isEmpty)
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
