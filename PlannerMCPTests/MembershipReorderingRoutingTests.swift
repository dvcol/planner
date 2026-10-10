import Foundation
import PlannerCore
import Testing

@testable import Planner

struct MembershipReorderingRoutingTests {
  @Test func savedMembershipReorderOverHTTPRetainsAppearanceStateAndSharedItemAfterReopen()
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
    let session = try #require(await readySession(planner))
    let hotel = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Hotel", notes: "Keep"))
    )
    let museum = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Museum")))
    let list = try await createSource(
      planner, session: session, command: .createList(content: .init(name: "Tokyo")))
    let hotelMembership = try await createMembership(
      planner, session: session, itemId: hotel.id, listId: list.id)
    let museumMembership = try await createMembership(
      planner, session: session, itemId: museum.id, listId: list.id)
    let appearance = PlannerAppearance.listMembership(
      listId: list.id, membershipId: hotelMembership)
    let completed = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .setCompletion(scope: .appearance(appearance), done: true)))
    guard case .applied(_, .complete) = completed.outcome else {
      Issue.record("Expected local completion before reordering; got \(completed.outcome).")
      return
    }
    guard
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(hotel))
    else { throw TestSetupFailure() }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let command: [String: Any] = [
        "type": "reorderMembership", "listId": list.id.uuidString,
        "membershipId": hotelMembership.uuidString, "placement": ["kind": "last"],
      ]
      let arguments = operation(UUID(), command: command)
      let reordered = try payload(
        try await httpSession.data(for: request(endpoint: endpoint, arguments: arguments)))
      try #require(reordered["state"] as? String == "applied")
      #expect(((reordered["result"] as? [String: Any])?["generated"] as? [Any])?.isEmpty == true)
      var laterCommand = command
      laterCommand["placement"] = ["kind": "first"]
      let later = try payload(
        try await httpSession.data(
          for: request(endpoint: endpoint, arguments: operation(UUID(), command: laterCommand))))
      try #require(later["state"] as? String == "applied")
      let replay = try payload(
        try await httpSession.data(for: request(endpoint: endpoint, arguments: arguments)))
      #expect(NSDictionary(dictionary: replay).isEqual(to: reordered))
      var changedReplay = arguments
      changedReplay["command"] = laterCommand
      let rejectedReplay = try payload(
        try await httpSession.data(for: request(endpoint: endpoint, arguments: changedReplay)))
      #expect(rejectedReplay["state"] as? String == "rejected")
      #expect(
        (rejectedReplay["reason"] as? [String: Any])?["code"] as? String
          == "operationPayloadMismatch")
      let reopened = PlannerCore.Planner(configuration: configuration)
      let reopenedSession = try #require(await readySession(reopened))
      guard
        case .appearance(let retainedAppearance) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance)),
        case .source(.item(let retainedItem)) = await reopened.read(
          session: reopenedSession, request: .source(hotel)),
        case .source(.list(let retainedList)) = await reopened.read(
          session: reopenedSession, request: .source(list)),
        case .snapshot(let snapshot) = await reopened.query(
          PlannerQuery(
            session: reopenedSession,
            request: .items(
              .init(
                scope: .list(list.id), completion: .all, archive: .all,
                sort: .init(mode: .manual)))))
      else { throw TestSetupFailure() }
      #expect(retainedAppearance.appearance == appearance)
      #expect(retainedAppearance.localDone && retainedAppearance.effectiveDone)
      #expect(!retainedAppearance.globalDone)
      #expect(retainedItem.content.title == "Hotel" && retainedItem.content.notes == "Keep")
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(retainedList.references.count == 2)
      #expect(
        snapshot.rows.compactMap { row -> UUID? in
          if case .appearance(_, .listMembership(_, let membershipId)) = row {
            return membershipId
          }
          return nil
        } == [hotelMembership, museumMembership])
      #expect(retainedList.progress.doneCount == 1 && retainedList.progress.totalCount == 2)
    } catch {
      await listener.stop()
      throw error
    }
    await listener.stop()
  }

  @Test func advertisedReorderingUsesExactMembershipAnchorsAndRejectsInvalidHTTPCommands()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let session = try #require(await readySession(planner))
    let hotel = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Hotel")))
    let museum = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Museum")))
    let list = try await createSource(
      planner, session: session, command: .createList(content: .init(name: "Tokyo")))
    let otherList = try await createSource(
      planner, session: session, command: .createList(content: .init(name: "Other")))
    let hotelMembership = try await createMembership(
      planner, session: session, itemId: hotel.id, listId: list.id)
    let museumMembership = try await createMembership(
      planner, session: session, itemId: museum.id, listId: list.id)
    let foreignMembership = try await createMembership(
      planner, session: session, itemId: hotel.id, listId: otherList.id)
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let command: [String: Any] = [
        "type": "reorderMembership", "listId": list.id.uuidString,
        "membershipId": museumMembership.uuidString, "placement": ["kind": "first"],
      ]
      for kind in ["before", "after", "before"] {
        var anchored = command
        anchored["placement"] = ["kind": kind, "associationId": hotelMembership.uuidString]
        let applied = try payload(
          try await httpSession.data(
            for: request(endpoint: endpoint, arguments: operation(UUID(), command: anchored))))
        try #require(applied["state"] as? String == "applied")
      }
      guard
        case .source(.list(let beforeRejection)) = await planner.read(
          session: session, request: .source(list))
      else { throw TestSetupFailure() }
      let invalidRequests: [([String: Any], String, String?)] = [
        (
          command.merging(["listId": 1]) { _, incoming in incoming }, "invalidInput",
          "/command/listId"
        ),
        (
          command.merging(["membershipId": "bad"]) { _, incoming in incoming }, "invalidInput",
          "/command/membershipId"
        ),
        (
          command.merging(["placement": ["kind": "before"]]) { _, incoming in incoming },
          "invalidInput", "/command/placement/associationId"
        ),
        (
          command.merging(["placement": ["kind": "after", "associationId": 1]]) { _, incoming in
            incoming
          }, "invalidInput", "/command/placement/associationId"
        ),
        (
          command.merging([
            "placement": ["kind": "first", "associationId": hotelMembership.uuidString]
          ]) { _, incoming in incoming }, "unknownField", "/command/placement/associationId"
        ),
        (
          command.merging(["placement": ["kind": "middle"]]) { _, incoming in incoming },
          "invalidInput", "/command/placement/kind"
        ),
        (
          command.merging(["placement": ["kind": "last", "extra": true]]) { _, incoming in incoming
          }, "unknownField", "/command/placement/extra"
        ),
        (
          command.merging(["extra/~": true]) { _, incoming in incoming }, "unknownField",
          "/command/extra~1~0"
        ),
        (
          command.merging(["itemId": hotel.id.uuidString]) { _, incoming in incoming },
          "unknownField", "/command/itemId"
        ),
        (
          command.merging(["listId": otherList.id.uuidString]) { _, incoming in incoming },
          "missingReference", nil
        ),
        (
          command.merging(["membershipId": museum.id.uuidString]) { _, incoming in incoming },
          "missingReference", nil
        ),
        (
          command.merging([
            "placement": ["kind": "before", "associationId": foreignMembership.uuidString]
          ]) { _, incoming in incoming }, "missingReference", "/command/placement/associationId"
        ),
        (
          command.merging([
            "placement": ["kind": "after", "associationId": museumMembership.uuidString]
          ]) { _, incoming in incoming }, "invalidInput", "/command/placement/associationId"
        ),
      ]
      for (invalidCommand, expectedCode, expectedPath) in invalidRequests {
        let rejected = try payload(
          try await httpSession.data(
            for: request(endpoint: endpoint, arguments: operation(UUID(), command: invalidCommand)))
        )
        #expect(rejected["state"] as? String == "rejected")
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == expectedCode)
        #expect(reason["propertyPath"] as? String == expectedPath)
      }
      var listingRequest = try request(endpoint: endpoint, arguments: [:])
      listingRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": [:],
      ])
      let exchange = try await httpSession.data(for: listingRequest)
      #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
      let listing = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
      let tools = try #require((listing["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let tool = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let schema = try #require(tool["inputSchema"] as? [String: Any])
      let commands = try #require(
        (schema["properties"] as? [String: Any])?["command"] as? [String: Any])
      let variants = try #require(commands["oneOf"] as? [[String: Any]])
      let reordering = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
            == "reorderMembership"
        })
      #expect(reordering["additionalProperties"] as? Bool == false)
      #expect(
        reordering["required"] as? [String] == ["type", "listId", "membershipId", "placement"])
      let properties = try #require(reordering["properties"] as? [String: Any])
      #expect((properties["membershipId"] as? [String: Any])?["format"] as? String == "uuid")
      let placementSchema = try #require(properties["placement"] as? [String: Any])
      let placements = try #require(placementSchema["oneOf"] as? [[String: Any]])
      #expect(placements.count == 2)
      #expect(placements[0]["required"] as? [String] == ["kind"])
      #expect(placements[1]["required"] as? [String] == ["kind", "associationId"])
      guard
        case .source(.list(let retained)) = await planner.read(
          session: session, request: .source(list)),
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(
              .init(
                scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual)))
          ))
      else { throw TestSetupFailure() }
      #expect(retained.updatedAt == beforeRejection.updatedAt)
      #expect(retained.references == beforeRejection.references)
      #expect(retained.progress.doneCount == 0 && retained.progress.totalCount == 2)
      #expect(
        snapshot.rows.compactMap { row -> UUID? in
          if case .appearance(_, .listMembership(_, let membershipId)) = row { return membershipId }
          return nil
        } == [museumMembership, hotelMembership])
    } catch {
      await listener.stop()
      throw error
    }
    await listener.stop()
  }

  private struct TestSetupFailure: Error {}

  private func readySession(_ planner: PlannerCore.Planner) async -> PlannerDatasetSession? {
    if case .ready(let session) = await planner.bootstrap() { return session }
    return nil
  }

  private func createSource(
    _ planner: PlannerCore.Planner, session: PlannerDatasetSession, command: PlannerCommand
  ) async throws -> PlannerEntityReference {
    let result = await planner.execute(
      PlannerOperation(operationId: UUID(), session: session, command: command))
    guard case .applied(let applied, .complete) = result.outcome else {
      Issue.record("Expected applied fixture creation; got \(result.outcome).")
      throw TestSetupFailure()
    }
    let source = try #require(applied.generated.first)
    return source
  }

  private func operation(_ operationId: UUID, command: [String: Any]) -> [String: Any] {
    ["formatVersion": 1, "operationId": operationId.uuidString, "command": command]
  }

  private func createMembership(
    _ planner: PlannerCore.Planner, session: PlannerDatasetSession, itemId: UUID, listId: UUID
  ) async throws -> UUID {
    let result = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .addMembership(itemId: itemId, listId: listId, placement: .last)))
    guard case .applied(let applied, .complete) = result.outcome,
      case .membership(let membershipId, _, _)? = applied.generatedReferences.first
    else { throw TestSetupFailure() }
    return membershipId
  }

  private func request(endpoint: URL, arguments: [String: Any]) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 1, "method": "tools/call",
      "params": ["name": "planner_execute", "arguments": arguments],
    ])
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.timeoutInterval = 5
    return request
  }

  private func payload(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    let response = try #require(exchange.1 as? HTTPURLResponse)
    #expect(response.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    let structured = try #require(tool["structuredContent"] as? [String: Any])
    #expect(tool["isError"] as? Bool == (structured["state"] as? String == "rejected"))
    let content = try #require(tool["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let textValue = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textValue).isEqual(to: structured))
    return structured
  }
}
