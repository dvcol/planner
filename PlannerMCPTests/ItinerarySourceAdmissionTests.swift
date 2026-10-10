import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItinerarySourceAdmissionTests {
  @Test func advertisedItineraryCreationRejectsMalformedFieldsWithoutChangingSavedSourceOrRecovery()
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
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: datasetSession,
          command: .createItinerary(
            content: .init(
              title: "Saved Tokyo", notes: "Keep",
              links: [.init(originalUrl: "https://example.com/route")])))
      ).outcome,
      let itinerary = creation.generated.first,
      case .source(.itinerary(let original)) = await planner.read(
        session: datasetSession, request: .source(itinerary))
    else {
      Issue.record("Save the native fixture before strict HTTP admission attempts.")
      return
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
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
      let creationSchema = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
            == "createItinerary"
        })
      let properties = try #require(creationSchema["properties"] as? [String: Any])
      let contentSchema = try #require(properties["content"] as? [String: Any])
      let contentFields = try #require(contentSchema["properties"] as? [String: Any])
      #expect(
        Set(contentFields.keys) == [
          "title", "notes", "color", "iconName", "location", "links", "categoryIds", "tagIds",
        ])
      #expect(contentSchema["required"] as? [String] == ["title"])
      #expect(contentSchema["additionalProperties"] as? Bool == false)
      for field in ["links", "categoryIds", "tagIds"] {
        #expect((contentFields[field] as? [String: Any])?["type"] as? String == "array")
      }
      let readTool = try #require(tools.first { $0["name"] as? String == "planner_read" })
      let readProperties = try #require(
        (readTool["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let readVariants = try #require(
        (readProperties["request"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let sourceVariant = try #require(
        readVariants.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "source"
        })
      let sourceProperties = try #require(
        (sourceVariant["properties"] as? [String: Any])?["source"] as? [String: Any])
      let sourceFields = try #require(sourceProperties["properties"] as? [String: Any])
      let kinds = try #require((sourceFields["kind"] as? [String: Any])?["enum"] as? [String])
      #expect(kinds.contains("itinerary"))
      let invalidInputs: [([String: Any], String, String)] = [
        (["title": NSNull()], "invalidInput", "/command/content/title"),
        (["title": " \n "], "invalidInput", "/command/content/title"),
        (["notes": 1], "invalidInput", "/command/content/notes"),
        (["iconName": false], "invalidInput", "/command/content/iconName"),
        (["color": true], "invalidInput", "/command/content/color"),
        (["color": ["red": 0]], "invalidInput", "/command/content/color/alpha"),
        (
          ["color": ["red": 2, "green": 0, "blue": 0, "alpha": 1]], "invalidInput",
          "/command/content/color/red"
        ),
        (
          [
            "location": [
              "displayName": NSNull(), "formattedAddress": NSNull(),
              "coordinate": ["latitude": "35", "longitude": 139],
            ]
          ], "invalidInput",
          "/command/content/location/coordinate/latitude"
        ),
        (["links": NSNull()], "invalidInput", "/command/content/links"),
        (
          ["links": [["originalUrl": "file:///private/tmp/route", "label": NSNull()]]],
          "invalidInput",
          "/command/content/links/0/originalUrl"
        ),
        (
          [
            "links": [
              [
                "originalUrl": "https://example.com", "label": NSNull(),
                "linkId": UUID().uuidString,
              ]
            ]
          ],
          "invalidInput", "/command/content/links/0/linkId"
        ),
        (["categoryIds": NSNull()], "invalidInput", "/command/content/categoryIds"),
        (["tagIds": [1]], "invalidInput", "/command/content/tagIds/0"),
        (["categoryIds": [UUID().uuidString]], "missingReference", "/command/content/categoryIds"),
        (["globalDone": true], "unknownField", "/command/content/globalDone"),
        (["x/y": "unexpected"], "unknownField", "/command/content/x~1y"),
      ]
      for (overrides, code, path) in invalidInputs {
        let command: [String: Any] = [
          "type": "createItinerary",
          "content": ["title": "Rejected"].merging(overrides) { _, incoming in incoming },
        ]
        let rejected = try toolValue(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, method: "tools/call",
              parameters: [
                "name": "planner_execute",
                "arguments": [
                  "formatVersion": 1, "operationId": UUID().uuidString, "command": command,
                ],
              ])), isError: true)
        #expect(rejected["state"] as? String == "rejected")
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        #expect(reason["propertyPath"] as? String == path)
        #expect(rejected["result"] == nil)
        #expect(rejected["recovery"] == nil)
      }
      guard
        case .source(.itinerary(let retained)) = await planner.read(
          session: datasetSession, request: .source(itinerary)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 1))
      else {
        Issue.record("Rejected requests retain the saved source and its acknowledged checkpoint.")
        await listener.stop()
        return
      }
      #expect(retained.content == original.content)
      #expect(retained.labels == original.labels)
      #expect(retained.references == original.references)
      #expect(retained.fieldHashes == original.fieldHashes)
      #expect(retained.createdAt == original.createdAt)
      #expect(retained.updatedAt == original.updatedAt)
      #expect(retained.state.globalDone == original.state.globalDone)
      #expect(retained.state.archived == original.state.archived)
      #expect(recovery.decodedBackup.backup.sources.count == 1)
      #expect(recovery.checkpointGeneration == 1)
      #expect(namespace.preparedProposals.isEmpty)
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
