import MapKit
import SwiftUI

/// Read-only selected-appearance map for the native layout comparison.
struct PrototypeMapItemDetail: View {
  let fixture: NavigationPrototypeFixture
  let source: NavigationPrototypeFixture.Source
  let appearance: NavigationPrototypeFixture.Appearance
  @State private var showDetails = false

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
          Annotation(
            source.title,
            coordinate: CLLocationCoordinate2D(
              latitude: coordinate.latitude, longitude: coordinate.longitude)
          ) {
            Button {
              showDetails = true
            } label: {
              Label(source.title, systemImage: "mappin.circle.fill")
                .padding(8)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map.appearance.\(appearance.id)")
          }
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
    .navigationTitle(source.title)
    .safeAreaInset(edge: .bottom) {
      HStack {
        Label(
          appearance.contextName,
          systemImage: fixture.isDone(appearance) ? "checkmark.circle.fill" : "circle")
        Spacer()
        Button("Inspect Item") { showDetails = true }
      }
      .padding()
      .background(.bar)
    }
    .sheet(isPresented: $showDetails) {
      NavigationStack {
        PrototypeItemDetail(fixture: fixture, source: source, appearance: appearance)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Close") { showDetails = false }
                .accessibilityIdentifier("map.details.close")
            }
          }
      }
      .presentationDetents([.large])
    }
  }
}
