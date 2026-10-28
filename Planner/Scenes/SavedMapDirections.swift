import MapKit
import Observation
import PlannerCore
import SwiftUI

@MainActor @Observable
final class SavedMapDirections {
  enum TravelMode: String, CaseIterable, Identifiable {
    case walking, driving, transit

    var id: Self { self }
    var title: String {
      switch self {
      case .walking: "Walking"
      case .driving: "Driving"
      case .transit: "Public transport"
      }
    }
    var transportType: MKDirectionsTransportType {
      switch self {
      case .walking: .walking
      case .driving: .automobile
      case .transit: .transit
      }
    }
    var launchMode: String {
      switch self {
      case .walking: MKLaunchOptionsDirectionsModeWalking
      case .driving: MKLaunchOptionsDirectionsModeDriving
      case .transit: MKLaunchOptionsDirectionsModeTransit
      }
    }
  }

  struct Stop: Equatable {
    let identity: PlannerRowIdentity
    let lifetime: UUID
    let title: String
    let coordinate: PlannerCoordinate?

    var mapItem: MKMapItem? {
      guard let coordinate else { return nil }
      let item = MKMapItem(
        location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
        address: nil)
      item.name = title
      return item
    }
  }

  struct Request: Equatable {
    let mode: TravelMode
    let stops: [Stop]
    let retry: Int

    @MainActor init(collection: SavedMapCollection, directions: SavedMapDirections) {
      mode = directions.mode
      retry = directions.retryCount
      guard collection.collection?.source.kind == .itinerary else {
        stops = []
        return
      }
      stops = collection.routingLocations.map { row, coordinate in
        return .init(
          identity: row.identity, lifetime: row.sourceLifetimeId, title: row.title,
          coordinate: coordinate)
      }
    }
  }

  enum Outcome {
    case loading, sameLocation, missingLocation
    case route(MKRoute)
    case transit(MKDirections.ETAResponse)
    case unavailable(Error)
  }

  struct Leg: Identifiable {
    let id: Int
    let start: Stop
    let end: Stop
    var outcome: Outcome
  }

  var mode = TravelMode.walking {
    didSet { if oldValue != mode { cancel() } }
  }
  private(set) var legs: [Leg] = []
  private(set) var isLoading = false
  private(set) var retryCount = 0
  @ObservationIgnored private var generation = UUID()
  @ObservationIgnored private var activeRequest: MKDirections?

  var routes: [MKRoute] {
    legs.compactMap { leg in
      guard case .route(let route) = leg.outcome else { return nil }
      return route
    }
  }

  /// Resolve only adjacent visible stops, preserving gaps and repeated appearances.
  func reload(_ request: Request) async {
    cancel()
    let identifier = generation
    legs = zip(request.stops, request.stops.dropFirst()).enumerated().map { index, pair in
      .init(id: index, start: pair.0, end: pair.1, outcome: .loading)
    }
    isLoading = !legs.isEmpty
    defer {
      if generation == identifier {
        activeRequest = nil
        isLoading = false
      }
    }
    for index in legs.indices {
      guard !Task.isCancelled, generation == identifier else { return }
      let leg = legs[index]
      guard let source = leg.start.mapItem, let destination = leg.end.mapItem else {
        legs[index].outcome = .missingLocation
        continue
      }
      if leg.start.coordinate == leg.end.coordinate {
        legs[index].outcome = .sameLocation
        continue
      }
      let query = MKDirections.Request()
      query.source = source
      query.destination = destination
      query.transportType = request.mode.transportType
      let directions = MKDirections(request: query)
      activeRequest = directions
      let deadline = Task { @MainActor in
        try await Task.sleep(for: .seconds(10))
        directions.cancel()
      }
      defer { deadline.cancel() }
      do {
        let outcome: Outcome
        if request.mode == .transit {
          outcome = .transit(try await directions.calculateETA())
        } else {
          let response = try await directions.calculate()
          if let route = response.routes.first {
            outcome = .route(route)
          } else {
            outcome = .unavailable(MKError(.directionsNotFound))
          }
        }
        guard !Task.isCancelled, generation == identifier else { return }
        legs[index].outcome = outcome
      } catch {
        guard !Task.isCancelled, generation == identifier else { return }
        legs[index].outcome = .unavailable(error)
      }
    }
  }

  func retry() {
    cancel()
    retryCount += 1
  }

  func cancel() {
    generation = UUID()
    activeRequest?.cancel()
    activeRequest = nil
    legs = []
    isLoading = false
  }
}

struct SavedMapDirectionsDetails: View {
  let directions: SavedMapDirections
  @Environment(\.dismiss) private var dismiss
  @State private var openingError: String?

  var body: some View {
    NavigationStack {
      List {
        Section {
          Text("Routes follow the visible itinerary stops in their saved order.")
          if directions.mode == .transit {
            Text("Public transport times are estimates. Open a leg in Maps for its full route.")
          }
        }
        ForEach(directions.legs) { leg in
          Section {
            status(leg)
            Button("Open in Maps", systemImage: "arrow.up.right") { open(leg) }
              .disabled(leg.start.coordinate == nil || leg.end.coordinate == nil)
              .accessibilityIdentifier("saved.map.route.open.\(leg.id)")
          } header: {
            Text("\(leg.id + 1). \(leg.start.title) → \(leg.end.title)")
          }
        }
        Button("Retry routes", systemImage: "arrow.clockwise") { directions.retry() }
          .disabled(directions.isLoading)
          .accessibilityIdentifier("saved.map.route.retry")
      }
      .navigationTitle(directions.mode.title)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Close") { dismiss() }.accessibilityIdentifier("saved.map.route.close")
        }
      }
      #if os(macOS)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 360, idealHeight: 520)
      #endif
      .alert(
        "Maps couldn't open",
        isPresented: Binding(
          get: { openingError != nil }, set: { if !$0 { openingError = nil } })
      ) {
        Button("OK") { openingError = nil }
      } message: {
        Text(openingError ?? "Try again.")
      }
    }
  }

  @ViewBuilder
  private func status(_ leg: SavedMapDirections.Leg) -> some View {
    switch leg.outcome {
    case .loading:
      ProgressView("Calculating route")
    case .sameLocation:
      Text("Same location")
    case .missingLocation:
      Label("Resolve both locations to calculate this leg.", systemImage: "mappin.slash")
    case .route(let route):
      Text(
        Duration.seconds(route.expectedTravelTime).formatted(.units(allowed: [.hours, .minutes]))
      )
      .accessibilityIdentifier("saved.map.route.calculated.\(leg.id)")
      Text(
        Measurement(value: route.distance, unit: UnitLength.meters),
        format: .measurement(width: .abbreviated)
      )
      .foregroundStyle(.secondary)
    case .transit(let response):
      Text(
        Duration.seconds(response.expectedTravelTime).formatted(
          .units(allowed: [.hours, .minutes]))
      )
      .accessibilityIdentifier("saved.map.route.transit.\(leg.id)")
    case .unavailable(let error):
      Label("Route unavailable", systemImage: "exclamationmark.triangle")
      Text(error.localizedDescription).font(.callout).foregroundStyle(.secondary)
    }
  }

  private func open(_ leg: SavedMapDirections.Leg) {
    guard let start = leg.start.mapItem, let end = leg.end.mapItem else { return }
    if !MKMapItem.openMaps(
      with: [start, end],
      launchOptions: [MKLaunchOptionsDirectionsModeKey: directions.mode.launchMode])
    {
      openingError = "Open Maps and try these directions again."
    }
  }
}
