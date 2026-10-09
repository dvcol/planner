import Foundation
import PlannerCore
import Testing

@testable import Planner

struct OperationStatusRoutingTests {
  @Test func statusReportsOriginalCheckpointAndDoesNotTreatMissingEvidenceAsRollback() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The real Planner dataset must initialize.")
      return
    }
    let operationIdentifier = UUID()
    let created = await planner.execute(
      PlannerOperation(
        operationId: operationIdentifier, session: datasetSession,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))))
    guard case .applied(let originalResult, .complete(let checkpoint)) = created.outcome else {
      Issue.record("Hotel must be independently saved before status inspection.")
      return
    }
    let source = try #require(originalResult.generated.first)
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let knownRequest = try request(endpoint: endpoint, operationIdentifier: operationIdentifier)
      let known = try structured(try await httpSession.data(for: knownRequest))
      #expect(known["operationId"] as? String == operationIdentifier.uuidString)
      #expect(known["state"] as? String == "appliedRecoveryComplete")
      #expect(known["checkpointGeneration"] as? String == "1")
      let result = try #require(known["result"] as? [String: Any])
      let generated = try #require(result["generated"] as? [[String: Any]])
      #expect(generated.count == 1)
      #expect(generated.first?["kind"] as? String == "item")
      #expect(generated.first?["id"] as? String == source.id.uuidString)
      let unknownIdentifier = UUID()
      let unknownRequest = try request(endpoint: endpoint, operationIdentifier: unknownIdentifier)
      let unknown = try structured(try await httpSession.data(for: unknownRequest))
      #expect(unknown["operationId"] as? String == unknownIdentifier.uuidString)
      #expect(unknown["state"] as? String == "noReliableEvidence")
      #expect(unknown["result"] == nil)
      #expect(unknown["reason"] == nil)
      await listener.stop()
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(session: datasetSession, request: .items(PlannerItemQuery())))
      else {
        Issue.record("Status reads must retain the public Item query.")
        return
      }
      #expect(snapshot.matchingCount == 1)
      #expect(snapshot.rows == [.source(source)])
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Status reads must retain independent recovery.")
        return
      }
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func request(endpoint: URL, operationIdentifier: UUID) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 1, "method": "tools/call",
      "params": [
        "name": "planner_operation_status",
        "arguments": [
          "formatVersion": 1, "operationId": operationIdentifier.uuidString,
        ],
      ],
    ])
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.timeoutInterval = 5
    return request
  }

  private func structured(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    let response = try #require(exchange.1 as? HTTPURLResponse)
    #expect(response.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    #expect(tool["isError"] as? Bool == false)
    let value = try #require(tool["structuredContent"] as? [String: Any])
    #expect(value["formatVersion"] as? Int == 1)
    let content = try #require(tool["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let textResult = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textResult).isEqual(to: value))
    return value
  }
}
