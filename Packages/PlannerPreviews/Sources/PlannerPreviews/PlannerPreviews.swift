import Foundation
import Observation

public struct PlannerPreviewSource: Sendable, Hashable {
  public let namespace: String
  public let sourceId: UUID
  public let sourceLifetimeId: UUID

  public init(namespace: String, sourceId: UUID, sourceLifetimeId: UUID) {
    self.namespace = namespace
    self.sourceId = sourceId
    self.sourceLifetimeId = sourceLifetimeId
  }
}

public struct PlannerLinkPreviewRequest: Sendable, Hashable {
  public let source: PlannerPreviewSource
  public let linkId: UUID
  public let originalURL: String

  public init(source: PlannerPreviewSource, linkId: UUID, originalURL: String) {
    self.source = source
    self.linkId = linkId
    self.originalURL = originalURL
  }
}

public struct PlannerLinkPreviewContent: Sendable, Equatable {
  public let title: String?
  public let imageData: Data?

  public init(title: String?, imageData: Data?) {
    self.title = title
    self.imageData = imageData
  }
}

public enum PlannerLinkPreviewState: Sendable, Equatable {
  case idle, loading
  case available(PlannerLinkPreviewContent)
  case unavailable
}

@MainActor
public protocol PlannerLinkPreviewProvider {
  func linkPreview(for originalURL: String) async throws -> PlannerLinkPreviewContent
}

@MainActor @Observable
public final class PlannerPreviews {
  @ObservationIgnored private let provider: any PlannerLinkPreviewProvider
  @ObservationIgnored private let links = NSCache<LinkCacheKey, CachedLink>()
  private var loadingLinks: Set<PlannerLinkPreviewRequest> = []
  private var linkRevision = 0

  public init(provider: any PlannerLinkPreviewProvider) {
    self.provider = provider
    links.countLimit = 128
    links.totalCostLimit = 32 * 1024 * 1024
  }

  public func linkState(for request: PlannerLinkPreviewRequest) -> PlannerLinkPreviewState {
    _ = linkRevision
    if let cached = links.object(forKey: LinkCacheKey(request)) { return cached.state }
    if loadingLinks.contains(request) { return .loading }
    return .idle
  }

  public func loadLink(_ request: PlannerLinkPreviewRequest) async {
    guard case .idle = linkState(for: request) else { return }
    loadingLinks.insert(request)
    defer {
      loadingLinks.remove(request)
      linkRevision += 1
    }
    do {
      let fetch = Task { try await provider.linkPreview(for: request.originalURL) }
      let content = try await fetch.value
      links.setObject(
        CachedLink(.available(content)), forKey: LinkCacheKey(request),
        cost: content.imageData?.count ?? 0)
    } catch {
      links.setObject(CachedLink(.unavailable), forKey: LinkCacheKey(request))
    }
  }

  public func retryLink(_ request: PlannerLinkPreviewRequest) async {
    guard !loadingLinks.contains(request) else { return }
    links.removeObject(forKey: LinkCacheKey(request))
    linkRevision += 1
    await loadLink(request)
  }
}

private final class LinkCacheKey: NSObject {
  let request: PlannerLinkPreviewRequest

  init(_ request: PlannerLinkPreviewRequest) { self.request = request }

  override var hash: Int { request.hashValue }

  override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? LinkCacheKey else { return false }
    return request == other.request
  }
}

private final class CachedLink {
  let state: PlannerLinkPreviewState
  init(_ state: PlannerLinkPreviewState) { self.state = state }
}
