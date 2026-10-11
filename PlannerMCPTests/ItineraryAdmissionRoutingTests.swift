import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItineraryAdmissionRoutingTests {
  @Test func advertisedEntryAndAppearanceVariantsRejectInvalidScopesWithoutChangingSavedData()
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
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    let otherList = try #require(
      try await save(.createList(content: .init(name: "Other List"))).generated.first)
    let otherItinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Other Route"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first,
      case .membership(let foreignMembershipId, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: otherList.id, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let directEntryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let listEntryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let foreignEntryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: otherItinerary.id, source: item, placement: .last)
      ).generatedReferences.first,
      case .source(.itinerary(let before)) = await planner.read(
        session: datasetSession, request: .source(itinerary)),
      case .source(.item(let originalItem)) = await planner.read(
        session: datasetSession, request: .source(item)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let original) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let listing = try result(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, method: "tools/list", parameters: [:])))
      let tools = try #require(listing["tools"] as? [[String: Any]])
      let execution = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let executionSchema = try #require(execution["inputSchema"] as? [String: Any])
      let commands = try #require(
        (executionSchema["properties"] as? [String: Any])?["command"] as? [String: Any])
      let variants = try #require(commands["oneOf"] as? [[String: Any]])
      for (commandType, required) in [
        ("addItineraryEntry", Set(["type", "itineraryId", "source", "placement"])),
        ("removeItineraryEntry", Set(["type", "itineraryId", "entryId"])),
        ("reorderItineraryEntry", Set(["type", "itineraryId", "entryId", "placement"])),
      ] {
        let variant = try #require(
          variants.first {
            (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
              == commandType
          })
        #expect(variant["additionalProperties"] as? Bool == false)
        #expect(Set(try #require(variant["required"] as? [String])) == required)
        #expect(Set(try #require(variant["properties"] as? [String: Any]).keys) == required)
      }
      let completion = try #require(
        variants.first {
          (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
            == "setCompletion"
        })
      let scope = try #require(
        (completion["properties"] as? [String: Any])?["scope"] as? [String: Any])
      let scopes = try #require(scope["oneOf"] as? [[String: Any]])
      let appearanceScope = try #require(
        scopes.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "appearance"
        })
      let completionAppearance = try #require(
        (appearanceScope["properties"] as? [String: Any])?["appearance"] as? [String: Any])
      let readTool = try #require(tools.first { $0["name"] as? String == "planner_read" })
      let readSchema = try #require(readTool["inputSchema"] as? [String: Any])
      let requests = try #require(
        (readSchema["properties"] as? [String: Any])?["request"] as? [String: Any])
      let readVariants = try #require(requests["oneOf"] as? [[String: Any]])
      let appearanceRequest = try #require(
        readVariants.first {
          (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
            == "appearance"
        })
      let readAppearance = try #require(
        (appearanceRequest["properties"] as? [String: Any])?["appearance"] as? [String: Any])
      #expect(NSDictionary(dictionary: completionAppearance).isEqual(to: readAppearance))
      let appearanceVariants = try #require(readAppearance["oneOf"] as? [[String: Any]])
      #expect(appearanceVariants.count == 3)
      for (kind, required) in [
        ("listMembership", Set(["kind", "listId", "membershipId"])),
        ("directItineraryItem", Set(["kind", "itineraryId", "entryId"])),
        ("expandedListItem", Set(["kind", "itineraryId", "listEntryId", "membershipId"])),
      ] {
        let variant = try #require(
          appearanceVariants.first {
            (($0["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"] as? String
              == kind
          })
        #expect(variant["additionalProperties"] as? Bool == false)
        #expect(Set(try #require(variant["required"] as? [String])) == required)
      }
      let addition: [String: Any] = [
        "type": "addItineraryEntry", "itineraryId": itinerary.id.uuidString,
        "source": ["kind": "item", "id": item.id.uuidString], "placement": ["kind": "last"],
      ]
      let removal: [String: Any] = [
        "type": "removeItineraryEntry", "itineraryId": itinerary.id.uuidString,
        "entryId": directEntryId.uuidString,
      ]
      let reorder: [String: Any] = [
        "type": "reorderItineraryEntry", "itineraryId": itinerary.id.uuidString,
        "entryId": directEntryId.uuidString, "placement": ["kind": "last"],
      ]
      func replacing(_ command: [String: Any], field: String, value: Any) -> [String: Any] {
        var changed = command
        changed[field] = value
        return changed
      }
      var missingOwner = addition
      missingOwner.removeValue(forKey: "itineraryId")
      let invalidCommands: [(command: [String: Any], code: String, path: String?)] = [
        (missingOwner, "invalidInput", "/command/itineraryId"),
        (
          replacing(addition, field: "itineraryId", value: "bad"), "invalidInput",
          "/command/itineraryId"
        ),
        (
          replacing(
            addition, field: "source", value: ["kind": "itinerary", "id": itinerary.id.uuidString]),
          "invalidInput", "/command/source/kind"
        ),
        (
          replacing(addition, field: "source", value: ["kind": "item", "id": NSNull()]),
          "invalidInput", "/command/source/id"
        ),
        (
          replacing(addition, field: "placement", value: ["kind": "last", "extra/~": true]),
          "unknownField", "/command/placement/extra~1~0"
        ),
        (
          replacing(addition, field: "placement", value: ["kind": "after"]), "invalidInput",
          "/command/placement/associationId"
        ),
        (
          replacing(
            addition, field: "placement",
            value: ["kind": "before", "associationId": foreignEntryId.uuidString]),
          "missingReference", "/command/placement/associationId"
        ),
        (
          replacing(removal, field: "placement", value: ["kind": "first"]), "unknownField",
          "/command/placement"
        ),
        (replacing(removal, field: "entryId", value: NSNull()), "invalidInput", "/command/entryId"),
        (replacing(removal, field: "entryId", value: item.id.uuidString), "missingReference", nil),
        (
          replacing(removal, field: "itineraryId", value: otherItinerary.id.uuidString),
          "missingReference", nil
        ),
        (
          replacing(
            reorder, field: "placement",
            value: ["kind": "before", "associationId": directEntryId.uuidString]), "invalidInput",
          "/command/placement/associationId"
        ),
      ]
      for testCase in invalidCommands {
        let operationId = UUID()
        let response = try result(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, method: "tools/call",
              parameters: [
                "name": "planner_execute",
                "arguments": [
                  "formatVersion": 1, "operationId": operationId.uuidString,
                  "command": testCase.command,
                ],
              ])))
        #expect(response["isError"] as? Bool == true)
        let structured = try #require(response["structuredContent"] as? [String: Any])
        #expect(structured["state"] as? String == "rejected")
        let failure = try #require(structured["reason"] as? [String: Any])
        #expect(failure["code"] as? String == testCase.code)
        #expect(failure["propertyPath"] as? String == testCase.path)
        let text = try #require(
          (response["content"] as? [[String: Any]])?.first?["text"] as? String)
        let encoded = try #require(
          JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        #expect(NSDictionary(dictionary: encoded).isEqual(to: structured))
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationId)
        else { throw CancellationError() }
      }
      let direct: [String: Any] = [
        "kind": "directItineraryItem", "itineraryId": itinerary.id.uuidString,
        "entryId": directEntryId.uuidString,
      ]
      let expanded: [String: Any] = [
        "kind": "expandedListItem", "itineraryId": itinerary.id.uuidString,
        "listEntryId": listEntryId.uuidString, "membershipId": membershipId.uuidString,
      ]
      var missingEntry = direct
      missingEntry.removeValue(forKey: "entryId")
      var missingMembership = expanded
      missingMembership.removeValue(forKey: "membershipId")
      let invalidAppearances: [(appearance: [String: Any], code: String, suffix: String?)] = [
        (missingEntry, "invalidInput", "/entryId"),
        (replacing(direct, field: "entryId", value: "bad"), "invalidInput", "/entryId"),
        (replacing(direct, field: "kind", value: "unknown"), "invalidInput", "/kind"),
        (replacing(direct, field: "listId", value: list.id.uuidString), "unknownField", "/listId"),
        (
          replacing(direct, field: "entryId", value: listEntryId.uuidString), "missingReference",
          nil
        ),
        (missingMembership, "invalidInput", "/membershipId"),
        (
          replacing(expanded, field: "listEntryId", value: NSNull()), "invalidInput", "/listEntryId"
        ),
        (
          replacing(expanded, field: "entryId", value: directEntryId.uuidString), "unknownField",
          "/entryId"
        ),
        (
          replacing(expanded, field: "membershipId", value: foreignMembershipId.uuidString),
          "missingReference", nil
        ),
        (
          replacing(expanded, field: "itineraryId", value: otherItinerary.id.uuidString),
          "missingReference", nil
        ),
        (
          replacing(expanded, field: "listEntryId", value: directEntryId.uuidString),
          "missingReference", nil
        ),
      ]
      for testCase in invalidAppearances {
        for toolName in ["planner_execute", "planner_read"] {
          let operationId = UUID()
          var arguments: [String: Any] = ["formatVersion": 1]
          if toolName == "planner_execute" {
            arguments["operationId"] = operationId.uuidString
            arguments["command"] = [
              "type": "setCompletion",
              "scope": ["kind": "appearance", "appearance": testCase.appearance], "done": true,
            ]
          } else {
            arguments["request"] = ["kind": "appearance", "appearance": testCase.appearance]
          }
          let response = try result(
            try await httpSession.data(
              for: request(
                endpoint: endpoint, method: "tools/call",
                parameters: [
                  "name": toolName, "arguments": arguments,
                ])))
          #expect(response["isError"] as? Bool == true)
          let structured = try #require(response["structuredContent"] as? [String: Any])
          let failure = try #require(structured["reason"] as? [String: Any])
          #expect(failure["code"] as? String == testCase.code)
          let prefix =
            toolName == "planner_execute" ? "/command/scope/appearance" : "/request/appearance"
          #expect(failure["propertyPath"] as? String == testCase.suffix.map { prefix + $0 })
          if toolName == "planner_execute" {
            guard
              case .noReliableEvidence = await planner.operationStatus(
                session: datasetSession, operationId: operationId)
            else { throw CancellationError() }
          }
        }
      }
      guard
        case .source(.itinerary(let retained)) = await planner.read(
          session: datasetSession, request: .source(itinerary)),
        case .source(.item(let retainedItem)) = await planner.read(
          session: datasetSession, request: .source(item)),
        case .listedNamespaces(let currentNamespaces) = await planner.inspectRecovery(
          request: .namespaces),
        case .selected(let recovered) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      #expect(retained.references == before.references)
      #expect(retained.updatedAt == before.updatedAt)
      #expect(retained.progress.doneCount == 0 && retained.progress.totalCount == 2)
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(retainedItem.state.globalDone == false)
      #expect(currentNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
      #expect(recovered.portableData == original.portableData)
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
}
