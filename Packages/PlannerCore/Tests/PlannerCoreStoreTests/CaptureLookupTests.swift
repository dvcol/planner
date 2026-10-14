import Foundation
import PlannerCore
import Testing
import UniformTypeIdentifiers

struct CaptureLookupTests {
  @Test(arguments: [false, true]) @MainActor
  func nativeRetryStopsConcurrentLookupOnlyWhenItPublishesNewInputs(cancelRetry: Bool) async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let original = "https://maps.apple.com/place?name=Museum"
    let loadCount = Progress(totalUnitCount: 2)
    let nativeProgress = Progress(totalUnitCount: 1)
    let nativeGate = CaptureLookupResponseGate()
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      loadCount.completedUnitCount += 1
      if loadCount.completedUnitCount == 1 {
        completion(Data(original.utf8), nil)
        return nil
      }
      Task {
        _ = try? await nativeGate.wait(timeout: .seconds(2))
        completion(Data(original.utf8), nil)
      }
      return nativeProgress
    }
    let lookupGate = CaptureLookupResponseGate()
    let transport = CaptureLookupTransport(responses: [
      .init(statusCode: 200, headerFields: [:], gate: lookupGate)
    ])
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .loaded(loaded)),
      let link = prepared.links.first
    else { throw CancellationError() }
    let retry = Task {
      await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        edit: .init(retryInputIndexes: [0]))
    }
    defer { retry.cancel() }
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while loadCount.completedUnitCount < 2, clock.now < deadline { await Task.yield() }
    try #require(loadCount.completedUnitCount == 2)
    let lookup = Task {
      await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId)
    }
    defer { lookup.cancel() }
    try #require(await transport.waitForRequestCount(1))
    if cancelRetry { retry.cancel() }
    await nativeGate.release()
    let retryResult = await retry.value
    if cancelRetry {
      guard case .rejected = retryResult else { throw CancellationError() }
    } else {
      guard case .draft(let updated) = retryResult else { throw CancellationError() }
      #expect(updated.generation != prepared.generation)
    }
    await lookupGate.release()
    let lookupResult = await lookup.value
    if cancelRetry {
      guard case .draft(let observed) = lookupResult else { throw CancellationError() }
      #expect(observed.preview.candidate?.displayName == "Museum")
      #expect(observed.generation == prepared.generation)
      #expect(await transport.responsesDeliveredAfterCancellation == 0)
    } else {
      guard case .rejected = lookupResult else { throw CancellationError() }
      #expect(await transport.responsesDeliveredAfterCancellation == 1)
    }
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
  }

  @Test(arguments: ["35.0%2C139.0", "restaurants+in+Tokyo%2BJapan"])
  func googleSearchPreviewDescribesIntentWithoutInventingAResolvedPlace(query: String) async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = CaptureLookupTransport()
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    let original = "https://www.google.com/maps/search/?api=1&query=\(query)"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      let link = prepared.links.first,
      case .draft(let observed) = await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId),
      let candidate = observed.preview.candidate,
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(observed.preview.state == .available && candidate.provider == .googleMaps)
    if query == "35.0%2C139.0" {
      #expect(candidate.coordinate == .init(latitude: 35, longitude: 139))
      #expect(candidate.displayName == nil)
    } else {
      #expect(candidate.coordinate == nil && candidate.displayName == "restaurants in Tokyo+Japan")
    }
    #expect(candidate.formattedAddress == nil && candidate.providerReference == nil)
    #expect(!candidate.uncertaintyReasons.isEmpty && candidate.attributionText == "Google Maps")
    #expect(observed.content == prepared.content && observed.content.location == nil)
    #expect(observed.links == prepared.links && observed.links.first?.originalUrl == original)
    #expect(observed.saveAllowed && before == after)
    #expect(await transport.requests.count == 1)
  }

  @Test(arguments: [405, 503])
  func failedHEADRequiresExplicitRetryAndPreservesOwnedEdits(statusCode: Int) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = CaptureLookupTransport(responses: [
      .init(statusCode: statusCode, headerFields: [:]), .init(statusCode: 200, headerFields: [:]),
    ])
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    let original = "https://maps.apple.com/place?name=Museum"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      case .draft(let edited) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        edit: .init(changes: .init(title: .set("My museum")))),
      let link = edited.links.first,
      case .draft(let failed) = await planner.lookupCapture(
        session: session, draftId: edited.draftId, generation: edited.generation,
        linkId: link.linkId),
      case .draft(let read) = await planner.readCapture(session: session, draftId: edited.draftId)
    else { throw CancellationError() }
    #expect(failed.preview.state == .unavailable && read.preview.state == .unavailable)
    #expect(failed.content.title == "My museum" && failed.saveAllowed)
    #expect(await transport.requests.count == 1)
    guard
      case .draft(let retried) = await planner.lookupCapture(
        session: session, draftId: edited.draftId, generation: edited.generation,
        linkId: link.linkId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(retried.preview.candidate?.displayName == "Museum")
    #expect(
      retried.content == edited.content && retried.links == edited.links && retried.saveAllowed)
    #expect(await transport.requests.count == 2)
    #expect(before == after)
  }

  @Test func relativeRedirectResolvesAgainstTheCurrentHop() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = CaptureLookupTransport(responses: [
      .init(statusCode: 303, headerFields: ["Location": "/place?name=Museum"]),
      .init(statusCode: 200, headerFields: [:]),
    ])
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    let original = "https://maps.apple.com/opaque#original"
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      let link = prepared.links.first,
      case .draft(let observed) = await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId)
    else { throw CancellationError() }
    #expect(observed.preview.candidate?.displayName == "Museum")
    #expect(observed.links.first?.originalUrl == original && observed.content == prepared.content)
    let requests = await transport.requests
    #expect(
      requests.map(\.absoluteString) == [
        "https://maps.apple.com/opaque", "https://maps.apple.com/place?name=Museum",
      ])
  }

  @Test(arguments: [
    "https://maps.apple.com/frame?center=35,139",
    "https://maps.apple.com/directions?destination=35,139",
    "https://maps.apple.com/place?place-id=my-location",
    "https://maps.apple.com/place?place-id=parked-car",
    "https://maps.apple.com/place?coordinate=NaN,139",
    "https://maps.apple.com/place?coordinate=91,139",
    "https://maps.apple.com/place?coordinate=35,139&coordinate=36,140",
    "https://www.google.com/maps/search/?query=35,139",
    "https://www.google.com/maps/search/?api=1&api=2&query=35,139",
    "https://www.google.com/maps/search/?api=1&query=35,139&query=36,140",
    "https://www.google.com/maps/@?api=1&map_action=map&center=35,139",
  ])
  func unsupportedOrAmbiguousPlaceIntentRemainsAnUnchangedUsableBookmark(original: String)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = CaptureLookupTransport()
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      let link = prepared.links.first,
      case .draft(let observed) = await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(observed.preview.state == .unavailable && observed.preview.candidate == nil)
    #expect(observed.content == prepared.content && observed.links == prepared.links)
    #expect(
      observed.saveAllowed && observed.links.first?.originalUrl == original && before == after)
    #expect(await transport.requests.count == 1)
  }

  @Test @MainActor
  func cancellingNativeInputRetryClearsItsObsoleteLookupIndicator() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let original = "https://maps.apple.com/place?name=Museum"
    let loadCount = Progress(totalUnitCount: 2)
    let nativeRetryProgress = Progress(totalUnitCount: 1)
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      loadCount.completedUnitCount += 1
      if loadCount.completedUnitCount == 1 {
        completion(Data(original.utf8), nil)
        return nil
      }
      return nativeRetryProgress
    }
    let gate = CaptureLookupResponseGate()
    let transport = CaptureLookupTransport(responses: [
      .init(statusCode: 200, headerFields: [:], gate: gate)
    ])
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .loaded(loaded)),
      let link = prepared.links.first
    else { throw CancellationError() }
    let lookup = Task {
      await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId)
    }
    defer { lookup.cancel() }
    try #require(await transport.waitForRequestCount(1))
    let retry = Task {
      await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        edit: .init(retryInputIndexes: [0]))
    }
    defer { retry.cancel() }
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while loadCount.completedUnitCount < 2, clock.now < deadline { await Task.yield() }
    try #require(loadCount.completedUnitCount == 2)
    retry.cancel()
    guard case .rejected(let retryFailure) = await retry.value else { throw CancellationError() }
    await gate.release()
    guard case .rejected = await lookup.value,
      case .draft(let current) = await planner.readCapture(
        session: session, draftId: prepared.draftId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(retryFailure.code == "captureDraftUnavailable" && nativeRetryProgress.isCancelled)
    #expect(current.preview.state == .unavailable && current.preview.candidate == nil)
    #expect(current.generation == prepared.generation && current.links == prepared.links)
    #expect(current.content == prepared.content && current.saveAllowed && before == after)
  }

  @Test func savingWhileLookupIsPendingKeepsTheOriginalAndRejectsLatePreview() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let gate = CaptureLookupResponseGate()
    let transport = CaptureLookupTransport(responses: [
      .init(statusCode: 200, headerFields: [:], gate: gate)
    ])
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    let original = "https://maps.apple.com/place?name=Museum&coordinate=35,139"
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      let link = prepared.links.first
    else { throw CancellationError() }
    let lookup = Task {
      await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId)
    }
    defer { lookup.cancel() }
    try #require(await transport.waitForRequestCount(1))
    guard
      case .draft(let loading) = await planner.readCapture(
        session: session, draftId: prepared.draftId),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyCapture(
          draftId: prepared.draftId, draftGeneration: prepared.generation,
          choice: .createNew, listIds: [])),
      case .applied(let result, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      let item = result.generated.first,
      case .source(.item(let saved)) = await planner.read(session: session, request: .source(item)),
      case .exported(let beforeLateResult) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(loading.preview.state == .loading && loading.saveAllowed)
    #expect(saved.content.links.map(\.originalUrl) == [original])
    #expect(saved.content.location == nil && saved.content.title == prepared.content.title)
    await gate.release()
    guard case .rejected(let reason) = await lookup.value,
      case .rejected = await planner.readCapture(session: session, draftId: prepared.draftId),
      case .exported(let afterLateResult) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(reason.code == "captureDraftUnavailable")
    #expect(beforeLateResult == afterLateResult)
    #expect(await transport.responsesDeliveredAfterCancellation == 1)
  }

  @Test(arguments: ["edit", "discard", "parentCancellation"])
  func draftChangesAndCancellationCannotPublishAnObsoleteLookup(action: String) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let gate = CaptureLookupResponseGate()
    let transport = CaptureLookupTransport(responses: [
      .init(statusCode: 200, headerFields: [:], gate: gate)
    ])
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url("https://maps.apple.com/place?name=Museum")])),
      let link = prepared.links.first
    else { throw CancellationError() }
    let lookup = Task {
      await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId)
    }
    defer { lookup.cancel() }
    try #require(await transport.waitForRequestCount(1))
    if action == "edit" {
      guard
        case .draft = await planner.updateCapture(
          session: session, draftId: prepared.draftId, generation: prepared.generation,
          edit: .init(changes: .init(title: .set("Edited"))))
      else { throw CancellationError() }
    } else if action == "discard" {
      guard
        case .cancelled = await planner.cancelCapture(
          session: session, draftId: prepared.draftId, generation: prepared.generation)
      else { throw CancellationError() }
    } else {
      lookup.cancel()
    }
    await gate.release()
    guard case .rejected(let reason) = await lookup.value,
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(reason.code == "captureDraftUnavailable")
    #expect(before == after)
    #expect(await transport.responsesDeliveredAfterCancellation == 1)
    let current = await planner.readCapture(session: session, draftId: prepared.draftId)
    if action == "discard" {
      guard case .rejected = current else { throw CancellationError() }
    } else {
      guard case .draft(let draft) = current else { throw CancellationError() }
      #expect(
        draft.preview.state != .loading && draft.preview.candidate == nil && draft.saveAllowed)
      if action == "edit" {
        #expect(draft.content.title == "Edited")
      } else {
        #expect(draft.content == prepared.content && draft.links == prepared.links)
      }
    }
  }

  @Test func newerLookupKeepsItsSelectionWhenAnOlderResultArrives() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let gate = CaptureLookupResponseGate()
    let transport = CaptureLookupTransport(responses: [
      .init(statusCode: 200, headerFields: [:], gate: gate),
      .init(statusCode: 200, headerFields: [:]),
    ])
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session,
        input: .direct([
          .url("https://maps.apple.com/place?name=First"),
          .url("https://maps.apple.com/place?name=Second"),
        ]))
    else { throw CancellationError() }
    let firstLink = try #require(prepared.links.first)
    let secondLink = try #require(prepared.links.last)
    let firstLookup = Task {
      await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: firstLink.linkId)
    }
    defer { firstLookup.cancel() }
    try #require(await transport.waitForRequestCount(1))
    guard
      case .draft(let loading) = await planner.readCapture(
        session: session, draftId: prepared.draftId)
    else { throw CancellationError() }
    #expect(loading.preview.state == .loading && loading.preview.linkId == firstLink.linkId)
    #expect(loading.saveAllowed && loading.content == prepared.content)
    guard
      case .draft(let second) = await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: secondLink.linkId)
    else { throw CancellationError() }
    #expect(second.preview.candidate?.displayName == "Second")
    await gate.release()
    let firstResult = await firstLookup.value
    if case .rejected(let reason) = firstResult {
      #expect(reason.code == "captureDraftUnavailable")
    } else {
      Issue.record("A superseded lookup must not publish its old result.")
    }
    guard
      case .draft(let current) = await planner.readCapture(
        session: session, draftId: prepared.draftId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(
      current.preview.linkId == secondLink.linkId
        && current.preview.candidate?.displayName == "Second")
    #expect(
      current.content == prepared.content && current.links == prepared.links && before == after)
    #expect(await transport.responsesDeliveredAfterCancellation == 1)
  }

  @Test func overallDeadlineReducesTheFinalRequestBudgetAndKeepsTheBookmarkUsable() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = CaptureLookupTransport(responses: [
      .init(
        statusCode: 301, headerFields: ["Location": "https://maps.apple/hop1"], delay: .seconds(3)),
      .init(
        statusCode: 301, headerFields: ["Location": "https://maps.apple.com/place?name=Museum"],
        delay: .seconds(3)),
      .init(statusCode: 200, headerFields: [:], delay: .seconds(3)),
    ])
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    let original = "https://maps.apple/hop0"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      let link = prepared.links.first,
      case .draft(let observed) = await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let timeouts = await transport.timeouts
    try #require(timeouts.count == 3)
    #expect(timeouts[0] == .seconds(4) && timeouts[1] == .seconds(4))
    #expect(timeouts[2] > .zero && timeouts[2] <= .seconds(2))
    #expect(observed.preview.state == .unavailable && observed.preview.candidate == nil)
    #expect(observed.links == prepared.links && observed.links.first?.originalUrl == original)
    #expect(observed.content == prepared.content && observed.saveAllowed && before == after)
  }

  @Test(
    arguments: [
      nil, "", "https://maps.apple/opaque#again", "https://example.com/place",
      "https://maps.apple.com.attacker.test/place", "http://maps.apple.com/place",
      "https://www.google.com/search?q=Museum",
    ] as [String?])
  func unusableRedirectStopsBeforeAnotherRequestAndKeepsPartialCapture(location: String?)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    var headerFields: [String: String] = [:]
    if let location { headerFields["Location"] = location }
    let transport = CaptureLookupTransport(responses: [
      .init(statusCode: 301, headerFields: headerFields)
    ])
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    let original = "https://maps.apple/opaque"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      let link = prepared.links.first,
      case .draft(let observed) = await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(observed.preview.state == .unavailable && observed.preview.candidate == nil)
    #expect(await transport.requests.count == 1)
    #expect(observed.links == prepared.links && observed.links.first?.originalUrl == original)
    #expect(observed.content == prepared.content && observed.saveAllowed && before == after)
  }

  @Test(arguments: [5, 6])
  func redirectBudgetAllowsFiveHopsAndNeverIssuesASeventhRequest(redirectCount: Int) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let destination = "https://maps.apple.com/place?name=Museum"
    var responses = (1...redirectCount).map { index in
      let location: String
      if index == redirectCount {
        location = destination
      } else {
        location = "https://maps.apple/hop\(index)"
      }
      return CaptureLookupHTTPResponse(statusCode: 301, headerFields: ["Location": location])
    }
    responses.append(.init(statusCode: 200, headerFields: [:]))
    let transport = CaptureLookupTransport(responses: responses)
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    let original = "https://maps.apple/hop0"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      let link = prepared.links.first,
      case .draft(let observed) = await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    if redirectCount == 5 {
      #expect(
        observed.preview.state == .available && observed.preview.candidate?.displayName == "Museum")
    } else {
      #expect(observed.preview.state == .unavailable && observed.preview.candidate == nil)
    }
    #expect(await transport.requests.count == 6)
    #expect(observed.links == prepared.links && observed.links.first?.originalUrl == original)
    #expect(observed.content == prepared.content && observed.saveAllowed && before == after)
  }

  @Test func allowedShortLinkRedirectKeepsTheOriginalBookmarkAndUsesExplicitHEADHops() async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let destination = "https://maps.apple.com/place?name=Museum&coordinate=35,139"
    let transport = CaptureLookupTransport(responses: [
      .init(statusCode: 301, headerFields: ["Location": destination]),
      .init(statusCode: 200, headerFields: [:]),
    ])
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    let original = "https://maps.apple/opaque?keep=%41#bookmark"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      let link = prepared.links.first,
      case .draft(let observed) = await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(
      observed.preview.state == .available && observed.preview.candidate?.displayName == "Museum")
    #expect(observed.links == prepared.links && observed.links.first?.originalUrl == original)
    #expect(observed.content == prepared.content && observed.saveAllowed && before == after)
    let requests = await transport.requests
    #expect(requests.map(\.absoluteString) == ["https://maps.apple/opaque?keep=%41", destination])
    let timeouts = await transport.timeouts
    #expect(timeouts == [.seconds(4), .seconds(4)])
  }

  @Test func documentedHTTPSPlaceLookupKeepsProviderPreviewSeparateFromSavedContent() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = CaptureLookupTransport()
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    let original =
      "https://maps.apple.com/place?name=Museum&coordinate=35,139&address=Tokyo#bookmark"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      let link = prepared.links.first,
      case .draft(let observed) = await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(observed.preview.state == .available)
    #expect(observed.preview.candidate?.displayName == "Museum")
    #expect(observed.preview.candidate?.formattedAddress == "Tokyo")
    #expect(observed.preview.candidate?.coordinate == .init(latitude: 35, longitude: 139))
    #expect(observed.content == prepared.content && observed.content.location == nil)
    #expect(observed.links == prepared.links && observed.links.first?.originalUrl == original)
    #expect(observed.generation == prepared.generation && observed.saveAllowed && before == after)
    let requests = await transport.requests
    #expect(
      requests.map(\.absoluteString) == [
        "https://maps.apple.com/place?name=Museum&coordinate=35,139&address=Tokyo"
      ])
  }

  @Test(arguments: ["website", "foreignLink", "staleGeneration"])
  func rejectedLookupLeavesTheCurrentCaptureAndSavedDataUnchanged(scenario: String) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let planner = Planner(configuration: captureLookupConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session,
        input: .direct([
          .url("http://maps.apple.com/?q=Museum"), .url("https://example.com/visit"),
        ]))
    else { throw CancellationError() }
    var linkId = try #require(prepared.links.first?.linkId)
    var generation = prepared.generation
    if scenario == "website" {
      linkId = try #require(prepared.links.last?.linkId)
    } else if scenario == "foreignLink" {
      linkId = UUID()
    } else {
      generation = UUID()
    }
    guard
      case .rejected(let failure) = await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: generation, linkId: linkId),
      case .draft(let current) = await planner.readCapture(
        session: session, draftId: prepared.draftId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    if scenario == "staleGeneration" {
      #expect(failure.code == "captureDraftUnavailable")
    } else {
      #expect(failure.code == "invalidInput" && failure.propertyPath == "/linkId")
    }
    #expect(current.generation == prepared.generation && current.links == prepared.links)
    #expect(current.preview.state == .notRequested && current.content == prepared.content)
    #expect(current.saveAllowed && before == after)
  }

  @Test func httpMapsBookmarkRemainsUsableWithoutNetworkLookup() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureLookupTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = CaptureLookupTransport()
    let planner = Planner(
      configuration: captureLookupConfiguration(directory), captureHTTPTransport: transport)
    let original = "http://maps.apple.com/?q=Museum"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      let link = prepared.links.first,
      case .draft(let observed) = await planner.lookupCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        linkId: link.linkId),
      case .draft(let current) = await planner.readCapture(
        session: session, draftId: prepared.draftId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(observed.preview.state == .unavailable && observed.preview.candidate == nil)
    #expect(observed.preview.linkId == link.linkId && current.preview.state == .unavailable)
    #expect(observed.links == prepared.links && observed.links.first?.originalUrl == original)
    #expect(observed.content == prepared.content && observed.saveAllowed && before == after)
    #expect(await transport.requests.isEmpty)
  }
}

private actor CaptureLookupTransport: PlannerCaptureHTTPTransport {
  private(set) var requests: [URL] = []
  private(set) var timeouts: [Duration] = []
  private(set) var responsesDeliveredAfterCancellation = 0
  private var responses: [CaptureLookupHTTPResponse]

  init(responses: [CaptureLookupHTTPResponse] = []) {
    self.responses = responses
  }

  func waitForRequestCount(_ count: Int) async throws -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while requests.count < count, clock.now < deadline {
      try await Task.sleep(for: .milliseconds(5))
    }
    return requests.count >= count
  }

  func head(requestURL: URL, timeout: Duration) async throws -> HTTPURLResponse {
    requests.append(requestURL)
    timeouts.append(timeout)
    let response: CaptureLookupHTTPResponse
    if responses.isEmpty {
      response = .init(statusCode: 200, headerFields: [:])
    } else {
      response = responses.removeFirst()
    }
    if let gate = response.gate, !(try await gate.wait(timeout: timeout)) {
      throw URLError(.timedOut)
    }
    if response.delay > .zero {
      try await Task.sleep(for: min(response.delay, timeout))
      if response.delay >= timeout { throw URLError(.timedOut) }
    }
    if Task.isCancelled { responsesDeliveredAfterCancellation += 1 }
    return try #require(
      HTTPURLResponse(
        url: requestURL, statusCode: response.statusCode, httpVersion: "HTTP/1.1",
        headerFields: response.headerFields))
  }
}

private struct CaptureLookupHTTPResponse: Sendable {
  let statusCode: Int
  let headerFields: [String: String]
  let delay: Duration
  let gate: CaptureLookupResponseGate?

  init(
    statusCode: Int, headerFields: [String: String], delay: Duration = .zero,
    gate: CaptureLookupResponseGate? = nil
  ) {
    self.statusCode = statusCode
    self.headerFields = headerFields
    self.delay = delay
    self.gate = gate
  }
}

private actor CaptureLookupResponseGate {
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

private func captureLookupConfiguration(_ directory: URL) -> PlannerStorageConfiguration {
  .init(
    storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
    controlURL: directory.appendingPathComponent("control/writer"),
    recoveryDirectoryURL: directory.appendingPathComponent("recovery", isDirectory: true),
    processRole: .mainApplication, storageMode: .localOnly)
}
