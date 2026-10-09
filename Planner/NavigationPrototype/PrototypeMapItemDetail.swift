import MapKit
import SwiftUI

/// Native map content embedded in the selected Item's detail form.
struct PrototypeMapItemDetail: View {
  let source: NavigationPrototypeFixture.Source

  var body: some View {
    Group {
      if let coordinate = source.content.location?.coordinate {
        Map(
          initialPosition: .region(
            MKCoordinateRegion(
              center: CLLocationCoordinate2D(
                latitude: coordinate.latitude, longitude: coordinate.longitude),
              span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)))
        ) {
          Marker(
            source.title,
            coordinate: CLLocationCoordinate2D(
              latitude: coordinate.latitude, longitude: coordinate.longitude)
          )
        }
        .mapControls {
          MapCompass()
          MapScaleView()
        }
      } else {
        ContentUnavailableView(
          "No location", systemImage: "mappin.slash",
          description: Text("This Item has no saved coordinates. It remains available in the List.")
        )
      }
    }
    .frame(height: 240)
    .accessibilityIdentifier("map.location")
  }
}
