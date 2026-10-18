import Foundation
import PlannerCore
import Testing

@testable import Planner

struct BulkCompletionAdmissionRoutingTests {
  @Test func malformedStaleAndRevokedBulkRequestsLeaveDataAndRecoveryUnchanged() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel", notes: "Keep notes"))).generated
        .first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    func recovery() async throws -> Data {
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
        case .selected(let selection) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      return selection.portableData
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      accessWindowIdentifier: UUID(), planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      func call(_ name: String, arguments: [String: Any], isError: Bool = false) async throws
        -> [String: Any]
      {
        let exchange = try await httpSession.data(
          for: request(endpoint: endpoint, name: name, arguments: arguments))
        let response = try #require(exchange.1 as? HTTPURLResponse)
        #expect(response.statusCode == 200)
        let envelope = try #require(
          JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
        #expect(envelope["error"] == nil)
        let result = try #require(envelope["result"] as? [String: Any])
        #expect(result["isError"] as? Bool == isError)
        return try #require(result["structuredContent"] as? [String: Any])
      }
      let scope: [String: Any] = ["kind": "list", "listId": list.id.uuidString]
      let command: [String: Any] = ["type": "setBulkCompletion", "scope": scope, "done": true]
      let originalRecovery = try await recovery()
      guard
        case .source(.item(let before)) = await planner.read(
          session: session, request: .source(item))
      else { throw CancellationError() }
      let reviewed = try await call(
        "planner_prepare_review", arguments: ["formatVersion": 1, "command": command])
      let token = try #require(reviewed["reviewToken"] as? String)
      let invalidReviews: [(arguments: [String: Any], code: String, path: String?)] = [
        (["formatVersion": 2, "command": command], "unsupportedVersion", "/formatVersion"),
        (["formatVersion": 1], "invalidInput", "/command"),
        (["formatVersion": 1, "command": command, "admin": true], "unknownField", "/admin"),
        (
          [
            "formatVersion": 1,
            "command": ["type": "createItem", "content": ["title": "Not saved"]],
          ], "invalidInput", "/command/listId"
        ),
        (
          ["formatVersion": 1, "command": ["type": "deleteSource"]], "forbiddenOperation",
          "/command/type"
        ),
        (
          ["formatVersion": 1, "command": ["type": "applyImport"]], "forbiddenOperation",
          "/command/type"
        ),
        (
          ["formatVersion": 1, "command": ["type": "restoreRecovery"]], "forbiddenOperation",
          "/command/type"
        ),
        (
          ["formatVersion": 1, "command": ["type": "restoreAssociation"]], "forbiddenOperation",
          "/command/type"
        ),
        (
          ["formatVersion": 1, "command": ["type": "setBulkCompletion", "scope": scope]],
          "invalidInput", "/command/done"
        ),
        (
          [
            "formatVersion": 1,
            "command": ["type": "setBulkCompletion", "scope": scope, "done": "true"],
          ], "invalidInput", "/command/done"
        ),
        (
          [
            "formatVersion": 1,
            "command": ["type": "setBulkCompletion", "scope": ["kind": "global"], "done": true],
          ], "invalidInput", "/command/scope/kind"
        ),
        (
          [
            "formatVersion": 1,
            "command": ["type": "setBulkCompletion", "scope": ["kind": "list"], "done": true],
          ], "invalidInput", "/command/scope/listId"
        ),
        (
          [
            "formatVersion": 1,
            "command": [
              "type": "setBulkCompletion", "scope": ["kind": "list", "listId": NSNull()],
              "done": true,
            ],
          ], "invalidInput", "/command/scope/listId"
        ),
        (
          [
            "formatVersion": 1,
            "command": [
              "type": "setBulkCompletion", "scope": ["kind": "list", "listId": "bad"], "done": true,
            ],
          ], "invalidInput", "/command/scope/listId"
        ),
        (
          [
            "formatVersion": 1,
            "command": [
              "type": "setBulkCompletion",
              "scope": [
                "kind": "list", "listId": list.id.uuidString, "itineraryId": UUID().uuidString,
              ], "done": true,
            ],
          ], "unknownField", "/command/scope/itineraryId"
        ),
        (
          [
            "formatVersion": 1,
            "command": [
              "type": "setBulkCompletion", "scope": scope, "done": true, "extra/key": true,
            ],
          ], "unknownField", "/command/extra~1key"
        ),
        (
          [
            "formatVersion": 1,
            "command": [
              "type": "setBulkCompletion", "scope": ["kind": "list", "listId": item.id.uuidString],
              "done": true,
            ],
          ], "missingReference", nil
        ),
      ]
      for testCase in invalidReviews {
        let rejected = try await call(
          "planner_prepare_review", arguments: testCase.arguments, isError: true)
        #expect(rejected["state"] as? String == "failed")
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(
          reason["code"] as? String == testCase.code,
          Comment(rawValue: String(describing: testCase.arguments)))
        #expect(
          reason["propertyPath"] as? String == testCase.path,
          Comment(rawValue: String(describing: testCase.arguments)))
      }
      for (suppliedToken, code) in [
        ("bad" as Any, "staleReview"), (UUID().uuidString as Any, "staleReview"),
        (true as Any, "invalidInput"),
      ] {
        let rejected = try await call(
          "planner_execute",
          arguments: [
            "formatVersion": 1,
            "operationId": UUID().uuidString, "command": command, "reviewToken": suppliedToken,
          ], isError: true)
        #expect(rejected["state"] as? String == "rejected")
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        if code == "staleReview" {
          let details = try #require(reason["details"] as? [String: Any])
          #expect(
            details["kind"] as? String == "staleReview"
              && details["requiresNewReview"] as? Bool == true)
          #expect(details["currentImpact"] is NSNull)
        }
      }
      guard
        case .source(.item(let retained)) = await planner.read(
          session: session, request: .source(item))
      else { throw CancellationError() }
      #expect(retained.fieldHashes == before.fieldHashes && retained.updatedAt == before.updatedAt)
      #expect(retained.state.globalDone == false && retained.references == before.references)
      #expect(try await recovery() == originalRecovery)
      let newItem = try #require(
        try await save(.createItem(content: .init(title: "New child"))).generated.first)
      _ = try await save(.addMembership(itemId: newItem.id, listId: list.id, placement: .last))
      let beforeStale = try await recovery()
      let stale = try await call(
        "planner_execute",
        arguments: [
          "formatVersion": 1,
          "operationId": UUID().uuidString, "command": command, "reviewToken": token,
        ], isError: true)
      #expect((stale["reason"] as? [String: Any])?["code"] as? String == "staleReview")
      #expect(try await recovery() == beforeStale)
      let fresh = try await call(
        "planner_prepare_review", arguments: ["formatVersion": 1, "command": command])
      #expect((fresh["impact"] as? [String: Any])?["targetCount"] as? String == "2")
      let freshToken = try #require(fresh["reviewToken"] as? String)
      await handler.revokeAccess()
      let revoked = try await httpSession.data(
        for: request(
          endpoint: endpoint, name: "planner_execute",
          arguments: [
            "formatVersion": 1, "operationId": UUID().uuidString, "command": command,
            "reviewToken": freshToken,
          ]))
      #expect((revoked.1 as? HTTPURLResponse)?.statusCode == 401)
      #expect(try await recovery() == beforeStale)
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .items(.init(scope: .list(list.id), completion: .all, archive: .all))))
      else { throw CancellationError() }
      #expect(snapshot.progress.first?.doneCount == 0 && snapshot.progress.first?.totalCount == 2)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func request(endpoint: URL, name: String, arguments: [String: Any]) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 1,
      "method": "tools/call", "params": ["name": name, "arguments": arguments],
    ])
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.timeoutInterval = 5
    return request
  }
}
