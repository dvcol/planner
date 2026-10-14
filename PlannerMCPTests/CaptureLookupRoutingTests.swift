import Foundation
import PlannerCore
import Testing

@testable import Planner

@Suite(.serialized)
struct CaptureLookupRoutingTests {
  @Test(arguments: [false, true])
  func unavailableLookupRetainsPartialCaptureWithoutAutomaticRetry(usesHTTPOriginal: Bool)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerMCPLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = MCPMapsLookupTransport()
    let fixture = try await CaptureHTTPFixture.open(
      directory: directory, captureHTTPTransport: transport)
    do {
      let original: String
      if usesHTTPOriginal {
        original = "http://maps.apple.com/place?name=Museum"
      } else {
        original = "https://maps.apple.com/place?place-id=my-location"
      }
      guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      let prepared = try await fixture.call(
        "planner_prepare_capture",
        arguments: ["formatVersion": 1, "inputs": [["kind": "url", "value": original]]])
      let links = try #require(prepared["links"] as? [[String: Any]])
      let draftIdentifier = try #require(prepared["draftId"] as? String)
      let generation = try #require(prepared["generation"] as? String)
      let linkIdentifier = try #require(links.first?["linkId"] as? String)
      let result = try await fixture.call(
        "planner_lookup_capture",
        arguments: [
          "formatVersion": 1, "draftId": draftIdentifier, "generation": generation,
          "linkId": linkIdentifier,
        ])
      let preview = try #require(result["preview"] as? [String: Any])
      #expect(preview["state"] as? String == "unavailable" && preview["candidate"] is NSNull)
      #expect(
        preview["linkId"] as? String == linkIdentifier && result["saveAllowed"] as? Bool == true)
      let retainedLinks = try #require(result["links"] as? [[String: Any]])
      #expect(retainedLinks.first?["originalUrl"] as? String == original)
      let read = try await fixture.call(
        "planner_read_capture", arguments: ["formatVersion": 1, "draftId": draftIdentifier])
      #expect(read["generation"] as? String == generation && read["saveAllowed"] as? Bool == true)
      let requests = await transport.requests
      if usesHTTPOriginal {
        #expect(requests.isEmpty)
      } else {
        #expect(requests.map(\.absoluteString) == [original])
      }
      guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(before == after)
      await fixture.stop()
    } catch {
      await fixture.stop()
      throw error
    }
  }

  @Test func revokedAgentAccessRejectsLookupBeforeExternalIO() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerMCPLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = MCPMapsLookupTransport()
    let fixture = try await CaptureHTTPFixture.open(
      directory: directory, captureHTTPTransport: transport)
    do {
      let prepared = try await fixture.call(
        "planner_prepare_capture",
        arguments: [
          "formatVersion": 1,
          "inputs": [["kind": "url", "value": "https://maps.apple.com/place?name=Museum"]],
        ])
      let links = try #require(prepared["links"] as? [[String: Any]])
      guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      await fixture.handler.revokeAccess()
      var request = URLRequest(url: fixture.endpoint)
      request.httpMethod = "POST"
      request.setValue(
        "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
      request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
      request.timeoutInterval = 5
      request.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": UUID().uuidString, "method": "tools/call",
        "params": [
          "name": "planner_lookup_capture",
          "arguments": [
            "formatVersion": 1, "draftId": try #require(prepared["draftId"]),
            "generation": try #require(prepared["generation"]),
            "linkId": try #require(links.first?["linkId"]),
          ],
        ],
      ])
      let (_, response) = try await fixture.httpSession.data(for: request)
      #expect((response as? HTTPURLResponse)?.statusCode == 401)
      #expect(
        (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Planner-Access-Window") == nil)
      #expect(await transport.requests.isEmpty)
      guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(before == after)
      await fixture.stop()
    } catch {
      await fixture.stop()
      throw error
    }
  }

  @Test func agentCanSaveDuringLookupAndLateProviderDataCannotChangeTheSavedItem() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerMCPLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let gate = MCPMapsLookupResponseGate()
    let transport = MCPMapsLookupTransport(gate: gate)
    let fixture = try await CaptureHTTPFixture.open(
      directory: directory, captureHTTPTransport: transport)
    var lookup: Task<Data, any Error>?
    defer { lookup?.cancel() }
    do {
      let original = "https://maps.apple.com/place?name=Museum&coordinate=35,139"
      let prepared = try await fixture.call(
        "planner_prepare_capture",
        arguments: [
          "formatVersion": 1,
          "inputs": [["kind": "url", "value": original], ["kind": "text", "value": "My visit"]],
        ])
      let draftIdentifier = try #require(prepared["draftId"] as? String)
      let generation = try #require(prepared["generation"] as? String)
      let links = try #require(prepared["links"] as? [[String: Any]])
      let linkIdentifier = try #require(links.first?["linkId"] as? String)
      let pendingLookup = Task {
        let result = try await fixture.call(
          "planner_lookup_capture",
          arguments: [
            "formatVersion": 1, "draftId": draftIdentifier, "generation": generation,
            "linkId": linkIdentifier,
          ], isError: true)
        return try JSONSerialization.data(withJSONObject: result)
      }
      lookup = pendingLookup
      try #require(await transport.waitForRequest())
      let loading = try await fixture.call(
        "planner_read_capture", arguments: ["formatVersion": 1, "draftId": draftIdentifier])
      #expect((loading["preview"] as? [String: Any])?["state"] as? String == "loading")
      #expect(loading["saveAllowed"] as? Bool == true)
      let command: [String: Any] = [
        "type": "applyCapture", "draftId": draftIdentifier, "draftGeneration": generation,
        "choice": ["kind": "createNew"], "listIds": [],
      ]
      let reviewed = try await fixture.call(
        "planner_prepare_review", arguments: ["formatVersion": 1, "command": command])
      let applied = try await fixture.call(
        "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": UUID().uuidString, "command": command,
          "reviewToken": try #require(reviewed["reviewToken"]),
        ])
      #expect(applied["state"] as? String == "applied")
      #expect((applied["recovery"] as? [String: Any])?["state"] as? String == "complete")
      let appliedResult = try #require(applied["result"] as? [String: Any])
      let generated = try #require(appliedResult["generated"] as? [[String: Any]])
      let itemIdentifier = try #require(
        generated.first { $0["kind"] as? String == "item" }?["id"] as? String)
      #expect(generated.filter { $0["kind"] as? String == "item" }.count == 1)
      let savedEnvelope = try await fixture.call(
        "planner_read",
        arguments: [
          "formatVersion": 1,
          "request": ["kind": "source", "source": ["kind": "item", "id": itemIdentifier]],
        ])
      let saved = try #require(savedEnvelope["value"] as? [String: Any])
      let content = try #require(saved["content"] as? [String: Any])
      #expect(content["title"] as? String == "My visit" && content["location"] is NSNull)
      #expect((content["links"] as? [[String: Any]])?.first?["originalUrl"] as? String == original)
      guard
        case .exported(let beforeLateResult) = await fixture.planner.exportData(
          session: fixture.session)
      else { throw CancellationError() }
      await gate.release()
      let lateResult = try #require(
        JSONSerialization.jsonObject(with: await pendingLookup.value) as? [String: Any])
      #expect(
        (lateResult["reason"] as? [String: Any])?["code"] as? String == "captureDraftUnavailable")
      #expect(await transport.responsesDeliveredAfterCancellation == 1)
      let discarded = try await fixture.call(
        "planner_read_capture", arguments: ["formatVersion": 1, "draftId": draftIdentifier],
        isError: true)
      #expect(
        (discarded["reason"] as? [String: Any])?["code"] as? String == "captureDraftUnavailable")
      guard
        case .exported(let afterLateResult) = await fixture.planner.exportData(
          session: fixture.session)
      else { throw CancellationError() }
      #expect(beforeLateResult == afterLateResult)
      await fixture.stop()
    } catch {
      await gate.release()
      lookup?.cancel()
      await fixture.stop()
      throw error
    }
  }

  @Test func malformedAndForeignLookupRequestsMakeNoExternalRequestOrSavedChange() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerMCPLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = MCPMapsLookupTransport()
    let fixture = try await CaptureHTTPFixture.open(
      directory: directory, captureHTTPTransport: transport)
    do {
      guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      let prepared = try await fixture.call(
        "planner_prepare_capture",
        arguments: [
          "formatVersion": 1,
          "inputs": [
            ["kind": "url", "value": "https://maps.apple.com/place?name=Museum"],
            ["kind": "url", "value": "https://example.com/visit"],
          ],
        ])
      let draftIdentifier = try #require(prepared["draftId"] as? String)
      let generation = try #require(prepared["generation"] as? String)
      let links = try #require(prepared["links"] as? [[String: Any]])
      let linkIdentifier = try #require(links.first?["linkId"] as? String)
      let websiteIdentifier = try #require(links.last?["linkId"] as? String)
      let base: [String: Any] = [
        "formatVersion": 1, "draftId": draftIdentifier, "generation": generation,
        "linkId": linkIdentifier,
      ]
      let cases: [(arguments: [String: Any], code: String, path: String?)] = [
        (base.filter { $0.key != "linkId" }, "invalidInput", "/linkId"),
        (
          base.merging(["formatVersion": 2]) { _, replacement in replacement },
          "unsupportedVersion", "/formatVersion"
        ),
        (
          base.merging(["extra/key": true]) { _, replacement in replacement },
          "unknownField", "/extra~1key"
        ),
        (
          base.merging(["draftId": "invalid"]) { _, replacement in replacement },
          "invalidInput", "/draftId"
        ),
        (
          base.merging(["generation": "invalid"]) { _, replacement in replacement },
          "invalidInput", "/generation"
        ),
        (
          base.merging(["linkId": "invalid"]) { _, replacement in replacement },
          "invalidInput", "/linkId"
        ),
        (
          base.merging(["linkId": UUID().uuidString]) { _, replacement in replacement },
          "invalidInput", "/linkId"
        ),
        (
          base.merging(["generation": UUID().uuidString]) { _, replacement in replacement },
          "captureDraftUnavailable", nil
        ),
        (
          base.merging(["draftId": UUID().uuidString]) { _, replacement in replacement },
          "captureDraftUnavailable", nil
        ),
        (
          base.merging(["linkId": websiteIdentifier]) { _, replacement in replacement },
          "invalidInput", "/linkId"
        ),
      ]
      for requestCase in cases {
        let rejected = try await fixture.call(
          "planner_lookup_capture", arguments: requestCase.arguments, isError: true)
        let reason = try #require(rejected["reason"] as? [String: Any])
        #expect(rejected["state"] as? String == "failed")
        #expect(reason["code"] as? String == requestCase.code)
        #expect(reason["propertyPath"] as? String == requestCase.path)
      }
      let current = try await fixture.call(
        "planner_read_capture", arguments: ["formatVersion": 1, "draftId": draftIdentifier])
      #expect(
        current["generation"] as? String == generation && current["saveAllowed"] as? Bool == true)
      #expect((current["preview"] as? [String: Any])?["state"] as? String == "notRequested")
      #expect(await transport.requests.isEmpty)
      guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(before == after)
      await fixture.stop()
    } catch {
      await fixture.stop()
      throw error
    }
  }

  @Test func lookupReturnsTemporaryProviderFieldsAndPreservesOwnedCaptureContent() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerMCPLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = MCPMapsLookupTransport()
    let fixture = try await CaptureHTTPFixture.open(
      directory: directory, captureHTTPTransport: transport)
    do {
      guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      let original =
        "https://maps.apple.com/place?name=Museum&address=Tokyo&coordinate=35,139#original"
      let prepared = try await fixture.call(
        "planner_prepare_capture",
        arguments: [
          "formatVersion": 1,
          "inputs": [["kind": "url", "value": original], ["kind": "text", "value": "My visit"]],
        ])
      let draftIdentifier = try #require(prepared["draftId"] as? String)
      let generation = try #require(prepared["generation"] as? String)
      let links = try #require(prepared["links"] as? [[String: Any]])
      let linkIdentifier = try #require(links.first?["linkId"] as? String)
      let lookedUp = try await fixture.call(
        "planner_lookup_capture",
        arguments: [
          "formatVersion": 1, "draftId": draftIdentifier, "generation": generation,
          "linkId": linkIdentifier,
        ])
      let preview = try #require(lookedUp["preview"] as? [String: Any])
      let candidate = try #require(preview["candidate"] as? [String: Any])
      let coordinate = try #require(candidate["coordinate"] as? [String: Any])
      #expect(
        preview["state"] as? String == "available" && preview["linkId"] as? String == linkIdentifier
      )
      #expect(candidate["provider"] as? String == "appleMaps")
      #expect(candidate["displayName"] as? String == "Museum")
      #expect(candidate["formattedAddress"] as? String == "Tokyo")
      #expect(coordinate["latitude"] as? Double == 35 && coordinate["longitude"] as? Double == 139)
      #expect(candidate["providerReference"] is NSNull)
      #expect((candidate["uncertaintyReasons"] as? [String])?.isEmpty == false)
      #expect(candidate["attributionText"] as? String == "Apple Maps")
      #expect(
        lookedUp["generation"] as? String == generation && lookedUp["saveAllowed"] as? Bool == true)
      #expect(
        try JSONSerialization.data(
          withJSONObject: #require(lookedUp["content"]), options: .sortedKeys)
          == JSONSerialization.data(
            withJSONObject: #require(prepared["content"]), options: .sortedKeys))
      let lookedUpLinks = try #require(lookedUp["links"] as? [[String: Any]])
      #expect(lookedUpLinks.first?["originalUrl"] as? String == original)
      let requests = await transport.requests
      #expect(
        requests.map(\.absoluteString) == [
          "https://maps.apple.com/place?name=Museum&address=Tokyo&coordinate=35,139"
        ])
      guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(before == after)
      await fixture.stop()
    } catch {
      await fixture.stop()
      throw error
    }
  }
}

private actor MCPMapsLookupTransport: PlannerCaptureHTTPTransport {
  private(set) var requests: [URL] = []
  private(set) var responsesDeliveredAfterCancellation = 0
  private let gate: MCPMapsLookupResponseGate?

  init(gate: MCPMapsLookupResponseGate? = nil) { self.gate = gate }

  func waitForRequest() async throws -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while requests.isEmpty, clock.now < deadline {
      try await Task.sleep(for: .milliseconds(5))
    }
    return !requests.isEmpty
  }

  func head(requestURL: URL, timeout: Duration) async throws -> HTTPURLResponse {
    requests.append(requestURL)
    if let gate, !(try await gate.wait(timeout: timeout)) { throw URLError(.timedOut) }
    if Task.isCancelled { responsesDeliveredAfterCancellation += 1 }
    return try #require(
      HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [:]))
  }
}

private actor MCPMapsLookupResponseGate {
  private var released = false

  func wait(timeout: Duration) async throws -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !released, clock.now < deadline {
      try await Task.detached { try await Task.sleep(for: .milliseconds(5)) }.value
    }
    return released
  }

  func release() { released = true }
}
