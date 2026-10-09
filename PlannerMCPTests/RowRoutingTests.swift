import Foundation
import PlannerCore
import Testing

@testable import Planner

struct RowRoutingTests {
  @Test func malformedZoneRequestsPreserveRowsAndStartOnlyZoneChangeCreatesNoEnd() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400)
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel")))
      ).outcome,
      let item = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createSchedule(
            source: item,
            form: .timed(start: start, end: nil, planningTimeZone: "Asia/Tokyo")))
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
                referenceInstant: start, displayTimeZone: "Asia/Tokyo")))))
    else {
      Issue.record(
        "A saved start-only appointment and issued rows must exist before HTTP validation.")
      return
    }
    let command: [String: Any] = [
      "type": "changeScheduleZone", "scheduleId": schedule.id.uuidString,
      "planningTimeZone": "UTC",
      "expectedFieldHashes": ["form": try #require(original.fieldHashes[.form]?.value)],
    ]
    let invalid: [([String: Any], String, String)] = [
      (
        command.merging(["scheduleId": "invalid"]) { _, incoming in incoming }, "invalidInput",
        "/command/scheduleId"
      ),
      (
        command.merging(["scheduleId": item.id.uuidString]) { _, incoming in incoming },
        "missingReference", ""
      ),
      (
        command.merging(["planningTimeZone": NSNull()]) { _, incoming in incoming }, "invalidInput",
        "/command/planningTimeZone"
      ),
      (
        command.merging(["planningTimeZone": true]) { _, incoming in incoming }, "invalidInput",
        "/command/planningTimeZone"
      ),
      (
        command.merging(["planningTimeZone": "Invalid/Zone"]) { _, incoming in incoming },
        "invalidInput", "/command/planningTimeZone"
      ),
      (
        command.merging(["expectedFieldHashes": [:]]) { _, incoming in incoming }, "invalidInput",
        "/command/expectedFieldHashes/form"
      ),
      (
        command.merging(["expectedFieldHashes": ["form": NSNull()]]) { _, incoming in incoming },
        "invalidInput", "/command/expectedFieldHashes/form"
      ),
      (
        command.merging(["expectedFieldHashes": ["form": "sha256-v1:invalid"]]) { _, incoming in
          incoming
        }, "invalidInput", "/command/expectedFieldHashes/form"
      ),
      (
        command.merging(["expectedFieldHashes": ["form": "invalid", "weird/~": "invalid"]]) {
          _, incoming in incoming
        }, "unknownField", "/command/expectedFieldHashes/weird~1~0"
      ),
      (
        command.merging(["start": 813_214_800]) { _, incoming in incoming }, "unknownField",
        "/command/start"
      ),
      (
        command.merging(["weird/~": true]) { _, incoming in incoming }, "unknownField",
        "/command/weird~1~0"
      ),
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
      let originalSource = try value(try await httpSession.data(for: sourceRequest))
      let rowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "rows", "generation": snapshot.generation.uuidString, "offset": "0",
            "limit": "1",
          ],
        ])
      let originalRows = try value(try await httpSession.data(for: rowRequest))
      for (invalidCommand, code, path) in invalid {
        let operationIdentifier = UUID()
        let rejected = try rejection(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_execute",
              arguments: [
                "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                "command": invalidCommand,
              ])))
        #expect(rejected["operationId"] as? String == operationIdentifier.uuidString)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        if path.isEmpty {
          #expect(reason["propertyPath"] is NSNull)
        } else {
          #expect(reason["propertyPath"] as? String == path)
        }
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationIdentifier)
        else {
          await listener.stop()
          Issue.record("Rejected zone requests must not create applied receipts.")
          return
        }
      }
      let unchanged = try value(try await httpSession.data(for: sourceRequest))
      let unchangedRows = try value(try await httpSession.data(for: rowRequest))
      #expect(NSDictionary(dictionary: unchanged).isEqual(to: originalSource))
      #expect(NSDictionary(dictionary: unchangedRows).isEqual(to: originalRows))
      guard
        case .listedNamespaces(let beforeNamespaces) = await planner.inspectRecovery(
          request: .namespaces)
      else {
        await listener.stop()
        Issue.record("Independent checkpoint must remain readable.")
        return
      }
      #expect(beforeNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 2)
      #expect(beforeNamespaces.first?.preparedProposals.isEmpty == true)
      let operationIdentifier = UUID()
      let edited = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": operationIdentifier.uuidString, "command": command,
            ])))
      #expect((edited["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let current = try value(try await httpSession.data(for: sourceRequest))
      let expectedForm: [String: Any] = [
        "kind": "timed", "start": 813_200_400, "end": NSNull(), "planningTimeZone": "UTC",
      ]
      #expect(
        NSDictionary(
          dictionary: try #require(
            ((current["value"] as? [String: Any])?["content"] as? [String: Any])?["form"]
              as? [String: Any])
        )
        .isEqual(to: expectedForm))
      let staleRows = try failure(try await httpSession.data(for: rowRequest))
      #expect(staleRows["code"] as? String == "staleSnapshot")
      let changedReplay = try rejection(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": operationIdentifier.uuidString,
              "command": command.merging(["planningTimeZone": "Europe/Paris"]) { _, incoming in
                incoming
              },
            ])))
      #expect(
        (changedReplay["reason"] as? [String: Any])?["code"] as? String
          == "operationPayloadMismatch")
      let afterMismatch = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: afterMismatch).isEqual(to: current))
      await listener.stop()
      guard
        case .appliedRecoveryComplete(_, let originalCheckpoint) = await planner.operationStatus(
          session: datasetSession, operationId: operationIdentifier),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Payload mismatch must retain the previously applied receipt and checkpoint.")
        return
      }
      #expect(originalCheckpoint == 3)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 3)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func scheduleZoneOverHTTPPreservesInstantsAndRetainsLaterZoneOnReplay() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      ).outcome,
      let item = created.generated.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: datasetSession, request: .source(item)),
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createSchedule(
            source: item,
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400.25),
              end: Date(timeIntervalSinceReferenceDate: 813_204_000.75),
              planningTimeZone: "Asia/Tokyo")))
      ).outcome,
      let schedule = scheduled.generated.first
    else {
      Issue.record("The original appointment must exist before changing its zone over HTTP.")
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
      let sourceRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "source", "source": ["kind": "schedule", "id": schedule.id.uuidString],
          ],
        ])
      let original = try value(try await httpSession.data(for: sourceRequest))
      let hashes = try #require(
        (original["value"] as? [String: Any])?["fieldHashes"] as? [String: String])
      let operationIdentifier = UUID()
      let zoneRequest = try request(
        endpoint: endpoint, name: "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": operationIdentifier.uuidString,
          "command": [
            "type": "changeScheduleZone", "scheduleId": schedule.id.uuidString,
            "planningTimeZone": "Europe/Paris", "expectedFieldHashes": hashes,
          ],
        ])
      let changed = try value(try await httpSession.data(for: zoneRequest))
      #expect(changed["operationId"] as? String == operationIdentifier.uuidString)
      #expect((changed["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let current = try value(try await httpSession.data(for: sourceRequest))
      let currentSource = try #require(current["value"] as? [String: Any])
      let currentHashes = try #require(currentSource["fieldHashes"] as? [String: String])
      let expectedForm: [String: Any] = [
        "kind": "timed", "start": 813_200_400.25, "end": 813_204_000.75,
        "planningTimeZone": "Europe/Paris",
      ]
      #expect(
        NSDictionary(
          dictionary: try #require(
            (currentSource["content"] as? [String: Any])?["form"] as? [String: Any])
        )
        .isEqual(to: expectedForm))
      #expect(
        NSDictionary(dictionary: try #require(currentSource["source"] as? [String: Any]))
          .isEqual(to: ["kind": "schedule", "id": schedule.id.uuidString]))
      #expect(currentHashes != hashes)
      let stale = try rejection(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "changeScheduleZone", "scheduleId": schedule.id.uuidString,
                "planningTimeZone": "UTC", "expectedFieldHashes": hashes,
              ],
            ])))
      let reason = try #require(stale["reason"] as? [String: Any])
      let details = try #require(reason["details"] as? [String: Any])
      #expect(reason["code"] as? String == "staleEdit")
      #expect(details["conflictingFields"] as? [String] == ["form"])
      #expect(
        NSDictionary(dictionary: try #require(details["currentValues"] as? [String: Any]))
          .isEqual(to: ["form": expectedForm]))
      #expect(details["currentFieldHashes"] as? [String: String] == currentHashes)
      let later = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "changeScheduleZone", "scheduleId": schedule.id.uuidString,
                "planningTimeZone": "UTC", "expectedFieldHashes": currentHashes,
              ],
            ])))
      #expect((later["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "4")
      let beforeReplay = try value(try await httpSession.data(for: sourceRequest))
      let replayed = try value(try await httpSession.data(for: zoneRequest))
      #expect(NSDictionary(dictionary: replayed).isEqual(to: changed))
      let retained = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: retained).isEqual(to: beforeReplay))
      #expect(
        (((retained["value"] as? [String: Any])?["content"] as? [String: Any])?["form"]
          as? [String: Any])?["planningTimeZone"] as? String == "UTC")
      await listener.stop()
      guard
        case .source(.item(let retainedItem)) = await planner.read(
          session: datasetSession, request: .source(item)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("The planned Item and independent checkpoint must remain intact.")
        return
      }
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 4)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func malformedScheduleEditsKeepTheSavedFormAndIssuedRowsUnchanged() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      ).outcome,
      let item = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createSchedule(
            source: item,
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
              planningTimeZone: "Asia/Tokyo")))
      ).outcome,
      let schedule = scheduled.generated.first,
      case .source(.schedule(let original)) = await planner.read(
        session: datasetSession, request: .source(schedule)),
      case .source(.item(let originalItem)) = await planner.read(
        session: datasetSession, request: .source(item)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(
          session: datasetSession,
          request: .items(
            PlannerItemQuery(
              rowPresentation: PlannerRowPresentationContext(
                referenceInstant: Date(timeIntervalSinceReferenceDate: 813_200_400),
                displayTimeZone: "Asia/Tokyo")))))
    else {
      Issue.record(
        "A saved Schedule and issued row generation must exist before malformed HTTP edits.")
      return
    }
    let validForm: [String: Any] = [
      "kind": "timed", "start": 813_214_800, "end": NSNull(), "planningTimeZone": "Asia/Tokyo",
    ]
    let hashes = ["form": try #require(original.fieldHashes[.form]?.value)]
    let validCommand: [String: Any] = [
      "type": "editSchedule", "scheduleId": schedule.id.uuidString,
      "changes": ["form": validForm], "expectedFieldHashes": hashes,
    ]
    let invalidCommands: [([String: Any], String, String)] = [
      (
        validCommand.merging(["scheduleId": "invalid"]) { _, incoming in incoming }, "invalidInput",
        "/command/scheduleId"
      ),
      (
        validCommand.merging(["scheduleId": item.id.uuidString]) { _, incoming in incoming },
        "missingReference", ""
      ),
      (
        validCommand.merging(["changes": NSNull()]) { _, incoming in incoming }, "invalidInput",
        "/command/changes"
      ),
      (
        validCommand.merging(["changes": [:]]) { _, incoming in incoming }, "invalidInput",
        "/command/changes/form"
      ),
      (
        validCommand.merging(["changes": ["form": NSNull()]]) { _, incoming in incoming },
        "invalidInput", "/command/changes/form"
      ),
      (
        validCommand.merging(["changes": ["form": validForm, "notes": "Wrong owner"]]) {
          _, incoming in incoming
        }, "unknownField", "/command/changes/notes"
      ),
      (
        validCommand.merging(["changes": ["form": ["kind": "allDay"]]]) { _, incoming in incoming },
        "unavailable", "/command/changes/form/kind"
      ),
      (
        validCommand.merging(["expectedFieldHashes": [:]]) { _, incoming in incoming },
        "invalidInput", "/command/expectedFieldHashes/form"
      ),
      (
        validCommand.merging(["expectedFieldHashes": ["form": NSNull()]]) { _, incoming in incoming
        }, "invalidInput", "/command/expectedFieldHashes/form"
      ),
      (
        validCommand.merging(["expectedFieldHashes": ["form": "sha256-v1:invalid"]]) {
          _, incoming in incoming
        }, "invalidInput", "/command/expectedFieldHashes/form"
      ),
      (
        validCommand.merging([
          "expectedFieldHashes": hashes.merging(["notes": "invalid"]) { _, incoming in incoming }
        ]) { _, incoming in incoming }, "unknownField", "/command/expectedFieldHashes/notes"
      ),
      (
        validCommand.merging(["weird/~": true]) { _, incoming in incoming }, "unknownField",
        "/command/weird~1~0"
      ),
    ]
    var invalid = invalidCommands
    let invalidForms: [([String: Any], String, String)] = [
      (
        ["kind": "timed", "start": 813_214_800, "planningTimeZone": "Asia/Tokyo"], "invalidInput",
        "/end"
      ),
      (validForm.merging(["start": "today"]) { _, incoming in incoming }, "invalidInput", "/start"),
      (validForm.merging(["start": true]) { _, incoming in incoming }, "invalidInput", "/start"),
      (validForm.merging(["end": "tomorrow"]) { _, incoming in incoming }, "invalidInput", "/end"),
      (validForm.merging(["end": 813_214_800]) { _, incoming in incoming }, "invalidInput", "/end"),
      (validForm.merging(["end": 813_214_799]) { _, incoming in incoming }, "invalidInput", "/end"),
      (
        validForm.merging(["planningTimeZone": "Invalid/Zone"]) { _, incoming in incoming },
        "invalidInput", "/planningTimeZone"
      ),
      (
        validForm.merging(["planningTimeZone": NSNull()]) { _, incoming in incoming },
        "invalidInput", "/planningTimeZone"
      ),
      (
        validForm.merging(["weird/~": true]) { _, incoming in incoming }, "unknownField",
        "/weird~1~0"
      ),
    ]
    for (form, code, path) in invalidForms {
      invalid.append(
        (
          validCommand.merging(["changes": ["form": form]]) { _, incoming in incoming },
          code, "/command/changes/form" + path
        ))
    }
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
      let before = try value(try await httpSession.data(for: sourceRequest))
      let rowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "rows", "generation": snapshot.generation.uuidString, "offset": "0",
            "limit": "1",
          ],
        ])
      let beforeRows = try value(try await httpSession.data(for: rowRequest))
      for (command, code, path) in invalid {
        let operationIdentifier = UUID()
        let rejected = try rejection(
          try await httpSession.data(
            for: request(
              endpoint: endpoint,
              name: "planner_execute",
              arguments: [
                "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                "command": command,
              ])))
        #expect(rejected["operationId"] as? String == operationIdentifier.uuidString)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        if path.isEmpty {
          #expect(reason["propertyPath"] is NSNull)
        } else {
          #expect(reason["propertyPath"] as? String == path)
        }
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationIdentifier)
        else {
          Issue.record("A rejected edit must not create applied Core evidence.")
          return
        }
      }
      let after = try value(try await httpSession.data(for: sourceRequest))
      let afterRows = try value(try await httpSession.data(for: rowRequest))
      #expect(NSDictionary(dictionary: after).isEqual(to: before))
      #expect(NSDictionary(dictionary: afterRows).isEqual(to: beforeRows))
      await listener.stop()
      guard
        case .source(.item(let unchangedItem)) = await planner.read(
          session: datasetSession, request: .source(item)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("The Item and independent checkpoint must remain readable.")
        return
      }
      #expect(unchangedItem.fieldHashes == originalItem.fieldHashes)
      #expect(unchangedItem.updatedAt == originalItem.updatedAt)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 2)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func guardedScheduleEditsOverHTTPRejectStaleFormsAndReplayWithoutReplacingLaterData()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      ).outcome,
      let item = created.generated.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: datasetSession, request: .source(item)),
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createSchedule(
            source: item,
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400),
              end: Date(timeIntervalSinceReferenceDate: 813_204_000), planningTimeZone: "Asia/Tokyo"
            )))
      ).outcome,
      let schedule = scheduled.generated.first
    else {
      Issue.record("The source Item and retained Schedule must exist before the real HTTP edit.")
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
      let sourceRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "source", "source": ["kind": "schedule", "id": schedule.id.uuidString],
          ],
        ])
      let original = try value(try await httpSession.data(for: sourceRequest))
      let originalHashes = try #require(
        (original["value"] as? [String: Any])?["fieldHashes"] as? [String: String])
      let replacement: [String: Any] = [
        "kind": "timed", "start": 813_214_800.25, "end": 813_218_400.75,
        "planningTimeZone": "Asia/Tokyo",
      ]
      let operationIdentifier = UUID()
      let editRequest = try request(
        endpoint: endpoint, name: "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": operationIdentifier.uuidString,
          "command": [
            "type": "editSchedule", "scheduleId": schedule.id.uuidString,
            "changes": ["form": replacement], "expectedFieldHashes": originalHashes,
          ],
        ])
      let edited = try value(try await httpSession.data(for: editRequest))
      #expect(edited["operationId"] as? String == operationIdentifier.uuidString)
      #expect((edited["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      #expect(((edited["result"] as? [String: Any])?["generated"] as? [Any])?.isEmpty == true)
      let current = try value(try await httpSession.data(for: sourceRequest))
      let currentSource = try #require(current["value"] as? [String: Any])
      let currentForm = try #require(
        (currentSource["content"] as? [String: Any])?["form"] as? [String: Any])
      let currentHashes = try #require(currentSource["fieldHashes"] as? [String: String])
      #expect(NSDictionary(dictionary: currentForm).isEqual(to: replacement))
      #expect(currentHashes != originalHashes)
      let staleIdentifier = UUID()
      let stale = try rejection(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": staleIdentifier.uuidString,
              "command": [
                "type": "editSchedule", "scheduleId": schedule.id.uuidString,
                "changes": ["form": replacement], "expectedFieldHashes": originalHashes,
              ],
            ])))
      #expect(stale["operationId"] as? String == staleIdentifier.uuidString)
      let reason = try #require(stale["reason"] as? [String: Any])
      let details = try #require(reason["details"] as? [String: Any])
      #expect(reason["code"] as? String == "staleEdit")
      #expect(reason["propertyPath"] is NSNull)
      #expect(details["kind"] as? String == "staleEdit")
      #expect(details["conflictingFields"] as? [String] == ["form"])
      #expect(
        NSDictionary(dictionary: try #require(details["currentValues"] as? [String: Any]))
          .isEqual(to: ["form": replacement]))
      #expect(details["currentFieldHashes"] as? [String: String] == currentHashes)
      let afterStale = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: afterStale).isEqual(to: current))
      let laterForm: [String: Any] = [
        "kind": "timed", "start": 813_222_000, "end": NSNull(), "planningTimeZone": "Europe/Paris",
      ]
      let later = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "editSchedule", "scheduleId": schedule.id.uuidString,
                "changes": ["form": laterForm], "expectedFieldHashes": currentHashes,
              ],
            ])))
      #expect((later["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "4")
      let laterSource = try value(try await httpSession.data(for: sourceRequest))
      let replayed = try value(try await httpSession.data(for: editRequest))
      #expect(NSDictionary(dictionary: replayed).isEqual(to: edited))
      let retained = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: retained).isEqual(to: laterSource))
      let retainedForm = try #require(
        ((retained["value"] as? [String: Any])?["content"] as? [String: Any])?["form"]
          as? [String: Any])
      #expect(NSDictionary(dictionary: retainedForm).isEqual(to: laterForm))
      await listener.stop()
      guard
        case .source(.item(let retainedItem)) = await planner.read(
          session: datasetSession, request: .source(item)),
        case .noReliableEvidence = await planner.operationStatus(
          session: datasetSession, operationId: staleIdentifier),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 4))
      else {
        Issue.record("The planned Item and independent latest recovery must remain intact.")
        return
      }
      #expect(retainedItem.content.title == "Hotel")
      #expect(retainedItem.content.notes == "Keep")
      #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
      #expect(retainedItem.updatedAt == originalItem.updatedAt)
      #expect(recovery.decodedBackup.backup.schedules.count == 1)
      #expect(recovery.decodedBackup.backup.schedules.first?.id == schedule.id)
      #expect(
        recovery.decodedBackup.backup.schedules.first?.form
          == .timed(
            start: Date(timeIntervalSinceReferenceDate: 813_222_000), end: nil,
            planningTimeZone: "Europe/Paris"))
      #expect(namespace.preparedProposals.isEmpty)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func scheduleSourceOverHTTPReturnsOriginalFormAndOnlyItsGuardedHash() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      )
      .outcome,
      let source = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createSchedule(
            source: source,
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400),
              end: Date(timeIntervalSinceReferenceDate: 813_204_000), planningTimeZone: "Asia/Tokyo"
            )))
      )
      .outcome,
      let assignment = scheduled.generated.first,
      case .source(.schedule(let original)) = await planner.read(
        session: datasetSession, request: .source(assignment))
    else {
      Issue.record("The real Schedule's typed source value must exist before HTTP reading.")
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
      let response = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1,
              "request": [
                "kind": "source",
                "source": ["kind": "schedule", "id": assignment.id.uuidString],
              ],
            ])))
      #expect(response["kind"] as? String == "source")
      let read = try #require(response["value"] as? [String: Any])
      #expect(
        NSDictionary(dictionary: try #require(read["source"] as? [String: Any]))
          .isEqual(to: ["kind": "schedule", "id": assignment.id.uuidString]))
      let content = try #require(read["content"] as? [String: Any])
      #expect(
        NSDictionary(dictionary: content).isEqual(to: [
          "source": ["kind": "item", "id": source.id.uuidString],
          "form": [
            "kind": "timed", "start": 813_200_400, "end": 813_204_000,
            "planningTimeZone": "Asia/Tokyo",
          ],
        ]))
      #expect(
        read["fieldHashes"] as? [String: String] == [
          "form": try #require(original.fieldHashes[.form]?.value)
        ])
      #expect(read["createdAt"] is NSNull)
      #expect(read["updatedAt"] is NSNull)
      #expect(read["progress"] is NSNull)
      #expect((read["labels"] as? [Any])?.isEmpty == true)
      #expect((read["references"] as? [Any])?.isEmpty == true)
      let state = try #require(read["state"] as? [String: Any])
      #expect(state["globalDone"] is NSNull)
      #expect(state["archived"] is NSNull)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func scheduledSourceOverHTTPEnumeratesBookmarksAndScheduleWithoutLosingContent()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Keep",
              links: [
                PlannerLinkInput(originalUrl: "https://maps.apple.com/?q=Hotel", label: "Map"),
                PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu"),
              ])))
      )
      .outcome,
      let source = created.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: datasetSession, request: .source(source)),
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createSchedule(
            source: source,
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
              planningTimeZone: "Asia/Tokyo")))
      ).outcome,
      let assignment = scheduled.generated.first
    else {
      Issue.record("A real Item must retain its own bookmarks and direct appointment.")
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
      let owner: [String: Any] = ["kind": "item", "id": source.id.uuidString]
      let response = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1, "request": ["kind": "source", "source": owner],
            ])))
      let read = try #require(response["value"] as? [String: Any])
      let references = try #require(read["references"] as? [[String: Any]])
      #expect(references.count == 3)
      let expectedLinks: [[String: Any]] = original.content.links.map {
        [
          "kind": "ownedLink", "id": $0.linkId.uuidString, "owner": owner,
          "source": NSNull(), "appearance": NSNull(),
        ]
      }
      let expectedSchedule: [String: Any] = [
        "kind": "schedule", "id": assignment.id.uuidString, "owner": NSNull(),
        "source": owner, "appearance": NSNull(),
      ]
      #expect(NSArray(array: references).isEqual(to: expectedLinks + [expectedSchedule]))
      let content = try #require(read["content"] as? [String: Any])
      #expect(content["title"] as? String == "Hotel")
      #expect(content["notes"] as? String == "Keep")
      #expect((content["links"] as? [[String: Any]])?.count == 2)
      #expect(read["updatedAt"] as? Double == original.updatedAt.timeIntervalSinceReferenceDate)
      #expect(
        read["fieldHashes"] as? [String: String]
          == Dictionary(
            uniqueKeysWithValues:
              original.fieldHashes.map { ($0.key.rawValue, $0.value.value) }))
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func malformedTimedAppointmentsRejectWithoutChangingSourceWindowOrRecovery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      )
      .outcome,
      let source = created.generated.first
    else {
      Issue.record("A saved Item must exist before invalid appointment requests.")
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
      let owner: [String: Any] = ["kind": "item", "id": source.id.uuidString]
      let sourceRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1, "request": ["kind": "source", "source": owner],
        ])
      let before = try value(try await httpSession.data(for: sourceRequest))
      let snapshot = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_query",
            arguments: [
              "formatVersion": 1, "query": ["kind": "items", "scope": ["kind": "global"]],
            ])))
      let rowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "rows",
            "generation": try #require(snapshot["generation"] as? String), "offset": "0",
            "limit": "1",
          ],
        ])
      let beforeWindow = try value(try await httpSession.data(for: rowRequest))
      let form: [String: Any] = [
        "kind": "timed", "start": 813_200_400,
        "end": NSNull(), "planningTimeZone": "Asia/Tokyo",
      ]
      let invalidForms: [(Any, String, String)] = [
        (NSNull(), "invalidInput", "/command/form"),
        (["kind": "unknown"], "invalidInput", "/command/form/kind"),
        (
          [
            "kind": "timed", "start": "813200400", "end": NSNull(),
            "planningTimeZone": "Asia/Tokyo",
          ],
          "invalidInput", "/command/form/start"
        ),
        (
          ["kind": "timed", "start": true, "end": NSNull(), "planningTimeZone": "Asia/Tokyo"],
          "invalidInput", "/command/form/start"
        ),
        (
          [
            "kind": "timed", "start": 813_200_400, "end": "813200401",
            "planningTimeZone": "Asia/Tokyo",
          ],
          "invalidInput", "/command/form/end"
        ),
        (
          ["kind": "timed", "start": 813_200_400, "planningTimeZone": "Asia/Tokyo"],
          "invalidInput", "/command/form/end"
        ),
        (
          [
            "kind": "timed", "start": 813_200_400, "end": 813_200_400,
            "planningTimeZone": "Asia/Tokyo",
          ],
          "invalidInput", "/command/form/end"
        ),
        (
          [
            "kind": "timed", "start": 813_200_400, "end": 813_200_399,
            "planningTimeZone": "Asia/Tokyo",
          ],
          "invalidInput", "/command/form/end"
        ),
        (
          ["kind": "timed", "start": 813_200_400, "end": NSNull(), "planningTimeZone": 0],
          "invalidInput", "/command/form/planningTimeZone"
        ),
        (
          [
            "kind": "timed", "start": 813_200_400, "end": NSNull(),
            "planningTimeZone": "Invalid/Zone",
          ],
          "invalidInput", "/command/form/planningTimeZone"
        ),
        (
          [
            "kind": "timed", "start": 813_200_400, "end": NSNull(),
            "planningTimeZone": "Asia/Tokyo",
            "unexpected/~": true,
          ], "unknownField", "/command/form/unexpected~1~0"
        ),
        (
          ["kind": "allDay", "start": ["year": 2026, "month": 10, "day": 9], "end": NSNull()],
          "unavailable", "/command/form/kind"
        ),
      ]
      var invalidCommands: [([String: Any], String, String)] = invalidForms.map {
        input, code, path in
        (["type": "createSchedule", "source": owner, "form": input], code, path)
      }
      invalidCommands += [
        (
          ["type": "createSchedule", "source": ["kind": "item", "id": "invalid"], "form": form],
          "invalidInput", "/command/source/id"
        ),
        (
          [
            "type": "createSchedule", "source": ["kind": "list", "id": source.id.uuidString],
            "form": form,
          ],
          "invalidInput", "/command/source/kind"
        ),
        (
          [
            "type": "createSchedule", "source": ["kind": "itinerary", "id": UUID().uuidString],
            "form": form,
          ],
          "unavailable", "/command/source/kind"
        ),
        (
          [
            "type": "createSchedule", "source": ["kind": "item", "id": UUID().uuidString],
            "form": form,
          ],
          "missingReference", "/command/source"
        ),
      ]
      for (command, code, path) in invalidCommands {
        let operationIdentifier = UUID()
        let rejected = try rejection(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_execute",
              arguments: [
                "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                "command": command,
              ])))
        #expect(rejected["operationId"] as? String == operationIdentifier.uuidString)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        #expect(reason["propertyPath"] as? String == path)
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationIdentifier)
        else {
          Issue.record("Invalid appointment requests must create no applied receipt.")
          await listener.stop()
          return
        }
      }
      #expect(
        NSDictionary(dictionary: try value(try await httpSession.data(for: sourceRequest)))
          .isEqual(to: before))
      #expect(
        NSDictionary(dictionary: try value(try await httpSession.data(for: rowRequest)))
          .isEqual(to: beforeWindow))
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Rejected requests must preserve the independent recovery namespace.")
        await listener.stop()
        return
      }
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 1)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
      let fractionalForm: [String: Any] = [
        "kind": "timed", "start": 813_200_400.25,
        "end": 813_200_400.5, "planningTimeZone": "Europe/Paris",
      ]
      let scheduled = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": ["type": "createSchedule", "source": owner, "form": fractionalForm],
            ])))
      #expect((scheduled["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "2")
      #expect(
        try failure(try await httpSession.data(for: rowRequest))["code"] as? String
          == "staleSnapshot")
      let fresh = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_query",
            arguments: [
              "formatVersion": 1,
              "query": [
                "kind": "items", "scope": ["kind": "global"],
                "rowPresentation": [
                  "referenceInstant": 813_200_400, "displayTimeZone": "Asia/Tokyo",
                ],
              ],
            ])))
      let window = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1,
              "request": [
                "kind": "rows",
                "generation": try #require(fresh["generation"] as? String), "offset": "0",
                "limit": "1",
              ],
            ])))
      let summary = try #require(
        ((window["rows"] as? [[String: Any]])?.first)?["scheduleSummary"] as? [String: Any])
      #expect(
        NSDictionary(dictionary: try #require(summary["form"] as? [String: Any]))
          .isEqual(to: fractionalForm))
      #expect(summary["additionalCount"] as? String == "0")
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func directTimedAppointmentsOverHTTPKeepInstantsAndGenerationBoundDateSelection()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      )
      .outcome,
      let source = created.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: datasetSession, request: .source(source))
    else {
      Issue.record("The real Item must exist before creating appointments over HTTP.")
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
      let owner: [String: Any] = ["kind": "item", "id": source.id.uuidString]
      let form: [String: Any] = [
        "kind": "timed", "start": 813_200_400,
        "end": NSNull(), "planningTimeZone": "Asia/Tokyo",
      ]
      let operationIdentifier = UUID()
      let creationRequest = try request(
        endpoint: endpoint, name: "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": operationIdentifier.uuidString,
          "command": ["type": "createSchedule", "source": owner, "form": form],
        ])
      let createdSchedule = try value(try await httpSession.data(for: creationRequest))
      let creationResult = try #require(createdSchedule["result"] as? [String: Any])
      let first = try #require((creationResult["generated"] as? [[String: Any]])?.first)
      #expect(first["kind"] as? String == "schedule")
      #expect(UUID(uuidString: try #require(first["id"] as? String)) != nil)
      #expect(
        (createdSchedule["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "2")
      let futureForm: [String: Any] = [
        "kind": "timed", "start": 813_214_800,
        "end": NSNull(), "planningTimeZone": "Asia/Tokyo",
      ]
      let futureCreation = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": ["type": "createSchedule", "source": owner, "form": futureForm],
            ])))
      let futureResult = try #require(futureCreation["result"] as? [String: Any])
      let future = try #require((futureResult["generated"] as? [[String: Any]])?.first)
      #expect(future["id"] as? String != first["id"] as? String)
      for zone in ["Asia/Tokyo", "Europe/Paris"] {
        for (instant, selected, expectedForm) in [
          (813_200_400, first, form), (813_202_200, future, futureForm),
        ] {
          let presentation: [String: Any] = ["referenceInstant": instant, "displayTimeZone": zone]
          let snapshot = try value(
            try await httpSession.data(
              for: request(
                endpoint: endpoint, name: "planner_query",
                arguments: [
                  "formatVersion": 1,
                  "query": [
                    "kind": "items", "scope": ["kind": "global"],
                    "rowPresentation": presentation,
                  ],
                ])))
          let generation = try #require(snapshot["generation"] as? String)
          let window = try value(
            try await httpSession.data(
              for: request(
                endpoint: endpoint, name: "planner_read",
                arguments: [
                  "formatVersion": 1,
                  "request": [
                    "kind": "rows", "generation": generation,
                    "offset": "0", "limit": "1",
                  ],
                ])))
          let row = try #require((window["rows"] as? [[String: Any]])?.first)
          let summary = try #require(row["scheduleSummary"] as? [String: Any])
          #expect(
            NSDictionary(dictionary: summary).isEqual(to: [
              "kind": "directItem", "schedule": selected, "owner": owner,
              "form": expectedForm, "additionalCount": "1",
            ]))
          #expect(
            NSDictionary(dictionary: try #require(window["rowPresentation"] as? [String: Any]))
              .isEqual(to: presentation))
          #expect(row["notes"] == nil)
          #expect(row["fieldHashes"] == nil)
        }
      }
      let replayed = try value(try await httpSession.data(for: creationRequest))
      #expect(NSDictionary(dictionary: replayed).isEqual(to: createdSchedule))
      await listener.stop()
      guard
        case .source(.item(let retained)) = await planner.read(
          session: datasetSession, request: .source(source)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: 3))
      else {
        Issue.record(
          "HTTP creation must save both appointments into the same canonical store and recovery.")
        return
      }
      #expect(retained.content.title == "Hotel")
      #expect(retained.content.notes == "Keep")
      #expect(retained.fieldHashes == original.fieldHashes)
      #expect(retained.updatedAt == original.updatedAt)
      #expect(retained.references.count == 2)
      #expect(recovery.decodedBackup.backup.schedules.count == 2)
      #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 3)
      #expect(namespace.preparedProposals.isEmpty)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func malformedBookmarkEditsRetainBothOwnersAndTheIssuedRowWindow() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Original notes",
              links: [PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu")])))
      )
      .outcome, let source = created.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: datasetSession, request: .source(source)),
      case .applied(let otherCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Museum",
              links: [PlannerLinkInput(originalUrl: "https://example.com/museum", label: nil)])))
      )
      .outcome, let otherSource = otherCreated.generated.first,
      case .source(.item(let otherOriginal)) = await planner.read(
        session: datasetSession, request: .source(otherSource))
    else {
      Issue.record("Two saved Items must have separate owned links before invalid editing.")
      return
    }
    let identifier = try #require(original.content.links.first?.linkId.uuidString)
    let foreignIdentifier = try #require(otherOriginal.content.links.first?.linkId.uuidString)
    let retainedLink: [String: Any] = [
      "linkId": identifier, "originalUrl": "https://example.com/menu", "label": "Menu",
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
          "request": ["kind": "source", "source": ["kind": "item", "id": source.id.uuidString]],
        ])
      let before = try value(try await httpSession.data(for: sourceRequest))
      let hashes = try #require(
        (before["value"] as? [String: Any])?["fieldHashes"] as? [String: String])
      let snapshot = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_query",
            arguments: [
              "formatVersion": 1, "query": ["kind": "items", "scope": ["kind": "global"]],
            ])))
      let rowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "rows", "generation": try #require(snapshot["generation"] as? String),
            "offset": "0", "limit": "2",
          ],
        ])
      let beforeWindow = try value(try await httpSession.data(for: rowRequest))
      let invalid: [(input: Any, code: String, path: String)] = [
        (NSNull(), "invalidInput", "/command/changes/links"),
        (
          [["originalUrl": "https://example.com/menu"]], "invalidInput",
          "/command/changes/links/0/label"
        ),
        (
          [["linkId": "invalid", "originalUrl": "https://example.com/menu", "label": NSNull()]],
          "invalidInput", "/command/changes/links/0/linkId"
        ),
        ([retainedLink, retainedLink], "invalidInput", "/command/changes/links/1/linkId"),
        (
          [
            [
              "linkId": foreignIdentifier, "originalUrl": "https://example.com/museum",
              "label": NSNull(),
            ]
          ],
          "invalidInput", "/command/changes/links/0/linkId"
        ),
        (
          [retainedLink, ["originalUrl": "file:///private/tmp/menu", "label": NSNull()]],
          "invalidInput", "/command/changes/links/1/originalUrl"
        ),
        (
          [["originalUrl": "https://example.com/menu", "label": NSNull(), "unexpected/~": true]],
          "unknownField", "/command/changes/links/0/unexpected~1~0"
        ),
      ]
      for expected in invalid {
        let operationIdentifier = UUID()
        let rejected = try rejection(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_execute",
              arguments: [
                "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                "command": [
                  "type": "editItem", "sourceId": source.id.uuidString,
                  "changes": ["notes": "Rejected notes", "links": expected.input],
                  "expectedFieldHashes": hashes,
                ],
              ])))
        #expect(rejected["operationId"] as? String == operationIdentifier.uuidString)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == expected.code)
        #expect(reason["propertyPath"] as? String == expected.path)
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationIdentifier)
        else {
          Issue.record(
            "Invalid bookmark edits must not save partial notes/links or an applied receipt.")
          await listener.stop()
          return
        }
      }
      let after = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: after).isEqual(to: before))
      let afterWindow = try value(try await httpSession.data(for: rowRequest))
      #expect(NSDictionary(dictionary: afterWindow).isEqual(to: beforeWindow))
      await listener.stop()
      guard
        case .source(.item(let otherRetained)) = await planner.read(
          session: datasetSession, request: .source(otherSource)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Invalid edits must retain the other owner and independent recovery.")
        return
      }
      #expect(otherRetained.content.links == otherOriginal.content.links)
      #expect(otherRetained.updatedAt == otherOriginal.updatedAt)
      #expect(otherRetained.fieldHashes == otherOriginal.fieldHashes)
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 2)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func ownedBookmarkReplacementOverHTTPRejectsStalePatchAndKeepsLaterEmptyValueOnReplay()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Original notes",
              links: [
                PlannerLinkInput(originalUrl: "https://maps.apple.com/?q=Hotel", label: "Map"),
                PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu"),
              ])))
      )
      .outcome, let source = created.generated.first
    else {
      Issue.record("The source and its owned links must be independently saved.")
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
      let sourceRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "item", "id": source.id.uuidString]],
        ])
      let before = try value(try await httpSession.data(for: sourceRequest))
      let original = try #require(before["value"] as? [String: Any])
      let hashes = try #require(original["fieldHashes"] as? [String: String])
      let content = try #require(original["content"] as? [String: Any])
      let originalLinks = try #require(content["links"] as? [[String: Any]])
      try #require(originalLinks.count == 2)
      let retainedIdentifier = try #require(originalLinks[1]["linkId"] as? String)
      let replacement: [[String: Any]] = [
        [
          "linkId": retainedIdentifier, "originalUrl": "https://tabelog.com/menu",
          "label": "Dinner",
        ],
        ["originalUrl": "https://example.com/gallery", "label": NSNull()],
      ]
      let editIdentifier = UUID()
      let editRequest = try request(
        endpoint: endpoint, name: "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": editIdentifier.uuidString,
          "command": [
            "type": "editItem", "sourceId": source.id.uuidString,
            "changes": ["links": replacement], "expectedFieldHashes": hashes,
          ],
        ])
      let edited = try value(try await httpSession.data(for: editRequest))
      #expect((edited["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "2")
      let current = try value(try await httpSession.data(for: sourceRequest))
      let currentSource = try #require(current["value"] as? [String: Any])
      let currentContent = try #require(currentSource["content"] as? [String: Any])
      let currentLinks = try #require(currentContent["links"] as? [[String: Any]])
      let currentHashes = try #require(currentSource["fieldHashes"] as? [String: String])
      #expect(
        currentLinks.map { $0["originalUrl"] as? String } == [
          "https://tabelog.com/menu", "https://example.com/gallery",
        ])
      #expect(currentLinks.first?["linkId"] as? String == retainedIdentifier)
      #expect(currentLinks.first?["label"] as? String == "Dinner")
      #expect(currentLinks.first?["kind"] as? String == "tabelog")
      #expect(currentLinks.last?["label"] is NSNull)
      #expect(currentLinks.last?["linkId"] as? String != retainedIdentifier)
      let staleIdentifier = UUID()
      let stale = try rejection(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": staleIdentifier.uuidString,
              "command": [
                "type": "editItem", "sourceId": source.id.uuidString,
                "changes": ["title": "Rejected title", "links": replacement],
                "expectedFieldHashes": hashes,
              ],
            ])))
      let reason = try #require(stale["reason"] as? [String: Any])
      let details = try #require(reason["details"] as? [String: Any])
      #expect(reason["code"] as? String == "staleEdit")
      #expect(details["conflictingFields"] as? [String] == ["links"])
      let currentValues = try #require(details["currentValues"] as? [String: Any])
      #expect(
        NSArray(array: try #require(currentValues["links"] as? [[String: Any]])).isEqual(
          to: currentLinks))
      #expect(
        details["currentFieldHashes"] as? [String: String] == [
          "links": try #require(currentHashes["links"])
        ])
      let afterStale = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: afterStale).isEqual(to: current))
      let emptied = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_execute",
            arguments: [
              "formatVersion": 1, "operationId": UUID().uuidString,
              "command": [
                "type": "editItem", "sourceId": source.id.uuidString,
                "changes": ["links": []], "expectedFieldHashes": currentHashes,
              ],
            ])))
      #expect((emptied["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let emptySource = try value(try await httpSession.data(for: sourceRequest))
      let replayed = try value(try await httpSession.data(for: editRequest))
      #expect(NSDictionary(dictionary: replayed).isEqual(to: edited))
      let retained = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: retained).isEqual(to: emptySource))
      let retainedContent = try #require(
        (retained["value"] as? [String: Any])?["content"] as? [String: Any])
      #expect(retainedContent["title"] as? String == "Hotel")
      #expect(retainedContent["notes"] as? String == "Original notes")
      #expect((retainedContent["links"] as? [[String: Any]])?.isEmpty == true)
      await listener.stop()
      guard
        case .noReliableEvidence = await planner.operationStatus(
          session: datasetSession, operationId: staleIdentifier),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record(
          "Stale edits must retain the last independent checkpoint without applied evidence.")
        return
      }
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 3)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func malformedLocationsRejectWholeCreationsAndEditsWithoutChangingSavedData() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    let location = PlannerOwnedLocation(
      displayName: nil, formattedAddress: "Meeting point A",
      coordinate: PlannerCoordinate(latitude: 35, longitude: 139))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Original notes", location: location)))
      )
      .outcome, let source = created.generated.first
    else {
      Issue.record("The original Item and owned address must be independently saved.")
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
      let sourceRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "item", "id": source.id.uuidString]],
        ])
      let before = try value(try await httpSession.data(for: sourceRequest))
      let hashes = try #require(
        (before["value"] as? [String: Any])?["fieldHashes"] as? [String: String])
      let snapshot = try value(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_query",
            arguments: [
              "formatVersion": 1, "query": ["kind": "items", "scope": ["kind": "global"]],
            ])))
      let rowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "rows", "generation": try #require(snapshot["generation"] as? String),
            "offset": "0", "limit": "1",
          ],
        ])
      let beforeWindow = try value(try await httpSession.data(for: rowRequest))
      let invalidLocations: [(input: Any, code: String, suffix: String)] = [
        (true, "invalidInput", ""),
        (["formattedAddress": NSNull(), "coordinate": NSNull()], "invalidInput", "/displayName"),
        (["displayName": NSNull(), "formattedAddress": NSNull()], "invalidInput", "/coordinate"),
        (
          ["displayName": 1, "formattedAddress": NSNull(), "coordinate": NSNull()],
          "invalidInput", "/displayName"
        ),
        (
          ["displayName": NSNull(), "formattedAddress": true, "coordinate": NSNull()],
          "invalidInput", "/formattedAddress"
        ),
        (
          ["displayName": NSNull(), "formattedAddress": NSNull(), "coordinate": ["latitude": 35]],
          "invalidInput", "/coordinate/longitude"
        ),
        (
          [
            "displayName": NSNull(), "formattedAddress": NSNull(),
            "coordinate": ["latitude": "35", "longitude": 139],
          ],
          "invalidInput", "/coordinate/latitude"
        ),
        (
          [
            "displayName": NSNull(), "formattedAddress": NSNull(),
            "coordinate": ["latitude": 35, "longitude": true],
          ],
          "invalidInput", "/coordinate/longitude"
        ),
        (
          [
            "displayName": NSNull(), "formattedAddress": NSNull(),
            "coordinate": ["latitude": 90.01, "longitude": 139],
          ],
          "invalidInput", "/coordinate"
        ),
        (
          [
            "displayName": NSNull(), "formattedAddress": NSNull(),
            "coordinate": ["latitude": 35, "longitude": -180.01],
          ],
          "invalidInput", "/coordinate"
        ),
        (
          [
            "displayName": NSNull(), "formattedAddress": NSNull(), "coordinate": NSNull(),
            "unexpected/~": true,
          ], "unknownField", "/unexpected~1~0"
        ),
        (
          [
            "displayName": NSNull(), "formattedAddress": NSNull(),
            "coordinate": ["latitude": 35, "longitude": 139, "unexpected/~": true],
          ],
          "unknownField", "/coordinate/unexpected~1~0"
        ),
      ]
      for expected in invalidLocations {
        for commandType in ["createItem", "editItem"] {
          let operationIdentifier = UUID()
          var command: [String: Any] = ["type": commandType]
          let propertyPrefix: String
          if commandType == "createItem" {
            command["content"] = ["title": "Rejected", "location": expected.input]
            propertyPrefix = "/command/content/location"
          } else {
            command["sourceId"] = source.id.uuidString
            command["changes"] = ["notes": "Rejected notes", "location": expected.input]
            command["expectedFieldHashes"] = hashes
            propertyPrefix = "/command/changes/location"
          }
          let rejected = try rejection(
            try await httpSession.data(
              for: request(
                endpoint: endpoint, name: "planner_execute",
                arguments: [
                  "formatVersion": 1, "operationId": operationIdentifier.uuidString,
                  "command": command,
                ])))
          #expect(rejected["operationId"] as? String == operationIdentifier.uuidString)
          let reason = try #require(rejected["reason"] as? [String: Any])
          #expect(reason["code"] as? String == expected.code)
          #expect(reason["propertyPath"] as? String == propertyPrefix + expected.suffix)
          guard
            case .noReliableEvidence = await planner.operationStatus(
              session: datasetSession, operationId: operationIdentifier)
          else {
            Issue.record(
              "Invalid location input must not save partial content or an applied receipt.")
            await listener.stop()
            return
          }
        }
      }
      let after = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: after).isEqual(to: before))
      let afterWindow = try value(try await httpSession.data(for: rowRequest))
      #expect(NSDictionary(dictionary: afterWindow).isEqual(to: beforeWindow))
      await listener.stop()
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Invalid locations must retain acknowledged recovery.")
        return
      }
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 1)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func ownedLocationOverHTTPRejectsStaleCompoundEditAndRetainsClearOnReplay() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let firstLocation: [String: Any] = [
      "displayName": NSNull(), "formattedAddress": "Meeting point A",
      "coordinate": ["latitude": 35, "longitude": 139],
    ]
    let secondLocation: [String: Any] = [
      "displayName": "Entrance", "formattedAddress": "Meeting point B",
      "coordinate": ["latitude": 35.25, "longitude": 139.5],
    ]
    do {
      let creationIdentifier = UUID()
      let creationRequest = try request(
        endpoint: endpoint, name: "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": creationIdentifier.uuidString,
          "command": [
            "type": "createItem",
            "content": ["title": "Hotel", "notes": "Original notes", "location": firstLocation],
          ],
        ])
      let creation = try value(try await httpSession.data(for: creationRequest))
      #expect(creation["state"] as? String == "applied")
      guard
        case .appliedRecoveryComplete(let applied, _) = await planner.operationStatus(
          session: datasetSession, operationId: creationIdentifier)
      else {
        Issue.record("The HTTP-created address must be actually saved.")
        await listener.stop()
        return
      }
      let source = try #require(applied.generated.first)
      let sourceRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "item", "id": source.id.uuidString]],
        ])
      let original = try value(try await httpSession.data(for: sourceRequest))
      let originalSource = try #require(original["value"] as? [String: Any])
      let originalHashes = try #require(originalSource["fieldHashes"] as? [String: String])
      let originalContent = try #require(originalSource["content"] as? [String: Any])
      #expect(
        NSDictionary(dictionary: try #require(originalContent["location"] as? [String: Any]))
          .isEqual(to: firstLocation))
      let editIdentifier = UUID()
      let editRequest = try request(
        endpoint: endpoint, name: "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": editIdentifier.uuidString,
          "command": [
            "type": "editItem", "sourceId": source.id.uuidString,
            "changes": ["location": secondLocation],
            "expectedFieldHashes": ["location": try #require(originalHashes["location"])],
          ],
        ])
      let edited = try value(try await httpSession.data(for: editRequest))
      #expect(edited["state"] as? String == "applied")
      let beforeStale = try value(try await httpSession.data(for: sourceRequest))
      let currentSource = try #require(beforeStale["value"] as? [String: Any])
      let currentHashes = try #require(currentSource["fieldHashes"] as? [String: String])
      let staleRequest = try request(
        endpoint: endpoint, name: "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": UUID().uuidString,
          "command": [
            "type": "editItem", "sourceId": source.id.uuidString,
            "changes": ["title": "Rejected title", "location": firstLocation],
            "expectedFieldHashes": originalHashes,
          ],
        ])
      let rejected = try rejection(try await httpSession.data(for: staleRequest))
      let reason = try #require(rejected["reason"] as? [String: Any])
      #expect(reason["code"] as? String == "staleEdit")
      let details = try #require(reason["details"] as? [String: Any])
      #expect(details["kind"] as? String == "staleEdit")
      #expect(details["conflictingFields"] as? [String] == ["location"])
      let currentValues = try #require(details["currentValues"] as? [String: Any])
      #expect(
        NSDictionary(dictionary: try #require(currentValues["location"] as? [String: Any])).isEqual(
          to: secondLocation))
      #expect(
        details["currentFieldHashes"] as? [String: String] == [
          "location": try #require(currentHashes["location"])
        ])
      let afterStale = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: afterStale).isEqual(to: beforeStale))
      let clearRequest = try request(
        endpoint: endpoint, name: "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": UUID().uuidString,
          "command": [
            "type": "editItem", "sourceId": source.id.uuidString, "changes": ["location": NSNull()],
            "expectedFieldHashes": ["location": try #require(currentHashes["location"])],
          ],
        ])
      let cleared = try value(try await httpSession.data(for: clearRequest))
      #expect((cleared["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let clearedSource = try value(try await httpSession.data(for: sourceRequest))
      let replayed = try value(try await httpSession.data(for: editRequest))
      #expect(NSDictionary(dictionary: replayed).isEqual(to: edited))
      let retained = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: retained).isEqual(to: clearedSource))
      let retainedContent = try #require(
        (retained["value"] as? [String: Any])?["content"] as? [String: Any])
      #expect(retainedContent["title"] as? String == "Hotel")
      #expect(retainedContent["notes"] as? String == "Original notes")
      #expect(retainedContent["location"] is NSNull)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func malformedOwnedLinksRejectTogetherWithoutChangingTheSavedSourceOrWindow() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Original notes",
              links: [PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu")])))
      ).outcome, let source = created.generated.first,
      case .source(.item(let saved)) = await planner.read(
        session: datasetSession, request: .source(source))
    else {
      Issue.record("The original Item must be independently saved before invalid agent input.")
      return
    }
    let existingLinkIdentifier = try #require(saved.content.links.first?.linkId.uuidString)
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
          "request": ["kind": "source", "source": ["kind": "item", "id": source.id.uuidString]],
        ])
      let before = try value(try await httpSession.data(for: sourceRequest))
      let queryRequest = try request(
        endpoint: endpoint, name: "planner_query",
        arguments: ["formatVersion": 1, "query": ["kind": "items", "scope": ["kind": "global"]]])
      let snapshot = try value(try await httpSession.data(for: queryRequest))
      let generation = try #require(snapshot["generation"] as? String)
      let rowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "1"],
        ])
      let beforeWindow = try value(try await httpSession.data(for: rowRequest))
      let rejections: [(input: Any, code: String, path: String)] = [
        (NSNull(), "invalidInput", "/command/content/links"),
        ([NSNull()], "invalidInput", "/command/content/links/0"),
        (
          [["originalUrl": "https://example.com/menu"]], "invalidInput",
          "/command/content/links/0/label"
        ),
        (
          [["originalUrl": 1, "label": NSNull()]], "invalidInput",
          "/command/content/links/0/originalUrl"
        ),
        (
          [["originalUrl": "https://example.com/menu", "label": true]], "invalidInput",
          "/command/content/links/0/label"
        ),
        (
          [["originalUrl": "https://example.com/menu", "label": NSNull(), "linkId": "invalid"]],
          "invalidInput", "/command/content/links/0/linkId"
        ),
        (
          [["originalUrl": "https://example.com/menu", "label": NSNull(), "linkId": 1]],
          "invalidInput", "/command/content/links/0/linkId"
        ),
        (
          [
            [
              "originalUrl": "https://example.com/menu", "label": NSNull(),
              "linkId": existingLinkIdentifier,
            ]
          ], "invalidInput", "/command/content/links/0/linkId"
        ),
        (
          [["originalUrl": "file:///private/tmp/menu", "label": NSNull()]], "invalidInput",
          "/command/content/links/0/originalUrl"
        ),
        (
          [["originalUrl": "https://example.com/menu", "label": NSNull(), "kind": "website"]],
          "unknownField", "/command/content/links/0/kind"
        ),
        (
          [
            [
              "originalUrl": "https://example.com/menu", "label": NSNull(),
              "providerReference": NSNull(),
            ]
          ], "unknownField", "/command/content/links/0/providerReference"
        ),
        (
          [["originalUrl": "https://example.com/menu", "label": NSNull(), "unexpected/~": true]],
          "unknownField", "/command/content/links/0/unexpected~1~0"
        ),
        (
          [
            ["originalUrl": "https://example.com/valid", "label": NSNull()],
            ["originalUrl": "https://example.com/invalid", "label": true],
          ], "invalidInput", "/command/content/links/1/label"
        ),
      ]
      for expected in rejections {
        let operationIdentifier = UUID()
        let invalidRequest = try request(
          endpoint: endpoint, name: "planner_execute",
          arguments: [
            "formatVersion": 1, "operationId": operationIdentifier.uuidString,
            "command": [
              "type": "createItem", "content": ["title": "Rejected", "links": expected.input],
            ],
          ])
        let rejected = try rejection(try await httpSession.data(for: invalidRequest))
        #expect(rejected["operationId"] as? String == operationIdentifier.uuidString)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == expected.code)
        #expect(reason["propertyPath"] as? String == expected.path)
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationIdentifier)
        else {
          Issue.record(
            "Invalid links must not save an Item, partial link array or applied receipt.")
          await listener.stop()
          return
        }
      }
      let after = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: after).isEqual(to: before))
      let afterWindow = try value(try await httpSession.data(for: rowRequest))
      #expect(NSDictionary(dictionary: afterWindow).isEqual(to: beforeWindow))
      await listener.stop()
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Invalid wire inputs must retain the original recovery checkpoint.")
        return
      }
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 1)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func ownedLinksOverHTTPRetainFullDetailsAndOneRowPreviewAfterReplay() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = storageConfiguration(directory)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize before the agent journey.")
      return
    }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let operationIdentifier = UUID()
    let creationRequest = try request(
      endpoint: endpoint, name: "planner_execute",
      arguments: [
        "formatVersion": 1, "operationId": operationIdentifier.uuidString,
        "command": [
          "type": "createItem",
          "content": [
            "title": "Museum", "notes": "Bring umbrella",
            "links": [
              ["originalUrl": "https://maps.apple.com/?q=Museum", "label": "Map"],
              [
                "originalUrl": "http://example.com/menu?b=2&a=1#prices", "label": "Menu",
                "linkId": NSNull(),
              ],
              ["originalUrl": "https://example.com/reservation", "label": NSNull()],
            ],
          ],
        ],
      ])
    do {
      let creation = try value(try await httpSession.data(for: creationRequest))
      #expect(creation["state"] as? String == "applied")
      #expect(creation["operationId"] as? String == operationIdentifier.uuidString)
      guard
        case .appliedRecoveryComplete(let applied, let checkpoint) = await planner.operationStatus(
          session: datasetSession, operationId: operationIdentifier)
      else {
        Issue.record("HTTP creation must have actual saved Core and recovery evidence.")
        await listener.stop()
        return
      }
      #expect(checkpoint == 1)
      let source = try #require(applied.generated.first)
      let sourceRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "item", "id": source.id.uuidString]],
        ])
      let full = try value(try await httpSession.data(for: sourceRequest))
      let sourceValue = try #require(full["value"] as? [String: Any])
      let content = try #require(sourceValue["content"] as? [String: Any])
      let links = try #require(content["links"] as? [[String: Any]])
      let linkIds = try links.map { try #require($0["linkId"] as? String) }
      #expect(linkIds.count == 3)
      #expect(Set(linkIds).count == 3)
      #expect(linkIds.allSatisfy { UUID(uuidString: $0) != nil })
      #expect(links.compactMap { $0["kind"] as? String } == ["appleMaps", "website", "website"])
      #expect(
        links.compactMap { $0["originalUrl"] as? String } == [
          "https://maps.apple.com/?q=Museum", "http://example.com/menu?b=2&a=1#prices",
          "https://example.com/reservation",
        ])
      #expect(links[2]["label"] is NSNull)
      #expect(links.allSatisfy { $0["providerReference"] is NSNull })
      #expect(content["notes"] as? String == "Bring umbrella")
      #expect(content["location"] is NSNull)
      let queryRequest = try request(
        endpoint: endpoint, name: "planner_query",
        arguments: ["formatVersion": 1, "query": ["kind": "items", "scope": ["kind": "global"]]])
      let snapshot = try value(try await httpSession.data(for: queryRequest))
      let generation = try #require(snapshot["generation"] as? String)
      let rowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "1"],
        ])
      let window = try value(try await httpSession.data(for: rowRequest))
      let rows = try #require(window["rows"] as? [[String: Any]])
      let row = try #require(rows.first)
      #expect(row["hasLinks"] as? Bool == true)
      #expect(row["links"] == nil)
      #expect(row["notes"] == nil)
      #expect(row["fieldHashes"] == nil)
      let preview = try #require(row["previewLink"] as? [String: Any])
      #expect(NSDictionary(dictionary: preview).isEqual(to: links[1]))
      let replay = try value(try await httpSession.data(for: creationRequest))
      #expect(NSDictionary(dictionary: replay).isEqual(to: creation))
      let afterReplay = try value(try await httpSession.data(for: sourceRequest))
      #expect(NSDictionary(dictionary: afterReplay).isEqual(to: full))
      let unchangedWindow = try value(try await httpSession.data(for: rowRequest))
      #expect(NSDictionary(dictionary: unchangedWindow).isEqual(to: window))
      await listener.stop()
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.item(let retained)) = await reopened.read(
          session: reopenedSession, request: .source(source))
      else {
        Issue.record("The HTTP-created owned links must survive native store reopen.")
        return
      }
      #expect(retained.content.links.map { $0.linkId.uuidString } == linkIds)
      #expect(
        retained.content.links.map(\.originalUrl)
          == links.compactMap { $0["originalUrl"] as? String })
      #expect(retained.content.notes == "Bring umbrella")
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func invalidCompletionScopesNeverFallBackToGlobalOrRecordAppliedEvidence() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(title: "Hotel", notes: "Original notes")))
      ).outcome
    else {
      Issue.record("Hotel must be independently saved before the rejection checks.")
      return
    }
    let source = try #require(creation.generated.first)
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
          "request": ["kind": "source", "source": ["kind": "item", "id": source.id.uuidString]],
        ])
      let before = try value(try await httpSession.data(for: sourceRequest))
      let rejections: [(field: String, input: Any, code: String, path: String)] = [
        ("done", 1, "invalidInput", "/command/done"),
        ("done", "true", "invalidInput", "/command/done"),
        ("scope", NSNull(), "invalidInput", "/command/scope"),
        ("scope", ["kind": "unexpected"], "invalidInput", "/command/scope/kind"),
        ("scope", ["kind": "globalItem"], "invalidInput", "/command/scope/itemId"),
        (
          "scope", ["kind": "globalItem", "itemId": "invalid"], "invalidInput",
          "/command/scope/itemId"
        ),
        (
          "scope",
          [
            "kind": "appearance", "itemId": source.id.uuidString,
            "appearance": ["kind": "listItem"],
          ], "unknownField", "/command/scope/itemId"
        ),
        (
          "scope",
          [
            "kind": "appearance",
            "appearance": [
              "kind": "listMembership",
              "listId": "00000000-0000-4000-8000-000000000201",
              "membershipId": "00000000-0000-4000-8000-000000000401",
            ],
          ], "unavailable", "/command/scope/kind"
        ),
        (
          "scope",
          [
            "kind": "globalItem", "itemId": source.id.uuidString,
            "appearance": ["kind": "listItem"],
          ], "unknownField", "/command/scope/appearance"
        ),
        ("unexpected/~", true, "unknownField", "/command/unexpected~1~0"),
      ]
      for expected in rejections {
        let operationIdentifier = UUID()
        var command: [String: Any] = [
          "type": "setCompletion", "scope": ["kind": "globalItem", "itemId": source.id.uuidString],
          "done": true,
        ]
        command[expected.field] = expected.input
        let invalidRequest = try request(
          endpoint: endpoint, name: "planner_execute",
          arguments: [
            "formatVersion": 1, "operationId": operationIdentifier.uuidString, "command": command,
          ])
        let rejected = try rejection(try await httpSession.data(for: invalidRequest))
        #expect(rejected["operationId"] as? String == operationIdentifier.uuidString)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == expected.code)
        #expect(reason["propertyPath"] as? String == expected.path)
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationIdentifier)
        else {
          Issue.record("Rejected input must never record an applied operation.")
          await listener.stop()
          return
        }
      }
      let after = try value(try await httpSession.data(for: sourceRequest))
      #expect(
        NSDictionary(dictionary: try #require(after["value"] as? [String: Any])).isEqual(
          to: try #require(before["value"] as? [String: Any])))
      await listener.stop()
      guard
        case .source(.item(let retained)) = await planner.read(
          session: datasetSession, request: .source(source)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("All rejected scopes must retain the original Item and independent recovery.")
        return
      }
      #expect(retained.state.globalDone == false)
      #expect(retained.state.archived == false)
      #expect(retained.content.notes == "Original notes")
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 1)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func rejection(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    #expect(tool["isError"] as? Bool == true)
    let structured = try #require(tool["structuredContent"] as? [String: Any])
    #expect(structured["formatVersion"] as? Int == 1)
    #expect(structured["state"] as? String == "rejected")
    let content = try #require(tool["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let textValue = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textValue).isEqual(to: structured))
    return structured
  }

  @Test func completionOverHTTPUpdatesRowsAndOldReplayPreservesReopenedState() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = storageConfiguration(directory)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(title: "Hotel", notes: "Original notes")))
      ).outcome
    else {
      Issue.record("Hotel must be independently saved before the agent journey.")
      return
    }
    let source = try #require(creation.generated.first)
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let completionIdentifier = UUID()
    let completionRequest = try request(
      endpoint: endpoint, name: "planner_execute",
      arguments: [
        "formatVersion": 1, "operationId": completionIdentifier.uuidString,
        "command": [
          "type": "setCompletion", "scope": ["kind": "globalItem", "itemId": source.id.uuidString],
          "done": true,
        ],
      ])
    do {
      let completed = try value(try await httpSession.data(for: completionRequest))
      #expect(completed["state"] as? String == "applied")
      #expect((completed["recovery"] as? [String: Any])?["state"] as? String == "complete")
      #expect((completed["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "2")
      let queryRequest = try request(
        endpoint: endpoint, name: "planner_query",
        arguments: [
          "formatVersion": 1,
          "query": ["kind": "items", "scope": ["kind": "global"], "completion": "done"],
        ])
      let doneQuery = try value(try await httpSession.data(for: queryRequest))
      #expect(doneQuery["matchingCount"] as? String == "1")
      let generation = try #require(doneQuery["generation"] as? String)
      let windowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "1"],
        ])
      let window = try value(try await httpSession.data(for: windowRequest))
      let row = try #require((window["rows"] as? [[String: Any]])?.first)
      #expect(row["title"] as? String == "Hotel")
      #expect(row["globalDone"] as? Bool == true)
      #expect(row["effectiveDone"] as? Bool == true)
      #expect(row["localDone"] is NSNull)
      #expect(row["archived"] as? Bool == false)
      let reopenRequest = try request(
        endpoint: endpoint, name: "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": UUID().uuidString,
          "command": [
            "type": "setCompletion",
            "scope": ["kind": "globalItem", "itemId": source.id.uuidString], "done": false,
          ],
        ])
      let reopened = try value(try await httpSession.data(for: reopenRequest))
      #expect(reopened["state"] as? String == "applied")
      #expect((reopened["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      let sourceRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "item", "id": source.id.uuidString]],
        ])
      let beforeReplay = try value(try await httpSession.data(for: sourceRequest))
      let replayed = try value(try await httpSession.data(for: completionRequest))
      #expect(replayed["state"] as? String == "applied")
      #expect((replayed["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "2")
      let afterReplay = try value(try await httpSession.data(for: sourceRequest))
      let current = try #require(afterReplay["value"] as? [String: Any])
      #expect(
        NSDictionary(dictionary: current).isEqual(
          to: try #require(beforeReplay["value"] as? [String: Any])))
      #expect((current["state"] as? [String: Any])?["globalDone"] as? Bool == false)
      #expect((current["content"] as? [String: Any])?["notes"] as? String == "Original notes")
      let todoRequest = try request(
        endpoint: endpoint, name: "planner_query",
        arguments: [
          "formatVersion": 1, "query": ["kind": "items", "scope": ["kind": "global"]],
        ])
      let todoQuery = try value(try await httpSession.data(for: todoRequest))
      #expect(todoQuery["matchingCount"] as? String == "1")
      #expect(
        ((todoQuery["rows"] as? [[String: Any]])?.first?["source"] as? [String: Any])?["id"]
          as? String == source.id.uuidString)
      await listener.stop()
      let newFacade = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let newSession) = await newFacade.bootstrap(),
        case .source(.item(let retained)) = await newFacade.read(
          session: newSession, request: .source(source)),
        case .listedNamespaces(let namespaces) = await newFacade.inspectRecovery(
          request: .namespaces)
      else {
        Issue.record("The HTTP completion journey must reopen with independent recovery.")
        return
      }
      #expect(retained.state.globalDone == false)
      #expect(retained.state.archived == false)
      #expect(retained.content.notes == "Original notes")
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 3)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func rowWindowRepeatsFixedContextAndOwnedMetadataOverHTTP() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize.")
      return
    }
    let saved = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createItem(
          content: PlannerItemContentInput(
            title: "Nezu Museum", subtitle: "Museum", notes: "Original notes",
            location: PlannerOwnedLocation(
              displayName: "Meeting point A", formattedAddress: "Tokyo",
              coordinate: PlannerCoordinate(latitude: 35, longitude: 139)),
            estimate: PlannerEstimate(minutes: 120, displayUnit: .hour)))))
    guard case .applied(let applied, .complete) = saved.outcome else {
      Issue.record("The Item must be independently saved before the HTTP read.")
      return
    }
    let source = try #require(applied.generated.first)
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    let context: [String: Any] = [
      "referenceInstant": 813198600.0, "displayTimeZone": "Asia/Tokyo",
    ]
    do {
      let queryRequest = try request(
        endpoint: endpoint, name: "planner_query",
        arguments: [
          "formatVersion": 1,
          "query": ["kind": "items", "scope": ["kind": "global"], "rowPresentation": context],
        ])
      let query = try value(try await httpSession.data(for: queryRequest))
      let generation = try #require(query["generation"] as? String)
      #expect(UUID(uuidString: generation) != nil)
      #expect(query["matchingCount"] as? String == "1")
      let queryContext = try #require(query["rowPresentation"] as? [String: Any])
      #expect(NSDictionary(dictionary: queryContext).isEqual(to: context))
      let readRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "1"],
        ])
      let window = try value(try await httpSession.data(for: readRequest))
      #expect(window["kind"] as? String == "rows")
      #expect(window["generation"] as? String == generation)
      #expect(window["offset"] as? String == "0")
      #expect(window["matchingCount"] as? String == "1")
      let windowContext = try #require(window["rowPresentation"] as? [String: Any])
      #expect(NSDictionary(dictionary: windowContext).isEqual(to: context))
      let rows = try #require(window["rows"] as? [[String: Any]])
      #expect(rows.count == 1)
      let row = try #require(rows.first)
      #expect(row["title"] as? String == "Nezu Museum")
      #expect(row["subtitle"] as? String == "Museum")
      let identity = try #require(row["identity"] as? [String: Any])
      #expect(identity["kind"] as? String == "source")
      #expect((identity["source"] as? [String: Any])?["id"] as? String == source.id.uuidString)
      let location = try #require(row["ownedLocation"] as? [String: Any])
      #expect(location["displayName"] as? String == "Meeting point A")
      #expect(location["formattedAddress"] as? String == "Tokyo")
      #expect((location["coordinate"] as? [String: Any])?["latitude"] as? Double == 35)
      #expect((location["coordinate"] as? [String: Any])?["longitude"] as? Double == 139)
      let estimate = try #require(row["estimate"] as? [String: Any])
      #expect(estimate["minutes"] as? String == "120")
      #expect(estimate["displayUnit"] as? String == "hour")
      #expect(row["globalDone"] as? Bool == false)
      #expect(row["localDone"] is NSNull)
      #expect(row["effectiveDone"] as? Bool == false)
      #expect(row["archived"] as? Bool == false)
      #expect(row["hasLocation"] as? Bool == true)
      #expect(row["hasLinks"] as? Bool == false)
      #expect(row["previewLink"] is NSNull)
      #expect((row["scheduleSummary"] as? [String: Any])?["kind"] as? String == "none")
      #expect(row["notes"] == nil)
      #expect(row["fieldHashes"] == nil)
      let emptyRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "rows", "generation": generation, "offset": "1",
            "limit": String(Int64.max),
          ],
        ])
      let empty = try value(try await httpSession.data(for: emptyRequest))
      #expect(empty["generation"] as? String == generation)
      #expect(empty["matchingCount"] as? String == "1")
      #expect((empty["rows"] as? [[String: Any]])?.isEmpty == true)
      #expect(
        NSDictionary(dictionary: try #require(empty["rowPresentation"] as? [String: Any]))
          .isEqual(to: context))
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func anotherWriterMakesHTTPWindowStaleWithoutReturningEmptySuccess() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = storageConfiguration(directory)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize.")
      return
    }
    let saved = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))))
    guard case .applied(let applied, .complete) = saved.outcome else {
      Issue.record("Hotel must be independently saved.")
      return
    }
    let source = try #require(applied.generated.first)
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let queryRequest = try request(
        endpoint: endpoint, name: "planner_query",
        arguments: ["formatVersion": 1, "query": ["kind": "items", "scope": ["kind": "global"]]])
      let original = try value(try await httpSession.data(for: queryRequest))
      #expect(original["matchingCount"] as? String == "1")
      let generation = try #require(original["generation"] as? String)
      let windowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "rows", "generation": generation, "offset": "0", "limit": "1",
          ],
        ])
      let firstWindow = try value(try await httpSession.data(for: windowRequest))
      #expect((firstWindow["rows"] as? [[String: Any]])?.first?["title"] as? String == "Hotel")
      let otherWriter = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let otherSession) = await otherWriter.bootstrap(),
        case .applied(_, .complete) = await otherWriter.execute(
          PlannerOperation(
            operationId: UUID(), session: otherSession,
            command: .setArchive(source: source, archived: true))
        ).outcome
      else {
        Issue.record("The other real facade must archive Hotel before rereading the window.")
        await listener.stop()
        return
      }
      let stale = try failure(try await httpSession.data(for: windowRequest))
      #expect(stale["code"] as? String == "staleSnapshot")
      #expect(stale["propertyPath"] is NSNull)
      let details = try #require(stale["details"] as? [String: Any])
      #expect(details["kind"] as? String == "staleSnapshot")
      #expect(details["requestedGeneration"] as? String == generation)
      #expect(details["currentGeneration"] is NSNull)
      let refreshed = try value(try await httpSession.data(for: queryRequest))
      #expect(refreshed["matchingCount"] as? String == "0")
      #expect((refreshed["rows"] as? [[String: Any]])?.isEmpty == true)
      await listener.stop()
      guard
        case .source(.item(let retained)) = await planner.read(
          session: datasetSession, request: .source(source))
      else {
        Issue.record("The stale-window rejection must retain the archived Item.")
        return
      }
      #expect(retained.content.notes == "Original notes")
      #expect(retained.state.archived == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func malformedRowRequestsLeaveTheValidDefaultGenerationReadable() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(configuration: storageConfiguration(directory))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize.")
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
      let queryRequest = try request(
        endpoint: endpoint, name: "planner_query",
        arguments: ["formatVersion": 1, "query": ["kind": "items", "scope": ["kind": "global"]]])
      let original = try value(try await httpSession.data(for: queryRequest))
      let generation = try #require(original["generation"] as? String)
      let context = try #require(original["rowPresentation"] as? [String: Any])
      #expect((context["referenceInstant"] as? Double)?.isFinite == true)
      #expect(TimeZone(identifier: try #require(context["displayTimeZone"] as? String)) != nil)
      let rejections: [(field: String, input: Any, code: String, path: String)] = [
        ("offset", 0, "invalidInput", "/request/offset"),
        ("offset", "00", "invalidInput", "/request/offset"),
        ("offset", "+1", "invalidInput", "/request/offset"),
        ("offset", "-1", "invalidInput", "/request/offset"),
        ("offset", "9223372036854775808", "invalidInput", "/request/offset"),
        ("limit", "0", "invalidInput", "/request/limit"),
        ("limit", "1.0", "invalidInput", "/request/limit"),
        ("generation", "invalid", "invalidInput", "/request/generation"),
        ("unexpected/~", true, "unknownField", "/request/unexpected~1~0"),
      ]
      for rejection in rejections {
        var fields: [String: Any] = [
          "kind": "rows", "generation": generation, "offset": "0", "limit": "1",
        ]
        fields[rejection.field] = rejection.input
        let invalidRequest = try request(
          endpoint: endpoint, name: "planner_read",
          arguments: ["formatVersion": 1, "request": fields])
        let reason = try failure(try await httpSession.data(for: invalidRequest))
        #expect(reason["code"] as? String == rejection.code)
        #expect(reason["propertyPath"] as? String == rejection.path)
      }
      let presentationRejections: [(input: [String: Any], code: String, path: String)] = [
        (
          ["referenceInstant": 813_198_600, "displayTimeZone": "Planner/Invalid"], "invalidInput",
          "/query/rowPresentation/displayTimeZone"
        ),
        (
          ["referenceInstant": "813198600", "displayTimeZone": "Asia/Tokyo"], "invalidInput",
          "/query/rowPresentation/referenceInstant"
        ),
        (
          ["referenceInstant": 813_198_600, "displayTimeZone": "Asia/Tokyo", "unexpected/~": true],
          "unknownField",
          "/query/rowPresentation/unexpected~1~0"
        ),
      ]
      for rejection in presentationRejections {
        let invalidRequest = try request(
          endpoint: endpoint, name: "planner_query",
          arguments: [
            "formatVersion": 1,
            "query": [
              "kind": "items", "scope": ["kind": "global"], "rowPresentation": rejection.input,
            ],
          ])
        let reason = try failure(try await httpSession.data(for: invalidRequest))
        #expect(reason["code"] as? String == rejection.code)
        #expect(reason["propertyPath"] as? String == rejection.path)
      }
      let windowRequest = try request(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "rows", "generation": generation, "offset": String(Int64.max),
            "limit": String(Int64.max),
          ],
        ])
      let window = try value(try await httpSession.data(for: windowRequest))
      #expect(window["generation"] as? String == generation)
      #expect(window["matchingCount"] as? String == "0")
      #expect((window["rows"] as? [[String: Any]])?.isEmpty == true)
      #expect(
        NSDictionary(dictionary: try #require(window["rowPresentation"] as? [String: Any])).isEqual(
          to: context))
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func storageConfiguration(_ directory: URL) -> PlannerStorageConfiguration {
    PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }

  private func failure(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    #expect(tool["isError"] as? Bool == true)
    let structured = try #require(tool["structuredContent"] as? [String: Any])
    #expect(structured["formatVersion"] as? Int == 1)
    #expect(structured["state"] as? String == "failed")
    #expect(structured["rows"] == nil)
    let reason = try #require(structured["reason"] as? [String: Any])
    let content = try #require(tool["content"] as? [[String: Any]])
    #expect(content.first?["text"] as? String == reason["message"] as? String)
    return reason
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
