import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItineraryArchiveRoutingTests {
  @Test func advertisedArchiveOverHTTPPreservesItineraryReferencesAndRejectsInvalidActions()
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
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route", notes: "Keep notes")))
        .generated
        .first)
    guard
      case .itineraryEntry(let entryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.directItineraryItem(itineraryId: itinerary.id, entryId: entryId)),
        done: true))
    guard
      case .source(.itinerary(let before)) = await planner.read(
        session: datasetSession, request: .source(itinerary)),
      case .source(.item(let originalItem)) = await planner.read(
        session: datasetSession, request: .source(item))
    else { throw CancellationError() }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let listing = try result(
        try await httpSession.data(
          for: request(endpoint: endpoint, method: "tools/list", parameters: [:])))
      let tools = try #require(listing["tools"] as? [[String: Any]])
      let execution = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let schema = try #require(execution["inputSchema"] as? [String: Any])
      let commands = try #require(
        (schema["properties"] as? [String: Any])?["command"] as? [String: Any])
      let variants = try #require(commands["oneOf"] as? [[String: Any]])
      let archiveSchema = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
            == "setArchive"
        })
      #expect(archiveSchema["additionalProperties"] as? Bool == false)
      let sourceSchema = try #require(
        (archiveSchema["properties"] as? [String: Any])?["source"] as? [String: Any])
      #expect(sourceSchema["additionalProperties"] as? Bool == false)
      let kindSchema = try #require(
        (sourceSchema["properties"] as? [String: Any])?["kind"] as? [String: Any])
      #expect(Set(try #require(kindSchema["enum"] as? [String])) == ["item", "list", "itinerary"])
      func execute(_ command: [String: Any], operationId: UUID = UUID(), isError: Bool = false)
        async throws -> [String: Any]
      {
        try value(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, method: "tools/call",
              parameters: [
                "name": "planner_execute",
                "arguments": [
                  "formatVersion": 1, "operationId": operationId.uuidString, "command": command,
                ],
              ])), isError: isError)
      }
      let archiveId = UUID()
      let source: [String: Any] = ["kind": "itinerary", "id": itinerary.id.uuidString]
      let archive: [String: Any] = ["type": "setArchive", "source": source, "archived": true]
      let archived = try await execute(archive, operationId: archiveId)
      #expect(archived["state"] as? String == "applied")
      #expect((archived["recovery"] as? [String: Any])?["state"] as? String == "complete")
      let read = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, method: "tools/call",
            parameters: [
              "name": "planner_read",
              "arguments": ["formatVersion": 1, "request": ["kind": "source", "source": source]],
            ])), isError: false)
      let saved = try #require(read["value"] as? [String: Any])
      #expect((saved["state"] as? [String: Any])?["archived"] as? Bool == true)
      #expect((saved["state"] as? [String: Any])?["globalDone"] is NSNull)
      #expect((saved["content"] as? [String: Any])?["notes"] as? String == "Keep notes")
      #expect((saved["progress"] as? [String: Any])?["doneCount"] as? String == "1")
      _ = try await execute(["type": "setArchive", "source": source, "archived": false])
      let replay = try await execute(archive, operationId: archiveId)
      #expect(NSDictionary(dictionary: replay).isEqual(to: archived))
      let mismatch = try await execute(
        ["type": "setArchive", "source": source, "archived": false], operationId: archiveId,
        isError: true)
      #expect(
        (mismatch["reason"] as? [String: Any])?["code"] as? String == "operationPayloadMismatch")
      let invalid: [(command: [String: Any], code: String, path: String?)] = [
        (
          ["type": "setArchive", "source": source, "archived": "true"], "invalidInput",
          "/command/archived"
        ),
        (["type": "setArchive", "source": source], "invalidInput", "/command/archived"),
        (
          ["type": "setArchive", "source": source, "archived": true, "done": true], "unknownField",
          "/command/done"
        ),
        (
          [
            "type": "setArchive", "source": ["kind": "category", "id": itinerary.id.uuidString],
            "archived": true,
          ], "invalidInput", "/command/source/kind"
        ),
        (
          ["type": "setArchive", "source": ["kind": "itinerary", "id": "bad"], "archived": true],
          "invalidInput", "/command/source/id"
        ),
        (
          [
            "type": "setArchive", "source": ["kind": "itinerary", "id": UUID().uuidString],
            "archived": true,
          ], "missingReference", nil
        ),
      ]
      for testCase in invalid {
        let operationId = UUID()
        let rejected = try await execute(testCase.command, operationId: operationId, isError: true)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == testCase.code)
        #expect(reason["propertyPath"] as? String == testCase.path)
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationId)
        else { throw CancellationError() }
      }
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.itinerary(let current)) = await reopened.read(
          session: reopenedSession, request: .source(itinerary)),
        case .source(.item(let retainedItem)) = await reopened.read(
          session: reopenedSession, request: .source(item))
      else { throw CancellationError() }
      #expect(current.state.archived == false)
      #expect(current.content == before.content)
      #expect(current.fieldHashes == before.fieldHashes)
      #expect(current.references == before.references)
      #expect(current.progress.totalCount == 1 && current.progress.doneCount == 1)
      #expect(retainedItem.state.archived == false && retainedItem.state.globalDone == false)
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
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

  private func result(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    let response = try #require(exchange.1 as? HTTPURLResponse)
    #expect(response.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    return try #require(envelope["result"] as? [String: Any])
  }

  private func value(_ exchange: (Data, URLResponse), isError: Bool) throws -> [String: Any] {
    let toolResult = try result(exchange)
    #expect(toolResult["isError"] as? Bool == isError)
    let structured = try #require(toolResult["structuredContent"] as? [String: Any])
    let text = try #require((toolResult["content"] as? [[String: Any]])?.first?["text"] as? String)
    let encoded = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: encoded).isEqual(to: structured))
    return structured
  }
}
