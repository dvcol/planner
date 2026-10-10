import Foundation
import PlannerCore
import Testing

@testable import Planner

struct MembershipMutationRoutingTests {
  @Test func removalOverHTTPPreservesSharedItemAndReplayCannotRemoveANewMembership() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    let session = try #require(await readySession(planner))
    let item = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Hotel", notes: "Keep"))
    )
    let list = try await createSource(
      planner, session: session, command: .createList(content: .init(name: "Tokyo")))
    let otherList = try await createSource(
      planner, session: session, command: .createList(content: .init(name: "Wishlist")))
    let membership = try await createMembership(
      planner, session: session, itemId: item.id, listId: list.id)
    let otherMembership = try await createMembership(
      planner, session: session, itemId: item.id, listId: otherList.id)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(
            scope: .appearance(.listMembership(listId: list.id, membershipId: membership)),
            done: true))
      ).outcome,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item))
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
        "type": "removeMembership", "listId": list.id.uuidString,
        "membershipId": membership.uuidString,
      ]
      let arguments = operation(UUID(), command: command)
      let removed = try payload(
        try await httpSession.data(for: request(endpoint: endpoint, arguments: arguments)))
      try #require(removed["state"] as? String == "applied")
      #expect(((removed["result"] as? [String: Any])?["generated"] as? [Any])?.isEmpty == true)
      guard
        case .source(.list(let emptied)) = await planner.read(
          session: session, request: .source(list))
      else { throw TestSetupFailure() }
      #expect(emptied.references.isEmpty && emptied.progress.state == .empty)
      let replacement = try await createMembership(
        planner, session: session, itemId: item.id, listId: list.id)
      #expect(replacement != membership)
      let replay = try payload(
        try await httpSession.data(for: request(endpoint: endpoint, arguments: arguments)))
      #expect(NSDictionary(dictionary: replay).isEqual(to: removed))
      var changed = command
      changed["membershipId"] = replacement.uuidString
      var changedArguments = arguments
      changedArguments["command"] = changed
      let mismatch = try payload(
        try await httpSession.data(for: request(endpoint: endpoint, arguments: changedArguments)))
      #expect(
        (mismatch["reason"] as? [String: Any])?["code"] as? String == "operationPayloadMismatch")
      let missing = try payload(
        try await httpSession.data(
          for: request(endpoint: endpoint, arguments: operation(UUID(), command: command))))
      #expect((missing["reason"] as? [String: Any])?["code"] as? String == "missingReference")
      let reopened = PlannerCore.Planner(configuration: configuration)
      let reopenedSession = try #require(await readySession(reopened))
      guard
        case .source(.item(let retainedItem)) = await reopened.read(
          session: reopenedSession, request: .source(item)),
        case .source(.list(let retainedList)) = await reopened.read(
          session: reopenedSession, request: .source(list)),
        case .appearance(let replacementAppearance) = await reopened.read(
          session: reopenedSession,
          request: .appearance(.listMembership(listId: list.id, membershipId: replacement))),
        case .appearance(let otherAppearance) = await reopened.read(
          session: reopenedSession,
          request: .appearance(.listMembership(listId: otherList.id, membershipId: otherMembership))
        ),
        case .failed(let removedAppearance) = await reopened.read(
          session: reopenedSession,
          request: .appearance(.listMembership(listId: list.id, membershipId: membership)))
      else { throw TestSetupFailure() }
      #expect(retainedItem.content.title == "Hotel" && retainedItem.content.notes == "Keep")
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(retainedList.references == [.membership(id: replacement, list: list, item: item)])
      #expect(!replacementAppearance.localDone && !replacementAppearance.effectiveDone)
      #expect(!otherAppearance.localDone && !otherAppearance.effectiveDone)
      #expect(removedAppearance.code == "missingReference")
    } catch {
      await listener.stop()
      throw error
    }
    await listener.stop()
  }
  @Test func moveOverHTTPCreatesTodoOrRetainsTheExistingDestinationWithoutCopyingTheItem()
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
    let item = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Hotel", notes: "Keep"))
    )
    let museum = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Museum")))
    let list = try await createSource(
      planner, session: session, command: .createList(content: .init(name: "Tokyo")))
    let destination = try await createSource(
      planner, session: session, command: .createList(content: .init(name: "Wishlist")))
    let membership = try await createMembership(
      planner, session: session, itemId: item.id, listId: list.id)
    let anchor = try await createMembership(
      planner, session: session, itemId: museum.id, listId: destination.id)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(
            scope: .appearance(.listMembership(listId: list.id, membershipId: membership)),
            done: true))
      ).outcome,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item))
    else { throw TestSetupFailure() }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let command: [String: Any] = [
        "type": "moveMembership", "listId": list.id.uuidString,
        "membershipId": membership.uuidString, "destinationListId": destination.id.uuidString,
        "placement": ["kind": "after", "associationId": anchor.uuidString],
      ]
      let arguments = operation(UUID(), command: command)
      let moved = try payload(
        try await httpSession.data(for: request(endpoint: endpoint, arguments: arguments)))
      try #require(moved["state"] as? String == "applied")
      let generated = try #require(
        (moved["result"] as? [String: Any])?["generated"] as? [[String: Any]])
      #expect(generated.count == 1)
      let generatedReference = try #require(generated.first)
      #expect(generatedReference["kind"] as? String == "membership")
      #expect(
        (generatedReference["owner"] as? [String: Any])?["id"] as? String
          == destination.id.uuidString)
      #expect(
        (generatedReference["source"] as? [String: Any])?["id"] as? String == item.id.uuidString)
      let movedMembership = try #require(
        (generatedReference["id"] as? String).flatMap(UUID.init(uuidString:)))
      #expect(movedMembership != membership)
      guard
        case .appearance(let newAppearance) = await planner.read(
          session: session,
          request: .appearance(
            .listMembership(listId: destination.id, membershipId: movedMembership)))
      else { throw TestSetupFailure() }
      #expect(!newAppearance.localDone && !newAppearance.effectiveDone && !newAppearance.globalDone)
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .setCompletion(scope: .appearance(newAppearance.appearance), done: true))
        ).outcome
      else { throw TestSetupFailure() }
      let replacement = try await createMembership(
        planner, session: session, itemId: item.id, listId: list.id)
      var existingCommand = command
      existingCommand["membershipId"] = replacement.uuidString
      existingCommand["placement"] = ["kind": "first"]
      let retained = try payload(
        try await httpSession.data(
          for: request(endpoint: endpoint, arguments: operation(UUID(), command: existingCommand))))
      #expect(retained["state"] as? String == "applied")
      #expect(((retained["result"] as? [String: Any])?["generated"] as? [Any])?.isEmpty == true)
      let replay = try payload(
        try await httpSession.data(for: request(endpoint: endpoint, arguments: arguments)))
      #expect(NSDictionary(dictionary: replay).isEqual(to: moved))
      var changedArguments = arguments
      var changedCommand = command
      changedCommand["placement"] = ["kind": "last"]
      changedArguments["command"] = changedCommand
      let mismatch = try payload(
        try await httpSession.data(for: request(endpoint: endpoint, arguments: changedArguments)))
      #expect(
        (mismatch["reason"] as? [String: Any])?["code"] as? String == "operationPayloadMismatch")
      let reopened = PlannerCore.Planner(configuration: configuration)
      let reopenedSession = try #require(await readySession(reopened))
      guard
        case .source(.item(let retainedItem)) = await reopened.read(
          session: reopenedSession, request: .source(item)),
        case .source(.list(let emptiedList)) = await reopened.read(
          session: reopenedSession, request: .source(list)),
        case .appearance(let retainedAppearance) = await reopened.read(
          session: reopenedSession,
          request: .appearance(
            .listMembership(listId: destination.id, membershipId: movedMembership))),
        case .snapshot(let snapshot) = await reopened.query(
          PlannerQuery(
            session: reopenedSession,
            request: .items(
              .init(
                scope: .list(destination.id), completion: .all, archive: .all,
                sort: .init(mode: .manual)))))
      else { throw TestSetupFailure() }
      #expect(emptiedList.references.isEmpty && emptiedList.progress.state == .empty)
      #expect(retainedAppearance.localDone && retainedAppearance.effectiveDone)
      #expect(!retainedAppearance.globalDone)
      #expect(retainedItem.content.title == "Hotel" && retainedItem.content.notes == "Keep")
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(
        snapshot.rows == [
          .appearance(
            source: museum,
            appearance: .listMembership(listId: destination.id, membershipId: anchor)),
          .appearance(
            source: item,
            appearance: .listMembership(listId: destination.id, membershipId: movedMembership)),
        ])
    } catch {
      await listener.stop()
      throw error
    }
    await listener.stop()
  }

  @Test func strictAdvertisedMutationShapesRejectInvalidRequestsWithoutChangingEitherList()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let session = try #require(await readySession(planner))
    let item = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Hotel", notes: "Keep"))
    )
    let museum = try await createSource(
      planner, session: session, command: .createItem(content: .init(title: "Museum")))
    let list = try await createSource(
      planner, session: session, command: .createList(content: .init(name: "Tokyo")))
    let destination = try await createSource(
      planner, session: session, command: .createList(content: .init(name: "Wishlist")))
    let membership = try await createMembership(
      planner, session: session, itemId: item.id, listId: list.id)
    let anchor = try await createMembership(
      planner, session: session, itemId: museum.id, listId: destination.id)
    let appearance = PlannerAppearance.listMembership(listId: list.id, membershipId: membership)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(appearance), done: true))
      ).outcome,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.list(let originalDestination)) = await planner.read(
        session: session, request: .source(destination)),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual)))))
    else { throw TestSetupFailure() }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      var listingRequest = try request(endpoint: endpoint, arguments: [:])
      listingRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 1, "method": "tools/list",
      ])
      let listingExchange = try await httpSession.data(for: listingRequest)
      #expect((listingExchange.1 as? HTTPURLResponse)?.statusCode == 200)
      let listing = try #require(
        JSONSerialization.jsonObject(with: listingExchange.0) as? [String: Any])
      let tools = try #require((listing["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let execution = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let schema = try #require(execution["inputSchema"] as? [String: Any])
      let properties = try #require(schema["properties"] as? [String: Any])
      let commands = try #require(
        (properties["command"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      for (type, required) in [
        ("removeMembership", ["type", "listId", "membershipId"]),
        ("moveMembership", ["type", "listId", "membershipId", "destinationListId", "placement"]),
      ] {
        let commandSchema = try #require(
          commands.first {
            (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
              == type
          })
        #expect(commandSchema["additionalProperties"] as? Bool == false)
        #expect(Set(commandSchema["required"] as? [String] ?? []) == Set(required))
        let commandProperties = try #require(commandSchema["properties"] as? [String: Any])
        #expect(Set(commandProperties.keys) == Set(required))
        if type == "moveMembership" {
          let placement = try #require(commandProperties["placement"] as? [String: Any])
          let variants = try #require(placement["oneOf"] as? [[String: Any]])
          #expect(variants.count == 2)
          #expect(variants.allSatisfy { $0["additionalProperties"] as? Bool == false })
        }
      }
      let remove: [String: Any] = [
        "type": "removeMembership", "listId": list.id.uuidString,
        "membershipId": membership.uuidString,
      ]
      let move: [String: Any] = [
        "type": "moveMembership", "listId": list.id.uuidString,
        "membershipId": membership.uuidString,
        "destinationListId": destination.id.uuidString,
        "placement": ["kind": "before", "associationId": anchor.uuidString],
      ]
      let variants: [([String: Any], String, String?)] = [
        (
          remove.merging(["listId": "invalid"]) { _, incoming in incoming }, "invalidInput",
          "/command/listId"
        ),
        (remove.filter { $0.key != "membershipId" }, "invalidInput", "/command/membershipId"),
        (
          remove.merging(["placement": ["kind": "last"]]) { _, incoming in incoming },
          "unknownField", "/command/placement"
        ),
        (
          remove.merging(["destination/list~id": "invalid"]) { _, incoming in incoming },
          "unknownField", "/command/destination~1list~0id"
        ),
        (
          remove.merging(["listId": destination.id.uuidString]) { _, incoming in incoming },
          "missingReference", nil
        ),
        (
          remove.merging(["membershipId": item.id.uuidString]) { _, incoming in incoming },
          "missingReference", nil
        ),
        (
          move.merging(["destinationListId": "invalid"]) { _, incoming in incoming },
          "invalidInput", "/command/destinationListId"
        ),
        (
          move.merging(["destinationListId": list.id.uuidString]) { _, incoming in incoming },
          "invalidInput", "/command/destinationListId"
        ),
        (
          move.merging(["destinationListId": item.id.uuidString]) { _, incoming in incoming },
          "missingReference", nil
        ),
        (
          move.merging(["placement": ["kind": "before", "associationId": membership.uuidString]]) {
            _, incoming in incoming
          }, "missingReference", "/command/placement/associationId"
        ),
        (
          move.merging(["placement": ["kind": "last", "associationId": anchor.uuidString]]) {
            _, incoming in incoming
          }, "unknownField", "/command/placement/associationId"
        ),
        (move.filter { $0.key != "placement" }, "invalidInput", "/command/placement"),
        (
          move.filter { $0.key != "destinationListId" }, "invalidInput",
          "/command/destinationListId"
        ),
        (
          move.merging(["placement": ["kind": "end"]]) { _, incoming in incoming }, "invalidInput",
          "/command/placement/kind"
        ),
      ]
      for (command, code, path) in variants {
        let operationIdentifier = UUID()
        let rejected = try payload(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, arguments: operation(operationIdentifier, command: command))))
        #expect(rejected["state"] as? String == "rejected")
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        #expect(reason["propertyPath"] as? String == path)
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: session, operationId: operationIdentifier)
        else { throw TestSetupFailure() }
      }
      guard
        case .source(.list(let retainedList)) = await planner.read(
          session: session, request: .source(list)),
        case .source(.list(let retainedDestination)) = await planner.read(
          session: session, request: .source(destination)),
        case .source(.item(let retainedItem)) = await planner.read(
          session: session, request: .source(item)),
        case .appearance(let retainedAppearance) = await planner.read(
          session: session, request: .appearance(appearance)),
        case .rows(let retainedWindow) = await planner.read(
          session: session, request: .rows(generation: issued.generation, offset: 0, limit: 1)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else { throw TestSetupFailure() }
      #expect(retainedList.references == originalList.references)
      #expect(retainedList.updatedAt == originalList.updatedAt)
      #expect(retainedDestination.references == originalDestination.references)
      #expect(retainedDestination.updatedAt == originalDestination.updatedAt)
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(
        retainedAppearance.localDone && retainedAppearance.effectiveDone
          && !retainedAppearance.globalDone)
      #expect(retainedWindow.rows.count == 1)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 7)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
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
