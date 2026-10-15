import Foundation
import Observation
import PlannerCore

public enum PlannerMapsPreviewResult: Sendable {
  case available(PlannerCapturePreviewCandidate)
  case unavailable
}

@MainActor
public protocol PlannerMapsPreviewProvider {
  func mapsPreview(for originalURL: String) async -> PlannerCapturePreviewCandidate?
}

@MainActor
public struct NativeMapsPreviewProvider: PlannerMapsPreviewProvider {
  private let resolver = PlannerMapsLinkResolver()

  public init() {}

  public func mapsPreview(for originalURL: String) async -> PlannerCapturePreviewCandidate? {
    await resolver.preview(originalURL: originalURL)
  }
}

@MainActor @Observable
public final class PlannerMapsPreviews {
  @ObservationIgnored private let provider: any PlannerMapsPreviewProvider
  @ObservationIgnored private let links = NSCache<MapsCacheKey, CachedMapsPreview>()

  public init(provider: any PlannerMapsPreviewProvider) {
    self.provider = provider
    links.countLimit = 128
  }

  /// Returns nil when this caller is cancelled or its cache entry has been superseded.
  public func load(_ request: PlannerLinkPreviewRequest) async -> PlannerMapsPreviewResult? {
    guard !Task.isCancelled else { return nil }
    let key = MapsCacheKey(request)
    if let result = links.object(forKey: key)?.result { return result }
    let entry = links.object(forKey: key) ?? CachedMapsPreview()
    links.setObject(entry, forKey: key)
    let candidate = await provider.mapsPreview(for: request.originalURL)
    guard !Task.isCancelled else { return nil }
    guard links.object(forKey: key) === entry else { return nil }
    if case .available = entry.result { return entry.result }
    if let candidate {
      entry.result = .available(candidate)
    } else {
      entry.result = .unavailable
    }
    return entry.result
  }

  public func retry(_ request: PlannerLinkPreviewRequest) async -> PlannerMapsPreviewResult? {
    guard !Task.isCancelled else { return nil }
    links.removeObject(forKey: MapsCacheKey(request))
    return await load(request)
  }
}

private final class MapsCacheKey: NSObject {
  let request: PlannerLinkPreviewRequest

  init(_ request: PlannerLinkPreviewRequest) { self.request = request }

  override var hash: Int { request.hashValue }

  override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? MapsCacheKey else { return false }
    return request == other.request
  }
}

private final class CachedMapsPreview {
  var result: PlannerMapsPreviewResult?
}
