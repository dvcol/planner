import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItemChronologicalSortRoutingTests {
  @Test func advertisedChronologicalSortsOverHTTPDistinguishItemEditsFromListOrganization()
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
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize before chronological HTTP queries.")
      return
    }
    var sources: [PlannerEntityReference] = []
    for title in ["Zulu", "Alpha", "Middle"] {
      guard
        case .applied(let creation, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createItem(content: .init(title: title)))
        ).outcome,
        let source = creation.generated.first
      else {
        Issue.record("Each fixture Item must save with complete recovery evidence.")
        return
      }
      sources.append(source)
    }
    let first = try await item(sources[0], planner: planner, session: session)
    let second = try await item(sources[1], planner: planner, session: session)
    let third = try await item(sources[2], planner: planner, session: session)
    try #require(first.createdAt < second.createdAt)
    try #require(second.createdAt < third.createdAt)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: sources[0].id, changes: .init(notes: .set("Later Item edit")),
            expectedFieldHashes: [.notes: try #require(first.fieldHashes[.notes])]))
      ).outcome
    else {
      Issue.record("The guarded content edit must save before date queries.")
      return
    }
    let edited = try await item(sources[0], planner: planner, session: session)
    try #require(edited.updatedAt > third.updatedAt)
    let originals = [edited, second, third]
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      var catalogRequest = try toolRequest(
        endpoint: endpoint, name: "planner_query", arguments: [:])
      catalogRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": [:],
      ])
      let (catalogData, catalogResponse) = try await httpSession.data(for: catalogRequest)
      #expect((catalogResponse as? HTTPURLResponse)?.statusCode == 200)
      let catalog = try #require(JSONSerialization.jsonObject(with: catalogData) as? [String: Any])
      let tools = try #require((catalog["result"] as? [String: Any])?["tools"] as? [[String: Any]])
      let queryTool = try #require(tools.first { $0["name"] as? String == "planner_query" })
      let properties = try #require(
        (queryTool["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let variants = try #require(
        (properties["query"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let itemSchema = try #require(
        variants.first {
          let fields = $0["properties"] as? [String: Any]
          return (fields?["kind"] as? [String: Any])?["const"] as? String == "items"
        })
      let itemProperties = try #require(itemSchema["properties"] as? [String: Any])
      let sort = try #require(itemProperties["sort"] as? [String: Any])
      #expect(sort["additionalProperties"] as? Bool == false)
      let sortProperties = try #require(sort["properties"] as? [String: Any])
      #expect(
        (sortProperties["mode"] as? [String: Any])?["enum"] as? [String] == [
          "title", "created", "lastUpdated", "duration", "manual",
        ])
      let cases: [(mode: String, direction: String, indices: [Int])] = [
        ("created", "ascending", [0, 1, 2]),
        ("created", "descending", [2, 1, 0]),
        ("lastUpdated", "ascending", [1, 2, 0]),
        ("lastUpdated", "descending", [0, 2, 1]),
      ]
      for scope in ["global", "inbox"] {
        for example in cases {
          let sorted = try await query(
            [
              "kind": "items", "scope": ["kind": scope],
              "sort": ["mode": example.mode, "direction": example.direction],
            ], endpoint: endpoint, httpSession: httpSession)
          #expect(sorted["matchingCount"] as? String == "3")
          #expect(
            try sourceIdentifiers(sorted) == example.indices.map { sources[$0].id.uuidString })
        }
      }
      guard
        case .applied(let creation, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createList(content: .init(name: "Tokyo")))
        ).outcome,
        let list = creation.generated.first
      else {
        Issue.record("The contextual fixture List must save.")
        await listener.stop()
        return
      }
      let manualIndices = [2, 0, 1]
      var membershipIdentifiers: [Int: UUID] = [:]
      for index in manualIndices {
        guard
          case .applied(let addition, .complete) = await planner.execute(
            PlannerOperation(
              operationId: UUID(), session: session,
              command: .addMembership(itemId: sources[index].id, listId: list.id, placement: .last))
          ).outcome,
          case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
        else {
          Issue.record("Every shared Item must have its exact saved Manual appearance.")
          await listener.stop()
          return
        }
        membershipIdentifiers[index] = membershipIdentifier
      }
      let completedAppearance = PlannerAppearance.listMembership(
        listId: list.id, membershipId: try #require(membershipIdentifiers[0]))
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .setCompletion(scope: .appearance(completedAppearance), done: true))
        ).outcome,
        case .source(.list(let originalList)) = await planner.read(
          session: session, request: .source(list))
      else {
        Issue.record("Local completion and saved order must be publicly readable.")
        await listener.stop()
        return
      }
      for example in cases {
        let sorted = try await query(
          [
            "kind": "items", "scope": ["kind": "list", "listId": list.id.uuidString],
            "completion": "all", "archive": "all",
            "sort": ["mode": example.mode, "direction": example.direction],
          ], endpoint: endpoint, httpSession: httpSession)
        #expect(sorted["matchingCount"] as? String == "3")
        #expect(try sourceIdentifiers(sorted) == example.indices.map { sources[$0].id.uuidString })
        let rows = try #require(sorted["rows"] as? [[String: Any]])
        let expectedMemberships = try example.indices.map {
          try #require(membershipIdentifiers[$0]).uuidString
        }
        #expect(
          rows.compactMap { ($0["appearance"] as? [String: String])?["membershipId"] }
            == expectedMemberships)
        let progress = try #require((sorted["progress"] as? [[String: Any]])?.first)
        #expect(progress["doneCount"] as? String == "1")
        #expect(progress["totalCount"] as? String == "3")
        let generation = try #require(sorted["generation"] as? String)
        let readRequest = try toolRequest(
          endpoint: endpoint, name: "planner_read",
          arguments: [
            "formatVersion": 1,
            "request": ["kind": "rows", "generation": generation, "offset": "1", "limit": "1"],
          ])
        let window = try toolValue(try await httpSession.data(for: readRequest))
        let windowRows = try #require(window["rows"] as? [[String: Any]])
        #expect(window["matchingCount"] as? String == "3")
        #expect(
          windowRows.first?["title"] as? String == originals[example.indices[1]].content.title)
      }
      let manual = try await query(
        [
          "kind": "items", "scope": ["kind": "list", "listId": list.id.uuidString],
          "completion": "all", "archive": "all",
          "sort": ["mode": "manual", "direction": "ascending"],
        ], endpoint: endpoint, httpSession: httpSession)
      #expect(try sourceIdentifiers(manual) == manualIndices.map { sources[$0].id.uuidString })
      guard
        case .source(.list(let currentList)) = await planner.read(
          session: session, request: .source(list)),
        case .appearance(let completed) = await planner.read(
          session: session, request: .appearance(completedAppearance))
      else {
        Issue.record("Sorting must retain saved order and the selected local completion scope.")
        await listener.stop()
        return
      }
      #expect(currentList.references == originalList.references)
      #expect(currentList.updatedAt == originalList.updatedAt)
      #expect(currentList.fieldHashes == originalList.fieldHashes)
      #expect(completed.localDone)
      #expect(completed.effectiveDone)
      #expect(completed.globalDone == false)
      for index in 0..<3 {
        let current = try await item(sources[index], planner: planner, session: session)
        #expect(current.createdAt == originals[index].createdAt)
        #expect(current.updatedAt == originals[index].updatedAt)
        #expect(current.fieldHashes == originals[index].fieldHashes)
        #expect(current.state.globalDone == false)
      }
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func item(
    _ source: PlannerEntityReference, planner: PlannerCore.Planner, session: PlannerDatasetSession
  ) async throws -> PlannerItemSourceRead {
    guard
      case .source(.item(let value)) = await planner.read(
        session: session, request: .source(source))
    else {
      Issue.record("The fixture Item must be readable through the public source seam.")
      throw FixtureFailure()
    }
    return value
  }

  private func query(_ query: [String: Any], endpoint: URL, httpSession: URLSession)
    async throws -> [String: Any]
  {
    let request = try toolRequest(
      endpoint: endpoint, name: "planner_query", arguments: ["formatVersion": 1, "query": query])
    return try toolValue(try await httpSession.data(for: request))
  }

  private func sourceIdentifiers(_ result: [String: Any]) throws -> [String] {
    let rows = try #require(result["rows"] as? [[String: Any]])
    return rows.compactMap { ($0["source"] as? [String: String])?["id"] }
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

  private func toolValue(_ exchange: (Data, URLResponse)) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    try #require(tool["isError"] as? Bool == false)
    let value = try #require(tool["structuredContent"] as? [String: Any])
    let content = try #require(tool["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let textValue = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: textValue).isEqual(to: value))
    return value
  }

  private struct FixtureFailure: Error {}
}
