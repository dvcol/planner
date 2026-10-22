import MapKit
import PlannerCore
import SwiftUI

enum SavedCollectionRepresentation: String {
  case list, map
}

struct SavedCollectionRepresentationMenu: View {
  @Binding var representation: SavedCollectionRepresentation
  let accessibilityIdentifier: String

  var body: some View {
    Menu {
      Button {
        representation = .list
      } label: {
        Label("List", systemImage: representation == .list ? "checkmark" : "list.bullet")
      }
      .accessibilityIdentifier("saved.collection.showList")
      Button {
        representation = .map
      } label: {
        Label("Map", systemImage: representation == .map ? "checkmark" : "map")
      }
      .accessibilityIdentifier("saved.collection.showMap")
    } label: {
      Label("View", systemImage: representation == .map ? "map" : "list.bullet")
    }
    .labelStyle(.iconOnly)
    .accessibilityValue(representation == .map ? "Map" : "List")
    .accessibilityIdentifier(accessibilityIdentifier)
    .help("Show as a list or map")
  }
}

struct SavedMapCollectionView: View {
  private enum PresentedSheet: Identifiable {
    case locations
    case group(SavedMapCoordinateIdentity)

    var id: String {
      switch self {
      case .locations: "locations"
      case .group(let coordinate): "\(coordinate.latitude),\(coordinate.longitude)"
      }
    }
  }

  private struct RowChoice: Identifiable {
    let row: PlannerMapRowRead

    var id: String {
      switch row.identity {
      case .source(let source): return "source.\(source.id.uuidString)"
      case .appearance(_, let appearance):
        switch appearance {
        case .listMembership(let owner, let membership):
          return "list.\(owner).\(membership)"
        case .directItineraryItem(let owner, let entry): return "direct.\(owner).\(entry)"
        case .expandedListItem(let owner, let entry, let membership):
          return "expanded.\(owner).\(entry).\(membership)"
        }
      }
    }
  }

  let collection: SavedMapCollection
  let select: (PlannerMapRowRead) -> Void
  @State private var camera = MapCameraPosition.automatic
  @State private var presentedSheet: PresentedSheet?
  @State private var pendingSelection: PlannerMapRowRead?

  var body: some View {
    Map(position: $camera) {
      ForEach(collection.groups) { group in
        Annotation(
          group.rows.count == 1 ? group.rows[0].title : "\(group.rows.count) items",
          coordinate: .init(
            latitude: group.coordinate.latitude, longitude: group.coordinate.longitude)
        ) {
          Button {
            if group.rows.count == 1 {
              select(group.rows[0])
            } else {
              presentedSheet = .group(group.id)
            }
          } label: {
            Label(
              group.rows.count == 1 ? group.rows[0].title : "\(group.rows.count) items",
              systemImage: "mappin.circle.fill"
            )
            .lineLimit(2)
            .frame(maxWidth: 220)
          }
          .buttonStyle(.borderedProminent)
          .buttonBorderShape(.capsule)
          .controlSize(.large)
          .accessibilityIdentifier(
            "saved.map.pin.\(group.coordinate.latitude),\(group.coordinate.longitude)")
        }
        .annotationTitles(.hidden)
      }
    }
    .mapControls {
      MapCompass()
      MapScaleView()
    }
    .accessibilityIdentifier("saved.map.collection")
    .overlay { status }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      HStack {
        Text("\(collection.locatedCount) of \(collection.matchingCount) items located")
          .font(.callout).foregroundStyle(.secondary)
        Spacer()
        Button("Locations", systemImage: "list.bullet") { presentedSheet = .locations }
          .buttonStyle(.bordered)
          .controlSize(.large)
          .accessibilityIdentifier("saved.map.locations")
      }
      .padding()
      .background(.bar)
    }
    .onChange(of: collection.groups.map(\.id), initial: true) {
      guard !camera.positionedByUser else { return }
      if collection.groups.count == 1, let coordinate = collection.groups.first?.coordinate {
        camera = .region(
          .init(
            center: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
            span: .init(latitudeDelta: 0.025, longitudeDelta: 0.025)))
      } else {
        camera = .automatic
      }
    }
    .sheet(item: $presentedSheet, onDismiss: finishSelection) { sheet in
      NavigationStack {
        List {
          ForEach(choices(for: sheet)) { choice in
            Button {
              pendingSelection = choice.row
              presentedSheet = nil
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(choice.row.title).foregroundStyle(.primary)
                Text(locationDescription(choice.row)).font(.caption).foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
              .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(choice.row.title)
            .accessibilityValue(locationDescription(choice.row))
            .accessibilityIdentifier("saved.map.location.\(choice.id)")
          }
        }
        .listStyle(.plain)
        .navigationTitle("Locations")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Close") { presentedSheet = nil }
          }
        }
      }
      .presentationDetents([.medium, .large])
    }
  }

  @ViewBuilder
  private var status: some View {
    switch collection.state {
    case .idle, .loading: ProgressView("Opening Map")
    case .failed(let reason):
      ContentUnavailableView(
        "Map unavailable", systemImage: "exclamationmark.triangle", description: Text(reason))
    case .ready:
      if collection.rows.isEmpty {
        ContentUnavailableView("No matching items", systemImage: "map")
      }
    }
  }

  private func choices(for sheet: PresentedSheet) -> [RowChoice] {
    switch sheet {
    case .locations: return collection.rows.map { .init(row: $0) }
    case .group(let coordinate):
      return collection.groups.first(where: { $0.id == coordinate })?.rows.map { .init(row: $0) }
        ?? []
    }
  }

  private func locationDescription(_ row: PlannerMapRowRead) -> String {
    switch collection.resolution(for: row.identity) {
    case .located: "Location available"
    case .noInput: "No saved location"
    case .addressCandidates: "Choose a place"
    case .unavailable: "Location unavailable"
    default: "Finding location"
    }
  }

  private func finishSelection() {
    guard let row = pendingSelection else { return }
    pendingSelection = nil
    select(row)
  }
}
