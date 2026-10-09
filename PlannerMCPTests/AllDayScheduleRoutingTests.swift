import Foundation
import PlannerCore
import Testing

@testable import Planner

struct AllDayScheduleRoutingTests {
  @Test func allDayCreationGuardedEditsTravelRowsAndRemovalUseTheSameSavedIdentity() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(title: "Tokyo Weekend", notes: "Keep")))
      ).outcome,
      let item = created.generated.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: datasetSession, request: .source(item))
    else {
      Issue.record("An owned Item must exist before the actual HTTP scheduling journey.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let originalForm: [String: Any] = [
      "kind": "allDay", "start": ["year": 2026, "month": 10, "day": 9],
      "end": ["year": 2026, "month": 10, "day": 11],
    ]
    let originalOperationIdentifier = UUID()
    let creation: [String: Any] = [
      "formatVersion": 1, "operationId": originalOperationIdentifier.uuidString,
      "command": [
        "type": "createSchedule", "source": ["kind": "item", "id": item.id.uuidString],
        "form": originalForm,
      ],
    ]
    do {
      let scheduled = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: creation)))
      #expect(scheduled["state"] as? String == "applied")
      #expect((scheduled["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "2")
      let generated = try #require(
        (scheduled["result"] as? [String: Any])?["generated"] as? [[String: Any]])
      let scheduleIdentifier = try #require(generated.first?["id"] as? String)
      #expect(generated.first?["kind"] as? String == "schedule")
      let schedule = PlannerEntityReference(
        kind: .schedule, id: try #require(UUID(uuidString: scheduleIdentifier)))
      let readArguments: [String: Any] = [
        "formatVersion": 1,
        "request": ["kind": "source", "source": ["kind": "schedule", "id": scheduleIdentifier]],
      ]
      let source = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: readArguments)))
      let sourceValue = try #require(source["value"] as? [String: Any])
      let sourceContent = try #require(sourceValue["content"] as? [String: Any])
      #expect(
        NSDictionary(dictionary: try #require(sourceContent["form"] as? [String: Any])).isEqual(
          to: originalForm))
      let originalHashes = try #require(sourceValue["fieldHashes"] as? [String: Any])
      for (instant, zone) in [(813_202_200.0, "Asia/Tokyo"), (813_227_400.0, "Europe/Paris")] {
        let presentation: [String: Any] = ["referenceInstant": instant, "displayTimeZone": zone]
        let query = try value(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_query",
              arguments: [
                "formatVersion": 1,
                "query": [
                  "kind": "items", "scope": ["kind": "global"], "rowPresentation": presentation,
                ],
              ])))
        let generation = try #require(query["generation"] as? String)
        let rows = try value(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_read",
              arguments: [
                "formatVersion": 1,
                "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "1"],
              ])))
        let summary = try #require(
          (rows["rows"] as? [[String: Any]])?.first?["scheduleSummary"] as? [String: Any])
        #expect(summary["kind"] as? String == "directItem")
        #expect((summary["schedule"] as? [String: Any])?["id"] as? String == scheduleIdentifier)
        #expect(summary["additionalCount"] as? String == "0")
        #expect(
          NSDictionary(dictionary: try #require(summary["form"] as? [String: Any])).isEqual(
            to: originalForm))
      }
      let laterForm: [String: Any] = [
        "kind": "allDay", "start": ["year": 2026, "month": 10, "day": 16],
        "end": ["year": 2026, "month": 10, "day": 18],
      ]
      let editIdentifier = UUID()
      let edit: [String: Any] = [
        "formatVersion": 1, "operationId": editIdentifier.uuidString,
        "command": [
          "type": "editSchedule", "scheduleId": scheduleIdentifier, "changes": ["form": laterForm],
          "expectedFieldHashes": originalHashes,
        ],
      ]
      let edited = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: edit)))
      #expect((edited["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let current = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: readArguments)))
      let currentHashes = try #require(
        (current["value"] as? [String: Any])?["fieldHashes"] as? [String: Any])
      let stale = try rejected(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString, "command": edit["command"]!,
            ])))
      let staleReason = try #require(stale["reason"] as? [String: Any])
      #expect(staleReason["code"] as? String == "staleEdit")
      let details = try #require(staleReason["details"] as? [String: Any])
      #expect(details["conflictingFields"] as? [String] == ["form"])
      #expect(
        NSDictionary(
          dictionary: try #require(
            (details["currentValues"] as? [String: Any])?["form"] as? [String: Any])
        ).isEqual(to: laterForm))
      #expect(
        NSDictionary(dictionary: try #require(details["currentFieldHashes"] as? [String: Any]))
          .isEqual(to: currentHashes))
      let zoneIdentifier = UUID()
      let zone = try rejected(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": zoneIdentifier.uuidString,
              "command": [
                "type": "changeScheduleZone", "scheduleId": scheduleIdentifier,
                "planningTimeZone": "Europe/Paris", "expectedFieldHashes": currentHashes,
              ],
            ])))
      #expect((zone["reason"] as? [String: Any])?["code"] as? String == "invalidInput")
      #expect(
        (zone["reason"] as? [String: Any])?["propertyPath"] as? String
          == "/command/planningTimeZone")
      let creationReplay = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: creation)))
      #expect(
        (creationReplay["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "2")
      let timedForm: [String: Any] = [
        "kind": "timed", "start": 813_200_400.25, "end": NSNull(), "planningTimeZone": "Asia/Tokyo",
      ]
      let converted = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "editSchedule", "scheduleId": scheduleIdentifier,
                "changes": ["form": timedForm], "expectedFieldHashes": currentHashes,
              ],
            ])))
      #expect((converted["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "4")
      let editReplay = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_execute", arguments: edit)))
      #expect((editReplay["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let retained = try value(
        try await httpSession.data(
          for: request(endpoint: endpoint, name: "planner_read", arguments: readArguments)))
      #expect(
        NSDictionary(
          dictionary: try #require(
            ((retained["value"] as? [String: Any])?["content"] as? [String: Any])?["form"]
              as? [String: Any])
        ).isEqual(to: timedForm))
      let removalIdentifier = UUID()
      let removal = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": removalIdentifier.uuidString,
              "command": ["type": "removeSchedule", "scheduleId": scheduleIdentifier],
            ])))
      #expect((removal["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "5")
      await listener.stop()
      guard
        case .source(.item(let retainedItem)) = await planner.read(
          session: datasetSession, request: .source(item)),
        case .failed(let missing) = await planner.read(
          session: datasetSession, request: .source(schedule)),
        case .noReliableEvidence = await planner.operationStatus(
          session: datasetSession, operationId: zoneIdentifier),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 5))
      else {
        Issue.record("The final native data and independent recovery must reflect HTTP outcomes.")
        return
      }
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(retainedItem.content.notes == "Keep")
      #expect(missing.code == "missingReference")
      #expect(recovery.decodedBackup.backup.schedules.isEmpty)
      #expect(recovery.decodedBackup.backup.deletionMarkers.first?.operationId == removalIdentifier)
      #expect(namespace.preparedProposals.isEmpty)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func invalidCivilFormRequestsLeaveSourceRowsAndIndependentCheckpointUnchanged() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    let start: [String: Any] = ["year": 2026, "month": 10, "day": 9]
    let form: [String: Any] = ["kind": "allDay", "start": start, "end": NSNull()]
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Friday", notes: "Keep")))
      ).outcome,
      let item = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createSchedule(
            source: item,
            form: .allDay(start: PlannerCivilDate(year: 2026, month: 10, day: 9), end: nil)))
      ).outcome,
      let schedule = scheduled.generated.first,
      case .source(.schedule(let original)) = await planner.read(
        session: datasetSession, request: .source(schedule)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(
          session: datasetSession,
          request: .items(
            PlannerItemQuery(
              rowPresentation: PlannerRowPresentationContext(
                referenceInstant: Date(timeIntervalSinceReferenceDate: 813_202_200),
                displayTimeZone: "Asia/Tokyo")))))
    else {
      Issue.record(
        "The original all-day source and row generation must exist before rejection checks.")
      return
    }
    let invalidForms: [([String: Any], String, String)] = [
      (["kind": "allDay", "end": NSNull()], "invalidInput", "/start"),
      (["kind": "allDay", "start": start], "invalidInput", "/end"),
      (form.merging(["start": NSNull()]) { _, incoming in incoming }, "invalidInput", "/start"),
      (form.merging(["start": []]) { _, incoming in incoming }, "invalidInput", "/start"),
      (form.merging(["start": 813_200_400]) { _, incoming in incoming }, "invalidInput", "/start"),
      (
        form.merging(["start": ["month": 10, "day": 9]]) { _, incoming in incoming },
        "invalidInput", "/start/year"
      ),
      (
        form.merging(["start": ["year": "2026", "month": 10, "day": 9]]) { _, incoming in incoming
        }, "invalidInput", "/start/year"
      ),
      (
        form.merging(["start": ["year": true, "month": 10, "day": 9]]) { _, incoming in incoming },
        "invalidInput", "/start/year"
      ),
      (
        form.merging(["start": ["year": 2026.5, "month": 10, "day": 9]]) { _, incoming in incoming
        }, "invalidInput", "/start/year"
      ),
      (
        form.merging(["start": ["year": NSNull(), "month": 10, "day": 9]]) { _, incoming in incoming
        }, "invalidInput", "/start/year"
      ),
      (
        form.merging(["start": ["year": Int.max, "month": 10, "day": 9]]) { _, incoming in incoming
        }, "invalidInput", "/start"
      ),
      (
        form.merging(["start": ["year": 0, "month": 10, "day": 9]]) { _, incoming in incoming },
        "invalidInput", "/start"
      ),
      (
        form.merging(["start": ["year": 2023, "month": 2, "day": 29]]) { _, incoming in incoming },
        "invalidInput", "/start"
      ),
      (
        form.merging(["start": ["year": 2026, "month": 13, "day": 9]]) { _, incoming in incoming },
        "invalidInput", "/start"
      ),
      (
        form.merging(["start": ["year": 2026, "month": 10, "day": 32]]) { _, incoming in incoming },
        "invalidInput", "/start"
      ),
      (
        form.merging(["start": ["year": 2026, "month": 10, "day": 9, "weird/~": true]]) {
          _, incoming in incoming
        }, "unknownField", "/start/weird~1~0"
      ),
      (
        form.merging(["planningTimeZone": "Asia/Tokyo"]) { _, incoming in incoming },
        "unknownField", "/planningTimeZone"
      ),
      (
        form.merging(["end": ["year": 2026, "month": 10, "day": 8]]) { _, incoming in incoming },
        "invalidInput", "/end"
      ),
      (
        form.merging(["end": ["year": 2026, "month": 2, "day": 29]]) { _, incoming in incoming },
        "invalidInput", "/end"
      ),
      (
        form.merging(["end": ["year": 2026, "month": 10, "day": false]]) { _, incoming in incoming
        }, "invalidInput", "/end/day"
      ),
      (form.merging(["end": 813_200_400]) { _, incoming in incoming }, "invalidInput", "/end"),
      (form.merging(["kind": "slot"]) { _, incoming in incoming }, "invalidInput", "/kind"),
    ]
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let sourceRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "source", "source": ["kind": "schedule", "id": schedule.id.uuidString],
          ],
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
      let hashes = Dictionary(
        uniqueKeysWithValues: original.fieldHashes.map { ($0.key.rawValue, $0.value.value) })
      for (invalidForm, code, path) in invalidForms {
        for editing in [false, true] {
          let command: [String: Any]
          let expectedPath: String
          if editing {
            command = [
              "type": "editSchedule", "scheduleId": schedule.id.uuidString,
              "changes": ["form": invalidForm], "expectedFieldHashes": hashes,
            ]
            expectedPath = "/command/changes/form" + path
          } else {
            command = [
              "type": "createSchedule", "source": ["kind": "item", "id": item.id.uuidString],
              "form": invalidForm,
            ]
            expectedPath = "/command/form" + path
          }
          let operationIdentifier = UUID()
          let result = try rejected(
            try await httpSession.data(
              for: request(
                endpoint: endpoint, name: "planner_execute",
                arguments: [
                  "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                  "command": command,
                ])))
          #expect(result["operationId"] as? String == operationIdentifier.uuidString)
          let reason = try #require(result["reason"] as? [String: Any])
          #expect(reason["code"] as? String == code)
          #expect(reason["propertyPath"] as? String == expectedPath)
          guard
            case .noReliableEvidence = await planner.operationStatus(
              session: datasetSession, operationId: operationIdentifier)
          else {
            await listener.stop()
            Issue.record("Invalid civil admission must create no applied receipt.")
            return
          }
        }
      }
      let unchangedSource = try value(try await httpSession.data(for: sourceRequest))
      let unchangedRows = try value(try await httpSession.data(for: rowRequest))
      #expect(NSDictionary(dictionary: unchangedSource).isEqual(to: originalSource))
      #expect(NSDictionary(dictionary: unchangedRows).isEqual(to: originalRows))
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 2))
      else {
        await listener.stop()
        Issue.record("Invalid all-day requests must retain their independently saved checkpoint.")
        return
      }
      #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 2)
      #expect(namespace.preparedProposals.isEmpty)
      #expect(recovery.decodedBackup.backup.schedules.count == 1)
      let leapForm: [String: Any] = [
        "kind": "allDay", "start": ["year": 2024, "month": 2, "day": 29], "end": NSNull(),
      ]
      let leap = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "createSchedule", "source": ["kind": "item", "id": item.id.uuidString],
                "form": leapForm,
              ],
            ])))
      #expect((leap["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let leapIdentifier = try #require(
        ((leap["result"] as? [String: Any])?["generated"] as? [[String: Any]])?.first?["id"]
          as? String)
      let read = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1,
              "request": ["kind": "source", "source": ["kind": "schedule", "id": leapIdentifier]],
            ])))
      #expect(
        NSDictionary(
          dictionary: try #require(
            ((read["value"] as? [String: Any])?["content"] as? [String: Any])?["form"]
              as? [String: Any])
        ).isEqual(to: leapForm))
      await listener.stop()
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
