import Foundation
import PlannerPreviews
import Testing

@MainActor
struct LinkPreviewTests {
  @Test func unicodeEquivalentURLPathsKeepTheirOwnPreviewResults() async {
    let source = PlannerPreviewSource(
      namespace: "local-dataset", sourceId: UUID(), sourceLifetimeId: UUID())
    let linkIdentifier = UUID()
    let composed = PlannerLinkPreviewRequest(
      source: source, linkId: linkIdentifier, originalURL: "https://example.com/caf\u{00E9}")
    let decomposed = PlannerLinkPreviewRequest(
      source: source, linkId: linkIdentifier, originalURL: "https://example.com/cafe\u{0301}")
    let firstContent = PlannerLinkPreviewContent(title: "First resource", imageData: Data([1]))
    let secondContent = PlannerLinkPreviewContent(title: "Second resource", imageData: Data([2]))
    let provider = RecordingLinkProvider(content: firstContent)
    let previews = PlannerPreviews(provider: provider)

    await previews.loadLink(composed)
    provider.content = secondContent
    #expect(previews.linkState(for: decomposed) == .idle)
    await previews.loadLink(decomposed)
    #expect(previews.linkState(for: composed) == .available(firstContent))
    #expect(previews.linkState(for: decomposed) == .available(secondContent))
    #expect(
      provider.requestedURLs.map { URL(string: $0)?.absoluteString } == [
        "https://example.com/caf%C3%A9", "https://example.com/cafe%CC%81",
      ])
  }

  @Test func aVisibleLinkLoadsAnImageAndSharesTheCachedResultOnlyWithItsExactRequest() async {
    let source = PlannerPreviewSource(
      namespace: "local-dataset", sourceId: UUID(), sourceLifetimeId: UUID())
    let request = PlannerLinkPreviewRequest(
      source: source, linkId: UUID(), originalURL: "https://example.com/menu?lang=en#food")
    let content = PlannerLinkPreviewContent(title: "Menu preview", imageData: Data([1, 2, 3]))
    let provider = RecordingLinkProvider(content: content)
    let previews = PlannerPreviews(provider: provider)

    #expect(previews.linkState(for: request) == .idle)
    #expect(provider.requestedURLs.isEmpty)
    await previews.loadLink(request)
    #expect(previews.linkState(for: request) == .available(content))
    #expect(provider.requestedURLs == ["https://example.com/menu?lang=en#food"])
    await previews.loadLink(request)
    #expect(provider.requestedURLs.count == 1)
    let differentBookmark = PlannerLinkPreviewRequest(
      source: source, linkId: UUID(), originalURL: request.originalURL)
    #expect(previews.linkState(for: differentBookmark) == .idle)
  }

  @Test func aLinkWithoutAnImageStaysAvailableAndAFailedProviderCanBeRetried() async {
    let request = PlannerLinkPreviewRequest(
      source: .init(namespace: "local-dataset", sourceId: UUID(), sourceLifetimeId: UUID()),
      linkId: UUID(), originalURL: "https://example.com/plain")
    let content = PlannerLinkPreviewContent(title: "Plain page", imageData: nil)
    let provider = RecoveringLinkProvider(content: content)
    let previews = PlannerPreviews(provider: provider)

    await previews.loadLink(request)
    #expect(previews.linkState(for: request) == .unavailable)
    #expect(request.originalURL == "https://example.com/plain")
    await previews.loadLink(request)
    #expect(provider.requestedURLs.count == 1)
    await previews.retryLink(request)
    #expect(previews.linkState(for: request) == .available(content))
    #expect(provider.requestedURLs == ["https://example.com/plain", "https://example.com/plain"])
  }

  @Test(arguments: ["url", "namespace", "lifetime"])
  func aLateResponseCannotReplaceAChangedRequest(_ changedValue: String) async {
    let originalSource = PlannerPreviewSource(
      namespace: "old-dataset", sourceId: UUID(), sourceLifetimeId: UUID())
    let linkIdentifier = UUID()
    let original = PlannerLinkPreviewRequest(
      source: originalSource, linkId: linkIdentifier, originalURL: "https://example.com/old")
    var currentSource = originalSource
    var currentURL = original.originalURL
    if changedValue == "url" {
      currentURL = "https://example.com/current"
    } else if changedValue == "namespace" {
      currentSource = PlannerPreviewSource(
        namespace: "current-dataset", sourceId: originalSource.sourceId,
        sourceLifetimeId: originalSource.sourceLifetimeId)
    } else {
      currentSource = PlannerPreviewSource(
        namespace: originalSource.namespace, sourceId: originalSource.sourceId,
        sourceLifetimeId: UUID())
    }
    let current = PlannerLinkPreviewRequest(
      source: currentSource, linkId: linkIdentifier, originalURL: currentURL)
    let provider = DelayedLinkProvider()
    let previews = PlannerPreviews(provider: provider)
    let oldLoad = Task { await previews.loadLink(original) }
    await provider.waitForRequests(1)
    #expect(previews.linkState(for: original) == .loading)
    #expect(previews.linkState(for: current) == .idle)
    let newLoad = Task { await previews.loadLink(current) }
    await provider.waitForRequests(2)
    #expect(previews.linkState(for: current) == .loading)
    await previews.loadLink(current)
    #expect(provider.requestCount == 2)
    let currentContent = PlannerLinkPreviewContent(title: "Current", imageData: Data([4, 5, 6]))
    provider.completeRequest(1, with: currentContent)
    await newLoad.value
    #expect(previews.linkState(for: current) == .available(currentContent))
    let oldContent = PlannerLinkPreviewContent(title: "Old", imageData: Data([1, 2, 3]))
    provider.completeRequest(0, with: oldContent)
    await oldLoad.value
    #expect(previews.linkState(for: current) == .available(currentContent))
    #expect(previews.linkState(for: original) == .available(oldContent))
  }

  @Test func aDisappearingRowDoesNotCancelThePreviewRequestedByItsDetail() async {
    let request = PlannerLinkPreviewRequest(
      source: .init(namespace: "local-dataset", sourceId: UUID(), sourceLifetimeId: UUID()),
      linkId: UUID(), originalURL: "https://example.com/shared")
    let provider = DelayedLinkProvider()
    let previews = PlannerPreviews(provider: provider)
    let disappearingRow = Task { await previews.loadLink(request) }
    await provider.waitForRequests(1)
    disappearingRow.cancel()
    await previews.loadLink(request)
    #expect(provider.requestCount == 1)
    #expect(previews.linkState(for: request) == .loading)
    let content = PlannerLinkPreviewContent(title: "Shared preview", imageData: Data([1, 2, 3]))
    provider.completeRequest(0, with: content)
    await disappearingRow.value
    #expect(previews.linkState(for: request) == .available(content))
  }
}

@MainActor
private final class RecordingLinkProvider: PlannerLinkPreviewProvider {
  var content: PlannerLinkPreviewContent
  private(set) var requestedURLs: [String] = []

  init(content: PlannerLinkPreviewContent) { self.content = content }

  func linkPreview(for originalURL: String) async throws -> PlannerLinkPreviewContent {
    requestedURLs.append(originalURL)
    return content
  }
}

@MainActor
private final class RecoveringLinkProvider: PlannerLinkPreviewProvider {
  enum Failure: Error { case offline }
  let content: PlannerLinkPreviewContent
  private(set) var requestedURLs: [String] = []

  init(content: PlannerLinkPreviewContent) { self.content = content }

  func linkPreview(for originalURL: String) async throws -> PlannerLinkPreviewContent {
    requestedURLs.append(originalURL)
    if requestedURLs.count == 1 { throw Failure.offline }
    return content
  }
}

@MainActor
private final class DelayedLinkProvider: PlannerLinkPreviewProvider {
  private var responses: [CheckedContinuation<PlannerLinkPreviewContent, any Error>] = []
  private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
  var requestCount: Int { responses.count }

  func linkPreview(for originalURL: String) async throws -> PlannerLinkPreviewContent {
    let content: PlannerLinkPreviewContent = try await withCheckedThrowingContinuation {
      continuation in
      responses.append(continuation)
      let ready = waiters.filter { $0.count <= responses.count }
      waiters.removeAll { $0.count <= responses.count }
      for waiter in ready { waiter.continuation.resume() }
    }
    try Task.checkCancellation()
    return content
  }

  func waitForRequests(_ count: Int) async {
    guard responses.count < count else { return }
    await withCheckedContinuation { waiters.append((count, $0)) }
  }

  func completeRequest(_ index: Int, with content: PlannerLinkPreviewContent) {
    responses[index].resume(returning: content)
  }
}
