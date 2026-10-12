import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ManualContainerEstimateRoutingTests {
  @Test func manualAndNestedBudgetReadsOverHTTPExposeUpperBoundsAndFinishedZero() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
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
    let museum = try #require(
      try await save(
        .createItem(
          content: .init(title: "Museum", estimate: .init(minutes: 120, displayUnit: .hour)))
      ).generated.first)
    let lunch = try #require(
      try await save(.createItem(content: .init(title: "Lunch"))).generated.first)
    let hotel = try #require(
      try await save(
        .createItem(
          content: .init(title: "Hotel", estimate: .init(minutes: 30, displayUnit: .minute)))
      ).generated.first)
    let list = try #require(
      try await save(
        .createList(
          content: .init(name: "Morning", manualEstimate: .init(minutes: 240, displayUnit: .hour)))
      ).generated.first)
    var membershipIdentifiers: [UUID] = []
    for item in [museum, lunch] {
      guard
        case .membership(let identifier, _, _) = try #require(
          try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
            .generatedReferences.first)
      else { throw CancellationError() }
      membershipIdentifiers.append(identifier)
    }
    _ = try await save(.setArchive(source: lunch, archived: true))
    let itinerary = try #require(
      try await save(
        .createItinerary(
          content: .init(title: "Day", manualEstimate: .init(minutes: 300, displayUnit: .hour)))
      ).generated.first)
    guard
      case .itineraryEntry(let listEntry, _, _) = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
        ).generatedReferences.first),
      case .itineraryEntry(let hotelEntry, _, _) = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: hotel, placement: .last)
        ).generatedReferences.first)
    else { throw CancellationError() }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    func estimates(_ source: PlannerEntityReference) async throws -> [String: Any] {
      let request = try toolRequest(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "source", "source": ["kind": source.kind.rawValue, "id": source.id.uuidString],
          ],
        ])
      let response = try operationValue(try await httpSession.data(for: request), isError: false)
      return try #require((response["value"] as? [String: Any])?["estimates"] as? [String: Any])
    }
    do {
      let standalone = try await estimates(list)
      #expect(
        standalone["fullEstimate"] as? [String: String] == ["kind": "exact", "minutes": "240"])
      #expect(
        standalone["remainingEstimate"] as? [String: String] == [
          "kind": "upperBound", "minutes": "240", "missingFinishedEstimateCount": "1",
        ])
      let nested = try await estimates(itinerary)
      #expect(
        nested["calculatedEstimate"] as? [String: String] == ["kind": "exact", "minutes": "270"])
      #expect(nested["fullEstimate"] as? [String: String] == ["kind": "exact", "minutes": "300"])
      #expect(
        nested["remainingEstimate"] as? [String: String] == [
          "kind": "upperBound", "minutes": "300", "missingFinishedEstimateCount": "1",
        ])
      _ = try await save(
        .setCompletion(
          scope: .appearance(
            .expandedListItem(
              itineraryId: itinerary.id, listEntryId: listEntry,
              membershipId: membershipIdentifiers[0])), done: true))
      let finishedBranch = try await estimates(itinerary)
      #expect(
        finishedBranch["remainingEstimate"] as? [String: String] == [
          "kind": "exact", "minutes": "60",
        ])
      _ = try await save(
        .setCompletion(
          scope: .appearance(.directItineraryItem(itineraryId: itinerary.id, entryId: hotelEntry)),
          done: true))
      let finished = try await estimates(itinerary)
      #expect(finished["fullEstimate"] as? [String: String] == ["kind": "exact", "minutes": "300"])
      #expect(
        finished["remainingEstimate"] as? [String: String] == ["kind": "exact", "minutes": "0"])
      #expect(finished["completedExceedsTotal"] as? Bool == false)
      let unchangedStandalone = try await estimates(list)
      #expect(
        unchangedStandalone["remainingEstimate"] as? [String: String] == [
          "kind": "upperBound", "minutes": "240", "missingFinishedEstimateCount": "1",
        ])
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test(arguments: [PlannerEntityKind.list, .itinerary])
  func manualEstimatesCreateEditClearAndReportStaleValuesOverHTTP(kind: PlannerEntityKind)
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
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: datasetSession))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let creationType = kind == .list ? "createList" : "createItinerary"
      let editType = kind == .list ? "editList" : "editItinerary"
      let nameField = kind == .list ? "name" : "title"
      let creation = try executionRequest(
        endpoint: endpoint, operationIdentifier: UUID(),
        command: [
          "type": creationType,
          "content": [
            nameField: "Plan", "notes": "Keep",
            "manualEstimate": ["minutes": "240", "displayUnit": "hour"],
          ],
        ])
      let appliedCreation = try operationValue(
        try await httpSession.data(for: creation), isError: false)
      let generated = try #require(
        (appliedCreation["result"] as? [String: Any])?["generated"] as? [[String: Any]])
      let identifier = try #require(generated.first?["id"] as? String)
      let source = PlannerEntityReference(
        kind: kind, id: try #require(UUID(uuidString: identifier)))
      let readRequest = try toolRequest(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": kind.rawValue, "id": identifier]],
        ])
      let original = try operationValue(
        try await httpSession.data(for: readRequest), isError: false)
      let originalValue = try #require(original["value"] as? [String: Any])
      let originalContent = try #require(originalValue["content"] as? [String: Any])
      #expect(
        originalContent["manualEstimate"] as? [String: String] == [
          "minutes": "240", "displayUnit": "hour",
        ])
      let originalHashes = try #require(originalValue["fieldHashes"] as? [String: String])
      let originalHash = try #require(originalHashes["manualEstimate"])
      let editedEstimate = ["minutes": "9007199254740993", "displayUnit": "year"]
      let edit = try executionRequest(
        endpoint: endpoint, operationIdentifier: UUID(),
        command: [
          "type": editType, "sourceId": identifier,
          "changes": ["manualEstimate": editedEstimate],
          "expectedFieldHashes": ["manualEstimate": originalHash],
        ])
      let edited = try operationValue(try await httpSession.data(for: edit), isError: false)
      #expect(edited["state"] as? String == "applied")
      let current = try operationValue(try await httpSession.data(for: readRequest), isError: false)
      let currentValue = try #require(current["value"] as? [String: Any])
      let currentContent = try #require(currentValue["content"] as? [String: Any])
      #expect(currentContent["manualEstimate"] as? [String: String] == editedEstimate)
      #expect(currentContent["notes"] as? String == "Keep")
      let currentHashes = try #require(currentValue["fieldHashes"] as? [String: String])
      #expect(
        currentHashes.filter { $0.key != "manualEstimate" }
          == originalHashes.filter { $0.key != "manualEstimate" })
      let stale = try executionRequest(
        endpoint: endpoint, operationIdentifier: UUID(),
        command: [
          "type": editType, "sourceId": identifier,
          "changes": ["notes": "Must not apply", "manualEstimate": NSNull()],
          "expectedFieldHashes": [
            "notes": try #require(originalHashes["notes"]), "manualEstimate": originalHash,
          ],
        ])
      let rejected = try operationValue(try await httpSession.data(for: stale), isError: true)
      let reason = try #require(rejected["reason"] as? [String: Any])
      #expect(reason["code"] as? String == "staleEdit")
      let details = try #require(reason["details"] as? [String: Any])
      #expect(details["conflictingFields"] as? [String] == ["manualEstimate"])
      #expect(
        (details["currentValues"] as? [String: Any])?["manualEstimate"] as? [String: String]
          == editedEstimate)
      #expect(
        (details["currentFieldHashes"] as? [String: String])?["manualEstimate"]
          == currentHashes["manualEstimate"])
      let invalid = try executionRequest(
        endpoint: endpoint, operationIdentifier: UUID(),
        command: [
          "type": editType, "sourceId": identifier,
          "changes": [
            "notes": "Must not apply", "manualEstimate": ["minutes": "0", "displayUnit": "hour"],
          ],
          "expectedFieldHashes": currentHashes,
        ])
      let invalidResult = try operationValue(
        try await httpSession.data(for: invalid), isError: true)
      #expect(
        (invalidResult["reason"] as? [String: Any])?["propertyPath"] as? String
          == "/command/changes/manualEstimate/minutes")
      let clear = try executionRequest(
        endpoint: endpoint, operationIdentifier: UUID(),
        command: [
          "type": editType, "sourceId": identifier, "changes": ["manualEstimate": NSNull()],
          "expectedFieldHashes": ["manualEstimate": try #require(currentHashes["manualEstimate"])],
        ])
      let cleared = try operationValue(try await httpSession.data(for: clear), isError: false)
      #expect(cleared["state"] as? String == "applied")
      let replay = try operationValue(try await httpSession.data(for: edit), isError: false)
      #expect(NSDictionary(dictionary: replay).isEqual(to: edited))
      let finalRead = try operationValue(
        try await httpSession.data(for: readRequest), isError: false)
      let finalContent = try #require(
        (finalRead["value"] as? [String: Any])?["content"] as? [String: Any])
      #expect(finalContent["manualEstimate"] is NSNull)
      #expect(finalContent["notes"] as? String == "Keep")
      let reopened = PlannerCore.Planner(configuration: configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
        throw CancellationError()
      }
      switch await reopened.read(session: reopenedSession, request: .source(source)) {
      case .source(.list(let read)):
        #expect(read.content.manualEstimate == nil)
        #expect(read.content.notes == "Keep")
      case .source(.itinerary(let read)):
        #expect(read.content.manualEstimate == nil)
        #expect(read.content.notes == "Keep")
      default: Issue.record("The HTTP edit must persist through public Core reopening.")
      }
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
