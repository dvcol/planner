import Foundation
import PlannerCore
import PlannerPreviews

@MainActor
enum PlannerSavedMapsFixture {
  static let delayedURL = "https://maps.apple.com/place?name=Delayed&coordinate=35,139"
  static let currentURL = "https://maps.apple.com/place?name=Current&coordinate=36,140"
  static let retryURL = "https://maps.apple.com/place?name=Retry&coordinate=35,139"

  static func seed(
    _ planner: PlannerCore.Planner, session: PlannerDatasetSession, usesRetry: Bool
  ) async throws {
    let links: [PlannerLinkInput]
    if usesRetry {
      links = [.init(originalUrl: retryURL, label: "Saved map")]
    } else {
      links = [
        .init(originalUrl: delayedURL, label: "Delayed place"),
        .init(originalUrl: currentURL, label: "Current place"),
      ]
    }
    let result = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .createItem(
          content: .init(
            title: usesRetry ? "Retry map" : "Delayed map", notes: "Owned map notes",
            links: links))))
    guard case .applied(_, .complete) = result.outcome else { throw CancellationError() }
  }
}

@MainActor
final class FixtureMapsPreviewProvider: PlannerMapsPreviewProvider {
  private let nativeProvider = NativeMapsPreviewProvider()
  private var retryAttempts = 0
  private var pendingPreviewContinuation:
    CheckedContinuation<PlannerCapturePreviewCandidate?, Never>?

  func mapsPreview(for originalURL: String) async -> PlannerCapturePreviewCandidate? {
    if originalURL == PlannerSavedMapsFixture.delayedURL {
      return await withCheckedContinuation { continuation in
        guard pendingPreviewContinuation == nil else {
          continuation.resume(returning: nil)
          return
        }
        pendingPreviewContinuation = continuation
      }
    }
    if originalURL == PlannerSavedMapsFixture.retryURL {
      retryAttempts += 1
      guard retryAttempts > 1 else { return nil }
      let name = retryAttempts == 2 ? "Recovered" : "Unrequested lookup"
      return await nativeProvider.mapsPreview(
        for: "https://maps.apple.com/place?name=\(name)&coordinate=35,139")
    }
    if originalURL == PlannerSavedMapsFixture.currentURL {
      guard let continuation = pendingPreviewContinuation else {
        return await nativeProvider.mapsPreview(
          for: "https://maps.apple.com/place?name=Reopened&coordinate=36,140")
      }
      pendingPreviewContinuation = nil
      let obsolete = await nativeProvider.mapsPreview(
        for: "https://maps.apple.com/place?name=Outdated&coordinate=35,139")
      continuation.resume(returning: obsolete)
    }
    return await nativeProvider.mapsPreview(for: originalURL)
  }
}
