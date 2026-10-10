import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItineraryEditAdmissionTests {
  @Test func advertisedItineraryEditsRejectMalformedPatchesWithoutChangingSavedData() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("Open the public Core fixture before HTTP patch admission.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      let outcome = await planner.execute(
        .init(operationId: UUID(), session: datasetSession, command: command)
      ).outcome
      guard case .applied(let result, .complete) = outcome, let source = result.generated.first
      else {
        Issue.record("Create each durable fixture source.")
        throw MissingResult()
      }
      return source
    }
    let category = try await create(.createCategory(content: .init(name: "Food")))
    let tag = try await create(.createTag(content: .init(name: "Rain")))
    let item = try await create(
      .createItem(
        content: .init(
          title: "Other owner", links: [.init(originalUrl: "https://example.com/item")])))
    let itinerary = try await create(
      .createItinerary(
        content: .init(
          title: "Saved Tokyo", notes: "Keep",
          links: [.init(originalUrl: "https://example.com/route")], categoryIds: [category.id],
          tagIds: [tag.id])))
    guard
      case .source(.itinerary(let original)) = await planner.read(
        session: datasetSession, request: .source(itinerary)),
      case .source(.item(let other)) = await planner.read(
        session: datasetSession, request: .source(item)),
      let ownedLink = original.content.links.first, let foreignLink = other.content.links.first
    else {
      Issue.record("Read actual owner/link identities and their hashes.")
      return
    }
    let hashes = Dictionary(
      uniqueKeysWithValues: original.fieldHashes.map { ($0.key.rawValue, $0.value.value) })
    let listener = PlannerMCPLoopbackListener(
      requestHandler: .init(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let advertisement = try await httpSession.data(
        for: request(endpoint: endpoint, method: "tools/list", parameters: [:]))
      #expect((advertisement.1 as? HTTPURLResponse)?.statusCode == 200)
      let envelope = try #require(
        JSONSerialization.jsonObject(with: advertisement.0) as? [String: Any])
      let tools = try #require((envelope["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let execution = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let executionProperties = try #require(
        (execution["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let variants = try #require(
        (executionProperties["command"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let schema = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
            == "editItinerary"
        })
      #expect(
        Set(schema["required"] as? [String] ?? []) == [
          "type", "sourceId", "changes", "expectedFieldHashes",
        ])
      #expect(schema["additionalProperties"] as? Bool == false)
      let properties = try #require(schema["properties"] as? [String: Any])
      let changesSchema = try #require(properties["changes"] as? [String: Any])
      let changesFields = try #require(changesSchema["properties"] as? [String: Any])
      let hashesSchema = try #require(properties["expectedFieldHashes"] as? [String: Any])
      let hashFields = try #require(hashesSchema["properties"] as? [String: Any])
      let fields: Set<String> = [
        "title", "notes", "color", "iconName", "location", "links", "categoryIds", "tagIds",
      ]
      #expect(Set(changesFields.keys) == fields && Set(hashFields.keys) == fields)
      #expect(changesSchema["minProperties"] as? Int == 1)
      #expect(
        changesSchema["additionalProperties"] as? Bool == false
          && hashesSchema["additionalProperties"] as? Bool == false)
      for field in ["links", "categoryIds", "tagIds"] {
        #expect((changesFields[field] as? [String: Any])?["type"] as? String == "array")
      }
      for field in fields {
        #expect(
          (hashFields[field] as? [String: Any])?["pattern"] as? String == "^sha256-v1:[0-9a-f]{64}$"
        )
      }
      func command(_ changes: [String: Any], expectedHashes: Any? = nil) -> [String: Any] {
        [
          "type": "editItinerary", "sourceId": itinerary.id.uuidString, "changes": changes,
          "expectedFieldHashes": expectedHashes ?? hashes,
        ]
      }
      let valid = command(["notes": "Must not save"])
      let invalidInputs: [([String: Any], String, String)] = [
        (command([:]), "invalidInput", "/command/changes"),
        (command(["title": NSNull()]), "invalidInput", "/command/changes/title"),
        (command(["title": false]), "invalidInput", "/command/changes/title"),
        (command(["notes": 1]), "invalidInput", "/command/changes/notes"),
        (command(["iconName": false]), "invalidInput", "/command/changes/iconName"),
        (command(["color": true]), "invalidInput", "/command/changes/color"),
        (command(["color": ["red": 0]]), "invalidInput", "/command/changes/color/alpha"),
        (
          command([
            "location": [
              "displayName": NSNull(), "formattedAddress": NSNull(),
              "coordinate": ["latitude": "35", "longitude": 139],
            ]
          ]), "invalidInput", "/command/changes/location/coordinate/latitude"
        ),
        (command(["links": NSNull()]), "invalidInput", "/command/changes/links"),
        (
          command(["links": [["originalUrl": "file:///private/tmp/route", "label": NSNull()]]]),
          "invalidInput", "/command/changes/links/0/originalUrl"
        ),
        (
          command([
            "links": [
              ["linkId": "not-a-uuid", "originalUrl": "https://example.com", "label": NSNull()]
            ]
          ]), "invalidInput", "/command/changes/links/0/linkId"
        ),
        (
          command([
            "links": [
              [
                "linkId": foreignLink.linkId.uuidString, "originalUrl": "https://example.com/item",
                "label": NSNull(),
              ]
            ]
          ]), "invalidInput", "/command/changes/links/0/linkId"
        ),
        (
          command([
            "links": [
              [
                "linkId": ownedLink.linkId.uuidString, "originalUrl": "https://example.com",
                "label": NSNull(),
              ],
              [
                "linkId": ownedLink.linkId.uuidString, "originalUrl": "https://example.com",
                "label": NSNull(),
              ],
            ]
          ]), "invalidInput", "/command/changes/links/1/linkId"
        ),
        (command(["categoryIds": NSNull()]), "invalidInput", "/command/changes/categoryIds"),
        (command(["tagIds": [1]]), "invalidInput", "/command/changes/tagIds/0"),
        (
          command(["categoryIds": [UUID().uuidString]]), "missingReference",
          "/command/changes/categoryIds"
        ),
        (
          command(["categoryIds": [tag.id.uuidString]]), "missingReference",
          "/command/changes/categoryIds"
        ),
        (command(["x/y": "unexpected"]), "unknownField", "/command/changes/x~1y"),
        (
          command(["notes": "Must not save"], expectedHashes: NSNull()), "invalidInput",
          "/command/expectedFieldHashes"
        ),
        (
          command(["notes": "Must not save"], expectedHashes: [String: String]()), "invalidInput",
          "/command/expectedFieldHashes/notes"
        ),
        (
          command(["notes": "Must not save"], expectedHashes: ["notes": 1]), "invalidInput",
          "/command/expectedFieldHashes/notes"
        ),
        (
          command(
            ["notes": "Must not save"],
            expectedHashes: ["notes": "sha256-v2:" + String(repeating: "a", count: 64)]),
          "invalidInput", "/command/expectedFieldHashes/notes"
        ),
        (
          command(
            ["notes": "Must not save"],
            expectedHashes: ["notes": try #require(hashes["notes"]), "title": "bad"]),
          "invalidInput", "/command/expectedFieldHashes/title"
        ),
        (
          command(["notes": "Must not save"], expectedHashes: ["x/y": "bad"]), "unknownField",
          "/command/expectedFieldHashes/x~1y"
        ),
        (
          valid.merging(["sourceId": NSNull()]) { _, incoming in incoming }, "invalidInput",
          "/command/sourceId"
        ),
        (
          valid.merging(["sourceId": "not-a-uuid"]) { _, incoming in incoming }, "invalidInput",
          "/command/sourceId"
        ),
        (
          valid.merging(["admin": true]) { _, incoming in incoming }, "unknownField",
          "/command/admin"
        ),
        (
          valid.merging(["changes": NSNull()]) { _, incoming in incoming }, "invalidInput",
          "/command/changes"
        ),
      ]
      for (command, code, path) in invalidInputs {
        let operationIdentifier = UUID()
        let rejected = try toolValue(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, method: "tools/call",
              parameters: [
                "name": "planner_execute",
                "arguments": [
                  "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                  "command": command,
                ],
              ])), isError: true)
        #expect(rejected["state"] as? String == "rejected")
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        #expect(reason["propertyPath"] as? String == path)
        #expect(rejected["result"] == nil && rejected["recovery"] == nil)
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationIdentifier)
        else {
          Issue.record("Rejected HTTP patches cannot create applied operation evidence.")
          await listener.stop()
          return
        }
      }
      guard
        case .source(.itinerary(let retained)) = await planner.read(
          session: datasetSession, request: .source(itinerary)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 4))
      else {
        Issue.record("Invalid HTTP patches preserve the source and independent recovery.")
        await listener.stop()
        return
      }
      #expect(retained.content == original.content && retained.fieldHashes == original.fieldHashes)
      #expect(retained.labels == original.labels && retained.references == original.references)
      #expect(retained.createdAt == original.createdAt && retained.updatedAt == original.updatedAt)
      #expect(retained.state.globalDone == nil && retained.state.archived == false)
      #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 4)
      #expect(namespace.preparedProposals.isEmpty)
      #expect(recovery.decodedBackup.backup.labelAssociations.count == 2)
      #expect(recovery.decodedBackup.backup.deletionMarkers.isEmpty)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }
  private struct MissingResult: Error {}

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
