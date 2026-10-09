import Foundation
import PlannerCore
import Testing

@testable import Planner

struct CommandRoutingTests {
  @Test func notesEditOverHTTPRejectsStaleHashAndRetainsFridayBooking() async throws {
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
    let created = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))))
    guard case .applied(let result, .complete) = created.outcome else {
      Issue.record("Hotel must be independently saved before editing.")
      return
    }
    let source = try #require(result.generated.first)
    guard
      case .source(let original) = await planner.read(
        session: datasetSession, request: .source(source))
    else {
      Issue.record("The original notes hash must come from a public read.")
      return
    }
    let originalHash = try #require(original.fieldHashes[.notes])
    let operationIdentifier = UUID()
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let edit = try executionRequest(
        endpoint: endpoint, operationIdentifier: operationIdentifier,
        command: [
          "type": "editItem", "sourceId": source.id.uuidString,
          "changes": ["notes": "Friday booking"],
          "expectedFieldHashes": ["notes": originalHash.value],
        ])
      let edited = try operationValue(try await httpSession.data(for: edit), isError: false)
      #expect(edited["state"] as? String == "applied")
      let recovery = try #require(edited["recovery"] as? [String: Any])
      #expect(recovery["state"] as? String == "complete")
      #expect(recovery["checkpointGeneration"] as? String == "2")
      guard
        case .source(let friday) = await planner.read(
          session: datasetSession, request: .source(source))
      else {
        Issue.record("HTTP must update the shared native Item.")
        return
      }
      #expect(friday.content.title == "Hotel")
      #expect(friday.content.notes == "Friday booking")
      #expect(friday.state.globalDone == false)
      #expect(friday.state.archived == false)
      let staleRequest = try executionRequest(
        endpoint: endpoint, operationIdentifier: UUID(),
        command: [
          "type": "editItem", "sourceId": source.id.uuidString,
          "changes": ["notes": "Monday booking"],
          "expectedFieldHashes": ["notes": originalHash.value],
        ])
      let stale = try operationValue(try await httpSession.data(for: staleRequest), isError: true)
      await listener.stop()
      #expect(stale["state"] as? String == "rejected")
      let reason = try #require(stale["reason"] as? [String: Any])
      #expect(reason["code"] as? String == "staleEdit")
      let details = try #require(reason["details"] as? [String: Any])
      #expect(details["kind"] as? String == "staleEdit")
      #expect(details["conflictingFields"] as? [String] == ["notes"])
      let currentValues = try #require(details["currentValues"] as? [String: Any])
      #expect(currentValues["notes"] as? String == "Friday booking")
      let hashes = try #require(details["currentFieldHashes"] as? [String: String])
      #expect(hashes["notes"] == friday.fieldHashes[.notes]?.value)
      guard
        case .source(let current) = await planner.read(
          session: datasetSession, request: .source(source))
      else {
        Issue.record("A stale agent edit must retain the current Item.")
        return
      }
      #expect(current.content.notes == "Friday booking")
      #expect(current.updatedAt == friday.updatedAt)
      #expect(current.fieldHashes == friday.fieldHashes)
      guard
        case .appliedRecoveryComplete(let saved, let checkpoint) = await planner.operationStatus(
          session: datasetSession, operationId: operationIdentifier)
      else {
        Issue.record("The successful edit must retain its original evidence.")
        return
      }
      #expect(saved.affected == [source])
      #expect(checkpoint == 2)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test(arguments: ["deleteSource", "applyImport", "restoreRecovery"])
  func nativeAdministrationIsForbiddenWithoutChangingHotel(_ commandType: String) async throws {
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
    let created = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))))
    guard case .applied(let originalResult, .complete(let checkpoint)) = created.outcome else {
      Issue.record("Hotel must be independently saved before rejected agent work.")
      return
    }
    let source = try #require(originalResult.generated.first)
    let operationIdentifier = UUID()
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let request = try executionRequest(
      endpoint: endpoint, operationIdentifier: operationIdentifier, command: ["type": commandType])
    do {
      let exchange = try await httpSession.data(for: request)
      await listener.stop()
      let response = try #require(exchange.1 as? HTTPURLResponse)
      #expect(response.statusCode == 200)
      let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
      #expect(envelope["error"] == nil)
      let tool = try #require(envelope["result"] as? [String: Any])
      #expect(tool["isError"] as? Bool == true)
      let structured = try #require(tool["structuredContent"] as? [String: Any])
      #expect(structured["state"] as? String == "rejected")
      #expect(structured["operationId"] as? String == operationIdentifier.uuidString)
      let reason = try #require(structured["reason"] as? [String: Any])
      #expect(reason["code"] as? String == "forbiddenOperation")
      #expect(reason["propertyPath"] as? String == "/command/type")
      guard
        case .source(let current) = await planner.read(
          session: datasetSession, request: .source(source))
      else {
        Issue.record("Rejected administration must retain Hotel.")
        return
      }
      #expect(current.content.title == "Hotel")
      #expect(current.content.notes == "Original notes")
      #expect(current.state.globalDone == false)
      #expect(current.state.archived == false)
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(session: datasetSession, request: .items(PlannerItemQuery())))
      else {
        Issue.record("Rejected administration must preserve the public query.")
        return
      }
      #expect(snapshot.matchingCount == 1)
      #expect(snapshot.rows == [.source(source)])
      guard
        case .noReliableEvidence = await planner.operationStatus(
          session: datasetSession, operationId: operationIdentifier)
      else {
        Issue.record("Adapter admission must not create a domain receipt.")
        return
      }
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("The existing independent checkpoint must remain available.")
        return
      }
      #expect(namespaces.count == 1)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func createOverHTTPPersistsHotelAndReplaysWithoutAnotherItem() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The real Planner dataset must initialize.")
      return
    }
    let operationIdentifier = try #require(
      UUID(uuidString: "00000000-0000-4000-8000-000000000901"))
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let request = try executionRequest(
      endpoint: endpoint, operationIdentifier: operationIdentifier,
      command: ["type": "createItem", "content": ["title": "Hotel", "notes": "Original notes"]])
    do {
      let firstExchange = try await httpSession.data(for: request)
      let first = try appliedCreation(firstExchange, operationIdentifier: operationIdentifier)
      let replayExchange = try await httpSession.data(for: request)
      let replay = try appliedCreation(replayExchange, operationIdentifier: operationIdentifier)
      await listener.stop()
      #expect(replay.itemIdentifier == first.itemIdentifier)
      #expect(replay.checkpoint == first.checkpoint)
      #expect(first.checkpoint == "1")
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
        Issue.record("HTTP-created data must reopen through the public Core.")
        return
      }
      let item = PlannerEntityReference(kind: .item, id: first.itemIdentifier)
      guard
        case .source(let read) = await reopened.read(
          session: reopenedSession, request: .source(item))
      else {
        Issue.record("HTTP-created Hotel must remain readable after reopening.")
        return
      }
      #expect(read.content.title == "Hotel")
      #expect(read.content.notes == "Original notes")
      #expect(read.state.globalDone == false)
      #expect(read.state.archived == false)
      guard
        case .snapshot(let snapshot) = await reopened.query(
          PlannerQuery(session: reopenedSession, request: .items(PlannerItemQuery())))
      else {
        Issue.record("The resulting Items must be discoverable through Core.")
        return
      }
      #expect(snapshot.matchingCount == 1)
      #expect(snapshot.rows == [.source(item)])
      guard
        case .appliedRecoveryComplete(let result, let checkpoint) = await reopened.operationStatus(
          session: reopenedSession, operationId: operationIdentifier)
      else {
        Issue.record("The original operation must retain complete recovery evidence.")
        return
      }
      #expect(result.generated == [item])
      #expect(checkpoint == 1)
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func executionRequest(
    endpoint: URL, operationIdentifier: UUID, command: [String: Any]
  ) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 1, "method": "tools/call",
      "params": [
        "name": "planner_execute",
        "arguments": [
          "formatVersion": 1, "operationId": operationIdentifier.uuidString, "command": command,
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

  private func operationValue(_ exchange: (Data, URLResponse), isError: Bool) throws -> [String:
    Any]
  {
    let response = try #require(exchange.1 as? HTTPURLResponse)
    #expect(response.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    #expect(tool["isError"] as? Bool == isError)
    let value = try #require(tool["structuredContent"] as? [String: Any])
    let content = try #require(tool["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let textResult = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textResult).isEqual(to: value))
    return value
  }

  private func appliedCreation(
    _ exchange: (Data, URLResponse), operationIdentifier: UUID
  ) throws -> (itemIdentifier: UUID, checkpoint: String) {
    let response = try #require(exchange.1 as? HTTPURLResponse)
    #expect(response.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    #expect(tool["isError"] as? Bool == false)
    let structured = try #require(tool["structuredContent"] as? [String: Any])
    #expect(structured["formatVersion"] as? Int == 1)
    #expect(structured["operationId"] as? String == operationIdentifier.uuidString)
    #expect(structured["state"] as? String == "applied")
    let result = try #require(structured["result"] as? [String: Any])
    let generated = try #require(result["generated"] as? [[String: Any]])
    #expect(generated.count == 1)
    let source = try #require(generated.first)
    #expect(source["kind"] as? String == "item")
    let spelling = try #require(source["id"] as? String)
    let itemIdentifier = try #require(UUID(uuidString: spelling))
    let affected = try #require(result["affected"] as? [[String: Any]])
    #expect(affected.count == 1)
    #expect(affected.first?["id"] as? String == spelling)
    #expect((result["progress"] as? [Any])?.isEmpty == true)
    #expect(result["importSummary"] is NSNull)
    let recovery = try #require(structured["recovery"] as? [String: Any])
    #expect(recovery["state"] as? String == "complete")
    let checkpoint = try #require(recovery["checkpointGeneration"] as? String)
    let content = try #require(tool["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let textResult = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textResult).isEqual(to: structured))
    return (itemIdentifier, checkpoint)
  }
}
