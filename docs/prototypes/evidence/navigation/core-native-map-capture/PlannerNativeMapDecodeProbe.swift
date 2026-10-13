import Foundation
import MapKit
import CoreLocation
@main struct Probe {
  static func main() throws {
    for length in [524_288, 1_048_576] {
      let mapItem = MKMapItem(location: CLLocation(latitude: 35.66, longitude: 139.7), address: nil)
      mapItem.name = String(repeating: "A", count: length)
      let data = try NSKeyedArchiver.archivedData(withRootObject: mapItem, requiringSecureCoding: true)
      let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: MKMapItem.self, from: data)
      print("decoded name bytes", length, "serialized map bytes", data.count, "readback bytes", decoded?.name?.utf8.count as Any)
    }
  }
}
