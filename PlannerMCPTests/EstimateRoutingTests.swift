import Foundation
import PlannerCore
import Testing

@testable import Planner

struct EstimateRoutingTests {
  @Test func guardedEstimateEditOverHTTPPreservesExactMinutesAndStartOnlySchedule() async throws {
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
          content: PlannerItemContentInput(
            title: "Hotel", subtitle: "Stay near station", notes: "Original notes",
            estimate: PlannerEstimate(minutes: 91, displayUnit: .hour)))))
    guard case .applied(let creation, .complete) = created.outcome else {
      Issue.record("Hotel must be saved before the agent edits its estimate.")
      return
    }
    let source = try #require(creation.generated.first)
    let form = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
      planningTimeZone: "Asia/Tokyo")
    let scheduled = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createSchedule(source: source, form: form)))
    guard case .applied(let scheduleCreation, .complete) = scheduled.outcome else {
      Issue.record("A start-only appointment must exist independently of the estimate.")
      return
    }
    let schedule = try #require(scheduleCreation.generated.first)
    guard
      case .source(.item(let original)) = await planner.read(
        session: datasetSession, request: .source(source))
    else {
      Issue.record("The estimate guard must come from a public source read.")
      return
    }
    let originalHash = try #require(original.fieldHashes[.estimate])
    let operationIdentifier = UUID()
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let command: [String: Any] = [
        "type": "editItem", "sourceId": source.id.uuidString,
        "changes": ["estimate": ["minutes": "9007199254740993", "displayUnit": "year"]],
        "expectedFieldHashes": ["estimate": originalHash.value],
      ]
      let edit = try executionRequest(
        endpoint: endpoint, operationIdentifier: operationIdentifier, command: command)
      let edited = try operationValue(try await httpSession.data(for: edit), isError: false)
      #expect(edited["state"] as? String == "applied")
      #expect((edited["recovery"] as? [String: Any])?["checkpointGeneration"] as? String == "3")
      guard
        case .source(.item(let current)) = await planner.read(
          session: datasetSession, request: .source(source))
      else {
        Issue.record("The agent edit must update the shared Item.")
        await listener.stop()
        return
      }
      #expect(
        current.content.estimate
          == PlannerEstimate(minutes: 9_007_199_254_740_993, displayUnit: .year))
      #expect(current.content.title == "Hotel")
      #expect(current.content.subtitle == "Stay near station")
      #expect(current.content.notes == "Original notes")
      #expect(current.createdAt == original.createdAt)
      #expect(
        current.fieldHashes.filter { $0.key != .estimate }
          == original.fieldHashes.filter { $0.key != .estimate })
      let sourceRequest = try toolRequest(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "item", "id": source.id.uuidString]],
        ])
      let sourceValue = try operationValue(
        try await httpSession.data(for: sourceRequest), isError: false)
      let sourceContent = try #require(
        (sourceValue["value"] as? [String: Any])?["content"] as? [String: Any])
      #expect(
        sourceContent["estimate"] as? [String: String] == [
          "minutes": "9007199254740993", "displayUnit": "year",
        ])
      let staleRequest = try executionRequest(
        endpoint: endpoint, operationIdentifier: UUID(),
        command: [
          "type": "editItem", "sourceId": source.id.uuidString,
          "changes": [
            "title": "Must not apply", "estimate": ["minutes": "120", "displayUnit": "hour"],
          ],
          "expectedFieldHashes": [
            "title": try #require(original.fieldHashes[.title]).value,
            "estimate": originalHash.value,
          ],
        ])
      let stale = try operationValue(try await httpSession.data(for: staleRequest), isError: true)
      let reason = try #require(stale["reason"] as? [String: Any])
      #expect(reason["code"] as? String == "staleEdit")
      let details = try #require(reason["details"] as? [String: Any])
      #expect(details["conflictingFields"] as? [String] == ["estimate"])
      let values = try #require(details["currentValues"] as? [String: Any])
      let staleEstimate = try #require(values["estimate"] as? [String: String])
      #expect(staleEstimate == ["minutes": "9007199254740993", "displayUnit": "year"])
      #expect(
        (details["currentFieldHashes"] as? [String: String])?["estimate"]
          == current.fieldHashes[.estimate]?.value)
      let clear = try executionRequest(
        endpoint: endpoint, operationIdentifier: UUID(),
        command: [
          "type": "editItem", "sourceId": source.id.uuidString,
          "changes": ["estimate": NSNull()],
          "expectedFieldHashes": ["estimate": try #require(current.fieldHashes[.estimate]).value],
        ])
      let cleared = try operationValue(try await httpSession.data(for: clear), isError: false)
      #expect(cleared["state"] as? String == "applied")
      let replay = try operationValue(try await httpSession.data(for: edit), isError: false)
      #expect(NSDictionary(dictionary: replay).isEqual(to: edited))
      let clearReplay = try operationValue(
        try await httpSession.data(for: clear), isError: false)
      #expect(NSDictionary(dictionary: clearReplay).isEqual(to: cleared))
      let changedReplay = try executionRequest(
        endpoint: endpoint, operationIdentifier: operationIdentifier,
        command: [
          "type": "editItem", "sourceId": source.id.uuidString,
          "changes": ["estimate": ["minutes": "9007199254740993", "displayUnit": "month"]],
          "expectedFieldHashes": ["estimate": originalHash.value],
        ])
      let mismatch = try operationValue(
        try await httpSession.data(for: changedReplay), isError: true)
      #expect(
        (mismatch["reason"] as? [String: Any])?["code"] as? String == "operationPayloadMismatch")
      let staleClearedRequest = try executionRequest(
        endpoint: endpoint, operationIdentifier: UUID(),
        command: [
          "type": "editItem", "sourceId": source.id.uuidString,
          "changes": ["estimate": ["minutes": "60", "displayUnit": "hour"]],
          "expectedFieldHashes": ["estimate": try #require(current.fieldHashes[.estimate]).value],
        ])
      let staleCleared = try operationValue(
        try await httpSession.data(for: staleClearedRequest), isError: true)
      let clearedReason = try #require(staleCleared["reason"] as? [String: Any])
      #expect(clearedReason["code"] as? String == "staleEdit")
      let clearedDetails = try #require(clearedReason["details"] as? [String: Any])
      #expect((clearedDetails["currentValues"] as? [String: Any])?["estimate"] is NSNull)
      guard
        case .source(.item(let retained)) = await planner.read(
          session: datasetSession, request: .source(source)),
        case .source(.schedule(let retainedSchedule)) = await planner.read(
          session: datasetSession, request: .source(schedule))
      else {
        Issue.record("The shared Item and start-only appointment must remain readable.")
        await listener.stop()
        return
      }
      #expect(retained.content.estimate == nil)
      #expect(retained.content.title == "Hotel")
      #expect(retained.content.subtitle == "Stay near station")
      #expect(retained.content.notes == "Original notes")
      #expect(
        retained.fieldHashes.filter { $0.key != .estimate }
          == original.fieldHashes.filter { $0.key != .estimate })
      #expect(retainedSchedule.content.source == source)
      #expect(retainedSchedule.content.form == form)
      guard
        case .appliedRecoveryComplete(let saved, let checkpoint) = await planner.operationStatus(
          session: datasetSession, operationId: operationIdentifier)
      else {
        Issue.record("Replay must retain the original edit's recovery evidence.")
        await listener.stop()
        return
      }
      #expect(saved.affected == [source])
      #expect(checkpoint == 3)
      var catalogRequest = edit
      catalogRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": [:],
      ])
      let (catalogData, catalogResponse) = try await httpSession.data(for: catalogRequest)
      #expect((catalogResponse as? HTTPURLResponse)?.statusCode == 200)
      let catalog = try #require(JSONSerialization.jsonObject(with: catalogData) as? [String: Any])
      let tools = try #require((catalog["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let execution = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let properties = try #require(
        (execution["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let variants = try #require(
        (properties["command"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let itemEdit = try #require(
        variants.first {
          let fields = $0["properties"] as? [String: Any]
          return (fields?["type"] as? [String: Any])?["const"] as? String == "editItem"
        })
      let itemEditProperties = try #require(itemEdit["properties"] as? [String: Any])
      let changesSchema = try #require(itemEditProperties["changes"] as? [String: Any])
      let changeProperties = try #require(changesSchema["properties"] as? [String: Any])
      let estimateSchema = try #require(changeProperties["estimate"] as? [String: Any])
      #expect(estimateSchema["type"] as? [String] == ["object", "null"])
      #expect(estimateSchema["additionalProperties"] as? Bool == false)
      #expect(estimateSchema["required"] as? [String] == ["minutes", "displayUnit"])
      let estimateProperties = try #require(estimateSchema["properties"] as? [String: Any])
      #expect((estimateProperties["minutes"] as? [String: Any])?["type"] as? String == "string")
      #expect(
        (estimateProperties["minutes"] as? [String: Any])?["pattern"] as? String == "^[1-9][0-9]*$")
      #expect(
        (estimateProperties["displayUnit"] as? [String: Any])?["enum"] as? [String] == [
          "minute", "hour", "day", "week", "month", "year",
        ])
      #expect(changesSchema["additionalProperties"] as? Bool == false)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func invalidEstimateEditsOverHTTPRejectWholePatchWithoutSavingEvidence() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let creationIdentifier = UUID()
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: creationIdentifier, session: datasetSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Keep",
              estimate: PlannerEstimate(minutes: 91, displayUnit: .hour))))
      ).outcome,
      let source = creation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: datasetSession, request: .source(source))
    else {
      Issue.record("A saved Item and current hashes must exist before invalid requests.")
      return
    }
    let invalidEstimates: [(value: Any, code: String, path: String)] = [
      (true, "invalidInput", "/command/changes/estimate"),
      ([], "invalidInput", "/command/changes/estimate"),
      ("60", "invalidInput", "/command/changes/estimate"),
      (["displayUnit": "hour"], "invalidInput", "/command/changes/estimate/minutes"),
      (["minutes": "60"], "invalidInput", "/command/changes/estimate/displayUnit"),
      (
        ["minutes": "60", "displayUnit": "hour", "extra": true], "unknownField",
        "/command/changes/estimate/extra"
      ),
    ]
    let invalidMinutes: [Any] = [
      "0", "-1", "-9223372036854775808", "9223372036854775808", "18446744073709551615",
      "01", "+1", "1.0", "1.0000000000000001", "1e2", " 1", "1 ", "", "١", 60, true, NSNull(),
    ]
    let invalidUnits: [Any] = ["fortnight", "Hour", "", 1, true, NSNull()]
    var invalid = invalidEstimates
    invalid += invalidMinutes.map {
      (["minutes": $0, "displayUnit": "hour"], "invalidInput", "/command/changes/estimate/minutes")
    }
    invalid += invalidUnits.map {
      (
        ["minutes": "60", "displayUnit": $0], "invalidInput",
        "/command/changes/estimate/displayUnit"
      )
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let originalTitleHash = try #require(original.fieldHashes[.title]).value
      let originalEstimateHash = try #require(original.fieldHashes[.estimate]).value
      var commands = invalid.map { specimen in
        (
          [
            "type": "editItem", "sourceId": source.id.uuidString,
            "changes": ["title": "Must not apply", "estimate": specimen.value],
            "expectedFieldHashes": ["title": originalTitleHash, "estimate": originalEstimateHash],
          ] as [String: Any], specimen.code, specimen.path
        )
      }
      commands.append(
        (
          [
            "type": "editItem", "sourceId": source.id.uuidString,
            "changes": [
              "title": "Must not apply", "estimate": ["minutes": "60", "displayUnit": "hour"],
            ],
            "expectedFieldHashes": ["title": originalTitleHash],
          ], "invalidInput", "/command/expectedFieldHashes/estimate"
        ))
      for (command, code, path) in commands {
        let operationIdentifier = UUID()
        let request = try executionRequest(
          endpoint: endpoint, operationIdentifier: operationIdentifier, command: command)
        let rejected = try operationValue(try await httpSession.data(for: request), isError: true)
        #expect(rejected["state"] as? String == "rejected")
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == code)
        #expect(reason["propertyPath"] as? String == path)
        guard
          case .noReliableEvidence = await planner.operationStatus(
            session: datasetSession, operationId: operationIdentifier),
          case .source(.item(let current)) = await planner.read(
            session: datasetSession, request: .source(source))
        else {
          Issue.record("Invalid estimate edits must preserve the Item without an applied receipt.")
          await listener.stop()
          return
        }
        #expect(current.content.title == "Hotel")
        #expect(current.content.notes == "Keep")
        #expect(current.content.estimate == PlannerEstimate(minutes: 91, displayUnit: .hour))
        #expect(current.updatedAt == original.updatedAt)
        #expect(current.fieldHashes == original.fieldHashes)
      }
      guard
        case .appliedRecoveryComplete(_, let checkpoint) = await planner.operationStatus(
          session: datasetSession, operationId: creationIdentifier)
      else {
        Issue.record("Rejected requests must preserve the creation's original recovery evidence.")
        await listener.stop()
        return
      }
      #expect(checkpoint == 1)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test(arguments: [
    PlannerEstimate(minutes: 1, displayUnit: .minute),
    PlannerEstimate(minutes: 120, displayUnit: .hour),
    PlannerEstimate(minutes: 2_880, displayUnit: .day),
    PlannerEstimate(minutes: 10_080, displayUnit: .week),
    PlannerEstimate(minutes: 86_400, displayUnit: .month),
    PlannerEstimate(minutes: 525_600, displayUnit: .year),
    PlannerEstimate(minutes: Int64.max, displayUnit: .year),
  ])
  func estimateBoundsAndEveryDisplayUnitPersistExactlyOverHTTP(estimate: PlannerEstimate)
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
    guard case .ready(let datasetSession) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: datasetSession,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      ).outcome,
      let source = creation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: datasetSession, request: .source(source))
    else {
      Issue.record("A saved Item must exist before the exact estimate edit.")
      return
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let operationIdentifier = UUID()
      let request = try executionRequest(
        endpoint: endpoint, operationIdentifier: operationIdentifier,
        command: [
          "type": "editItem", "sourceId": source.id.uuidString,
          "changes": [
            "estimate": [
              "minutes": String(estimate.minutes), "displayUnit": estimate.displayUnit.rawValue,
            ]
          ],
          "expectedFieldHashes": ["estimate": try #require(original.fieldHashes[.estimate]).value],
        ])
      let applied = try operationValue(try await httpSession.data(for: request), isError: false)
      #expect(applied["state"] as? String == "applied")
      let sourceRequest = try toolRequest(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "item", "id": source.id.uuidString]],
        ])
      let read = try operationValue(try await httpSession.data(for: sourceRequest), isError: false)
      let content = try #require((read["value"] as? [String: Any])?["content"] as? [String: Any])
      #expect(
        content["estimate"] as? [String: String] == [
          "minutes": String(estimate.minutes), "displayUnit": estimate.displayUnit.rawValue,
        ])
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.item(let current)) = await reopened.read(
          session: reopenedSession, request: .source(source)),
        case .appliedRecoveryComplete(let saved, let checkpoint) = await reopened.operationStatus(
          session: reopenedSession, operationId: operationIdentifier)
      else {
        Issue.record(
          "Exact HTTP estimates must persist and retain original recovery evidence after reopen.")
        await listener.stop()
        return
      }
      #expect(current.content.estimate == estimate)
      #expect(current.content.notes == "Keep")
      #expect(saved.affected == [source])
      #expect(checkpoint == 2)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func executionRequest(
    endpoint: URL, operationIdentifier: UUID, command: [String: Any]
  ) throws -> URLRequest {
    try toolRequest(
      endpoint: endpoint, name: "planner_execute",
      arguments: [
        "formatVersion": 1, "operationId": operationIdentifier.uuidString, "command": command,
      ])
  }

  private func toolRequest(endpoint: URL, name: String, arguments: [String: Any]) throws
    -> URLRequest
  {
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
    let textValue = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textValue).isEqual(to: value))
    return value
  }
}
