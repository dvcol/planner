import Foundation

/// Reads temporary Maps link values without creating a capture or saving content.
public struct PlannerMapsLinkResolver: Sendable {
  private let transport: any PlannerCaptureHTTPTransport

  public init(transport: any PlannerCaptureHTTPTransport = PlannerNativeCaptureHTTPTransport()) {
    self.transport = transport
  }

  public func preview(originalURL: String) async -> PlannerCapturePreviewCandidate? {
    guard !Task.isCancelled, let requestURL = plannerCaptureRequestURL(originalURL) else {
      return nil
    }
    if let candidate = plannerCapturePlaceCandidate(requestURL) { return candidate }
    return await plannerLookupCapturePlace(originalURL, transport: transport)
  }
}
