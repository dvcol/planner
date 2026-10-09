import Foundation
import PlannerCore
import Testing

@testable import Planner

struct RowRoutingTests {
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
        case .source(let retained) = await planner.read(
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
