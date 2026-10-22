import Foundation
import PlannerCore
import Testing

@testable import Planner

@MainActor
struct MapWindowRoutingTests {
  @Test func mapWindowsExposeSavedInputsAndExactContextOverHttp() async throws {
    let fixture = try makePlannerIntentStorage()
    let planner = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(
        .createItem(
          content: .init(
            title: "Museum", notes: "Private notes omitted from Map rows",
            location: .init(
              displayName: "Entrance", formattedAddress: "1 Museum Way",
              coordinate: .init(latitude: 35, longitude: 139)),
            links: [
              .init(originalUrl: "https://example.com/guide"),
              .init(originalUrl: "https://maps.apple.com/?q=Museum", label: "Entrance"),
            ]
          ))
      ).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    guard
      case .membership(let membership, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let entry, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let directEntry, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: item, placement: .last)
      ).generatedReferences.first,
      case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let backup) = planner.decodeImport(before)
    else { throw CancellationError() }
    let itemLifetime = try #require(backup.backup.items.first { $0.id == item.id }?.lifetimeId)
    let listLifetime = try #require(backup.backup.lists.first { $0.id == list.id }?.lifetimeId)
    let mapLink = try #require(backup.backup.ownedLinks.first { $0.kind == .appleMaps })
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      func exchange(_ method: String, parameters: [String: Any]) async throws
        -> [String: Any]
      {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: [
          "jsonrpc": "2.0", "id": 1,
          "method": method, "params": parameters,
        ])
        request.setValue(
          "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
        request.timeoutInterval = 5
        let (bytes, response) = try await httpSession.data(for: request)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let envelope = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        #expect(envelope["error"] == nil)
        return try #require(envelope["result"] as? [String: Any])
      }
      func call(_ name: String, _ arguments: [String: Any], isError: Bool = false) async throws
        -> [String: Any]
      {
        let result = try await exchange(
          "tools/call", parameters: ["name": name, "arguments": arguments])
        let structured = try #require(result["structuredContent"] as? [String: Any])
        try #require(
          result["isError"] as? Bool == isError,
          "Unexpected \(name) response: \(structured)")
        if !isError {
          let text = try #require(
            (result["content"] as? [[String: Any]])?.first?["text"] as? String)
          let encoded = try #require(
            JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
          #expect(NSDictionary(dictionary: encoded).isEqual(to: structured))
        }
        return structured
      }
      let advertised = try await exchange("tools/list", parameters: [:])
      let tools = try #require(advertised["tools"] as? [[String: Any]])
      let readTool = try #require(tools.first { $0["name"] as? String == "planner_read" })
      let schema = try JSONSerialization.data(withJSONObject: try #require(readTool["inputSchema"]))
      #expect(String(decoding: schema, as: UTF8.self).contains("\"mapRows\""))
      var retainedGeneration: String?
      for (scope, expectedPlacement): ([String: Any], [String: Any]?) in [
        (["kind": "global"], nil),
        (
          ["kind": "list", "listId": list.id.uuidString],
          ["kind": "listMembership", "membershipId": membership.uuidString, "childPosition": "1"]
        ),
        (
          ["kind": "itinerary", "itineraryId": itinerary.id.uuidString],
          [
            "kind": "itineraryListItem", "entryId": entry.uuidString, "routePosition": "1",
            "membershipId": membership.uuidString, "childPosition": "1",
            "list": [
              "source": ["kind": "list", "id": list.id.uuidString],
              "sourceLifetimeId": listLifetime.uuidString, "title": "Food",
            ],
          ]
        ),
      ] {
        let query = try await call(
          "planner_query",
          [
            "formatVersion": 1,
            "query": ["kind": "items", "scope": scope, "completion": "all", "archive": "all"],
          ])
        let generation = try #require(query["generation"] as? String)
        retainedGeneration = generation
        let page = try await call(
          "planner_read",
          [
            "formatVersion": 1,
            "request": ["kind": "mapRows", "generation": generation, "offset": "0", "limit": "1"],
          ])
        #expect(page["kind"] as? String == "mapRows" && page["formatVersion"] as? Int == 1)
        #expect(page["generation"] as? String == generation && page["offset"] as? String == "0")
        let expectedCount = scope["kind"] as? String == "itinerary" ? "2" : "1"
        #expect(page["matchingCount"] as? String == expectedCount)
        let rows = try #require(page["rows"] as? [[String: Any]])
        let row = try #require(rows.first)
        #expect(rows.count == 1 && row["title"] as? String == "Museum")
        #expect(row["sourceLifetimeId"] as? String == itemLifetime.uuidString)
        #expect(
          Set(row.keys) == [
            "identity", "sourceLifetimeId", "title", "ownedLocation", "mapsLinks", "placement",
          ])
        #expect(
          NSDictionary(dictionary: try #require(row["identity"] as? [String: Any])).isEqual(
            to: try #require((query["rows"] as? [[String: Any]])?.first)))
        #expect(
          NSDictionary(dictionary: try #require(row["ownedLocation"] as? [String: Any])).isEqual(
            to: [
              "displayName": "Entrance", "formattedAddress": "1 Museum Way",
              "coordinate": ["latitude": 35, "longitude": 139],
            ]))
        let links = try #require(row["mapsLinks"] as? [[String: Any]])
        #expect(links.count == 1)
        #expect(links.first?["linkId"] as? String == mapLink.id.uuidString)
        #expect(links.first?["originalUrl"] as? String == "https://maps.apple.com/?q=Museum")
        if let expectedPlacement {
          #expect(
            NSDictionary(dictionary: try #require(row["placement"] as? [String: Any])).isEqual(
              to: expectedPlacement))
          #expect(page["collection"] is [String: Any])
        } else {
          #expect(row["placement"] is NSNull && page["collection"] is NSNull)
        }
        let branches = try #require(page["listBranches"] as? [[String: Any]])
        if scope["kind"] as? String == "itinerary" {
          #expect(branches.count == 1 && branches.first?["entryId"] as? String == entry.uuidString)
          #expect(
            branches.first?["routePosition"] as? String == "1"
              && branches.first?["matchingChildCount"] as? String == "1")
          #expect(branches.first?["matchesHeader"] as? Bool == true)
          let directPage = try await call(
            "planner_read",
            [
              "formatVersion": 1,
              "request": [
                "kind": "mapRows", "generation": generation, "offset": "1", "limit": "1",
              ],
            ])
          let directRows = try #require(directPage["rows"] as? [[String: Any]])
          let direct = try #require(directRows.first)
          #expect(directRows.count == 1 && directPage["matchingCount"] as? String == "2")
          #expect(
            NSDictionary(dictionary: try #require(direct["placement"] as? [String: Any])).isEqual(
              to: [
                "kind": "itineraryItem", "entryId": directEntry.uuidString, "routePosition": "2",
              ]))
          #expect(
            NSDictionary(dictionary: try #require(direct["identity"] as? [String: Any])).isEqual(
              to: try #require((query["rows"] as? [[String: Any]])?.last)))
          #expect(Set(direct.keys) == Set(row.keys))
          let terminal = try await call(
            "planner_read",
            [
              "formatVersion": 1,
              "request": [
                "kind": "mapRows", "generation": generation, "offset": "2", "limit": "1",
              ],
            ])
          #expect((terminal["rows"] as? [[String: Any]])?.isEmpty == true)
          #expect((terminal["listBranches"] as? [[String: Any]])?.count == 1)
        } else {
          #expect(branches.isEmpty)
        }
      }
      let generation = try #require(retainedGeneration)
      for request: [String: Any] in [
        ["kind": "mapRows", "generation": generation, "offset": "-1", "limit": "1"],
        ["kind": "mapRows", "generation": generation, "offset": "0", "limit": "0"],
        ["kind": "mapRows", "generation": generation, "offset": 0, "limit": "1"],
        [
          "kind": "mapRows", "generation": generation, "offset": "0",
          "limit": "9223372036854775808",
        ],
        ["kind": "mapRows", "generation": generation, "offset": "0", "limit": "1", "extra": true],
      ] {
        let failure = try await call(
          "planner_read", ["formatVersion": 1, "request": request], isError: true)
        let expectedCode = request["extra"] == nil ? "invalidInput" : "unknownField"
        #expect((failure["reason"] as? [String: Any])?["code"] as? String == expectedCode)
      }
      let catalog = try await call(
        "planner_query",
        [
          "formatVersion": 1,
          "query": ["kind": "catalog", "sourceKind": "list", "archive": "all"],
        ])
      let catalogGeneration = try #require(catalog["generation"] as? String)
      let wrongKind = try await call(
        "planner_read",
        [
          "formatVersion": 1,
          "request": [
            "kind": "mapRows", "generation": catalogGeneration, "offset": "0", "limit": "1",
          ],
        ], isError: true)
      #expect((wrongKind["reason"] as? [String: Any])?["code"] as? String == "invalidInput")
      let unknown = try await call(
        "planner_read",
        [
          "formatVersion": 1,
          "request": [
            "kind": "mapRows", "generation": UUID().uuidString, "offset": "0", "limit": "1",
          ],
        ], isError: true)
      #expect((unknown["reason"] as? [String: Any])?["code"] as? String == "staleSnapshot")
      guard case .exported(let after) = await planner.exportData(session: session) else {
        throw CancellationError()
      }
      #expect(before == after)
      _ = try await save(.setArchive(source: item, archived: true))
      let stale = try await call(
        "planner_read",
        [
          "formatVersion": 1,
          "request": ["kind": "mapRows", "generation": generation, "offset": "0", "limit": "1"],
        ], isError: true)
      #expect((stale["reason"] as? [String: Any])?["code"] as? String == "staleSnapshot")
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }
}
