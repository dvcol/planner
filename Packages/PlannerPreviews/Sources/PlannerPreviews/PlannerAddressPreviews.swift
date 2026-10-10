import Foundation
import Observation

public struct PlannerAddressPreviewRequest: Sendable, Hashable {
  public let source: PlannerPreviewSource
  public let address: String
  /// Keep byte-distinct address edits separate despite Swift's Unicode-equivalent String equality.
  private let addressBytes: Data

  public init(source: PlannerPreviewSource, address: String) {
    self.source = source
    self.address = address
    addressBytes = Data(address.utf8)
  }
}

public struct PlannerAddressCandidate: Sendable, Hashable, Identifiable {
  public let id: String
  public let name: String
  public let address: String?
  public let latitude: Double
  public let longitude: Double

  public init(id: String, name: String, address: String?, latitude: Double, longitude: Double) {
    self.id = id
    self.name = name
    self.address = address
    self.latitude = latitude
    self.longitude = longitude
  }
}

public enum PlannerAddressPreviewState: Sendable, Equatable {
  case idle, loading
  case available([PlannerAddressCandidate])
  case unavailable
}

@MainActor
public protocol PlannerAddressPreviewProvider {
  func addressPreview(for address: String) async throws -> [PlannerAddressCandidate]
}

@MainActor @Observable
public final class PlannerAddressPreviews {
  @ObservationIgnored private let provider: any PlannerAddressPreviewProvider
  @ObservationIgnored private let addresses = NSCache<AddressCacheKey, CachedAddress>()
  private var loadingAddresses: Set<PlannerAddressPreviewRequest> = []
  private var addressRevision = 0

  public init(provider: any PlannerAddressPreviewProvider) {
    self.provider = provider
    addresses.countLimit = 128
  }

  public func addressState(for request: PlannerAddressPreviewRequest) -> PlannerAddressPreviewState
  {
    _ = addressRevision
    if let cached = addresses.object(forKey: AddressCacheKey(request)) { return cached.state }
    if loadingAddresses.contains(request) { return .loading }
    return .idle
  }

  public func loadAddress(_ request: PlannerAddressPreviewRequest) async {
    guard case .idle = addressState(for: request) else { return }
    loadingAddresses.insert(request)
    defer {
      loadingAddresses.remove(request)
      addressRevision += 1
    }
    do {
      let fetch = Task { try await provider.addressPreview(for: request.address) }
      let candidates = try await fetch.value
      addresses.setObject(CachedAddress(.available(candidates)), forKey: AddressCacheKey(request))
    } catch {
      addresses.setObject(CachedAddress(.unavailable), forKey: AddressCacheKey(request))
    }
  }

  public func retryAddress(_ request: PlannerAddressPreviewRequest) async {
    guard !loadingAddresses.contains(request) else { return }
    addresses.removeObject(forKey: AddressCacheKey(request))
    addressRevision += 1
    await loadAddress(request)
  }
}

private final class AddressCacheKey: NSObject {
  let request: PlannerAddressPreviewRequest

  init(_ request: PlannerAddressPreviewRequest) { self.request = request }

  override var hash: Int { request.hashValue }

  override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? AddressCacheKey else { return false }
    return request == other.request
  }
}

private final class CachedAddress {
  let state: PlannerAddressPreviewState
  init(_ state: PlannerAddressPreviewState) { self.state = state }
}
