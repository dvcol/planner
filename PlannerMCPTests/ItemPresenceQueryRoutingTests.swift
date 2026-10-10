import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItemPresenceQueryRoutingTests {
  @Test func ownedAddressAndLinkFiltersOverHTTPPreserveContextualRowsAndProgress() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Initialize the real store before HTTP presence queries.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let result, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = result.generated.first
      else {
        Issue.record("Save each HTTP fixture through public durable Core commands.")
        throw CancellationError()
      }
      return source
    }
    let category = try await create(.createCategory(content: .init(name: "Travel")))
    let tag = try await create(.createTag(content: .init(name: "Rain")))
    let list = try await create(.createList(content: .init(name: "Stops")))
    let inputs = [
      PlannerItemContentInput(
        title: "A Hotel",
        location: .init(displayName: nil, formattedAddress: "Tokyo", coordinate: nil),
        estimate: .init(minutes: 120, displayUnit: .hour),
        links: [.init(originalUrl: "https://example.com/hotel")],
        categoryIds: [category.id], tagIds: [tag.id]),
      PlannerItemContentInput(
        title: "B Maps",
        location: .init(
          displayName: "Meeting point", formattedAddress: nil,
          coordinate: .init(latitude: 35, longitude: 139)),
        links: [.init(originalUrl: "https://maps.apple.com/?q=Tokyo")]),
      PlannerItemContentInput(
        title: "C Blank",
        location: .init(displayName: nil, formattedAddress: " \t", coordinate: nil)),
      PlannerItemContentInput(
        title: "D Inbox",
        location: .init(displayName: nil, formattedAddress: "Paris", coordinate: nil)),
    ]
    var sources: [PlannerEntityReference] = []
    var memberships: [UUID] = []
    for (index, input) in inputs.enumerated() {
      let item = try await create(.createItem(content: input))
      sources.append(item)
      if index == 3 { continue }
      guard
        case .applied(let addition, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let identifier, _, _)? = addition.generatedReferences.first
      else {
        Issue.record("Presence filters must retain exact live List appearances.")
        return
      }
      memberships.append(identifier)
    }
    for command: PlannerCommand in [
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: memberships[0])),
        done: true),
      .setArchive(source: sources[1], archived: true),
    ] {
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome
      else {
        Issue.record("Save independent completion/archive states before HTTP filtering.")
        return
      }
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      func query(_ fields: [String: Any]) async throws -> [String: Any] {
        try toolValue(
          try await httpSession.data(
            for: request(
              endpoint: endpoint, name: "planner_query",
              arguments: ["formatVersion": 1, "query": fields])))
      }
      let global: [String: Any] = [
        "kind": "items", "scope": ["kind": "global"], "completion": "all", "archive": "all",
      ]
      let examples: [([String: Any], [Int])] = [
        ([:], [0, 1, 2, 3]),
        (["hasAddress": true], [0, 3]),
        (["hasLinks": true], [0, 1]),
        (["hasAddress": true, "hasLinks": true], [0]),
        (["hasAddress": false, "hasLinks": false], [0, 1, 2, 3]),
        (["scope": ["kind": "inbox"], "hasAddress": true], [3]),
        (["scope": ["kind": "inbox"], "hasLinks": true], []),
        (
          [
            "text": "HOTEL", "categories": ["ids": [category.id.uuidString]],
            "tags": ["ids": [tag.id.uuidString]], "lists": ["ids": [list.id.uuidString]],
            "duration": [
              "minimumMinutes": "120", "maximumMinutes": "120", "includeUnknown": false,
            ],
            "hasAddress": true, "hasLinks": true,
          ], [0]
        ),
      ]
      for (overrides, expectedIndices) in examples {
        let snapshot = try await query(global.merging(overrides) { _, incoming in incoming })
        #expect(snapshot["matchingCount"] as? String == String(expectedIndices.count))
        let rows = try #require(snapshot["rows"] as? [[String: Any]])
        #expect(
          rows.compactMap { ($0["source"] as? [String: String])?["id"] }
            == expectedIndices.map { sources[$0].id.uuidString })
        #expect(rows.allSatisfy { $0["kind"] as? String == "source" })
      }
      let listQuery: [String: Any] = [
        "kind": "items", "scope": ["kind": "list", "listId": list.id.uuidString],
        "hasAddress": true, "hasLinks": true, "sort": ["mode": "manual", "direction": "ascending"],
      ]
      let ordinary = try await query(listQuery)
      #expect(ordinary["matchingCount"] as? String == "0")
      #expect((ordinary["rows"] as? [[String: Any]])?.isEmpty == true)
      let done = try await query(
        listQuery.merging(["completion": "done"]) { _, incoming in incoming })
      let allLinks = try await query(
        listQuery.merging(["completion": "all", "archive": "all", "hasAddress": false]) {
          _, incoming in incoming
        })
      #expect(done["matchingCount"] as? String == "1")
      #expect(allLinks["matchingCount"] as? String == "2")
      let linkRows = try #require(allLinks["rows"] as? [[String: Any]])
      #expect(
        linkRows.compactMap { ($0["appearance"] as? [String: String])?["membershipId"] }
          == [memberships[0].uuidString, memberships[1].uuidString])
      for snapshot in [ordinary, done, allLinks] {
        let progress = try #require((snapshot["progress"] as? [[String: Any]])?.first)
        #expect(progress["doneCount"] as? String == "1")
        #expect(progress["totalCount"] as? String == "3")
      }
      let generation = try #require(allLinks["generation"] as? String)
      let window = try toolValue(
        try await httpSession.data(
          for: request(
            endpoint: endpoint, name: "planner_read",
            arguments: [
              "formatVersion": 1,
              "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "2"],
            ])))
      let hydrated = try #require(window["rows"] as? [[String: Any]])
      #expect(hydrated.count == 2)
      let hotel = try #require(hydrated.first)
      let map = try #require(hydrated.last)
      #expect(hotel["globalDone"] as? Bool == false)
      #expect(hotel["localDone"] as? Bool == true)
      #expect(hotel["effectiveDone"] as? Bool == true)
      #expect((hotel["ownedLocation"] as? [String: Any])?["formattedAddress"] as? String == "Tokyo")
      #expect(
        (hotel["previewLink"] as? [String: Any])?["originalUrl"] as? String
          == "https://example.com/hotel")
      #expect(map["archived"] as? Bool == true)
      #expect(map["hasLocation"] as? Bool == true)
      #expect(map["hasLinks"] as? Bool == true)
      #expect(map["previewLink"] is NSNull)
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Read-only HTTP filters leave independent recovery unchanged.")
        await listener.stop()
        return
      }
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 12)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func request(endpoint: URL, name: String, arguments: [String: Any]) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 1,
      "method": "tools/call", "params": ["name": name, "arguments": arguments],
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
    let decodedText = try #require(
      JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: decodedText).isEqual(to: value))
    return value
  }
}
