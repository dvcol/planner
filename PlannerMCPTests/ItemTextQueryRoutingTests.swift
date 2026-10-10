import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItemTextQueryRoutingTests {
  @Test func crossFieldTextSearchOverHTTPReturnsOnlyMatchingIdentitiesWithoutEditingData()
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
      Issue.record("The real Planner dataset must initialize.")
      return
    }
    var sources: [PlannerEntityReference] = []
    for input in [
      PlannerItemContentInput(
        title: "Ramen lunch", subtitle: "Afternoon pause", notes: "Check vegetarian options",
        location: PlannerOwnedLocation(
          displayName: "Meeting point", formattedAddress: "Ginza fixture address", coordinate: nil),
        links: [PlannerLinkInput(originalUrl: "https://example.com/ramen", label: "Menu")]),
      PlannerItemContentInput(title: "Vegetarian gardens", notes: "Outdoor walk"),
    ] {
      guard
        case .applied(let creation, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session, command: .createItem(content: input))
        ).outcome,
        let source = creation.generated.first
      else {
        Issue.record("Both shared fixture Items must save before searching.")
        return
      }
      sources.append(source)
    }
    let ramen = sources[0]
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(ramen))
    else {
      Issue.record("Original content and hashes must be publicly readable.")
      return
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let request = try toolRequest(
        endpoint: endpoint, name: "planner_query",
        arguments: [
          "formatVersion": 1,
          "query": ["kind": "items", "scope": ["kind": "global"], "text": " VEGETARIAN\t\nmenu "],
        ])
      let queried = try toolValue(try await httpSession.data(for: request), isError: false)
      #expect(queried["matchingCount"] as? String == "1")
      let rows = try #require(queried["rows"] as? [[String: Any]])
      #expect(rows.count == 1)
      #expect(rows.first?["kind"] as? String == "source")
      #expect(
        (rows.first?["source"] as? [String: String]) == ["kind": "item", "id": ramen.id.uuidString])
      let generation = try #require(queried["generation"] as? String)
      let rowRequest = try toolRequest(
        endpoint: endpoint, name: "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "rows", "generation": generation, "offset": "0", "limit": "1"],
        ])
      let window = try toolValue(try await httpSession.data(for: rowRequest), isError: false)
      #expect(window["matchingCount"] as? String == "1")
      let readRows = try #require(window["rows"] as? [[String: Any]])
      #expect(readRows.first?["title"] as? String == "Ramen lunch")
      #expect(readRows.first?["subtitle"] as? String == "Afternoon pause")
      let inboxRequest = try toolRequest(
        endpoint: endpoint, name: "planner_query",
        arguments: [
          "formatVersion": 1,
          "query": ["kind": "items", "scope": ["kind": "inbox"], "text": "VEGETARIAN menu"],
        ])
      let inbox = try toolValue(try await httpSession.data(for: inboxRequest), isError: false)
      #expect(inbox["matchingCount"] as? String == "1")
      #expect(NSArray(array: try #require(inbox["rows"] as? [Any])).isEqual(to: rows))
      for text in ["Ginza", "Menu", "/ramen", "VEGETARIAN\tmenu", "Lunch", "Afternoon"] {
        let fieldRequest = try toolRequest(
          endpoint: endpoint, name: "planner_query",
          arguments: [
            "formatVersion": 1,
            "query": ["kind": "items", "scope": ["kind": "global"], "text": text],
          ])
        let fieldResult = try toolValue(
          try await httpSession.data(for: fieldRequest), isError: false)
        #expect(fieldResult["matchingCount"] as? String == "1")
        #expect(NSArray(array: try #require(fieldResult["rows"] as? [Any])).isEqual(to: rows))
      }
      let invalidTexts: [Any] = [NSNull(), true, 1, [], ["word": "menu"]]
      for invalidText in invalidTexts {
        let invalidRequest = try toolRequest(
          endpoint: endpoint, name: "planner_query",
          arguments: [
            "formatVersion": 1,
            "query": ["kind": "items", "scope": ["kind": "global"], "text": invalidText],
          ])
        let rejected = try toolValue(try await httpSession.data(for: invalidRequest), isError: true)
        #expect(rejected["state"] as? String == "failed")
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == "invalidInput")
        #expect(reason["propertyPath"] as? String == "/query/text")
      }
      let retainedWindow = try toolValue(
        try await httpSession.data(for: rowRequest), isError: false)
      #expect(NSDictionary(dictionary: retainedWindow).isEqual(to: window))
      var catalogRequest = request
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
      #expect((itemProperties["text"] as? [String: Any])?["type"] as? String == "string")
      #expect((itemSchema["required"] as? [String])?.contains("text") == false)
      #expect(itemSchema["additionalProperties"] as? Bool == false)
      guard
        case .source(.item(let retained)) = await planner.read(
          session: session, request: .source(ramen)),
        case .snapshot(let native) = await planner.query(
          PlannerQuery(session: session, request: .items(.init(text: "vegetarian menu"))))
      else {
        Issue.record("HTTP text must use the canonical query while preserving the shared Item.")
        await listener.stop()
        return
      }
      #expect(native.rows == [.source(ramen)])
      #expect(retained.content.title == "Ramen lunch")
      #expect(retained.content.notes == "Check vegetarian options")
      #expect(retained.updatedAt == original.updatedAt)
      #expect(retained.fieldHashes == original.fieldHashes)
      #expect(retained.references == original.references)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
  }

  @Test func listTextSearchOverHTTPRetainsFullProgressAndIndependentLocalCompletion()
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
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let listCreation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = listCreation.generated.first
    else {
      Issue.record("The saved List must initialize.")
      return
    }
    var sources: [PlannerEntityReference] = []
    var membershipIdentifiers: [UUID] = []
    for title in ["Hotel", "Nezu Museum", "Archived Museum"] {
      guard
        case .applied(let creation, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createItem(content: .init(title: title)))
        ).outcome,
        let source = creation.generated.first,
        case .applied(let addition, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: source.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let membershipIdentifier, _, _)? = addition.generatedReferences.first
      else {
        Issue.record("Each Item must have one saved List appearance.")
        return
      }
      sources.append(source)
      membershipIdentifiers.append(membershipIdentifier)
    }
    let completedAppearance = PlannerAppearance.listMembership(
      listId: list.id, membershipId: membershipIdentifiers[1])
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .appearance(completedAppearance), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setArchive(source: sources[2], archived: true))
      ).outcome,
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Local completion and archive must save independently before the query.")
      return
    }
    let listener = PlannerMCPLoopbackListener(
      requestHandler: PlannerMCPRequestHandler(
        credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", accessWindowIdentifier: UUID(),
        planner: planner, datasetSession: session))
    let endpoint = try await listener.start(port: 0)
    let httpSession = URLSession(configuration: .ephemeral)
    defer { httpSession.invalidateAndCancel() }
    do {
      let ordinaryRequest = try toolRequest(
        endpoint: endpoint, name: "planner_query",
        arguments: [
          "formatVersion": 1,
          "query": [
            "kind": "items", "scope": ["kind": "list", "listId": list.id.uuidString],
            "text": "museum",
            "sort": ["mode": "manual", "direction": "ascending"],
          ],
        ])
      let ordinary = try toolValue(try await httpSession.data(for: ordinaryRequest), isError: false)
      #expect(ordinary["matchingCount"] as? String == "0")
      #expect((ordinary["rows"] as? [Any])?.isEmpty == true)
      let ordinaryProgress = try #require((ordinary["progress"] as? [[String: Any]])?.first)
      #expect(ordinaryProgress["doneCount"] as? String == "1")
      #expect(ordinaryProgress["totalCount"] as? String == "3")
      let allRequest = try toolRequest(
        endpoint: endpoint, name: "planner_query",
        arguments: [
          "formatVersion": 1,
          "query": [
            "kind": "items", "scope": ["kind": "list", "listId": list.id.uuidString],
            "text": "MUSEUM",
            "completion": "all", "archive": "all",
            "sort": ["mode": "manual", "direction": "ascending"],
          ],
        ])
      let allStates = try toolValue(try await httpSession.data(for: allRequest), isError: false)
      #expect(allStates["matchingCount"] as? String == "2")
      let rows = try #require(allStates["rows"] as? [[String: Any]])
      #expect(
        rows.compactMap { ($0["source"] as? [String: String])?["id"] } == [
          sources[1].id.uuidString, sources[2].id.uuidString,
        ])
      #expect(
        rows.compactMap { ($0["appearance"] as? [String: String])?["membershipId"] } == [
          membershipIdentifiers[1].uuidString, membershipIdentifiers[2].uuidString,
        ])
      #expect(
        NSDictionary(dictionary: try #require((allStates["progress"] as? [[String: Any]])?.first))
          .isEqual(to: ordinaryProgress))
      guard
        case .source(.list(let current)) = await planner.read(
          session: session, request: .source(list)),
        case .appearance(let completed) = await planner.read(
          session: session, request: .appearance(completedAppearance)),
        case .source(.item(let source)) = await planner.read(
          session: session, request: .source(sources[1]))
      else {
        Issue.record(
          "Text filtering must retain the source, independent local state and saved order.")
        await listener.stop()
        return
      }
      #expect(completed.localDone)
      #expect(completed.effectiveDone)
      #expect(completed.globalDone == false)
      #expect(source.state.globalDone == false)
      #expect(current.references == original.references)
      #expect(current.updatedAt == original.updatedAt)
      #expect(current.fieldHashes == original.fieldHashes)
      await listener.stop()
    } catch {
      await listener.stop()
      throw error
    }
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
    #expect(tool["isError"] as? Bool == isError)
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
}
