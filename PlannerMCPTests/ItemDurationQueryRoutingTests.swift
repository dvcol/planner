import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItemDurationQueryRoutingTests {
  @Test func durationSchemaAndAdmissionOverHTTPPreserveExactIntegersAndRejectInvalidGroups()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = planner(at: directory)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real Planner dataset must initialize.")
      return
    }
    var sources: [PlannerEntityReference] = []
    for content in [
      PlannerItemContentInput(
        title: "Lower neighbor",
        estimate: PlannerEstimate(minutes: 9_007_199_254_740_992, displayUnit: .year)),
      PlannerItemContentInput(
        title: "Upper neighbor",
        estimate: PlannerEstimate(minutes: 9_007_199_254_740_993, displayUnit: .year)),
      PlannerItemContentInput(
        title: "Maximum", estimate: PlannerEstimate(minutes: Int64.max, displayUnit: .year)),
      PlannerItemContentInput(title: "Unknown"),
    ] {
      sources.append(try await createItem(content, planner: planner, session: session))
    }
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(sources[1]))
    else {
      Issue.record("The source must be publicly readable before agent filtering.")
      return
    }
    let listener = listener(planner: planner, session: session)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let issued = try await query(
        ["kind": "items", "scope": ["kind": "global"]],
        endpoint: endpoint, httpSession: httpSession)
      let generation = try #require(issued["generation"] as? String)
      let rowRequest = try toolRequest(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "4"],
        ])
      let originalWindow = try toolValue(
        try await httpSession.data(for: rowRequest), isError: false)
      let cases: [(minimum: Any, maximum: Any, includeUnknown: Bool, indices: [Int])] = [
        (NSNull(), "9007199254740992", false, [0]),
        ("9007199254740993", "9007199254740993", false, [1]),
        ("9223372036854775807", "9223372036854775807", false, [2]),
        (NSNull(), "0", false, []),
        (NSNull(), "0", true, [3]),
        ("0", NSNull(), false, [0, 2, 1]),
        ("0", NSNull(), true, [0, 2, 3, 1]),
      ]
      for example in cases {
        let result = try await query(
          [
            "kind": "items", "scope": ["kind": "global"],
            "duration": [
              "minimumMinutes": example.minimum, "maximumMinutes": example.maximum,
              "includeUnknown": example.includeUnknown,
            ],
          ], endpoint: endpoint, httpSession: httpSession)
        #expect(result["matchingCount"] as? String == String(example.indices.count))
        #expect(try sourceIdentifiers(result) == example.indices.map { sources[$0].id.uuidString })
      }
      var invalidCases: [(duration: Any, code: String, path: String)] = []
      for group: Any in [true, 120, "120", []] {
        invalidCases.append((group, "invalidInput", "/query/duration"))
      }
      let invalidBounds: [Any] = [
        true, 120, "", "01", "+1", "-1", " 1", "1.0", "1e2", "9223372036854775808", [], [:],
      ]
      for field in ["minimumMinutes", "maximumMinutes"] {
        for invalid in invalidBounds {
          var duration: [String: Any] = [
            "minimumMinutes": NSNull(), "maximumMinutes": NSNull(), "includeUnknown": false,
          ]
          duration[field] = invalid
          invalidCases.append((duration, "invalidInput", "/query/duration/" + field))
        }
      }
      for field in ["minimumMinutes", "maximumMinutes", "includeUnknown"] {
        var duration: [String: Any] = [
          "minimumMinutes": NSNull(), "maximumMinutes": NSNull(), "includeUnknown": false,
        ]
        duration.removeValue(forKey: field)
        invalidCases.append((duration, "invalidInput", "/query/duration/" + field))
      }
      for invalid: Any in [NSNull(), "true", 1, [], [:]] {
        invalidCases.append(
          (
            ["minimumMinutes": NSNull(), "maximumMinutes": NSNull(), "includeUnknown": invalid],
            "invalidInput", "/query/duration/includeUnknown"
          ))
      }
      invalidCases.append(
        (
          ["minimumMinutes": "121", "maximumMinutes": "120", "includeUnknown": false],
          "invalidInput", "/query/duration"
        ))
      invalidCases.append(
        (
          [
            "minimumMinutes": NSNull(), "maximumMinutes": NSNull(), "includeUnknown": false,
            "extra/key~": true,
          ], "unknownField", "/query/duration/extra~1key~0"
        ))
      #expect(invalidCases.count == 38)
      for example in invalidCases {
        let rejected = try await query(
          ["kind": "items", "scope": ["kind": "global"], "duration": example.duration],
          endpoint: endpoint, httpSession: httpSession, isError: true)
        #expect(rejected["state"] as? String == "failed")
        #expect(rejected["generation"] == nil)
        #expect(rejected["rows"] == nil)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == example.code)
        #expect(reason["propertyPath"] as? String == example.path)
      }
      let retainedWindow = try toolValue(
        try await httpSession.data(for: rowRequest), isError: false)
      #expect(NSDictionary(dictionary: retainedWindow).isEqual(to: originalWindow))
      var catalogRequest = rowRequest
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
      #expect(itemSchema["additionalProperties"] as? Bool == false)
      #expect((itemSchema["required"] as? [String])?.contains("duration") == false)
      let itemProperties = try #require(itemSchema["properties"] as? [String: Any])
      let durationVariants = try #require(
        (itemProperties["duration"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      #expect(durationVariants.count == 2)
      #expect(durationVariants.contains { $0["type"] as? String == "null" })
      let durationSchema = try #require(
        durationVariants.first { $0["type"] as? String == "object" })
      #expect(durationSchema["additionalProperties"] as? Bool == false)
      #expect(
        Set(try #require(durationSchema["required"] as? [String])) == [
          "minimumMinutes", "maximumMinutes", "includeUnknown",
        ])
      let fields = try #require(durationSchema["properties"] as? [String: Any])
      #expect(Set(fields.keys) == ["minimumMinutes", "maximumMinutes", "includeUnknown"])
      #expect((fields["includeUnknown"] as? [String: Any])?["type"] as? String == "boolean")
      for field in ["minimumMinutes", "maximumMinutes"] {
        let bound = try #require(fields[field] as? [String: Any])
        #expect(Set(try #require(bound["type"] as? [String])) == ["string", "null"])
        #expect(bound["pattern"] as? String == "^(0|[1-9][0-9]*)$")
      }
      guard
        case .source(.item(let current)) = await planner.read(
          session: session, request: .source(sources[1]))
      else {
        Issue.record("All rejected and successful queries must preserve the source.")
        await listener.stop()
        return
      }
      #expect(current.content.estimate == original.content.estimate)
      #expect(current.content.estimate?.minutes == 9_007_199_254_740_993)
      #expect(current.content.estimate?.displayUnit == .year)
      #expect(current.fieldHashes == original.fieldHashes)
      #expect(current.updatedAt == original.updatedAt)
      #expect(current.references == original.references)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func listDurationQueriesOverHTTPNarrowCumulativelyAndRetainFullProgressAndManualOrder()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = planner(at: directory)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = creation.generated.first
    else {
      Issue.record("The real List must initialize before agent filtering.")
      return
    }
    let contents = [
      PlannerItemContentInput(
        title: "Short café", notes: "Garden entrance",
        estimate: PlannerEstimate(minutes: 119, displayUnit: .minute)),
      PlannerItemContentInput(
        title: "Boundary café", notes: "Garden entrance",
        estimate: PlannerEstimate(minutes: 120, displayUnit: .hour)),
      PlannerItemContentInput(
        title: "Long café", notes: "Garden entrance",
        estimate: PlannerEstimate(minutes: 121, displayUnit: .minute)),
      PlannerItemContentInput(title: "Unknown café", notes: "Garden entrance"),
      PlannerItemContentInput(
        title: "Hotel", notes: "Garden entrance",
        estimate: PlannerEstimate(minutes: 1, displayUnit: .minute)),
    ]
    var sources: [PlannerEntityReference] = []
    var membershipIdentifiers: [UUID] = []
    for content in contents {
      let source = try await createItem(content, planner: planner, session: session)
      guard
        case .applied(let addition, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: source.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
      else {
        Issue.record("Each source must have one saved List appearance.")
        return
      }
      sources.append(source)
      membershipIdentifiers.append(membershipIdentifier)
    }
    let completedAppearance = PlannerAppearance.listMembership(
      listId: list.id, membershipId: membershipIdentifiers[1])
    for command: PlannerCommand in [
      .setCompletion(scope: .appearance(completedAppearance), done: true),
      .setCompletion(scope: .globalItem(itemId: sources[2].id), done: true),
      .setArchive(source: sources[2], archived: true),
    ] {
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome
      else {
        Issue.record("Completion and archive must save independently before filtering.")
        return
      }
    }
    guard
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Saved order must be publicly readable before querying.")
      return
    }
    let listener = listener(planner: planner, session: session)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      var fields: [String: Any] = [
        "kind": "items", "scope": ["kind": "list", "listId": list.id.uuidString],
        "text": "cafe garden", "sort": ["mode": "manual", "direction": "ascending"],
        "duration": ["minimumMinutes": "120", "maximumMinutes": "121", "includeUnknown": false],
      ]
      let ordinary = try await query(fields, endpoint: endpoint, httpSession: httpSession)
      #expect(ordinary["matchingCount"] as? String == "0")
      #expect((ordinary["rows"] as? [Any])?.isEmpty == true)
      let fullProgress = try #require((ordinary["progress"] as? [[String: Any]])?.first)
      #expect(fullProgress["doneCount"] as? String == "2")
      #expect(fullProgress["totalCount"] as? String == "5")
      fields["completion"] = "all"
      fields["archive"] = "all"
      let allStates = try await query(fields, endpoint: endpoint, httpSession: httpSession)
      #expect(allStates["matchingCount"] as? String == "2")
      #expect(
        try sourceIdentifiers(allStates) == [sources[1].id.uuidString, sources[2].id.uuidString])
      let rows = try #require(allStates["rows"] as? [[String: Any]])
      #expect(
        rows.compactMap { ($0["appearance"] as? [String: String])?["membershipId"] } == [
          membershipIdentifiers[1].uuidString, membershipIdentifiers[2].uuidString,
        ])
      fields["duration"] = [
        "minimumMinutes": "120", "maximumMinutes": "121", "includeUnknown": true,
      ]
      let unknown = try await query(fields, endpoint: endpoint, httpSession: httpSession)
      #expect(unknown["matchingCount"] as? String == "3")
      #expect(
        try sourceIdentifiers(unknown) == [
          sources[1].id.uuidString, sources[2].id.uuidString, sources[3].id.uuidString,
        ])
      fields["duration"] = NSNull()
      let cleared = try await query(fields, endpoint: endpoint, httpSession: httpSession)
      #expect(cleared["matchingCount"] as? String == "4")
      #expect(
        try sourceIdentifiers(cleared) == sources.prefix(4).map { $0.id.uuidString })
      for result in [allStates, unknown, cleared] {
        #expect(
          NSDictionary(dictionary: try #require((result["progress"] as? [[String: Any]])?.first))
            .isEqual(to: fullProgress))
      }
      let global = try await query(
        [
          "kind": "items", "scope": ["kind": "global"], "text": "cafe garden",
          "duration": [
            "minimumMinutes": "120", "maximumMinutes": "120", "includeUnknown": false,
          ],
        ], endpoint: endpoint, httpSession: httpSession)
      #expect(global["matchingCount"] as? String == "1")
      #expect(try sourceIdentifiers(global) == [sources[1].id.uuidString])
      guard
        case .source(.list(let current)) = await planner.read(
          session: session, request: .source(list)),
        case .appearance(let completed) = await planner.read(
          session: session, request: .appearance(completedAppearance)),
        case .source(.item(let source)) = await planner.read(
          session: session, request: .source(sources[1]))
      else {
        Issue.record("Queries must preserve saved order and the exact local completion context.")
        await listener.stop()
        return
      }
      #expect(current.references == original.references)
      #expect(current.updatedAt == original.updatedAt)
      #expect(current.fieldHashes == original.fieldHashes)
      #expect(completed.localDone)
      #expect(completed.effectiveDone)
      #expect(completed.globalDone == false)
      #expect(source.state.globalDone == false)
      #expect(source.content.estimate == PlannerEstimate(minutes: 120, displayUnit: .hour))
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func inclusiveDurationQueriesOverHTTPKeepUnknownEstimatesExplicitAndRowsReadable()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = planner(at: directory)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real Planner dataset must initialize.")
      return
    }
    var sources: [PlannerEntityReference] = []
    for content in [
      PlannerItemContentInput(
        title: "Short walk", estimate: PlannerEstimate(minutes: 119, displayUnit: .minute)),
      PlannerItemContentInput(
        title: "Boundary lunch", estimate: PlannerEstimate(minutes: 120, displayUnit: .hour)),
      PlannerItemContentInput(
        title: "Long visit", estimate: PlannerEstimate(minutes: 121, displayUnit: .minute)),
      PlannerItemContentInput(title: "Unknown stop"),
    ] {
      sources.append(try await createItem(content, planner: planner, session: session))
    }
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(sources[1]))
    else {
      Issue.record("Saved estimates must be publicly readable before querying.")
      return
    }
    let listener = listener(planner: planner, session: session)
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      for scope in ["global", "inbox"] {
        let bounded = try await query(
          [
            "kind": "items", "scope": ["kind": scope],
            "duration": [
              "minimumMinutes": NSNull(), "maximumMinutes": "120", "includeUnknown": false,
            ],
          ], endpoint: endpoint, httpSession: httpSession)
        #expect(bounded["matchingCount"] as? String == "2")
        #expect(
          try sourceIdentifiers(bounded) == [sources[1].id.uuidString, sources[0].id.uuidString])
        let generation = try #require(bounded["generation"] as? String)
        let windowRequest = try toolRequest(
          endpoint: endpoint, name: "planner_read",
          arguments: [
            "formatVersion": 1,
            "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "2"],
          ])
        let window = try toolValue(try await httpSession.data(for: windowRequest), isError: false)
        #expect(window["matchingCount"] as? String == "2")
        let rows = try #require(window["rows"] as? [[String: Any]])
        #expect(rows.compactMap { $0["title"] as? String } == ["Boundary lunch", "Short walk"])
        let includeUnknown = try await query(
          [
            "kind": "items", "scope": ["kind": scope],
            "duration": [
              "minimumMinutes": NSNull(), "maximumMinutes": "120", "includeUnknown": true,
            ],
          ], endpoint: endpoint, httpSession: httpSession)
        #expect(includeUnknown["matchingCount"] as? String == "3")
        #expect(
          try sourceIdentifiers(includeUnknown) == [
            sources[1].id.uuidString, sources[0].id.uuidString, sources[3].id.uuidString,
          ])
        for duration: Any in [
          NSNull(),
          ["minimumMinutes": NSNull(), "maximumMinutes": NSNull(), "includeUnknown": false],
        ] {
          let unrestricted = try await query(
            ["kind": "items", "scope": ["kind": scope], "duration": duration],
            endpoint: endpoint, httpSession: httpSession)
          #expect(unrestricted["matchingCount"] as? String == "4")
          #expect(
            try sourceIdentifiers(unrestricted) == [
              sources[1].id.uuidString, sources[2].id.uuidString,
              sources[0].id.uuidString, sources[3].id.uuidString,
            ])
        }
      }
      guard
        case .source(.item(let current)) = await planner.read(
          session: session, request: .source(sources[1]))
      else {
        Issue.record("HTTP filtering must preserve saved source data.")
        await listener.stop()
        return
      }
      #expect(current.content.title == original.content.title)
      #expect(current.content.estimate == original.content.estimate)
      #expect(current.updatedAt == original.updatedAt)
      #expect(current.fieldHashes == original.fieldHashes)
      #expect(current.references == original.references)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func planner(at directory: URL) -> PlannerCore.Planner {
    PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
  }

  private func createItem(
    _ content: PlannerItemContentInput, planner: PlannerCore.Planner, session: PlannerDatasetSession
  ) async throws -> PlannerEntityReference {
    let outcome = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session, command: .createItem(content: content))
    ).outcome
    guard case .applied(let creation, .complete) = outcome else {
      Issue.record("The fixture Item must save with complete recovery evidence.")
      throw FixtureFailure()
    }
    return try #require(creation.generated.first)
  }

  private func listener(planner: PlannerCore.Planner, session: PlannerDatasetSession)
    -> PlannerMCPLoopbackListener
  {
    PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
  }

  private func query(
    _ query: [String: Any], endpoint: URL, httpSession: URLSession, isError: Bool = false
  ) async throws -> [String: Any] {
    let request = try toolRequest(
      endpoint: endpoint, name: "planner_query", arguments: ["formatVersion": 1, "query": query])
    return try toolValue(try await httpSession.data(for: request), isError: isError)
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

  private func toolValue(_ exchange: (Data, URLResponse), isError: Bool) throws -> [String: Any] {
    #expect((exchange.1 as? HTTPURLResponse)?.statusCode == 200)
    let envelope = try #require(JSONSerialization.jsonObject(with: exchange.0) as? [String: Any])
    #expect(envelope["error"] == nil)
    let tool = try #require(envelope["result"] as? [String: Any])
    try #require(tool["isError"] as? Bool == isError)
    let value = try #require(tool["structuredContent"] as? [String: Any])
    if !isError {
      let content = try #require(tool["content"] as? [[String: Any]])
      let text = try #require(content.first?["text"] as? String)
      let textValue = try #require(
        JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
      #expect(NSDictionary(dictionary: textValue).isEqual(to: value))
    }
    return value
  }

  private struct FixtureFailure: Error {}
}
