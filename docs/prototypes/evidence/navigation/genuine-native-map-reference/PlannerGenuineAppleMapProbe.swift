import CoreLocation
import Foundation
import MapKit

@main @MainActor struct GenuineAppleMapProbe {
  static func main() async {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = "Nezu Museum"
    request.resultTypes = .pointOfInterest
    request.region = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 35.6617, longitude: 139.7175),
      span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    let search = MKLocalSearch(request: request)
    let timeout = Task {
      try? await Task.sleep(for: .seconds(10))
      if !Task.isCancelled { search.cancel() }
    }
    defer { timeout.cancel() }
    do {
      let response = try await search.start()
      guard let mapItem = response.mapItems.first(where: { $0.identifier != nil }),
        let identifier = mapItem.identifier?.rawValue
      else {
        emit(["available": false, "reason": "No native result supplied an identifier", "count": response.mapItems.count])
        return
      }
      let data = try NSKeyedArchiver.archivedData(withRootObject: mapItem, requiringSecureCoding: true)
      let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: MKMapItem.self, from: data)
      try data.write(to: URL(fileURLWithPath: "/private/tmp/PlannerGenuineAppleMapFixture.data"))
      emit(["available": true, "provider": "MKLocalSearch", "name": mapItem.name ?? "", "identifier": identifier, "roundTripIdentifier": decoded?.identifier?.rawValue ?? "", "archiveBytes": data.count])
    } catch {
      emit(["available": false, "reason": String(describing: error)])
    }
  }

  static func emit(_ result: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
      let text = String(data: data, encoding: .utf8)
    else { return }
    print(text)
  }
}
