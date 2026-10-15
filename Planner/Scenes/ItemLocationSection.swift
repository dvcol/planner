import MapKit
import PlannerCore
import PlannerPreviews
import SwiftUI

struct ItemLocationSection: View {
  let title: String
  let location: PlannerOwnedLocation?
  var showMissingLocation = false
  var previewSource: PlannerPreviewSource?
  var links: [PlannerOwnedLinkRead] = []

  var body: some View {
    if let location {
      Section("Location") {
        if let name = location.displayName { Text(name) }
        if let address = location.formattedAddress {
          Label(address, systemImage: "mappin.and.ellipse")
        }
        if let coordinate = location.coordinate {
          ItemLocationMap(
            title: title,
            coordinate: CLLocationCoordinate2D(
              latitude: coordinate.latitude, longitude: coordinate.longitude))
        } else if let address = location.formattedAddress, let previewSource {
          let request = PlannerAddressPreviewRequest(source: previewSource, address: address)
          ItemAddressPreview(request: request).id(request)
        }
      }
    } else if showMissingLocation && !canPreviewMapsLink {
      Section("Location") {
        ContentUnavailableView(
          "No location", systemImage: "mappin.slash",
          description: Text("This Item has no saved coordinates. It remains available in the List.")
        )
        .frame(height: 240)
        .accessibilityIdentifier("map.location")
      }
    }
    if canPreviewMapsLink, let previewSource {
      ItemMapsPreviewSection(links: mapsLinks, source: previewSource)
    }
  }

  private var mapsLinks: [PlannerOwnedLinkRead] {
    links.filter { $0.kind == .appleMaps || $0.kind == .googleMaps }
  }

  private var canPreviewMapsLink: Bool {
    location?.coordinate == nil && location?.formattedAddress == nil
      && previewSource != nil && !mapsLinks.isEmpty
  }
}

struct ItemLocationMap: View {
  let title: String
  let coordinate: CLLocationCoordinate2D
  var accessibilityIdentifier = "map.location"

  var body: some View {
    Map(
      initialPosition: .region(
        MKCoordinateRegion(
          center: coordinate,
          span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)))
    ) {
      Marker(title, coordinate: coordinate)
    }
    .mapControls {
      MapCompass()
      MapScaleView()
    }
    .frame(height: 240)
    .accessibilityIdentifier(accessibilityIdentifier)
    .id("\(coordinate.latitude),\(coordinate.longitude)")
  }
}
