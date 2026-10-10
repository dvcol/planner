import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItemLabelAdmissionTests {
  @Test func advertisedLabelSetsValidateAtomicallyAndNormalizeUUIDSpellings() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let categoryCreation, _) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createCategory(content: PlannerCategoryContentInput(name: "Food")))
      ).outcome,
      let category = categoryCreation.generated.first,
      case .applied(let tagCreation, _) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createTag(content: PlannerTagContentInput(name: "Rain")))
      ).outcome,
      let tag = tagCreation.generated.first,
      case .applied(let itemCreation, _) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Keep", categoryIds: [category.id], tagIds: [tag.id])))
      ).outcome,
      let item = itemCreation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: datasetSession, request: .source(item))
    else {
      Issue.record(
        "Seed live labels and their owner through the public Core before HTTP admission.")
      return
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let hashes = Dictionary(
      uniqueKeysWithValues: original.fieldHashes.map {
        ($0.key.rawValue, $0.value.value)
      })
    do {
      func execute(_ command: [String: Any], operationIdentifier: UUID = UUID(), isError: Bool)
        async throws -> [String: Any]
      {
        try toolValue(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, method: "tools/call",
              parameters: [
                "name": "planner_execute",
                "arguments": [
                  "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                  "command": command,
                ],
              ])), isError: isError)
      }
      let advertisement = try await httpSession.data(
        for: request(
          endpoint: endpoint, method: "tools/list", parameters: [:]))
      #expect((advertisement.1 as? HTTPURLResponse)?.statusCode == 200)
      let envelope = try #require(
        JSONSerialization.jsonObject(with: advertisement.0) as? [String: Any])
      let tools = try #require((envelope["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let execution = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let properties = try #require(
        (execution["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let variants = try #require(
        (properties["command"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      for (commandType, collection) in [("createItem", "content"), ("editItem", "changes")] {
        let variant = try #require(
          variants.first {
            (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
              == commandType
          })
        let commandFields = try #require(variant["properties"] as? [String: Any])
        let collectionSchema = try #require(commandFields[collection] as? [String: Any])
        #expect(collectionSchema["additionalProperties"] as? Bool == false)
        let collectionFields = try #require(collectionSchema["properties"] as? [String: Any])
        for field in ["categoryIds", "tagIds"] {
          let schema = try #require(collectionFields[field] as? [String: Any])
          #expect(schema["type"] as? String == "array")
          #expect(schema["items"] as? [String: String] == ["type": "string", "format": "uuid"])
        }
      }
      let missing = UUID().uuidString
      let invalidCreations: [([String: Any], String, String)] = [
        (["categoryIds": NSNull()], "invalidInput", "/command/content/categoryIds"),
        (["tagIds": "rain"], "invalidInput", "/command/content/tagIds"),
        (["categoryIds": [1]], "invalidInput", "/command/content/categoryIds/0"),
        (["tagIds": ["invalid"]], "invalidInput", "/command/content/tagIds/0"),
        (["categoryIds": [tag.id.uuidString]], "missingReference", "/command/content/categoryIds"),
        (["tagIds": [category.id.uuidString]], "missingReference", "/command/content/tagIds"),
        (["categoryIds": [missing]], "missingReference", "/command/content/categoryIds"),
        (["tagIds": [missing]], "missingReference", "/command/content/tagIds"),
        (["labels": [] as [String]], "unknownField", "/command/content/labels"),
      ]
      let validEdit: [String: Any] = [
        "type": "editItem", "sourceId": item.id.uuidString,
        "changes": ["notes": "Must not save", "categoryIds": [category.id.uuidString]],
        "expectedFieldHashes": hashes,
      ]
      let invalidEdits: [([String: Any], String, String)] = [
        (["changes": ["categoryIds": NSNull()]], "invalidInput", "/command/changes/categoryIds"),
        (["changes": ["tagIds": NSNull()]], "invalidInput", "/command/changes/tagIds"),
        (
          ["changes": ["categoryIds": [category.id.uuidString, "invalid"]]], "invalidInput",
          "/command/changes/categoryIds/1"
        ),
        (["changes": ["tagIds": [false]]], "invalidInput", "/command/changes/tagIds/0"),
        (
          ["changes": ["notes": "Must not save", "categoryIds": [tag.id.uuidString]]],
          "missingReference", "/command/changes/categoryIds"
        ),
        (
          ["changes": ["tagIds": [category.id.uuidString]]], "missingReference",
          "/command/changes/tagIds"
        ),
        (
          ["changes": ["categoryIds": [] as [String], "tagIds": [missing]]], "missingReference",
          "/command/changes/tagIds"
        ),
        (
          ["expectedFieldHashes": ["notes": try #require(hashes["notes"])]], "invalidInput",
          "/command/expectedFieldHashes/categoryIds"
        ),
        (
          ["expectedFieldHashes": ["notes": try #require(hashes["notes"]), "categoryIds": "bad"]],
          "invalidInput", "/command/expectedFieldHashes/categoryIds"
        ),
        (["changes": ["labels": [] as [String]]], "unknownField", "/command/changes/labels"),
      ]
      let invalidCommands =
        invalidCreations.map { content, code, path in
          (
            [
              "type": "createItem",
              "content": ["title": "Rejected"].merging(content) { _, incoming in incoming },
            ] as [String: Any], code, path
          )
        }
        + invalidEdits.map { overrides, code, path in
          (validEdit.merging(overrides) { _, incoming in incoming }, code, path)
        }
      for (command, code, propertyPath) in invalidCommands {
        let operationIdentifier = UUID()
        let rejected = try await execute(
          command, operationIdentifier: operationIdentifier, isError: true)
        #expect(rejected["state"] as? String == "rejected")
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        #expect(reason["propertyPath"] as? String == propertyPath)
        guard
          case .source(.item(let unchanged)) = await planner.read(
            session: datasetSession, request: .source(item)),
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationIdentifier)
        else {
          Issue.record("Rejected label commands cannot change the owner or claim applied evidence.")
          await listener.stop()
          return
        }
        #expect(unchanged.content.notes == "Keep")
        #expect(unchanged.content.categoryIds == [category.id])
        #expect(unchanged.content.tagIds == [tag.id])
        #expect(unchanged.references == original.references)
        #expect(unchanged.fieldHashes == original.fieldHashes)
        #expect(unchanged.updatedAt == original.updatedAt)
      }
      guard
        case .listedNamespaces(let rejectedNamespaces) = await planner.inspectRecovery(
          request: .namespaces),
        let rejectedNamespace = rejectedNamespaces.first,
        case .selected(let rejectedRecovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: rejectedNamespace.namespaceId, checkpointGeneration: 3))
      else {
        Issue.record("Inspect the acknowledged graph after every invalid request.")
        await listener.stop()
        return
      }
      #expect(rejectedNamespace.acknowledgedSnapshot?.checkpointGeneration == 3)
      #expect(rejectedNamespace.preparedProposals.isEmpty)
      #expect(rejectedRecovery.decodedBackup.backup.items.count == 1)
      #expect(rejectedRecovery.decodedBackup.backup.labelAssociations.count == 2)
      let creationIdentifier = UUID()
      let duplicateCreation: [String: Any] = [
        "type": "createItem",
        "content": [
          "title": "Museum",
          "categoryIds": [category.id.uuidString.lowercased(), category.id.uuidString],
          "tagIds": [tag.id.uuidString, tag.id.uuidString.lowercased()],
        ],
      ]
      let created = try await execute(
        duplicateCreation, operationIdentifier: creationIdentifier, isError: false)
      #expect(created["state"] as? String == "applied")
      #expect(((created["result"] as? [String: Any])?["generated"] as? [Any])?.count == 3)
      let canonicalCreation: [String: Any] = [
        "type": "createItem",
        "content": [
          "title": "Museum",
          "categoryIds": [category.id.uuidString], "tagIds": [tag.id.uuidString],
        ],
      ]
      #expect(
        NSDictionary(
          dictionary: try await execute(
            canonicalCreation, operationIdentifier: creationIdentifier, isError: false)
        ).isEqual(to: created))
      let clearIdentifier = UUID()
      let clearCommand: [String: Any] = [
        "type": "editItem", "sourceId": item.id.uuidString,
        "changes": ["categoryIds": [] as [String], "tagIds": [] as [String]],
        "expectedFieldHashes": hashes,
      ]
      let cleared = try await execute(
        clearCommand, operationIdentifier: clearIdentifier, isError: false)
      #expect(cleared["state"] as? String == "applied")
      guard
        case .source(.item(let empty)) = await planner.read(
          session: datasetSession, request: .source(item))
      else {
        Issue.record("Read the cleared label sets before re-adding.")
        await listener.stop()
        return
      }
      #expect(empty.labels.isEmpty)
      #expect(empty.references.isEmpty)
      let emptyHashes = Dictionary(
        uniqueKeysWithValues: empty.fieldHashes.map { ($0.key.rawValue, $0.value.value) })
      let readded = try await execute(
        [
          "type": "editItem", "sourceId": item.id.uuidString,
          "changes": [
            "categoryIds": [category.id.uuidString, category.id.uuidString.lowercased()],
            "tagIds": [tag.id.uuidString],
          ],
          "expectedFieldHashes": emptyHashes,
        ], isError: false)
      #expect(readded["state"] as? String == "applied")
      #expect((readded["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "6")
      #expect(
        NSDictionary(
          dictionary: try await execute(
            clearCommand, operationIdentifier: clearIdentifier, isError: false)
        ).isEqual(to: cleared))
      guard
        case .source(.item(let retained)) = await planner.read(
          session: datasetSession, request: .source(item)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Earlier clear replay must preserve the later ordinary selections.")
        await listener.stop()
        return
      }
      #expect(retained.content.categoryIds == [category.id])
      #expect(retained.content.tagIds == [tag.id])
      #expect(retained.references.count == 2)
      #expect(retained.references.allSatisfy { !original.references.contains($0) })
      #expect(retained.fieldHashes == original.fieldHashes)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 6)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func request(endpoint: URL, method: String, parameters: [String: Any]) throws
    -> URLRequest
  {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 1, "method": method, "params": parameters,
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
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
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
