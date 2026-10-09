import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ListRoutingTests {
  @Test func listCreationAndDetailReadRetainOwnedMetadataAndEmptyDerivedProgress() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = storageConfiguration(directory)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The native dataset must initialize before actual HTTP List creation.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let originalContent: [String: Any] = [
      "name": " Tokyo Food ", "notes": "", "iconName": "fork.knife",
      "color": ["red": 0.125, "green": 0.5, "blue": 0.75, "alpha": 1.0],
    ]
    let originalOperationIdentifier = UUID()
    let creation: [String: Any] = [
      "formatVersion": 1, "operationId": originalOperationIdentifier.uuidString,
      "command": ["type": "createList", "content": originalContent],
    ]
    do {
      let created = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: creation)))
      #expect(created["state"] as? String == "applied")
      #expect((created["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "1")
      let generated = try #require(
        (created["result"] as? [String: Any])?["generated"] as? [[String: Any]])
      #expect(generated.count == 1)
      #expect(generated.first?["kind"] as? String == "list")
      let listIdentifier = try #require(generated.first?["id"] as? String)
      let read = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1,
              "request": ["kind": "source", "source": ["kind": "list", "id": listIdentifier]],
            ])))
      #expect(read["kind"] as? String == "source")
      let sourceValue = try #require(read["value"] as? [String: Any])
      #expect(
        Set(sourceValue.keys) == [
          "source", "content", "createdAt", "updatedAt", "fieldHashes", "state", "labels",
          "references", "progress",
        ])
      #expect(
        NSDictionary(dictionary: try #require(sourceValue["content"] as? [String: Any])).isEqual(
          to: originalContent))
      let sourceState = try #require(sourceValue["state"] as? [String: Any])
      #expect(sourceState["globalDone"] is NSNull)
      #expect(sourceState["archived"] as? Bool == false)
      #expect((sourceValue["labels"] as? [Any])?.isEmpty == true)
      #expect((sourceValue["references"] as? [Any])?.isEmpty == true)
      let progress = try #require(sourceValue["progress"] as? [String: Any])
      #expect(Set(progress.keys) == ["container", "state", "doneCount", "totalCount"])
      #expect(progress["state"] as? String == "empty")
      #expect(progress["doneCount"] as? String == "0")
      #expect(progress["totalCount"] as? String == "0")
      #expect((progress["container"] as? [String: Any])?["id"] as? String == listIdentifier)
      let reopened = PlannerCore.Planner(configuration: configuration)
      let list = PlannerEntityReference(
        kind: .list, id: try #require(UUID(uuidString: listIdentifier)))
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.list(let nativeRead)) = await reopened.read(
          session: reopenedSession, request: .source(list)),
        case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(
          request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await reopened.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 1))
      else {
        await listener.stop()
        Issue.record("HTTP-created Lists must reopen through Core with independent recovery.")
        return
      }
      #expect(nativeRead.content.name == " Tokyo Food ")
      #expect(nativeRead.content.notes == "")
      #expect(nativeRead.content.iconName == "fork.knife")
      #expect(recovery.decodedBackup.backup.lists.first?.content == nativeRead.content)
      #expect(
        sourceValue["createdAt"] as? Double == nativeRead.createdAt.timeIntervalSinceReferenceDate)
      #expect(
        sourceValue["updatedAt"] as? Double == nativeRead.updatedAt.timeIntervalSinceReferenceDate)
      let hashes = try #require(sourceValue["fieldHashes"] as? [String: String])
      #expect(Set(hashes.keys) == ["name", "notes", "color", "iconName"])
      #expect(
        hashes
          == Dictionary(
            uniqueKeysWithValues: nativeRead.fieldHashes.map {
              ($0.key.rawValue, $0.value.value)
            }))
      let replay = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: creation)))
      #expect(NSDictionary(dictionary: replay).isEqual(to: created))
      let defaultCreation = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": ["type": "createList", "content": ["name": "Wishlist"]],
            ])))
      #expect(
        (defaultCreation["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "2")
      let defaultIdentifier = try #require(
        ((defaultCreation["result"] as? [String: Any])?["generated"] as? [[String: Any]])?.first?[
          "id"]
          as? String)
      let defaultRead = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1,
              "request": ["kind": "source", "source": ["kind": "list", "id": defaultIdentifier]],
            ])))
      let defaultContent = try #require(
        (defaultRead["value"] as? [String: Any])?["content"] as? [String: Any])
      #expect(defaultContent["notes"] is NSNull)
      #expect(defaultContent["color"] is NSNull)
      #expect(defaultContent["iconName"] is NSNull)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func listFieldGuardsRejectConflictsAndRetainLaterDataOnReplay() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let itemResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      ).outcome,
      let item = itemResult.generated.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: datasetSession, request: .source(item))
    else {
      Issue.record("Independent Item data must be saved before the HTTP List edit journey.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let creation: [String: Any] = [
      "formatVersion": 1, "operationId": UUID().uuidString,
      "command": ["type": "createList", "content": ["name": "Tokyo Food", "notes": "Original"]],
    ]
    do {
      let created = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: creation)))
      let listIdentifier = try #require(
        ((created["result"] as? [String: Any])?["generated"] as? [[String: Any]])?.first?["id"]
          as? String)
      let readArguments: [String: Any] = [
        "formatVersion": 1,
        "request": ["kind": "source", "source": ["kind": "list", "id": listIdentifier]],
      ]
      let original = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: readArguments)))
      let originalValue = try #require(original["value"] as? [String: Any])
      let originalHashes = try #require(originalValue["fieldHashes"] as? [String: Any])
      let blue: [String: Any] = ["red": 0, "green": 0, "blue": 1, "alpha": 1]
      let editIdentifier = UUID()
      let edit: [String: Any] = [
        "formatVersion": 1, "operationId": editIdentifier.uuidString,
        "command": [
          "type": "editList", "sourceId": listIdentifier,
          "changes": ["notes": "Friday booking", "color": blue, "iconName": "fork.knife"],
          "expectedFieldHashes": originalHashes,
        ],
      ]
      let edited = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: edit)))
      #expect(edited["state"] as? String == "applied")
      #expect((edited["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let before = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: readArguments)))
      let beforeValue = try #require(before["value"] as? [String: Any])
      let beforeHashes = try #require(beforeValue["fieldHashes"] as? [String: Any])
      let stale = try rejected(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "editList", "sourceId": listIdentifier,
                "changes": ["name": "Must not save", "notes": "Monday booking"],
                "expectedFieldHashes": originalHashes,
              ],
            ])))
      let reason = try #require(stale["reason"] as? [String: Any])
      #expect(reason["code"] as? String == "staleEdit")
      let details = try #require(reason["details"] as? [String: Any])
      #expect(details["kind"] as? String == "staleEdit")
      #expect(details["conflictingFields"] as? [String] == ["notes"])
      #expect((details["currentValues"] as? [String: Any])?["notes"] as? String == "Friday booking")
      #expect(
        (details["currentFieldHashes"] as? [String: Any])?["notes"] as? String
          == beforeHashes["notes"] as? String)
      let unchanged = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: readArguments)))
      #expect(NSDictionary(dictionary: unchanged).isEqual(to: before))
      let staleColor = try rejected(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "editList", "sourceId": listIdentifier,
                "changes": ["color": NSNull()], "expectedFieldHashes": originalHashes,
              ],
            ])))
      let colorDetails = try #require(
        (staleColor["reason"] as? [String: Any])?["details"] as? [String: Any])
      #expect(colorDetails["conflictingFields"] as? [String] == ["color"])
      #expect(
        NSDictionary(
          dictionary: try #require(
            (colorDetails["currentValues"] as? [String: Any])?["color"] as? [String: Any])
        ).isEqual(to: blue))
      let cleared = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "editList", "sourceId": listIdentifier,
                "changes": [
                  "name": "  Café 東京  ", "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
                ], "expectedFieldHashes": beforeHashes,
              ],
            ])))
      #expect((cleared["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "4")
      let replay = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: edit)))
      #expect(NSDictionary(dictionary: replay).isEqual(to: edited))
      let originalReplay = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: creation)))
      #expect(NSDictionary(dictionary: originalReplay).isEqual(to: created))
      let latest = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: readArguments)))
      let latestContent = try #require(
        (latest["value"] as? [String: Any])?["content"] as? [String: Any])
      #expect(latestContent["name"] as? String == "  Café 東京  ")
      #expect(latestContent["notes"] is NSNull)
      #expect(latestContent["color"] is NSNull)
      #expect(latestContent["iconName"] is NSNull)
      let nullColor = try rejected(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "editList", "sourceId": listIdentifier, "changes": ["color": blue],
                "expectedFieldHashes": beforeHashes,
              ],
            ])))
      let nullDetails = try #require(
        (nullColor["reason"] as? [String: Any])?["details"] as? [String: Any])
      #expect((nullDetails["currentValues"] as? [String: Any])?["color"] is NSNull)
      var toolsRequest = try request(endpoint: endpoint, name: "planner_read", arguments: [:])
      toolsRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": [:],
      ])
      let toolsExchange = try await httpSession.data(for: toolsRequest)
      #expect((toolsExchange.1 as? HTTPURLResponse)?.statusCode == 200)
      let toolsEnvelope = try #require(
        JSONSerialization.jsonObject(with: toolsExchange.0) as? [String: Any])
      let tools = try #require(
        (toolsEnvelope["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let executionTool = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let schemaProperties = try #require(
        (executionTool["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let commands = try #require(
        (schemaProperties["command"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let listCommands = commands.filter {
        let kind =
          (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
        return ["createList", "editList"].contains(kind ?? "")
      }
      #expect(listCommands.count == 2)
      for command in listCommands {
        #expect(command["additionalProperties"] as? Bool == false)
      }
      guard
        case .source(.item(let retainedItem)) = await planner.read(
          session: datasetSession, request: .source(item)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 4))
      else {
        await listener.stop()
        Issue.record(
          "HTTP List edits must retain Item content and acknowledged mixed-source recovery.")
        return
      }
      #expect(retainedItem.content.notes == "Keep")
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 4)
      #expect(namespace.preparedProposals.isEmpty)
      #expect(recovery.decodedBackup.backup.lists.first?.content.name == "  Café 東京  ")
      #expect(recovery.decodedBackup.backup.lists.first?.content.notes == nil)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func invalidListAdmissionRetainsSourceRowsAndAcknowledgedRecovery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let listResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createList(content: PlannerListContentInput(name: "Tokyo Food", notes: "Keep")))
      ).outcome,
      let list = listResult.generated.first,
      case .source(.list(let originalList)) = await planner.read(
        session: datasetSession, request: .source(list)),
      case .applied(let itemResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      ).outcome,
      let item = itemResult.generated.first,
      case .applied(let scheduleResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createSchedule(
            source: item,
            form: .allDay(start: PlannerCivilDate(year: 2026, month: 10, day: 9), end: nil)))
      ).outcome,
      let schedule = scheduleResult.generated.first,
      case .source(.schedule(let originalSchedule)) = await planner.read(
        session: datasetSession, request: .source(schedule)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(session: datasetSession, request: .items(PlannerItemQuery())))
    else {
      Issue.record(
        "Mixed-source saved data and an issued Item row window must precede invalid requests.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let hashes = Dictionary(
      uniqueKeysWithValues: originalList.fieldHashes.map { ($0.key.rawValue, $0.value.value) })
    let valid: [String: Any] = ["name": "Tokyo Food"]
    let invalidContent: [([String: Any], String, String)] = [
      (["name": " \n\t"], "invalidInput", "/name"),
      (["name": NSNull()], "invalidInput", "/name"),
      (["name": true], "invalidInput", "/name"),
      (["name": "Tokyo Food", "notes": 7], "invalidInput", "/notes"),
      (["name": "Tokyo Food", "iconName": false], "invalidInput", "/iconName"),
      (["name": "Tokyo Food", "color": "blue"], "invalidInput", "/color"),
      (
        ["name": "Tokyo Food", "color": ["red": 0, "green": 0, "blue": 1]],
        "invalidInput", "/color/alpha"
      ),
      (
        ["name": "Tokyo Food", "color": ["red": true, "green": 0, "blue": 1, "alpha": 1]],
        "invalidInput", "/color/red"
      ),
      (
        ["name": "Tokyo Food", "color": ["red": 0, "green": "zero", "blue": 1, "alpha": 1]],
        "invalidInput", "/color/green"
      ),
      (
        ["name": "Tokyo Food", "color": ["red": 0, "green": 0, "blue": NSNull(), "alpha": 1]],
        "invalidInput", "/color/blue"
      ),
      (
        ["name": "Tokyo Food", "color": ["red": 0, "green": 0, "blue": 1, "alpha": 2]],
        "invalidInput", "/color/alpha"
      ),
      (
        [
          "name": "Tokyo Food",
          "color": ["red": 0, "green": 0, "blue": 1, "alpha": 1, "space": "srgb"],
        ],
        "unknownField", "/color/space"
      ),
      (["name": "Tokyo Food", "archived": true], "unknownField", "/archived"),
      (["name": "Tokyo Food", "globalDone": true], "unknownField", "/globalDone"),
      (["name": "Tokyo Food", "links": []], "unknownField", "/links"),
      (["name": "Tokyo Food", "memberships": []], "unknownField", "/memberships"),
      (["name": "Tokyo Food", "name~/": "Other"], "unknownField", "/name~0~1"),
    ]
    do {
      let sourceRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "list", "id": list.id.uuidString]],
        ])
      let rowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "rows", "generation": snapshot.generation.uuidString, "offset": "0",
            "limit": "1",
          ],
        ])
      let originalSource = try value(try await httpSession.data(for: sourceRequest))
      let originalRows = try value(try await httpSession.data(for: rowRequest))
      var attempts: [([String: Any], String, String)] = []
      for (content, code, path) in invalidContent {
        attempts.append(
          (
            ["type": "createList", "content": content], code, "/command/content" + path
          ))
        attempts.append(
          (
            [
              "type": "editList", "sourceId": list.id.uuidString, "changes": content,
              "expectedFieldHashes": hashes,
            ],
            code, "/command/changes" + path
          ))
      }
      let edit: [String: Any] = [
        "type": "editList", "sourceId": list.id.uuidString, "changes": valid,
        "expectedFieldHashes": hashes,
      ]
      attempts += [
        (["type": "createList", "content": [:]], "invalidInput", "/command/content/name"),
        (
          edit.merging(["sourceId": "not-a-uuid"]) { _, incoming in incoming }, "invalidInput",
          "/command/sourceId"
        ),
        (
          edit.merging(["changes": [:]]) { _, incoming in incoming }, "invalidInput",
          "/command/changes"
        ),
        (
          edit.merging(["expectedFieldHashes": [:]]) { _, incoming in incoming }, "invalidInput",
          "/command/expectedFieldHashes/name"
        ),
        (
          edit.merging(["expectedFieldHashes": ["name": "bad"]]) { _, incoming in incoming },
          "invalidInput", "/command/expectedFieldHashes/name"
        ),
        (
          edit.merging(["expectedFieldHashes": ["name": 7]]) { _, incoming in incoming },
          "invalidInput", "/command/expectedFieldHashes/name"
        ),
        (
          edit.merging(["expectedFieldHashes": ["globalDone": "bad"]]) { _, incoming in incoming },
          "unknownField", "/command/expectedFieldHashes/globalDone"
        ),
        (
          edit.merging(["expectedFieldHashes": NSNull()]) { _, incoming in incoming },
          "invalidInput", "/command/expectedFieldHashes"
        ),
        (
          edit.merging(["changes": NSNull()]) { _, incoming in incoming }, "invalidInput",
          "/command/changes"
        ),
        (
          edit.merging(["lifetimeId": UUID().uuidString]) { _, incoming in incoming },
          "unknownField", "/command/lifetimeId"
        ),
      ]
      #expect(attempts.count == 44)
      for (command, code, path) in attempts {
        let operationIdentifier = UUID()
        let attempted = try rejected(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_execute",
              arguments: [
                "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                "command": command,
              ])))
        #expect(attempted["operationId"] as? String == operationIdentifier.uuidString)
        let reason = try #require(attempted["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        #expect(reason["propertyPath"] as? String == path)
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationIdentifier)
        else {
          await listener.stop()
          Issue.record("Invalid List admission must produce no applied or prepared evidence.")
          return
        }
      }
      let retainedSource = try value(try await httpSession.data(for: sourceRequest))
      let retainedRows = try value(try await httpSession.data(for: rowRequest))
      #expect(NSDictionary(dictionary: retainedSource).isEqual(to: originalSource))
      #expect(NSDictionary(dictionary: retainedRows).isEqual(to: originalRows))
      guard
        case .source(.schedule(let retainedSchedule)) = await planner.read(
          session: datasetSession, request: .source(schedule)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 3))
      else {
        await listener.stop()
        Issue.record("Invalid List requests must retain mixed-source recovery and other Schedules.")
        return
      }
      #expect(retainedSchedule.content == originalSchedule.content)
      #expect(retainedSchedule.fieldHashes == originalSchedule.fieldHashes)
      #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 3)
      #expect(namespace.preparedProposals.isEmpty)
      #expect(recovery.decodedBackup.backup.sources.count == 2)
      #expect(recovery.decodedBackup.backup.schedules.count == 1)
      #expect(recovery.decodedBackup.backup.lists.first?.content == originalList.content)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func advertisedListArchiveRoutesWithoutChangingContentOrReapplyingOldState() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let result, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createList(content: PlannerListContentInput(name: "Wishlist", notes: "Keep")))
      ).outcome,
      let list = result.generated.first,
      case .source(.list(let original)) = await planner.read(
        session: datasetSession, request: .source(list))
    else {
      Issue.record("A native List must save before advertised HTTP Archive/Unarchive.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      var toolsRequest = try request(endpoint: endpoint, name: "planner_read", arguments: [:])
      toolsRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": [:],
      ])
      let exchange = try await httpSession.data(for: toolsRequest)
      #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
      let toolsEnvelope = try #require(
        JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
      let tools = try #require(
        (toolsEnvelope["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let executionTool = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let properties = try #require(
        (executionTool["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let commands = try #require(
        (properties["command"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let archive = try #require(
        commands.first {
          (($0["properties"] as? [String: Any])?["type"] as? [String: Any])?["const"] as? String
            == "setArchive"
        })
      let archiveProperties = try #require(archive["properties"] as? [String: Any])
      let sourceProperties = try #require(
        (archiveProperties["source"] as? [String: Any])?["properties"] as? [String: Any])
      #expect(
        (sourceProperties["kind"] as? [String: Any])?["enum"] as? [String] == ["item", "list"])
      let archiveArguments: [String: Any] = [
        "formatVersion": 1, "operationId": UUID().uuidString,
        "command": [
          "type": "setArchive", "source": ["kind": "list", "id": list.id.uuidString],
          "archived": true,
        ],
      ]
      let archived = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: archiveArguments)))
      #expect((archived["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "2")
      let readArguments: [String: Any] = [
        "formatVersion": 1,
        "request": ["kind": "source", "source": ["kind": "list", "id": list.id.uuidString]],
      ]
      let archivedRead = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: readArguments)))
      let archivedValue = try #require(archivedRead["value"] as? [String: Any])
      #expect((archivedValue["state"] as? [String: Any])?["archived"] as? Bool == true)
      #expect((archivedValue["state"] as? [String: Any])?["globalDone"] is NSNull)
      #expect((archivedValue["progress"] as? [String: Any])?["state"] as? String == "empty")
      let unarchived = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "setArchive", "source": ["kind": "list", "id": list.id.uuidString],
                "archived": false,
              ],
            ])))
      #expect((unarchived["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let replay = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: archiveArguments)))
      #expect(NSDictionary(dictionary: replay).isEqual(to: archived))
      guard
        case .source(.list(let current)) = await planner.read(
          session: datasetSession, request: .source(list)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        await listener.stop()
        Issue.record("Unarchive must remain saved after old HTTP Archive replay.")
        return
      }
      #expect(current.state.archived == false)
      #expect(current.state.globalDone == nil)
      #expect(current.content == original.content)
      #expect(current.fieldHashes == original.fieldHashes)
      #expect(current.createdAt == original.createdAt)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 3)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func membershipReferencesAndMixedReceiptsAreCompleteThroughActualHTTPReads() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = storageConfiguration(directory)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let itemCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel")))
      ).outcome,
      let item = itemCreated.generated.first,
      case .applied(let listCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createList(content: PlannerListContentInput(name: "Tokyo")))
      ).outcome,
      let list = listCreated.generated.first
    else {
      Issue.record("Native sources must save before HTTP reference inspection.")
      return
    }
    let operationIdentifier = UUID()
    guard
      case .applied(let added, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: datasetSession,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let membershipIdentifier, _, _)? = added.generatedReferences.first
    else {
      Issue.record("Core must save a membership receipt before HTTP inspection.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let expectedReference: [String: Any] = [
      "kind": "membership", "id": membershipIdentifier.uuidString,
      "owner": ["kind": "list", "id": list.id.uuidString],
      "source": ["kind": "item", "id": item.id.uuidString],
      "appearance": [
        "kind": "listMembership", "listId": list.id.uuidString,
        "membershipId": membershipIdentifier.uuidString,
      ],
    ]
    do {
      for source in [list, item] {
        let read = try value(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_read",
              arguments: [
                "formatVersion": 1,
                "request": [
                  "kind": "source",
                  "source": ["kind": source.kind.rawValue, "id": source.id.uuidString],
                ],
              ])))
        let sourceValue = try #require(read["value"] as? [String: Any])
        let references = try #require(sourceValue["references"] as? [[String: Any]])
        #expect(references.count == 1)
        #expect(
          NSDictionary(dictionary: try #require(references.first)).isEqual(to: expectedReference))
        if source.kind == .list {
          let progress = try #require(sourceValue["progress"] as? [String: Any])
          #expect(progress["state"] as? String == "partial")
          #expect(progress["doneCount"] as? String == "0")
          #expect(progress["totalCount"] as? String == "1")
        }
      }
      let status = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_operation_status",
            arguments: ["formatVersion": 1, "operationId": operationIdentifier.uuidString])))
      #expect(status["state"] as? String == "appliedRecoveryComplete")
      #expect(status["checkpointGeneration"] as? String == String(checkpoint))
      let result = try #require(status["result"] as? [String: Any])
      let generated = try #require(result["generated"] as? [[String: Any]])
      #expect(generated.count == 1)
      #expect(
        NSDictionary(dictionary: try #require(generated.first)).isEqual(to: expectedReference))
      let affected = try #require(result["affected"] as? [[String: Any]])
      #expect(affected.count == 2)
      #expect(NSDictionary(dictionary: affected[0]).isEqual(to: expectedReference))
      #expect(
        NSDictionary(dictionary: affected[1]).isEqual(to: [
          "kind": "list", "id": list.id.uuidString,
        ]))
      await listener.stop()
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .appliedRecoveryComplete(let retained, let retainedCheckpoint) =
          await reopened.operationStatus(
            session: reopenedSession, operationId: operationIdentifier)
      else {
        Issue.record("Mixed reference/source receipts must survive native reopen.")
        return
      }
      #expect(retained == added)
      #expect(retainedCheckpoint == checkpoint)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func exactAppearanceReadRetainsLiveItemContentAndIndependentStatesOverHTTP() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let itemCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Original",
              links: [PlannerLinkInput(originalUrl: "https://example.com/hotel", label: "Website")])
          ))
      ).outcome,
      let item = itemCreated.generated.first,
      case .applied(let listCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createList(content: PlannerListContentInput(name: "Tokyo")))
      ).outcome,
      let list = listCreated.generated.first,
      case .applied(let memberCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let membershipIdentifier, _, _)? = memberCreated.generatedReferences.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: datasetSession, request: .source(item))
    else {
      Issue.record("A real saved appearance must exist before HTTP detail reads.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let appearance: [String: Any] = [
      "kind": "listMembership", "listId": list.id.uuidString,
      "membershipId": membershipIdentifier.uuidString,
    ]
    let arguments: [String: Any] = [
      "formatVersion": 1, "request": ["kind": "appearance", "appearance": appearance],
    ]
    do {
      let original = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: arguments)))
      #expect(original["kind"] as? String == "appearance")
      let originalValue = try #require(original["value"] as? [String: Any])
      #expect(
        Set(originalValue.keys) == [
          "appearance", "source", "content", "globalDone", "localDone", "effectiveDone", "archived",
          "fieldHashes",
        ])
      #expect(
        NSDictionary(dictionary: try #require(originalValue["appearance"] as? [String: Any]))
          .isEqual(to: appearance))
      #expect(
        NSDictionary(dictionary: try #require(originalValue["source"] as? [String: Any])).isEqual(
          to: ["kind": "item", "id": item.id.uuidString]))
      #expect(originalValue["globalDone"] as? Bool == false)
      #expect(originalValue["localDone"] as? Bool == false)
      #expect(originalValue["effectiveDone"] as? Bool == false)
      #expect(originalValue["archived"] as? Bool == false)
      let content = try #require(originalValue["content"] as? [String: Any])
      #expect(
        Set(content.keys) == [
          "title", "subtitle", "notes", "location", "estimate", "links", "categoryIds", "tagIds",
        ])
      #expect(content["title"] as? String == "Hotel")
      #expect(content["notes"] as? String == "Original")
      #expect(content["subtitle"] is NSNull)
      #expect(content["location"] is NSNull)
      #expect(content["estimate"] is NSNull)
      #expect(
        (content["links"] as? [[String: Any]])?.first?["originalUrl"] as? String
          == "https://example.com/hotel")
      #expect(
        originalValue["fieldHashes"] as? [String: String]
          == Dictionary(
            uniqueKeysWithValues: originalItem.fieldHashes.map { ($0.key.rawValue, $0.value.value) }
          ))
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: datasetSession,
            command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
        ).outcome,
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: datasetSession,
            command: .editItem(
              sourceId: item.id, changes: PlannerItemChanges(notes: .set("Booking updated")),
              expectedFieldHashes: originalItem.fieldHashes))
        ).outcome
      else {
        await listener.stop()
        Issue.record("Shared source edits must remain independent of contextual reads.")
        return
      }
      let changed = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: arguments)))
      let changedValue = try #require(changed["value"] as? [String: Any])
      #expect((changedValue["content"] as? [String: Any])?["notes"] as? String == "Booking updated")
      #expect(changedValue["globalDone"] as? Bool == true)
      #expect(changedValue["localDone"] as? Bool == false)
      #expect(changedValue["effectiveDone"] as? Bool == true)
      #expect(
        NSDictionary(dictionary: try #require(changedValue["appearance"] as? [String: Any]))
          .isEqual(to: appearance))
      var listRequest = try request(endpoint: endpoint, name: "planner_read", arguments: [:])
      listRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 2, "method": "tools/list",
      ])
      let toolsExchange = try await httpSession.data(for: listRequest)
      let envelope = try #require(
        JSONSerialization.jsonObject(with: toolsExchange.0) as? [String: Any])
      let tools = try #require((envelope["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let definition = try #require(tools.first { $0["name"] as? String == "planner_read" })
      let schema = try #require(definition["inputSchema"] as? [String: Any])
      let properties = try #require(schema["properties"] as? [String: Any])
      let variants = try #require(
        (properties["request"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let variant = try #require(
        variants.first { variant in
          ((variant["properties"] as? [String: Any])?["kind"] as? [String: Any])?["const"]
            as? String == "appearance"
        })
      #expect(Set(try #require(variant["required"] as? [String])) == ["kind", "appearance"])
      let appearanceSchema = try #require(
        (variant["properties"] as? [String: Any])?["appearance"] as? [String: Any])
      #expect(appearanceSchema["additionalProperties"] as? Bool == false)
      #expect(
        Set(try #require(appearanceSchema["required"] as? [String])) == [
          "kind", "listId", "membershipId",
        ])
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func malformedAppearanceReadsNeverFallbackOrChangeSavedData() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let itemCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      ).outcome,
      let item = itemCreated.generated.first,
      case .applied(let listCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createList(content: PlannerListContentInput(name: "Tokyo")))
      ).outcome,
      let list = listCreated.generated.first,
      case .applied(let added, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let membershipIdentifier, _, _)? = added.generatedReferences.first,
      case .source(.item(let original)) = await planner.read(
        session: datasetSession, request: .source(item)),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(session: datasetSession, request: .items(PlannerItemQuery())))
    else {
      Issue.record("Saved sources and a row window must exist before invalid detail requests.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let valid: [String: Any] = [
      "kind": "listMembership", "listId": list.id.uuidString,
      "membershipId": membershipIdentifier.uuidString,
    ]
    var cases: [(value: Any, code: String, path: String?)] = [
      (NSNull(), "invalidInput", "/request/appearance"),
      ("membership", "invalidInput", "/request/appearance"),
      ([], "invalidInput", "/request/appearance"),
      (
        [
          "kind": "directItineraryItem", "listId": list.id.uuidString,
          "membershipId": membershipIdentifier.uuidString,
        ], "invalidInput", "/request/appearance/kind"
      ),
      (
        [
          "kind": "listMembership", "listId": UUID().uuidString,
          "membershipId": membershipIdentifier.uuidString,
        ], "missingReference", nil
      ),
      (
        [
          "kind": "listMembership", "listId": list.id.uuidString,
          "membershipId": item.id.uuidString,
        ], "missingReference", nil
      ),
    ]
    for field in ["kind", "listId", "membershipId"] {
      var omitted = valid
      omitted.removeValue(forKey: field)
      cases.append((omitted, "invalidInput", "/request/appearance/" + field))
      for value in [NSNull(), 42, false, "invalid"] as [Any] {
        var changed = valid
        changed[field] = value
        cases.append((changed, "invalidInput", "/request/appearance/" + field))
      }
    }
    for field in ["source", "rank", "unknown/~"] {
      var changed = valid
      changed[field] = "unexpected"
      let escaped = field.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(
        of: "/", with: "~1")
      cases.append((changed, "unknownField", "/request/appearance/" + escaped))
    }
    do {
      #expect(cases.count == 24)
      for candidate in cases {
        let exchange = try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1, "request": ["kind": "appearance", "appearance": candidate.value],
            ]))
        #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
        let envelope = try #require(
          JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
        #expect(envelope["error"] == nil)
        let tool = try #require(envelope["result"] as? [String: Any])
        #expect(tool["isError"] as? Bool == true)
        let result = try #require(tool["structuredContent"] as? [String: Any])
        #expect(result["state"] as? String == "failed")
        #expect(result["value"] == nil)
        let reason = try #require(result["reason"] as? [String: Any])
        #expect(reason["code"] as? String == candidate.code)
        #expect(reason["propertyPath"] as? String == candidate.path)
      }
      let validRead = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1,
              "request": [
                "kind": "appearance",
                "appearance": [
                  "kind": "listMembership", "listId": list.id.uuidString.lowercased(),
                  "membershipId": membershipIdentifier.uuidString.lowercased(),
                ],
              ],
            ])))
      let validValue = try #require(validRead["value"] as? [String: Any])
      #expect(
        NSDictionary(dictionary: try #require(validValue["appearance"] as? [String: Any])).isEqual(
          to: valid))
      await listener.stop()
      guard
        case .source(.item(let retained)) = await planner.read(
          session: datasetSession, request: .source(item)),
        case .rows(let rows) = await planner.read(
          session: datasetSession,
          request: .rows(generation: issued.generation, offset: 0, limit: 1)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Failed detail reads must preserve source state, issued rows and recovery.")
        return
      }
      #expect(retained.content.notes == original.content.notes)
      #expect(retained.updatedAt == original.updatedAt)
      #expect(retained.fieldHashes == original.fieldHashes)
      #expect(rows.rows.count == 1)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 3)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func rejected(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    #expect(tool["isError"] as? Bool == true)
    let structured = try #require(tool["structuredContent"] as? [String: Any])
    #expect(structured["state"] as? String == "rejected")
    let content = try #require(tool["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let textValue = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textValue).isEqual(to: structured))
    return structured
  }

  private func storageConfiguration(_ directory: URL) -> PlannerStorageConfiguration {
    PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
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
    try #require(tool["isError"] as? Bool == false)
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
