import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItemLabelRoutingTests {
  @Test func itemLabelsOverHTTPStayLiveAcrossGuardedEditsReplayAndReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("Open the real Core dataset before its HTTP label journey.")
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
      func execute(
        _ command: [String: Any], operationIdentifier: UUID = UUID(), isError: Bool = false
      )
        async throws -> [String: Any]
      {
        try toolValue(
          try await httpSession.data(
            for: toolRequest(
              endpoint: endpoint, name: "planner_execute",
              arguments: [
                "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                "command": command,
              ])), isError: isError)
      }
      func createLabel(_ kind: String, content: [String: Any]) async throws -> String {
        let outcome = try await execute(["type": kind, "content": content])
        try #require(outcome["state"] as? String == "applied")
        let result = try #require(outcome["result"] as? [String: Any])
        let generated = try #require(result["generated"] as? [[String: Any]])
        return try #require(generated.first?["id"] as? String)
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
      let food = try await createLabel(
        "createCategory",
        content: [
          "name": "Food", "color": ["red": 0, "green": 0, "blue": 1, "alpha": 1],
          "iconName": "fork.knife",
        ])
      let culture = try await createLabel("createCategory", content: ["name": "Culture"])
      let rain = try await createLabel("createTag", content: ["name": "Rain"])
      let travel = try await createLabel("createTag", content: ["name": "Travel"])
      let creationIdentifier = UUID()
      let creationCommand: [String: Any] = [
        "type": "createItem",
        "content": ["title": "Hotel", "notes": "Keep", "categoryIds": [food], "tagIds": [rain]],
      ]
      let created = try await execute(creationCommand, operationIdentifier: creationIdentifier)
      try #require(created["state"] as? String == "applied")
      #expect((created["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "5")
      let creationResult = try #require(created["result"] as? [String: Any])
      let generated = try #require(creationResult["generated"] as? [[String: Any]])
      #expect(generated.count == 3)
      let item = try #require(generated.first { $0["kind"] as? String == "item" }?["id"] as? String)
      let original = try await read("item", identifier: item)
      let originalHashes = try #require(original["fieldHashes"] as? [String: String])
      let originalContent = try #require(original["content"] as? [String: Any])
      #expect(originalContent["categoryIds"] as? [String] == [food])
      #expect(originalContent["tagIds"] as? [String] == [rain])
      let labels = try #require(original["labels"] as? [[String: Any]])
      #expect(labels.count == 2)
      let foodMetadata = try #require(
        labels.first {
          ($0["reference"] as? [String: String])?["id"] == food
        })
      #expect(Set(foodMetadata.keys) == ["reference", "name", "color", "iconName"])
      #expect(foodMetadata["reference"] as? [String: String] == ["kind": "category", "id": food])
      #expect(foodMetadata["name"] as? String == "Food")
      #expect(
        foodMetadata["color"] as? [String: Double] == ["red": 0, "green": 0, "blue": 1, "alpha": 1])
      #expect(foodMetadata["iconName"] as? String == "fork.knife")
      let rainMetadata = try #require(
        labels.first {
          ($0["reference"] as? [String: String])?["id"] == rain
        })
      #expect(rainMetadata["reference"] as? [String: String] == ["kind": "tag", "id": rain])
      #expect(rainMetadata["name"] as? String == "Rain")
      #expect(rainMetadata["color"] is NSNull)
      #expect(rainMetadata["iconName"] is NSNull)
      let references = try #require(original["references"] as? [[String: Any]])
      #expect(references.count == 2)
      for reference in references {
        #expect(Set(reference.keys) == ["kind", "id", "owner", "source", "appearance"])
        #expect(reference["kind"] as? String == "labelAssociation")
        #expect(reference["owner"] as? [String: String] == ["kind": "item", "id": item])
        #expect(reference["appearance"] is NSNull)
      }
      let originalCategory = try await read("category", identifier: food)
      let categoryHashes = try #require(originalCategory["fieldHashes"] as? [String: String])
      let renamed = try await execute([
        "type": "editCategory", "sourceId": food,
        "changes": ["name": "Dining"], "expectedFieldHashes": categoryHashes,
      ])
      #expect(renamed["state"] as? String == "applied")
      let afterRename = try await read("item", identifier: item)
      let renamedLabels = try #require(afterRename["labels"] as? [[String: Any]])
      #expect(
        renamedLabels.first {
          ($0["reference"] as? [String: String])?["id"] == food
        }?["name"] as? String == "Dining")
      #expect(afterRename["fieldHashes"] as? [String: String] == originalHashes)
      #expect(afterRename["updatedAt"] as? Double == original["updatedAt"] as? Double)
      #expect(
        NSArray(array: try #require(afterRename["references"] as? [Any])).isEqual(to: references))
      let categoryEditIdentifier = UUID()
      let categoryEditCommand: [String: Any] = [
        "type": "editItem", "sourceId": item,
        "changes": ["categoryIds": [food, culture]], "expectedFieldHashes": originalHashes,
      ]
      let categoryEdit = try await execute(
        categoryEditCommand, operationIdentifier: categoryEditIdentifier)
      #expect(categoryEdit["state"] as? String == "applied")
      #expect(
        (categoryEdit["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "7")
      let tagEdit = try await execute([
        "type": "editItem", "sourceId": item,
        "changes": ["tagIds": [travel]], "expectedFieldHashes": originalHashes,
      ])
      #expect(tagEdit["state"] as? String == "applied")
      #expect((tagEdit["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "8")
      let beforeConflict = try await read("item", identifier: item)
      let currentHashes = try #require(beforeConflict["fieldHashes"] as? [String: String])
      let stale = try await execute(
        [
          "type": "editItem", "sourceId": item,
          "changes": ["notes": "Must not save", "categoryIds": [] as [String]],
          "expectedFieldHashes": originalHashes,
        ], isError: true)
      #expect(stale["state"] as? String == "rejected")
      let reason = try #require(stale["reason"] as? [String: Any])
      #expect(reason["code"] as? String == "staleEdit")
      let details = try #require(reason["details"] as? [String: Any])
      #expect(details["conflictingFields"] as? [String] == ["categoryIds"])
      #expect(
        details["currentValues"] as? [String: [String]] == [
          "categoryIds": [food, culture].sorted()
        ])
      #expect(
        details["currentFieldHashes"] as? [String: String] == [
          "categoryIds": try #require(currentHashes["categoryIds"])
        ])
      #expect(
        NSDictionary(dictionary: try await read("item", identifier: item)).isEqual(
          to: beforeConflict))
      #expect(
        NSDictionary(
          dictionary: try await execute(
            categoryEditCommand,
            operationIdentifier: categoryEditIdentifier)
        ).isEqual(to: categoryEdit))
      #expect(
        NSDictionary(
          dictionary: try await execute(
            creationCommand,
            operationIdentifier: creationIdentifier)
        ).isEqual(to: created))
      let latest = try await read("item", identifier: item)
      #expect(NSDictionary(dictionary: latest).isEqual(to: beforeConflict))
      let detachedRain = try await read("tag", identifier: rain)
      #expect((detachedRain["references"] as? [Any])?.isEmpty == true)
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.item(let saved)) = await reopened.read(
          session: reopenedSession,
          request: .source(
            PlannerEntityReference(kind: .item, id: try #require(UUID(uuidString: item))))),
        case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(
          request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await reopened.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 8))
      else {
        Issue.record("HTTP label data and its normalized recovery must survive reopening.")
        await listener.stop()
        return
      }
      #expect(saved.content.categoryIds == Set([food, culture].compactMap(UUID.init(uuidString:))))
      #expect(saved.content.tagIds == [try #require(UUID(uuidString: travel))])
      #expect(saved.content.notes == "Keep")
      #expect(saved.labels.count == 3)
      #expect(recovery.decodedBackup.backup.labelAssociations.count == 3)
      #expect(recovery.decodedBackup.backup.deletionMarkers.count == 1)
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
