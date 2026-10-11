import Foundation
import PlannerCore
import Testing

@testable import Planner

struct SourceDeletionRoutingTests {
  @Test(arguments: [PlannerEntityKind.category, .tag, .item])
  func statelessHTTPCannotReviewOrApplyNativeSourceDeletionEvenWithAnIssuedToken(
    _ sourceKind: PlannerEntityKind
  ) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let createSource: PlannerCommand
    if sourceKind == .item {
      createSource = .createItem(content: .init(title: "Food"))
    } else if sourceKind == .category {
      createSource = .createCategory(content: .init(name: "Food"))
    } else {
      createSource = .createTag(content: .init(name: "Food"))
    }
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: createSource)
      ).outcome,
      let source = created.generated.first,
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: source)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let before) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let command: [String: Any] = [
        "type": "deleteSource",
        "source": ["kind": sourceKind.rawValue, "id": source.id.uuidString],
      ]
      let operationId = UUID()
      for (name, arguments, state) in [
        (
          "planner_prepare_review", ["formatVersion": 1, "command": command] as [String: Any],
          "failed"
        ),
        (
          "planner_execute",
          [
            "formatVersion": 1, "operationId": operationId.uuidString, "command": command,
            "reviewToken": review.reviewToken.opaqueValue,
          ], "rejected"
        ),
      ] {
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
        let exchange = try await httpSession.data(for: request)
        #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
        let envelope = try #require(
          JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
        let result = try #require(envelope["result"] as? [String: Any])
        #expect(result["isError"] as? Bool == true)
        let content = try #require(result["structuredContent"] as? [String: Any])
        let reason = try #require(content["reason"] as? [String: Any])
        #expect(content["state"] as? String == state)
        #expect(reason["code"] as? String == "forbiddenOperation")
        #expect(reason["propertyPath"] as? String == "/command/type")
      }
      guard
        case .source(let retained) = await planner.read(
          session: session, request: .source(source)),
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationId),
        case .selected(let after) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      switch retained {
      case .item(let source):
        #expect(source.content.title == "Food" && source.references.isEmpty)
      case .category(let source):
        #expect(source.content.name == "Food" && source.references.isEmpty)
      case .tag(let source): #expect(source.content.name == "Food" && source.references.isEmpty)
      default: throw CancellationError()
      }
      #expect(before.portableData == after.portableData)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }
}
