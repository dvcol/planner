import Foundation
import PlannerCore
import Testing

@testable import Planner

struct CaptureRoutingTests {
  @Test func discoveryAdvertisesCaptureAndReviewedApplyWithoutAdministration() async throws {
    let fixture = try await CaptureHTTPFixture.open()
    do {
      let result = try await fixture.request(method: "tools/list", parameters: [:])
      let tools = try #require(result["tools"] as? [[String: Any]])
      let names = Set(tools.compactMap { $0["name"] as? String })
      #expect(
        [
          "planner_prepare_capture", "planner_update_capture", "planner_read_capture",
          "planner_cancel_capture", "planner_lookup_capture",
        ].allSatisfy(names.contains))
      #expect(!names.contains("planner_export"))
      let lookup = try #require(tools.first { $0["name"] as? String == "planner_lookup_capture" })
      let lookupSchema = try #require(lookup["inputSchema"] as? [String: Any])
      #expect(
        Set(try #require(lookupSchema["required"] as? [String])) == [
          "formatVersion", "draftId", "generation", "linkId",
        ])
      #expect(lookupSchema["additionalProperties"] as? Bool == false)
      let lookupAnnotations = try #require(lookup["annotations"] as? [String: Any])
      #expect(lookupAnnotations["openWorldHint"] as? Bool == true)
      #expect(lookupAnnotations["destructiveHint"] as? Bool == false)
      let update = try #require(tools.first { $0["name"] as? String == "planner_update_capture" })
      let schema = try #require(update["inputSchema"] as? [String: Any])
      #expect(
        Set(try #require(schema["required"] as? [String])) == [
          "formatVersion", "draftId", "generation", "changes",
        ])
      let execute = try #require(tools.first { $0["name"] as? String == "planner_execute" })
      let executionSchema = try #require(execute["inputSchema"] as? [String: Any])
      let properties = try #require(executionSchema["properties"] as? [String: Any])
      let command = try #require(properties["command"] as? [String: Any])
      let choices = try #require(command["oneOf"] as? [[String: Any]])
      let commandKinds = choices.compactMap { choice -> String? in
        let fields = choice["properties"] as? [String: Any]
        return (fields?["type"] as? [String: Any])?["const"] as? String
      }
      #expect(commandKinds.contains("applyCapture"))
      #expect(
        !commandKinds.contains("deleteSource") && !commandKinds.contains("applyImport")
          && !commandKinds.contains("restoreRecovery"))
      await fixture.stop()
    } catch {
      await fixture.stop()
      throw error
    }
  }

  @Test func exactReuseAddsOnlyMissingLinksAndMembershipsWithoutChangingOwnedOrLocalState()
    async throws
  {
    let fixture = try await CaptureHTTPFixture.open()
    do {
      let item = try await fixture.save(
        .createItem(
          content: .init(
            title: "Existing", notes: "Keep notes",
            links: [
              .init(originalUrl: "https://example.com/existing?keep=%41", label: "My bookmark")
            ])))
      let firstList = try await fixture.save(.createList(content: .init(name: "First")))
      let secondList = try await fixture.save(.createList(content: .init(name: "Second")))
      let membership = try await fixture.execute(
        .addMembership(itemId: item.id, listId: firstList.id, placement: .last))
      let membershipIdentifier = try #require(
        membership.generatedReferences.compactMap { reference -> UUID? in
          if case .membership(let identifier, _, _) = reference { return identifier }
          return nil
        }.first)
      _ = try await fixture.execute(
        .setCompletion(
          scope: .appearance(
            .listMembership(listId: firstList.id, membershipId: membershipIdentifier)), done: true))
      _ = try await fixture.execute(.setCompletion(scope: .globalItem(itemId: item.id), done: true))
      _ = try await fixture.execute(.setArchive(source: item, archived: true))
      let prepared = try await fixture.call(
        "planner_prepare_capture",
        arguments: [
          "formatVersion": 1,
          "inputs": [
            ["kind": "url", "value": "https://example.com/existing?keep=%41"],
            ["kind": "url", "value": "https://example.com/new?keep=%2f"],
          ],
        ])
      let candidates = try #require(prepared["reuseCandidates"] as? [[String: Any]])
      #expect(candidates.count == 1 && candidates.first?["itemId"] as? String == item.id.uuidString)
      #expect(
        candidates.first?["globalDone"] as? Bool == true
          && candidates.first?["archived"] as? Bool == true)
      let command: [String: Any] = [
        "type": "applyCapture", "draftId": try #require(prepared["draftId"]),
        "draftGeneration": try #require(prepared["generation"]),
        "choice": ["kind": "reuse", "itemId": item.id.uuidString],
        "listIds": [firstList.id.uuidString, secondList.id.uuidString],
      ]
      let review = try await fixture.call(
        "planner_prepare_review", arguments: ["formatVersion": 1, "command": command])
      let impact = try #require(review["impact"] as? [String: Any])
      let details = try #require(impact["captureDetails"] as? [String: Any])
      #expect(details["createContent"] is NSNull)
      #expect(details["missingListIds"] as? [String] == [secondList.id.uuidString])
      let missingLinks = try #require(details["missingLinks"] as? [[String: Any]])
      #expect(
        missingLinks.count == 1
          && missingLinks.first?["originalUrl"] as? String == "https://example.com/new?keep=%2f")
      let targets = try #require(review["targets"] as? [[String: Any]])
      #expect(targets.contains { $0["kind"] as? String == "reference" })
      let applied = try await fixture.call(
        "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": UUID().uuidString, "command": command,
          "reviewToken": try #require(review["reviewToken"]),
        ])
      #expect(applied["state"] as? String == "applied")
      let result = try #require(applied["result"] as? [String: Any])
      #expect(
        (result["generated"] as? [[String: Any]])?.contains { $0["kind"] as? String == "item" }
          == false)
      let read = try await fixture.call(
        "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "item", "id": item.id.uuidString]],
        ])
      let value = try #require(read["value"] as? [String: Any])
      let content = try #require(value["content"] as? [String: Any])
      #expect(
        content["title"] as? String == "Existing" && content["notes"] as? String == "Keep notes")
      let state = try #require(value["state"] as? [String: Any])
      #expect(state["globalDone"] as? Bool == true && state["archived"] as? Bool == true)
      let links = try #require(content["links"] as? [[String: Any]])
      #expect(
        links.compactMap { $0["originalUrl"] as? String } == [
          "https://example.com/existing?keep=%41", "https://example.com/new?keep=%2f",
        ])
      #expect(links.first?["label"] as? String == "My bookmark")
      let appearance = try await fixture.call(
        "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": [
            "kind": "appearance",
            "appearance": [
              "kind": "listMembership", "listId": firstList.id.uuidString,
              "membershipId": membershipIdentifier.uuidString,
            ],
          ],
        ])
      let appearanceValue = try #require(appearance["value"] as? [String: Any])
      #expect(appearanceValue["localDone"] as? Bool == true)
      guard
        case .snapshot(let snapshot) = await fixture.planner.query(
          .init(
            session: fixture.session,
            request: .items(.init(completion: .all, archive: .all))))
      else { throw CancellationError() }
      #expect(snapshot.matchingCount == 1)
      await fixture.stop()
    } catch {
      await fixture.stop()
      throw error
    }
  }

  @Test func malformedAndStaleCaptureRequestsPreserveTheCurrentDraftAndSavedData() async throws {
    let fixture = try await CaptureHTTPFixture.open()
    do {
      let prepared = try await fixture.call(
        "planner_prepare_capture",
        arguments: [
          "formatVersion": 1, "inputs": [["kind": "url", "value": "https://example.com/current"]],
        ])
      let draftIdentifier = try #require(prepared["draftId"] as? String)
      let generation = try #require(prepared["generation"] as? String)
      guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      let base: [String: Any] = [
        "formatVersion": 1, "draftId": draftIdentifier, "generation": generation,
        "changes": ["notes": "Owned"],
      ]
      let cases: [(name: String, arguments: [String: Any], code: String, path: String?)] = [
        (
          "planner_prepare_capture", ["formatVersion": 2, "inputs": []], "unsupportedVersion",
          "/formatVersion"
        ),
        (
          "planner_prepare_capture",
          ["formatVersion": 1, "inputs": [["kind": "mapItem", "value": "fake"]]], "invalidInput",
          "/inputs/0/kind"
        ),
        (
          "planner_prepare_capture",
          ["formatVersion": 1, "inputs": [["kind": "url", "value": 1]]], "invalidInput",
          "/inputs/0/value"
        ),
        (
          "planner_prepare_capture",
          [
            "formatVersion": 1,
            "inputs": [["kind": "text", "value": "Owned", "origin": "independent"]],
          ], "unknownField", "/inputs/0/origin"
        ),
        (
          "planner_read_capture", ["formatVersion": 1, "draftId": "bad"], "invalidInput", "/draftId"
        ),
        (
          "planner_cancel_capture", ["formatVersion": 1, "draftId": draftIdentifier],
          "invalidInput", "/generation"
        ),
        (
          "planner_update_capture",
          base.merging(["changes": ["contentOrigins": ["title": "independent"]]]) { _, incoming in
            incoming
          }, "unknownField", "/changes/contentOrigins"
        ),
        (
          "planner_update_capture",
          base.merging([
            "changes": [
              "location": [
                "displayName": "Owned", "formattedAddress": NSNull(),
                "coordinate": ["latitude": 91, "longitude": 0],
              ]
            ]
          ]) { _, incoming in incoming }, "invalidInput", "/changes/location/coordinate"
        ),
        (
          "planner_update_capture",
          base.merging(["removeInputIndexes": ["01"]]) { _, incoming in incoming }, "invalidInput",
          "/removeInputIndexes/0"
        ),
        (
          "planner_update_capture",
          base.merging(["retryInputIndexes": ["9223372036854775808"]]) { _, incoming in incoming },
          "invalidInput", "/retryInputIndexes/0"
        ),
        (
          "planner_update_capture", base.merging(["extra/key": true]) { _, incoming in incoming },
          "unknownField", "/extra~1key"
        ),
      ]
      for testCase in cases {
        let rejected = try await fixture.call(
          testCase.name, arguments: testCase.arguments, isError: true)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(reason["code"] as? String == testCase.code)
        #expect(
          reason["propertyPath"] as? String == testCase.path,
          "Case \(testCase.name): \(testCase.arguments)")
      }
      let read = try await fixture.call(
        "planner_read_capture", arguments: ["formatVersion": 1, "draftId": draftIdentifier])
      #expect(read["generation"] as? String == generation)
      let updated = try await fixture.call("planner_update_capture", arguments: base)
      let command: [String: Any] = [
        "type": "applyCapture", "draftId": draftIdentifier,
        "draftGeneration": try #require(updated["generation"]), "choice": ["kind": "createNew"],
        "listIds": [],
      ]
      let review = try await fixture.call(
        "planner_prepare_review", arguments: ["formatVersion": 1, "command": command])
      let edited = try await fixture.call(
        "planner_update_capture",
        arguments: base.merging([
          "generation": try #require(updated["generation"]),
          "changes": ["title": "New current title"],
        ]) { _, incoming in incoming })
      let stale = try await fixture.call(
        "planner_execute",
        arguments: [
          "formatVersion": 1,
          "operationId": UUID().uuidString, "command": command,
          "reviewToken": try #require(review["reviewToken"]),
        ], isError: true)
      #expect((stale["reason"] as? [String: Any])?["code"] as? String == "staleReview")
      let staleCancellation = try await fixture.call(
        "planner_cancel_capture",
        arguments: [
          "formatVersion": 1, "draftId": draftIdentifier, "generation": generation,
        ], isError: true)
      #expect(
        (staleCancellation["reason"] as? [String: Any])?["code"] as? String
          == "captureDraftUnavailable")
      let current = try await fixture.call(
        "planner_read_capture", arguments: ["formatVersion": 1, "draftId": draftIdentifier])
      #expect(current["generation"] as? String == edited["generation"] as? String)
      guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(after == before)
      await fixture.stop()
    } catch {
      await fixture.stop()
      throw error
    }
  }

  @Test func agentEditsReviewsAppliesAndReplaysOneCaptureWithItsListMemberships() async throws {
    let fixture = try await CaptureHTTPFixture.open()
    do {
      let firstList = try await fixture.save(.createList(content: .init(name: "First")))
      let secondList = try await fixture.save(.createList(content: .init(name: "Second")))
      let category = try await fixture.save(.createCategory(content: .init(name: "Food")))
      let prepared = try await fixture.call(
        "planner_prepare_capture",
        arguments: [
          "formatVersion": 1,
          "inputs": [["kind": "url", "value": "https://example.com/meeting?keep=exact"]],
        ])
      let draftIdentifier = try #require(prepared["draftId"] as? String)
      let generation = try #require(prepared["generation"] as? String)
      let updated = try await fixture.call(
        "planner_update_capture",
        arguments: [
          "formatVersion": 1, "draftId": draftIdentifier, "generation": generation,
          "changes": [
            "title": "My meeting", "subtitle": "Lunch", "notes": NSNull(),
            "location": [
              "displayName": "My meeting point", "formattedAddress": "Owned address",
              "coordinate": ["latitude": 35.0, "longitude": 139.0],
            ],
            "estimate": ["minutes": "65", "displayUnit": "hour"],
            "categoryIds": [category.id.uuidString],
          ],
        ])
      let updatedGeneration = try #require(updated["generation"] as? String)
      #expect(updatedGeneration != generation)
      let command: [String: Any] = [
        "type": "applyCapture", "draftId": draftIdentifier,
        "draftGeneration": updatedGeneration, "choice": ["kind": "createNew"],
        "listIds": [firstList.id.uuidString, secondList.id.uuidString],
      ]
      let reviewed = try await fixture.call(
        "planner_prepare_review",
        arguments: [
          "formatVersion": 1, "command": command,
        ])
      let token = try #require(reviewed["reviewToken"] as? String)
      let impact = try #require(reviewed["impact"] as? [String: Any])
      #expect(impact["kind"] as? String == "capture" && impact["targetCount"] as? String == "2")
      let details = try #require(impact["captureDetails"] as? [String: Any])
      let reviewedContent = try #require(details["createContent"] as? [String: Any])
      #expect(reviewedContent["title"] as? String == "My meeting")
      #expect(
        Set(try #require(details["missingListIds"] as? [String])) == [
          firstList.id.uuidString, secondList.id.uuidString,
        ])
      let unreviewed = try await fixture.call(
        "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": UUID().uuidString, "command": command,
        ], isError: true)
      #expect((unreviewed["reason"] as? [String: Any])?["code"] as? String == "staleReview")
      let operationIdentifier = UUID().uuidString
      let applied = try await fixture.call(
        "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": operationIdentifier, "command": command,
          "reviewToken": token,
        ])
      #expect(applied["state"] as? String == "applied")
      #expect((applied["recovery"] as? [String: Any])?["state"] as? String == "complete")
      let result = try #require(applied["result"] as? [String: Any])
      let generated = try #require(result["generated"] as? [[String: Any]])
      #expect(generated.count == 4)
      let itemIdentifier = try #require(
        generated.first { $0["kind"] as? String == "item" }?["id"] as? String)
      let savedEnvelope = try await fixture.call(
        "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "item", "id": itemIdentifier]],
        ])
      let saved = try #require(savedEnvelope["value"] as? [String: Any])
      let content = try #require(saved["content"] as? [String: Any])
      #expect(
        content["title"] as? String == "My meeting" && content["subtitle"] as? String == "Lunch")
      #expect(content["notes"] is NSNull)
      #expect(
        (content["location"] as? [String: Any])?["formattedAddress"] as? String == "Owned address")
      #expect((content["estimate"] as? [String: Any])?["minutes"] as? String == "65")
      #expect(content["categoryIds"] as? [String] == [category.id.uuidString])
      let links = try #require(content["links"] as? [[String: Any]])
      #expect(
        links.count == 1
          && links.first?["originalUrl"] as? String == "https://example.com/meeting?keep=exact")
      let references = try #require(saved["references"] as? [[String: Any]])
      #expect(references.filter { $0["kind"] as? String == "membership" }.count == 2)
      let committedCancellation = try await fixture.call(
        "planner_cancel_capture",
        arguments: [
          "formatVersion": 1, "draftId": draftIdentifier, "generation": updatedGeneration,
        ])
      #expect(
        committedCancellation["state"] as? String == "notCancellable"
          && committedCancellation["operationId"] as? String == operationIdentifier)
      await fixture.stop()
      let reopened = try await CaptureHTTPFixture.open(directory: fixture.directory)
      do {
        let replay = try await reopened.call(
          "planner_execute",
          arguments: [
            "formatVersion": 1, "operationId": operationIdentifier, "command": command,
            "reviewToken": token,
          ])
        #expect(replay["state"] as? String == "applied")
        #expect(
          try JSONSerialization.data(
            withJSONObject: #require(replay["result"]), options: .sortedKeys)
            == JSONSerialization.data(withJSONObject: result, options: .sortedKeys))
        await reopened.stop()
      } catch {
        await reopened.stop()
        throw error
      }
    } catch {
      await fixture.stop()
      throw error
    }
  }

  @Test func prepareReadAndCancelRetainExactInputsWithoutSavingData() async throws {
    let fixture = try await CaptureHTTPFixture.open()
    do {
      guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      let prepared = try await fixture.call(
        "planner_prepare_capture",
        arguments: [
          "formatVersion": 1,
          "inputs": [
            ["kind": "url", "value": "https://example.com/%2f?keep=%41"],
            ["kind": "text", "value": "Museum idea\nBring lunch"],
          ],
        ])
      let draftIdentifier = try #require(prepared["draftId"] as? String)
      let generation = try #require(prepared["generation"] as? String)
      #expect(UUID(uuidString: draftIdentifier) != nil && UUID(uuidString: generation) != nil)
      let content = try #require(prepared["content"] as? [String: Any])
      #expect(
        content["title"] as? String == "Museum idea" && content["notes"] as? String == "Bring lunch"
      )
      let links = try #require(prepared["links"] as? [[String: Any]])
      #expect(
        links.count == 1
          && links.first?["originalUrl"] as? String == "https://example.com/%2f?keep=%41")
      #expect(prepared["saveAllowed"] as? Bool == true)
      #expect((prepared["reuseCandidates"] as? [Any])?.isEmpty == true)
      let read = try await fixture.call(
        "planner_read_capture",
        arguments: [
          "formatVersion": 1, "draftId": draftIdentifier,
        ])
      #expect(
        read["draftId"] as? String == draftIdentifier && read["generation"] as? String == generation
      )
      let cancelled = try await fixture.call(
        "planner_cancel_capture",
        arguments: [
          "formatVersion": 1, "draftId": draftIdentifier, "generation": generation,
        ])
      #expect(cancelled["state"] as? String == "cancelled")
      let unavailable = try await fixture.call(
        "planner_read_capture",
        arguments: [
          "formatVersion": 1, "draftId": draftIdentifier,
        ], isError: true)
      #expect(
        (unavailable["reason"] as? [String: Any])?["code"] as? String == "captureDraftUnavailable")
      let removable = try await fixture.call(
        "planner_prepare_capture",
        arguments: [
          "formatVersion": 1,
          "inputs": [
            ["kind": "url", "value": "https://example.com/removable"],
            ["kind": "text", "value": "Owned activity"],
          ],
        ])
      let removed = try await fixture.call(
        "planner_update_capture",
        arguments: [
          "formatVersion": 1, "draftId": try #require(removable["draftId"]),
          "generation": try #require(removable["generation"]), "changes": [:],
          "removeInputIndexes": ["0"],
        ])
      #expect((removed["links"] as? [Any])?.isEmpty == true)
      #expect((removed["content"] as? [String: Any])?["title"] as? String == "Owned activity")
      let retried = try await fixture.call(
        "planner_update_capture",
        arguments: [
          "formatVersion": 1, "draftId": try #require(removed["draftId"]),
          "generation": try #require(removed["generation"]), "changes": [:],
          "retryInputIndexes": ["1"],
        ])
      #expect((retried["content"] as? [String: Any])?["title"] as? String == "Owned activity")
      _ = try await fixture.call(
        "planner_cancel_capture",
        arguments: [
          "formatVersion": 1, "draftId": try #require(retried["draftId"]),
          "generation": try #require(retried["generation"]),
        ])
      guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(after == before)
      await fixture.stop()
    } catch {
      await fixture.stop()
      throw error
    }
  }
}

struct CaptureHTTPFixture {
  let directory: URL
  let planner: PlannerCore.Planner
  let session: PlannerDatasetSession
  let handler: PlannerMCPRequestHandler
  let listener: PlannerMCPLoopbackListener
  let endpoint: URL
  let httpSession: URLSession

  static func open(
    directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString),
    captureHTTPTransport: any PlannerCaptureHTTPTransport = PlannerNativeCaptureHTTPTransport()
  ) async throws -> Self {
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly),
      captureHTTPTransport: captureHTTPTransport)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      accessWindowIdentifier: UUID(), planner: planner, datasetSession: session)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    return Self(
      directory: directory, planner: planner, session: session,
      handler: handler, listener: listener, endpoint: endpoint,
      httpSession: URLSession(configuration: .ephemeral))
  }

  func save(_ command: PlannerCommand) async throws -> PlannerEntityReference {
    let result = try await execute(command)
    guard let source = result.generated.first
    else { throw CancellationError() }
    return source
  }

  func execute(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
    else { throw CancellationError() }
    return result
  }

  func call(_ name: String, arguments: [String: Any], isError: Bool = false) async throws
    -> [String: Any]
  {
    let result = try await request(
      method: "tools/call", parameters: ["name": name, "arguments": arguments])
    #expect(result["isError"] as? Bool == isError)
    return try #require(result["structuredContent"] as? [String: Any])
  }

  func request(method: String, parameters: [String: Any]) async throws -> [String: Any] {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": UUID().uuidString, "method": method, "params": parameters,
    ])
    request.timeoutInterval = 5
    let (data, response) = try await httpSession.data(for: request)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)
    #expect((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Mcp-Session-Id") == nil)
    let envelope = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(envelope["error"] == nil)
    return try #require(envelope["result"] as? [String: Any])
  }

  func stop() async {
    httpSession.invalidateAndCancel()
    await listener.stop()
  }

}
