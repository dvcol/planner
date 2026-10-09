import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ArchiveRoutingTests {
  @Test func archiveAndUnarchiveOverHTTPRetainSourcesAndOldReplayDoesNotReapply() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize.")
      return
    }
    let hotel = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))))
    let museum = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createItem(
          content: PlannerItemContentInput(title: "Museum", notes: "Museum notes"))))
    guard case .applied(let hotelResult, .complete) = hotel.outcome,
      case .applied(let museumResult, .complete) = museum.outcome
    else {
      Issue.record("Both fixture Items must be independently saved.")
      return
    }
    let hotelSource = try #require(hotelResult.generated.first)
    let museumSource = try #require(museumResult.generated.first)
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let archiveOperationIdentifier = UUID()
    let archiveRequest = try request(
      endpoint: endpoint, name: "planner_execute",
      arguments: [
        "formatVersion": 1, "operationId": archiveOperationIdentifier.uuidString,
        "command": [
          "type": "setArchive", "source": ["kind": "item", "id": hotelSource.id.uuidString],
          "archived": true,
        ],
      ])
    do {
      let archived = try value(try await httpSession.data(for: archiveRequest))
      #expect(archived["state"] as? String == "applied")
      let archiveRecovery = try #require(archived["recovery"] as? [String: Any])
      #expect(archiveRecovery["state"] as? String == "complete")
      #expect(archiveRecovery["checkpointGeneration"] as? String == "3")
      let readRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "source", "source": ["kind": "item", "id": hotelSource.id.uuidString],
          ],
        ])
      let archivedRead = try value(try await httpSession.data(for: readRequest))
      let sourceRead = try #require(archivedRead["value"] as? [String: Any])
      let content = try #require(sourceRead["content"] as? [String: Any])
      #expect(content["title"] as? String == "Hotel")
      #expect(content["notes"] as? String == "Original notes")
      let state = try #require(sourceRead["state"] as? [String: Any])
      #expect(state["globalDone"] as? Bool == false)
      #expect(state["archived"] as? Bool == true)
      let queryRequest = try request(
        endpoint: endpoint, name: "planner_query",
        arguments: [
          "formatVersion": 1, "query": ["kind": "items", "scope": ["kind": "global"]],
        ])
      let ordinary = try value(try await httpSession.data(for: queryRequest))
      #expect(ordinary["matchingCount"] as? String == "1")
      let ordinaryRows = try #require(ordinary["rows"] as? [[String: Any]])
      #expect(ordinaryRows.count == 1)
      #expect(
        (ordinaryRows.first?["source"] as? [String: Any])?["id"] as? String
          == museumSource.id.uuidString)
      let unarchiveRequest = try request(
        endpoint: endpoint, name: "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": UUID().uuidString,
          "command": [
            "type": "setArchive", "source": ["kind": "item", "id": hotelSource.id.uuidString],
            "archived": false,
          ],
        ])
      let unarchived = try value(try await httpSession.data(for: unarchiveRequest))
      #expect(unarchived["state"] as? String == "applied")
      #expect((unarchived["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "4")
      let replayed = try value(try await httpSession.data(for: archiveRequest))
      #expect(replayed["state"] as? String == "applied")
      #expect((replayed["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let restoredQuery = try value(try await httpSession.data(for: queryRequest))
      #expect(restoredQuery["matchingCount"] as? String == "2")
      let restoredRows = try #require(restoredQuery["rows"] as? [[String: Any]])
      #expect(
        restoredRows.compactMap { ($0["source"] as? [String: Any])?["id"] as? String } == [
          hotelSource.id.uuidString, museumSource.id.uuidString,
        ])
      await listener.stop()
      guard
        case .source(.item(let retainedHotel)) = await planner.read(
          session: datasetSession, request: .source(hotelSource)),
        case .source(.item(let retainedMuseum)) = await planner.read(
          session: datasetSession, request: .source(museumSource))
      else {
        Issue.record("Archive and replay must retain both native source identities.")
        return
      }
      #expect(retainedHotel.content.notes == "Original notes")
      #expect(retainedHotel.state.archived == false)
      #expect(retainedHotel.state.globalDone == false)
      #expect(retainedMuseum.content.title == "Museum")
      #expect(retainedMuseum.content.notes == "Museum notes")
      #expect(retainedMuseum.state.archived == false)
      #expect(retainedMuseum.state.globalDone == false)
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

  private func value(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    let response = try #require(exchange.1 as? HTTPURLResponse)
    #expect(response.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    #expect(tool["isError"] as? Bool == false)
    let structured = try #require(tool["structuredContent"] as? [String: Any])
    #expect(structured["formatVersion"] as? Int == 1)
    let content = try #require(tool["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let textValue = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textValue).isEqual(to: structured))
    return structured
  }
}
