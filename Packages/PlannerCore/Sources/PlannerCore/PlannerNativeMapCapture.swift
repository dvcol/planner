import Foundation
import MapKit

func plannerNativeMapCandidate(_ mapItem: MKMapItem) -> PlannerCapturePreviewCandidate {
  var coordinate: PlannerCoordinate?
  var uncertaintyReasons: [String] = []
  if mapItem.isCurrentLocation {
    uncertaintyReasons.append("This shared place refers to a changing current location.")
  } else {
    let nativeCoordinate = mapItem.location.coordinate
    if CLLocationCoordinate2DIsValid(nativeCoordinate) {
      coordinate = .init(latitude: nativeCoordinate.latitude, longitude: nativeCoordinate.longitude)
    } else {
      uncertaintyReasons.append("No valid fixed coordinate was supplied.")
    }
  }
  var reference: PlannerProviderReference?
  if let identifier = mapItem.identifier?.rawValue, !identifier.isEmpty {
    reference = .init(kind: .applePlaceId, value: identifier)
  }
  return .init(
    provider: .appleMaps, displayName: mapItem.name,
    formattedAddress: mapItem.address?.fullAddress, coordinate: coordinate,
    providerReference: reference, uncertaintyReasons: uncertaintyReasons,
    attributionText: nil)
}
