import Foundation
import PlannerCore
import Testing

@testable import Planner

struct MissingStoreRoutingTests {
  @Test(arguments: ["execute", "source"])
  func authenticatedOperationsCannotRecreateLostStorageOrPublishAnEmptyReplacement(_ action: String)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeDirectory = directory.appendingPathComponent("store")
    let retainedDirectory = directory.appendingPathComponent("retained-store")
    let configuration = PlannerStorageConfiguration(
      storeURL: storeDirectory.appendingPathComponent("Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      ).outcome,
      let source = creation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let originalRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    try FileManager.default.moveItem(at: storeDirectory, to: retainedDirectory)
    try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    do {
      var request = URLRequest(url: endpoint)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
      request.setValue(
        "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
      let name: String
      let arguments: [String: Any]
      if action == "execute" {
        name = "planner_execute"
        arguments = [
          "formatVersion": 1, "operationId": UUID().uuidString,
          "command": ["type": "createItem", "content": ["title": "Museum"]],
        ]
      } else {
        name = "planner_read"
        arguments = [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "item", "id": source.id.uuidString]],
        ]
      }
      request.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 1, "method": "tools/call",
        "params": ["name": name, "arguments": arguments],
      ])
      let exchange = try await httpSession.data(for: request)
      let response = try #require(exchange.1 as? HTTPURLResponse)
      #expect(response.statusCode == 200)
      let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
      let tool = try #require(envelope["result"] as? [String: Any])
      let structured = try #require(tool["structuredContent"] as? [String: Any])
      let reason = try #require(structured["reason"] as? [String: Any])
      #expect(tool["isError"] as? Bool == true)
      #expect(structured["state"] as? String == (action == "execute" ? "rejected" : "failed"))
      #expect(reason["code"] as? String == "unavailable")
      #expect(
        structured["result"] == nil && structured["recovery"] == nil && structured["value"] == nil)
      #expect(!FileManager.default.fileExists(atPath: configuration.storeURL.path))
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
    guard
      case .selected(let retainedRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .listed(let retainedNamespace) = await planner.inspectRecovery(
        request: .namespace(namespaceId: namespace.namespaceId))
    else { throw CancellationError() }
    #expect(retainedRecovery.portableData == originalRecovery.portableData)
    #expect(retainedNamespace.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    #expect(retainedNamespace.preparedProposals.isEmpty)
    try FileManager.default.removeItem(at: storeDirectory)
    try FileManager.default.moveItem(at: retainedDirectory, to: storeDirectory)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let restored)) = await reopened.read(
        session: reopenedSession, request: .source(source))
    else { throw CancellationError() }
    #expect(restored.content.title == "Hotel" && restored.content.notes == "Original notes")
    #expect(
      restored.updatedAt == original.updatedAt && restored.fieldHashes == original.fieldHashes)
  }
}
