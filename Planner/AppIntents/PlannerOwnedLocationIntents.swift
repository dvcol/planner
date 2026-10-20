#if !PLANNER_FIXTURES
  import AppIntents
  import CoreLocation
  import Foundation
  import GeoToolbox
  import PlannerCore

  struct EditPlannerItemLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Edit Item location"
    static let description = IntentDescription(
      "Edit saved place text. Omitted text stays unchanged; empty text clears it. Keep the saved pin unless Remove saved pin is selected. Links stay unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Place name") var placeName: String?
    @Parameter(title: "Address") var address: String?
    @Parameter(title: "Remove saved pin", default: false) var removeSavedPin: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      guard placeName != nil || address != nil || removeSavedPin else {
        throw PlannerOwnedLocationIntentFailure(
          message: "Choose place text to change or remove the saved pin.")
      }
      let dialog = try await updatePlannerOwnedLocation(
        source: .init(kind: .item, id: item.id), store: plannerStore
      ) { current in
        plannerEditedOwnedLocation(
          current, placeName: placeName, address: address,
          removeSavedPin: removeSavedPin)
      }
      return .result(dialog: dialog)
    }
  }

  struct EditPlannerItineraryLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Edit Itinerary location"
    static let description = IntentDescription(
      "Edit saved place text. Omitted text stays unchanged; empty text clears it. Keep the saved pin unless Remove saved pin is selected. Links stay unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Place name") var placeName: String?
    @Parameter(title: "Address") var address: String?
    @Parameter(title: "Remove saved pin", default: false) var removeSavedPin: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      guard placeName != nil || address != nil || removeSavedPin else {
        throw PlannerOwnedLocationIntentFailure(
          message: "Choose place text to change or remove the saved pin.")
      }
      let dialog = try await updatePlannerOwnedLocation(
        source: .init(kind: .itinerary, id: itinerary.id), store: plannerStore
      ) { current in
        plannerEditedOwnedLocation(
          current, placeName: placeName, address: address,
          removeSavedPin: removeSavedPin)
      }
      return .result(dialog: dialog)
    }
  }

  struct SetPlannerItemLocationPinIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Item location pin"
    static let description = IntentDescription(
      "Save an explicit location point while keeping authored place text. An address without a resolved point cannot set a pin. Links stay unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Location") var location: PlaceDescriptor
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>
    static var parameterSummary: some ParameterSummary {
      Summary("Set saved pin of \(\.$item) to \(\.$location)")
    }

    @MainActor func perform() async throws -> PerformResult {
      let coordinate = try plannerOwnedPinCoordinate(location)
      let dialog = try await updatePlannerOwnedLocation(
        source: .init(kind: .item, id: item.id), store: plannerStore
      ) { current in
        .init(
          displayName: current?.displayName, formattedAddress: current?.formattedAddress,
          coordinate: coordinate)
      }
      return .result(dialog: dialog)
    }
  }

  struct SetPlannerItineraryLocationPinIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Itinerary location pin"
    static let description = IntentDescription(
      "Save an explicit location point while keeping authored place text. An address without a resolved point cannot set a pin. Links stay unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Location") var location: PlaceDescriptor
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>
    static var parameterSummary: some ParameterSummary {
      Summary("Set saved pin of \(\.$itinerary) to \(\.$location)")
    }

    @MainActor func perform() async throws -> PerformResult {
      let coordinate = try plannerOwnedPinCoordinate(location)
      let dialog = try await updatePlannerOwnedLocation(
        source: .init(kind: .itinerary, id: itinerary.id), store: plannerStore
      ) { current in
        .init(
          displayName: current?.displayName, formattedAddress: current?.formattedAddress,
          coordinate: coordinate)
      }
      return .result(dialog: dialog)
    }
  }

  struct ClearPlannerItemLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear Item location"
    static let description = IntentDescription(
      "Remove the saved place name, address and pin. Keep all original links, including Maps links."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await updatePlannerOwnedLocation(
        source: .init(kind: .item, id: item.id), store: plannerStore
      ) { _ in nil }
      return .result(dialog: dialog)
    }
  }

  struct ClearPlannerItineraryLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear Itinerary location"
    static let description = IntentDescription(
      "Remove the saved place name, address and pin. Keep all original links, including Maps links."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await updatePlannerOwnedLocation(
        source: .init(kind: .itinerary, id: itinerary.id), store: plannerStore
      ) { _ in nil }
      return .result(dialog: dialog)
    }
  }

  private func plannerEditedOwnedLocation(
    _ current: PlannerOwnedLocation?, placeName: String?,
    address: String?, removeSavedPin: Bool
  ) -> PlannerOwnedLocation? {
    var displayName = current?.displayName
    var formattedAddress = current?.formattedAddress
    if let placeName { displayName = placeName.isEmpty ? nil : placeName }
    if let address { formattedAddress = address.isEmpty ? nil : address }
    let coordinate = removeSavedPin ? nil : current?.coordinate
    guard displayName != nil || formattedAddress != nil || coordinate != nil else { return nil }
    return .init(
      displayName: displayName, formattedAddress: formattedAddress, coordinate: coordinate)
  }

  private func plannerOwnedPinCoordinate(_ location: PlaceDescriptor) throws -> PlannerCoordinate {
    var selectedCoordinate: PlannerCoordinate?
    for representation in location.representations {
      let coordinate: CLLocationCoordinate2D
      switch representation {
      case .coordinate(let point): coordinate = point
      case .deviceLocation(let point): coordinate = point.coordinate
      case .address: continue
      @unknown default:
        throw PlannerOwnedLocationIntentFailure(
          message: "This location representation is not supported.")
      }
      guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
        CLLocationCoordinate2DIsValid(coordinate)
      else { throw PlannerOwnedLocationIntentFailure(message: "Choose a valid location point.") }
      let candidate = PlannerCoordinate(
        latitude: coordinate.latitude, longitude: coordinate.longitude)
      if let selectedCoordinate, selectedCoordinate != candidate {
        throw PlannerOwnedLocationIntentFailure(
          message: "This location contains conflicting points. Choose one location point.")
      }
      selectedCoordinate = candidate
    }
    guard let selectedCoordinate else {
      throw PlannerOwnedLocationIntentFailure(
        message:
          "Choose a location with an explicit point. Address text alone cannot set a saved pin.")
    }
    return selectedCoordinate
  }

  @MainActor
  private func updatePlannerOwnedLocation(
    source: PlannerEntityReference, store: SavedPlannerStore,
    change: (PlannerOwnedLocation?) throws -> PlannerOwnedLocation?
  ) async throws -> IntentDialog {
    let (planner, session) = try await store.appIntentContext()
    try Task.checkCancellation()
    let command: PlannerCommand
    switch await planner.read(session: session, request: .source(source)) {
    case .source(.item(let current)) where source.kind == .item:
      let value = try change(current.content.location)
      let locationChange = value.map(PlannerFieldChange.set) ?? .clear
      command = .editItem(
        sourceId: current.source.id, changes: .init(location: locationChange),
        expectedFieldHashes: current.fieldHashes)
    case .source(.itinerary(let current)) where source.kind == .itinerary:
      let value = try change(current.content.location)
      let locationChange = value.map(PlannerFieldChange.set) ?? .clear
      command = .editItinerary(
        sourceId: current.source.id, changes: .init(location: locationChange),
        expectedFieldHashes: current.fieldHashes)
    case .failed(let reason): throw PlannerOwnedLocationIntentFailure(message: reason.message)
    default:
      throw PlannerOwnedLocationIntentFailure(
        message: "Planner could not read this location's source.")
    }
    let result = try await store.executeAppIntent(command)
    switch result.outcome {
    case .rejected(let reason): throw PlannerOwnedLocationIntentFailure(message: reason.message)
    case .unverified:
      throw PlannerOwnedLocationIntentFailure(
        message:
          "Planner could not verify this change. Open Planner to review recovery before making another change."
      )
    case .applied(_, let recovery):
      switch recovery {
      case .complete: return "Updated the saved location. Links and bookings are unchanged."
      case .incomplete:
        return
          "The location changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
      }
    }
  }

  private struct PlannerOwnedLocationIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
