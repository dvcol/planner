import MapKit
import PlannerCore
import PlannerPreviews
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

struct SavedMapCollectionLayout<Summary: View, MapContent: View>: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let summary: Summary
  let mapContent: MapContent

  init(@ViewBuilder summary: () -> Summary, @ViewBuilder mapContent: () -> MapContent) {
    self.summary = summary()
    self.mapContent = mapContent()
  }

  var body: some View {
    GeometryReader { geometry in
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          mapContent.safeAreaInset(edge: .top, spacing: 0) {
            ScrollView { summary }
              .scrollBounceBehavior(.basedOnSize)
              .frame(height: geometry.size.height / 3)
              .accessibilityLabel("Plan summary")
              .accessibilityIdentifier("saved.map.summary")
          }
        } else {
          VStack(spacing: 0) {
            summary
            mapContent.frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
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

    var context: String? {
      switch row.placement {
      case .itineraryItem(_, let routePosition): return "Stop \(routePosition)"
      case .itineraryListItem(_, let routePosition, let list, _, let childPosition):
        return "\(list.title) · Stop \(routePosition) · Item \(childPosition)"
      default: return nil
      }
    }

    var accessibilityTitle: String {
      guard let context else { return row.title }
      return "\(row.title) · \(context)"
    }

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
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var camera = MapCameraPosition.automatic
  @State private var observedCamera: MapCamera?
  @State private var preservesUserCamera = false
  @State private var presentedSheet: PresentedSheet?
  @State private var pendingSelection: PlannerMapRowRead?
  @State private var locationChoiceMessage: String?

  private var locatedCountDescription: String {
    "\(collection.locatedCount) of \(collection.matchingCount) items located"
  }

  private var locationsButton: some View {
    Button {
      presentedSheet = .locations
    } label: {
      Label("Locations", systemImage: "list.bullet")
    }
    .buttonStyle(.bordered)
    .controlSize(.large)
    .accessibilityIdentifier("saved.map.locations")
    .help("Locations")
  }

  @ViewBuilder
  private var footer: some View {
    if dynamicTypeSize.isAccessibilitySize {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
          Text("\(collection.locatedCount)/\(collection.matchingCount)")
            .font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel(locatedCountDescription)
          Spacer(minLength: 0)
          locationsButton.labelStyle(.iconOnly)
        }
        VStack(alignment: .leading, spacing: 12) {
          Text(locatedCountDescription).font(.callout).foregroundStyle(.secondary)
          locationsButton.labelStyle(.iconOnly)
        }
      }
    } else {
      HStack {
        Text(locatedCountDescription).font(.callout).foregroundStyle(.secondary)
        Spacer()
        locationsButton.labelStyle(.titleOnly)
      }
    }
  }

  var body: some View {
    Map(position: $camera) {
      ForEach(collection.groups) { group in
        let markerTitle = group.rows.count == 1 ? group.rows[0].title : "\(group.rows.count) items"
        let visibleMarkerTitle =
          if group.rows.count > 1 && dynamicTypeSize.isAccessibilitySize {
            String(group.rows.count)
          } else {
            markerTitle
          }
        Annotation(
          markerTitle,
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
            Label(visibleMarkerTitle, systemImage: "mappin.circle.fill")
              .lineLimit(2)
              .frame(maxWidth: 220)
          }
          .buttonStyle(.borderedProminent)
          .buttonBorderShape(.capsule)
          .controlSize(.large)
          .accessibilityLabel(markerTitle)
          .accessibilityIdentifier(
            "saved.map.pin.\(group.coordinate.latitude),\(group.coordinate.longitude)")
        }
        .annotationTitles(.hidden)
      }
    }
    .onGeometryChange(for: CGSize.self) { geometry in
      geometry.size
    } action: { _ in
      guard let observedCamera else { return }
      preservesUserCamera = preservesUserCamera || camera.positionedByUser
      camera = .camera(observedCamera)
    }
    .onMapCameraChange { context in observedCamera = context.camera }
    .mapControls {
      MapCompass()
      MapScaleView()
    }
    .accessibilityIdentifier("saved.map.collection")
    .overlay { status }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      footer
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.bar)
    }
    .onChange(of: collection.groups.map(\.id), initial: true) {
      guard !camera.positionedByUser && !preservesUserCamera else { return }
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
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Button {
                  pendingSelection = choice.row
                  presentedSheet = nil
                } label: {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(choice.row.title).foregroundStyle(.primary)
                    if let context = choice.context {
                      Text(context).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(locationDescription(choice.row)).font(.caption).foregroundStyle(.secondary)
                  }
                  .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                  .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.accessibilityTitle)
                .accessibilityValue(locationDescription(choice.row))
                .accessibilityIdentifier("saved.map.location.\(choice.id)")
                if (collection.addressChoices(for: choice.row.identity)?.candidates.count ?? 0) > 1
                  || (collection.mapsLinkChoices(for: choice.row.identity)?.links.count ?? 0) > 1
                  || collection.resolution(for: choice.row.identity) == .unavailable
                {
                  locationOptions(for: choice)
                }
              }
              if let preview = collection.mapsPreview(for: choice.row.identity) {
                VStack(alignment: .leading, spacing: 4) {
                  if let attribution = preview.attributionText {
                    Text(attribution)
                      .accessibilityIdentifier("saved.map.location.provider.\(choice.id)")
                  }
                  ForEach(Array(preview.uncertaintyReasons.enumerated()), id: \.offset) {
                    index, reason in
                    Text(reason)
                      .fixedSize(horizontal: false, vertical: true)
                      .accessibilityIdentifier(
                        "saved.map.location.uncertainty.\(choice.id).\(index)")
                  }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
              }
            }
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
      .alert(
        "Location changed",
        isPresented: Binding(
          get: { locationChoiceMessage != nil },
          set: { if !$0 { locationChoiceMessage = nil } })
      ) {
        Button("OK") { locationChoiceMessage = nil }
      } message: {
        Text(locationChoiceMessage ?? "Choose this location again.")
      }
      .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
    }
  }

  private func locationOptions(for choice: RowChoice) -> some View {
    Menu {
      if let choices = collection.addressChoices(for: choice.row.identity),
        choices.candidates.count > 1
      {
        Picker(
          "Matching places",
          selection: Binding(
            get: { collection.addressChoices(for: choice.row.identity)?.selectedCandidateId },
            set: { selectedIdentifier in
              guard let candidate = choices.candidates.first(where: { $0.id == selectedIdentifier })
              else { return }
              if !collection.chooseAddressCandidate(
                candidate, request: choices.request, for: choice.row.identity)
              {
                locationChoiceMessage = "The saved address changed. Choose a place again."
              }
            })
        ) {
          Text("Choose a place").tag(nil as String?).disabled(true)
          ForEach(choices.candidates) { candidate in
            Text(candidate.address.map { "\(candidate.name), \($0)" } ?? candidate.name)
              .tag(Optional(candidate.id))
          }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("saved.map.address.selector.\(choice.id)")
      }

      if let choices = collection.mapsLinkChoices(for: choice.row.identity), choices.links.count > 1
      {
        Picker(
          "Map link",
          selection: Binding(
            get: {
              collection.mapsLinkChoices(for: choice.row.identity)?.selected.linkId
                ?? choices.selected.linkId
            },
            set: { selectedLinkIdentifier in
              guard let link = choices.links.first(where: { $0.linkId == selectedLinkIdentifier })
              else {
                locationChoiceMessage = "The saved Maps links changed. Choose a link again."
                return
              }
              let request = PlannerLinkPreviewRequest(
                source: choices.selected.source, linkId: link.linkId, originalURL: link.originalUrl)
              if !collection.chooseMapsLink(request, for: choice.row.identity) {
                locationChoiceMessage = "This saved Maps link changed. Choose it again."
              }
            })
        ) {
          ForEach(choices.links, id: \.linkId) { link in
            Text(link.label ?? link.originalUrl).tag(link.linkId)
          }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("saved.map.link.selector.\(choice.id)")
      }
      if collection.resolution(for: choice.row.identity) == .unavailable {
        Button("Retry location", systemImage: "arrow.clockwise") {
          collection.retry(for: choice.row.identity)
        }
        .accessibilityIdentifier("saved.map.location.retry.\(choice.id)")
      }
    } label: {
      Label("Location options", systemImage: "ellipsis.circle")
        .frame(minWidth: 44, minHeight: 44)
    }
    .labelStyle(.iconOnly)
    .buttonStyle(.borderless)
    .accessibilityLabel("Location options for \(choice.accessibilityTitle)")
    .accessibilityIdentifier("saved.map.location.options.\(choice.id)")
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
