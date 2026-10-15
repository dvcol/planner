import Foundation
import PlannerCore
import PlannerPreviews
import Testing

@MainActor
struct MapsPreviewTests {
  @Test(arguments: ["url-bytes", "fragment", "namespace", "source", "lifetime", "link"])
  func changingAnyRequestIdentityRequiresItsOwnLookup(_ changedField: String) async throws {
    let original = PlannerLinkPreviewRequest(
      source: .init(namespace: "original-dataset", sourceId: UUID(), sourceLifetimeId: UUID()),
      linkId: UUID(), originalURL: "https://maps.apple.com/place?name=Caf\u{00E9}")
    var source = original.source
    var linkIdentifier = original.linkId
    var originalURL = original.originalURL
    switch changedField {
    case "url-bytes": originalURL = "https://maps.apple.com/place?name=Cafe\u{0301}"
    case "fragment": originalURL += "#changed"
    case "namespace":
      source = .init(
        namespace: "different-dataset", sourceId: source.sourceId,
        sourceLifetimeId: source.sourceLifetimeId)
    case "source":
      source = .init(
        namespace: source.namespace, sourceId: UUID(), sourceLifetimeId: source.sourceLifetimeId)
    case "lifetime":
      source = .init(
        namespace: source.namespace, sourceId: source.sourceId, sourceLifetimeId: UUID())
    default: linkIdentifier = UUID()
    }
    let changed = PlannerLinkPreviewRequest(
      source: source, linkId: linkIdentifier, originalURL: originalURL)
    let candidate = try #require(
      await PlannerMapsLinkResolver().preview(
        originalURL: "https://maps.apple.com/place?name=Museum&coordinate=35,139"))
    let provider = RecordingMapsPreviewProvider(candidate: candidate)
    let previews = PlannerMapsPreviews(provider: provider)
    _ = await previews.load(original)
    _ = await previews.load(changed)
    _ = await previews.load(original)
    #expect(provider.requestedURLs.count == 2)
    #expect(provider.requestedURLs.last?.utf8.elementsEqual(originalURL.utf8) == true)
  }

  @Test func anUnavailablePreviewIsCachedUntilExplicitRetry() async throws {
    let request = mapsRequest()
    let provider = RecordingMapsPreviewProvider(candidate: nil)
    let previews = PlannerMapsPreviews(provider: provider)
    guard case .unavailable = await previews.load(request) else {
      Issue.record("A failed provider should produce the link fallback")
      return
    }
    provider.candidate = try #require(
      await PlannerMapsLinkResolver().preview(
        originalURL: "https://maps.apple.com/place?name=Recovered&coordinate=35,139"))
    guard case .unavailable = await previews.load(request) else {
      Issue.record("Reappearance must not automatically retry a failed lookup")
      return
    }
    #expect(provider.requestedURLs.count == 1)
    guard case .available(let recovered) = await previews.retry(request) else {
      Issue.record("Explicit Retry should recover")
      return
    }
    #expect(recovered.displayName == "Recovered")
    #expect(provider.requestedURLs.count == 2)
  }

  @Test func anObsoleteResponseDoesNotStartAnotherLookupWhileRetryIsPending() async throws {
    let request = mapsRequest()
    let provider = DelayedMapsPreviewProvider()
    let previews = PlannerMapsPreviews(provider: provider)
    let oldLoad = Task { await previews.load(request) }
    await provider.waitForRequests(1)
    let retry = Task { await previews.retry(request) }
    await provider.waitForRequests(2)
    provider.completeRequest(0, with: nil)
    #expect(await oldLoad.value == nil)
    let current = try #require(
      await PlannerMapsLinkResolver().preview(
        originalURL: "https://maps.apple.com/place?coordinate=36,140&name=Current"))
    provider.completeRequest(1, with: current)
    guard case .available(let result) = await retry.value else {
      Issue.record("Explicit Retry must still finish")
      return
    }
    #expect(result.displayName == "Current")
    #expect(provider.requestCount == 2)
  }

  @Test func retrySupersedesAnOlderResponseForTheSameBookmark() async throws {
    let request = mapsRequest()
    let provider = DelayedMapsPreviewProvider()
    let previews = PlannerMapsPreviews(provider: provider)
    let oldLoad = Task { await previews.load(request) }
    await provider.waitForRequests(1)
    let retry = Task { await previews.retry(request) }
    await provider.waitForRequests(2)
    let current = try #require(
      await PlannerMapsLinkResolver().preview(
        originalURL: "https://maps.apple.com/place?coordinate=36,140&name=Current"))
    provider.completeRequest(1, with: current)
    guard case .available(let retried) = await retry.value else {
      Issue.record("Retry must return the current preview")
      return
    }
    #expect(retried.displayName == "Current")
    provider.completeRequest(0, with: nil)
    #expect(await oldLoad.value == nil)
    guard case .available(let cached) = await previews.load(request) else {
      Issue.record("A late failure must not replace the current preview")
      return
    }
    #expect(cached.coordinate?.latitude == 36)
    #expect(provider.requestCount == 2)
  }

  @Test func cancellationDiscardsALateResponseWithoutCancellingAnotherWindow() async throws {
    let request = mapsRequest()
    let provider = DelayedMapsPreviewProvider()
    let previews = PlannerMapsPreviews(provider: provider)
    let disappearingWindow = Task { await previews.load(request) }
    await provider.waitForRequests(1)
    disappearingWindow.cancel()
    let survivingWindow = Task { await previews.load(request) }
    await provider.waitForRequests(2)
    let outdated = try #require(
      await PlannerMapsLinkResolver().preview(
        originalURL: "https://maps.apple.com/place?coordinate=35,139&name=Outdated"))
    provider.completeRequest(0, with: outdated)
    #expect(await disappearingWindow.value == nil)
    let current = try #require(
      await PlannerMapsLinkResolver().preview(
        originalURL: "https://maps.apple.com/place?coordinate=36,140&name=Current"))
    provider.completeRequest(1, with: current)
    guard case .available(let result) = await survivingWindow.value else {
      Issue.record("The surviving window must receive its own preview")
      return
    }
    #expect(result.displayName == "Current")
    #expect(result.coordinate?.latitude == 36)
    guard case .available(let cached) = await previews.load(request) else {
      Issue.record("The active preview should be cached")
      return
    }
    #expect(cached.displayName == "Current")
    #expect(provider.requestCount == 2)
  }

  @Test func savedLinkPreviewIsTemporaryAndReusesOnlyItsExactRequest() async throws {
    let originalURL =
      "https://www.google.com/maps/search/?api=1&query=35.6804%2C139.7690#original-fragment"
    let candidate = try #require(await PlannerMapsLinkResolver().preview(originalURL: originalURL))
    let request = PlannerLinkPreviewRequest(
      source: .init(namespace: "local-dataset", sourceId: UUID(), sourceLifetimeId: UUID()),
      linkId: UUID(), originalURL: originalURL)
    let provider = RecordingMapsPreviewProvider(candidate: candidate)
    let previews = PlannerMapsPreviews(provider: provider)

    let result = await previews.load(request)
    guard case .available(let preview) = result else {
      Issue.record("Expected a temporary Maps preview")
      return
    }
    #expect(preview.coordinate?.latitude == 35.6804)
    #expect(preview.coordinate?.longitude == 139.7690)
    #expect(preview.provider == .googleMaps)
    #expect(preview.formattedAddress == nil)
    #expect(request.originalURL.utf8.elementsEqual(originalURL.utf8))
    _ = await previews.load(request)
    #expect(provider.requestedURLs == [originalURL])
    let anotherLink = PlannerLinkPreviewRequest(
      source: request.source, linkId: UUID(), originalURL: originalURL)
    _ = await previews.load(anotherLink)
    #expect(provider.requestedURLs.count == 2)
  }
}

@MainActor
private func mapsRequest() -> PlannerLinkPreviewRequest {
  .init(
    source: .init(namespace: "local-dataset", sourceId: UUID(), sourceLifetimeId: UUID()),
    linkId: UUID(), originalURL: "https://maps.apple/short-preview")
}

@MainActor
private final class RecordingMapsPreviewProvider: PlannerMapsPreviewProvider {
  var candidate: PlannerCapturePreviewCandidate?
  private(set) var requestedURLs: [String] = []

  init(candidate: PlannerCapturePreviewCandidate?) { self.candidate = candidate }

  func mapsPreview(for originalURL: String) async -> PlannerCapturePreviewCandidate? {
    requestedURLs.append(originalURL)
    return candidate
  }
}

@MainActor
private final class DelayedMapsPreviewProvider: PlannerMapsPreviewProvider {
  private var responses: [CheckedContinuation<PlannerCapturePreviewCandidate?, Never>] = []
  private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
  var requestCount: Int { responses.count }

  func mapsPreview(for originalURL: String) async -> PlannerCapturePreviewCandidate? {
    guard responses.count < 2 else {
      Issue.record("An obsolete response started an unrequested third lookup")
      return nil
    }
    return await withCheckedContinuation { continuation in
      responses.append(continuation)
      let ready = waiters.filter { $0.count <= responses.count }
      waiters.removeAll { $0.count <= responses.count }
      for waiter in ready { waiter.continuation.resume() }
    }
  }

  func waitForRequests(_ count: Int) async {
    guard responses.count < count else { return }
    await withCheckedContinuation { waiters.append((count, $0)) }
  }

  func completeRequest(_ index: Int, with candidate: PlannerCapturePreviewCandidate?) {
    responses[index].resume(returning: candidate)
  }
}
