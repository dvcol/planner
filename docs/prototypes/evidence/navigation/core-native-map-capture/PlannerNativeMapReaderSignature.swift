import Foundation
import MapKit
func decodeMap(_ data: Data) throws -> MKMapItem {
  try MKMapItem.object(withItemProviderData: data, typeIdentifier: MKMapItemTypeIdentifier)
}
