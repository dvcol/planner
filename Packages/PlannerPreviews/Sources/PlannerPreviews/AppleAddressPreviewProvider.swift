import Foundation
import MapKit

@MainActor
public struct AppleAddressPreviewProvider: PlannerAddressPreviewProvider {
  public init() {}

  public func addressPreview(for address: String) async throws -> [PlannerAddressCandidate] {
    guard let request = MKGeocodingRequest(addressString: address) else {
      throw AddressError.invalidAddress
    }
    let mapItems = try await request.mapItems
    return mapItems.compactMap { mapItem in
      let coordinate = mapItem.location.coordinate
      guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
      return PlannerAddressCandidate(
        id: mapItem.identifier?.rawValue ?? UUID().uuidString,
        name: mapItem.name ?? address,
        address: mapItem.addressRepresentations?.fullAddress(
          includingRegion: true, singleLine: true) ?? mapItem.address?.fullAddress,
        latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
  }
}

private enum AddressError: Error { case invalidAddress }
