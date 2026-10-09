import Foundation
import PlannerCore
import Testing

@testable import Planner

struct MembershipCreationRoutingTests {
  @Test func membershipAdditionOverHTTPRetainsLiveIdentityOrderLocalCompletionAndReplay()
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
    let firstItem = try #require(
      await createSource(
        planner, session: session, command: .createItem(content: .init(title: "Y"))))
    let secondItem = try #require(
      await createSource(
        planner, session: session, command: .createItem(content: .init(title: "X", notes: "Keep"))))
    let list = try #require(
      await createSource(
        planner, session: session, command: .createList(content: .init(name: "Tokyo"))))
    guard
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(secondItem))
    else {
      Issue.record("The shared Item must be readable before organizing it over HTTP.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let first = try payload(
        try await httpSession.data(
          for: request(
            endpoint: endpoint,
            arguments: addition(
              firstItem.id, list: list.id, operationId: UUID(), placement: "first"))))
      #expect(first["state"] as? String == "applied")
      let operationId = UUID()
      let arguments = addition(
        secondItem.id, list: list.id, operationId: operationId, placement: "last")
      let added = try payload(
        try await httpSession.data(for: request(endpoint: endpoint, arguments: arguments)))
      #expect(added["state"] as? String == "applied")
      let generated = try #require(
        (added["result"] as? [String: Any])?["generated"] as? [[String: Any]])
      #expect(generated.count == 1)
      let membership = try #require(generated.first)
      #expect(membership["kind"] as? String == "membership")
      let identifier = try #require(membership["id"] as? String)
      let membershipId = try #require(UUID(uuidString: identifier))
      #expect(membershipId != secondItem.id && membershipId != list.id)
      #expect((membership["owner"] as? [String: Any])?["id"] as? String == list.id.uuidString)
      #expect(
        (membership["source"] as? [String: Any])?["id"] as? String == secondItem.id.uuidString)
      #expect(
        (membership["appearance"] as? [String: Any])?["membershipId"] as? String == identifier)
      #expect((added["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "5")
      let appearance = PlannerAppearance.listMembership(listId: list.id, membershipId: membershipId)
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .setCompletion(scope: .appearance(appearance), done: true))
        )
        .outcome,
        case .source(.list(let beforeDuplicate)) = await planner.read(
          session: session, request: .source(list))
      else {
        throw TestSetupFailure()
      }
      let duplicate = try payload(
        try await httpSession.data(
          for: request(
            endpoint: endpoint,
            arguments: addition(
              secondItem.id, list: list.id, operationId: UUID(), placement: "first"))))
      #expect(duplicate["state"] as? String == "applied")
      #expect(((duplicate["result"] as? [String: Any])?["generated"] as? [Any])?.isEmpty == true)
      #expect((duplicate["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "7")
      let replay = try payload(
        try await httpSession.data(for: request(endpoint: endpoint, arguments: arguments)))
      #expect(NSDictionary(dictionary: replay).isEqual(to: added))
      let changedReplay = try payload(
        try await httpSession.data(
          for: request(
            endpoint: endpoint,
            arguments: addition(
              secondItem.id, list: list.id, operationId: operationId, placement: "first"))))
      #expect(changedReplay["state"] as? String == "rejected")
      #expect(
        (changedReplay["reason"] as? [String: Any])?["code"] as? String
          == "operationPayloadMismatch")
      let reopened = PlannerCore.Planner(configuration: configuration)
      let reopenedSession = try #require(await readySession(reopened))
      guard
        case .appearance(let retained) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance)),
        case .source(.item(let retainedItem)) = await reopened.read(
          session: reopenedSession, request: .source(secondItem)),
        case .source(.list(let retainedList)) = await reopened.read(
          session: reopenedSession, request: .source(list)),
        case .snapshot(let snapshot) = await reopened.query(
          PlannerQuery(
            session: reopenedSession,
            request: .items(
              .init(
                scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual)))
          )),
        case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(
          request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await reopened.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 7))
      else {
        throw TestSetupFailure()
      }
      #expect(retained.source == secondItem)
      #expect(retained.localDone && retained.effectiveDone && !retained.globalDone)
      #expect(retainedItem.content.title == "X" && retainedItem.content.notes == "Keep")
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(retainedList.references.count == 2)
      #expect(retainedList.updatedAt == beforeDuplicate.updatedAt)
      #expect(retainedList.progress.doneCount == 1 && retainedList.progress.totalCount == 2)
      #expect(
        snapshot.rows.compactMap { row -> UUID? in
          if case .appearance(let source, _) = row { return source.id }
          return nil
        } == [firstItem.id, secondItem.id])
      #expect(recovery.decodedBackup.backup.memberships.count == 2)
      #expect(
        recovery.decodedBackup.backup.memberships.first { $0.id == membershipId }?.localDone == true
      )
      #expect(namespace.preparedProposals.isEmpty)
    } catch {
      await listener.stop()
      throw error
    }
    await listener.stop()
  }

  @Test func anchoredMembershipAdditionIsAdvertisedAndRejectsInvalidRequestsWithoutChangingTheList()
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
    let anchorItem = try #require(
      await createSource(
        planner, session: session, command: .createItem(content: .init(title: "A"))))
    let beforeItem = try #require(
      await createSource(
        planner, session: session, command: .createItem(content: .init(title: "B"))))
    let afterItem = try #require(
      await createSource(
        planner, session: session, command: .createItem(content: .init(title: "C"))))
    let list = try #require(
      await createSource(
        planner, session: session, command: .createList(content: .init(name: "Tokyo"))))
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let anchorResult = try payload(
        try await httpSession.data(
          for: request(
            endpoint: endpoint,
            arguments: addition(
              anchorItem.id, list: list.id, operationId: UUID(), placement: "last"))))
      let anchor = try #require(
        ((anchorResult["result"] as? [String: Any])?["generated"] as? [[String: Any]])?.first?["id"]
          as? String)
      for (source, placement) in [(beforeItem, "before"), (afterItem, "after")] {
        var arguments = addition(
          source.id, list: list.id, operationId: UUID(), placement: placement)
        var command = try #require(arguments["command"] as? [String: Any])
        command["placement"] = ["kind": placement, "associationId": anchor]
        arguments["command"] = command
        let added = try payload(
          try await httpSession.data(for: request(endpoint: endpoint, arguments: arguments)))
        #expect(added["state"] as? String == "applied")
      }
      let valid = try #require(
        addition(beforeItem.id, list: list.id, operationId: UUID(), placement: "last")["command"]
          as? [String: Any])
      let invalidRequests: [([String: Any], String, String)] = [
        (
          valid.merging(["itemId": 1]) { _, incoming in incoming }, "invalidInput",
          "/command/itemId"
        ),
        (
          valid.merging(["listId": "bad"]) { _, incoming in incoming }, "invalidInput",
          "/command/listId"
        ),
        (
          valid.merging(["placement": ["kind": "before"]]) { _, incoming in incoming },
          "invalidInput", "/command/placement/associationId"
        ),
        (
          valid.merging(["placement": ["kind": "after", "associationId": 1]]) { _, incoming in
            incoming
          }, "invalidInput", "/command/placement/associationId"
        ),
        (
          valid.merging(["placement": ["kind": "first", "associationId": anchor]]) { _, incoming in
            incoming
          }, "unknownField", "/command/placement/associationId"
        ),
        (
          valid.merging(["placement": ["kind": "middle"]]) { _, incoming in incoming },
          "invalidInput", "/command/placement/kind"
        ),
        (
          valid.merging(["weird/~": true]) { _, incoming in incoming }, "unknownField",
          "/command/weird~1~0"
        ),
      ]
      for (command, expectedCode, expectedPath) in invalidRequests {
        let rejected = try payload(
          try await httpSession.data(
            for: request(
              endpoint: endpoint,
              arguments: ["formatVersion": 1, "operationId": UUID().uuidString, "command": command])
          ))
        #expect(rejected["state"] as? String == "rejected")
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == expectedCode)
        #expect(reason["propertyPath"] as? String == expectedPath)
      }
      var listingRequest = try request(endpoint: endpoint, arguments: [:])
      listingRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": [:],
      ])
      let listingExchange = try await httpSession.data(for: listingRequest)
      let listing = try #require(
        JSONSerialization.jsonObject(with: listingExchange.0) as? [String: Any])
      let tools = try #require((listing["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let tool = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let schema = try #require(tool["inputSchema"] as? [String: Any])
      let commands = try #require(
        (schema["properties"] as? [String: Any])?["command"] as? [String: Any])
      let variants = try #require(commands["oneOf"] as? [[String: Any]])
      let additionSchema = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
            == "addMembership"
        })
      let placementSchema = try #require(
        (additionSchema["properties"] as? [String: Any])?["placement"] as? [String: Any])
      let placements = try #require(placementSchema["oneOf"] as? [[String: Any]])
      #expect(placements.count == 2)
      #expect((placements[1]["required"] as? [String]) == ["kind", "associationId"])
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(
            session: session,
            request: .items(
              .init(
                scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual)))
          )),
        case .source(.list(let retained)) = await planner.read(
          session: session, request: .source(list)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else { throw TestSetupFailure() }
      #expect(
        snapshot.rows.compactMap { row -> UUID? in
          if case .appearance(let source, _) = row { return source.id }
          return nil
        } == [beforeItem.id, anchorItem.id, afterItem.id])
      #expect(retained.references.count == 3)
      #expect(retained.progress.doneCount == 0 && retained.progress.totalCount == 3)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 7)
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
  ) async -> PlannerEntityReference? {
    if case .applied(let applied, .complete) = await planner.execute(
      PlannerOperation(operationId: UUID(), session: session, command: command)
    ).outcome {
      return applied.generated.first
    }
    return nil
  }

  private func addition(_ itemId: UUID, list: UUID, operationId: UUID, placement: String)
    -> [String: Any]
  {
    [
      "formatVersion": 1, "operationId": operationId.uuidString,
      "command": [
        "type": "addMembership", "itemId": itemId.uuidString,
        "listId": list.uuidString, "placement": ["kind": placement],
      ],
    ]
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
