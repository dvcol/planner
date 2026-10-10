import MapKit
import PlannerCore
import SwiftUI

struct ItemLocationSection: View {
  let title: String
  let location: PlannerOwnedLocation?
  var showMissingLocation = false

  var body: some View {
    if let location {
      Section("Location") {
        if let name = location.displayName { Text(name) }
        if let address = location.formattedAddress {
          Label(address, systemImage: "mappin.and.ellipse")
        }
        if let coordinate = location.coordinate {
          ItemLocationMap(title: title, coordinate: coordinate)
        }
      }
    } else if showMissingLocation {
      Section("Location") {
        ContentUnavailableView(
          "No location", systemImage: "mappin.slash",
          description: Text("This Item has no saved coordinates. It remains available in the List.")
        )
        .frame(height: 240)
        .accessibilityIdentifier("map.location")
      }
    }
  }
}

private struct ItemLocationMap: View {
  let title: String
  let coordinate: PlannerCoordinate

  var body: some View {
    Map(
      initialPosition: .region(
        MKCoordinateRegion(
          center: CLLocationCoordinate2D(
            latitude: coordinate.latitude, longitude: coordinate.longitude),
          span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)))
    ) {
      Marker(
        title,
        coordinate: CLLocationCoordinate2D(
          latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
    .mapControls {
      MapCompass()
      MapScaleView()
    }
    .frame(height: 240)
    .accessibilityIdentifier("map.location")
    .id("\(coordinate.latitude),\(coordinate.longitude)")
  }
}
