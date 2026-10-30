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
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  let summary: Summary
  let mapContent: MapContent

  init(@ViewBuilder summary: () -> Summary, @ViewBuilder mapContent: () -> MapContent) {
    self.summary = summary()
    self.mapContent = mapContent()
  }

  var body: some View {
    GeometryReader { geometry in
      mapContent
        .safeAreaInset(edge: .top, spacing: 0) {
          if dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact {
            ScrollView { summary }
              .scrollBounceBehavior(.basedOnSize)
              .frame(height: geometry.size.height / 3)
              .background(.background)
              .accessibilityLabel("Plan summary")
              .accessibilityIdentifier("saved.map.summary")
          } else {
            summary.background(.background)
          }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }
  }
}

struct SavedMapCollectionView: View {
  private enum PresentedSheet: Identifiable {
    case locations
    case directions
    case group(SavedMapCoordinateIdentity)

    var id: String {
      switch self {
      case .locations: "locations"
      case .directions: "directions"
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
  @State private var directions = SavedMapDirections()
  @State private var camera = MapCameraPosition.automatic
  @State private var observedCamera: MapCamera?
  @State private var mapSize = CGSize.zero
  @State private var preservesUserCamera = false
  @State private var presentedSheet: PresentedSheet?
  @State private var pendingSelection: PlannerMapRowRead?
  @State private var locationChoiceMessage: String?

  private var locatedCountDescription: String {
    let itemNoun = collection.matchingCount == 1 ? "item" : "items"
    return "\(collection.locatedCount) of \(collection.matchingCount) \(itemNoun) located"
  }

  private var locationsButton: some View {
    Button {
      presentedSheet = .locations
    } label: {
      Label("Locations", systemImage: "list.bullet")
    }
    .buttonStyle(.bordered)
    .controlSize(.large)
    // At accessibility sizes this action is icon-only; full names scale in the sheet.
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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

  private var travelModePicker: some View {
    @Bindable var directions = directions
    return Menu {
      Picker("Travel mode", selection: $directions.mode) {
        ForEach(SavedMapDirections.TravelMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
    } label: {
      Text(directions.mode.title)
    }
    .accessibilityLabel("Travel mode")
    .accessibilityValue(directions.mode.title)
    .accessibilityIdentifier("saved.map.travelMode")
  }

  private var routesButton: some View {
    Button {
      presentedSheet = .directions
    } label: {
      Label("Routes", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        .opacity(directions.isLoading ? 0 : 1)
        .overlay {
          if directions.isLoading {
            ProgressView().controlSize(.small).accessibilityHidden(true)
          }
        }
    }
    .buttonStyle(.bordered)
    .controlSize(.large)
    .labelStyle(.iconOnly)
    // Full route text scales in details; this action only displays an icon.
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    .accessibilityLabel("Routes")
    .accessibilityValue(directions.isLoading ? "Calculating routes" : "")
    .help("Routes")
    .accessibilityIdentifier("saved.map.routes")
  }

  private var routeControls: some View {
    HStack(spacing: 12) {
      travelModePicker
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
      routesButton
    }
  }

  var body: some View {
    Map(position: $camera) {
      ForEach(Array(directions.routes.enumerated()), id: \.offset) { _, route in
        MapPolyline(route.polyline).stroke(Color.accentColor, lineWidth: 4)
      }
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
              .frame(maxWidth: max(44, min(220, mapSize.width * 0.45)))
          }
          .buttonStyle(.borderedProminent)
          .buttonBorderShape(.capsule)
          .controlSize(.large)
          // Full titles scale in Locations; map labels stay compact beside nearby pins.
          .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityLabel(markerTitle)
          .accessibilityIdentifier(
            "saved.map.pin.\(group.coordinate.latitude),\(group.coordinate.longitude)")
        }
        .annotationTitles(.hidden)
      }
    }
    .onGeometryChange(for: CGSize.self) { geometry in
      geometry.size
    } action: { size in
      mapSize = size
    }
    .task(id: mapSize) {
      let size = mapSize
      await Task.yield()
      guard !Task.isCancelled, mapSize == size, size.width > 0, size.height > 0 else { return }
      if preservesUserCamera || camera.positionedByUser {
        preservesUserCamera = true
        if let observedCamera { camera = .camera(observedCamera) }
      } else {
        fitLocations()
      }
    }
    .onMapCameraChange { context in observedCamera = context.camera }
    .mapControls {
      MapCompass()
      MapScaleView()
    }
    .accessibilityIdentifier("saved.map.collection")
    .overlay { status }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        if routeRequest.stops.count > 1 { routeControls }
        footer
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
      .background(.bar)
    }
    .onChange(of: collection.groups.map(\.id), initial: true) {
      guard !camera.positionedByUser && !preservesUserCamera else { return }
      fitLocations()
    }
    .onChange(of: directions.routes.count) {
      guard !camera.positionedByUser && !preservesUserCamera else { return }
      fitLocations()
    }
    .sheet(item: $presentedSheet, onDismiss: finishSelection) { sheet in
      switch sheet {
      case .directions:
        SavedMapDirectionsDetails(directions: directions)
      default:
        locationsSheet(for: sheet)
      }
    }
    .task(id: routeRequest) { await directions.reload(routeRequest) }
    .onDisappear { directions.cancel() }
  }

  /// Automatic framing must follow the pane's size until the user positions the map.
  private func fitLocations() {
    guard mapSize.width > 0, mapSize.height > 0 else { return }
    if collection.groups.count == 1, let coordinate = collection.groups.first?.coordinate {
      camera = .camera(
        .init(
          centerCoordinate: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
          distance: 3_000))
    } else if !collection.groups.isEmpty {
      var bounds = MKMapRect.null
      for group in collection.groups {
        let point = MKMapPoint(
          .init(latitude: group.coordinate.latitude, longitude: group.coordinate.longitude))
        bounds = bounds.union(.init(x: point.x, y: point.y, width: 0, height: 0))
      }
      for route in directions.routes { bounds = bounds.union(route.polyline.boundingMapRect) }
      // Keep native world wrapping for plans spanning more than half the globe.
      if bounds.width > MKMapRect.world.width / 2 {
        camera = .automatic
      } else {
        let padded = bounds.insetBy(
          dx: -max(bounds.width / 2, 500), dy: -max(bounds.height / 2, 500))
        let aspectRatio = mapSize.width / mapSize.height
        let width = max(padded.width, padded.height * aspectRatio)
        let height = max(padded.height, padded.width / aspectRatio)
        camera = .rect(
          .init(
            x: padded.midX - width / 2, y: padded.midY - height / 2,
            width: width, height: height))
      }
    } else {
      camera = .automatic
    }
  }

  private var routeRequest: SavedMapDirections.Request {
    .init(collection: collection, directions: directions)
  }

  private func locationsSheet(for sheet: PresentedSheet) -> some View {
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
    #if os(macOS)
      .frame(minWidth: 400, minHeight: 320)
    #endif
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
        "Map unavailable", systemImage: "exclamationmark.triangle", description: Text(reason)
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.background)
    case .ready:
      if collection.rows.isEmpty {
        ContentUnavailableView("No matching items", systemImage: "map")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.background)
      }
    }
  }

  private func choices(for sheet: PresentedSheet) -> [RowChoice] {
    switch sheet {
    case .locations: return collection.rows.map { .init(row: $0) }
    case .directions: return []
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
