#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import CoreLocation
  import GeoToolbox
  import PlannerCore

  @MainActor
  func readPlannerDeferredItemSource(identifier: String) async throws -> PlannerItemSourceRead {
    @AppDependency var plannerStore: SavedPlannerStore
    try await plannerStore.beginAppIntentAction()
    defer { plannerStore.endAppIntentAction() }
    try Task.checkCancellation()
    let (planner, session) = try await plannerStore.appIntentContext()
    try Task.checkCancellation()
    guard
      let sourceIdentifier = UUID(
        uuidString: try plannerResolveIntentIdentifier(identifier, store: plannerStore))
    else {
      throw PlannerDeferredContentFailure(message: "This saved choice has an invalid identity.")
    }
    switch await planner.read(
      session: session, request: .source(.init(kind: .item, id: sourceIdentifier)))
    {
    case .source(.item(let current)): return current
    case .failed(let reason): throw PlannerDeferredContentFailure(message: reason.message)
    default:
      throw PlannerDeferredContentFailure(message: "Planner could not read this Item's content.")
    }
  }

  @MainActor
  func readPlannerDeferredListSource(identifier: String) async throws -> PlannerListSourceRead {
    @AppDependency var plannerStore: SavedPlannerStore
    try await plannerStore.beginAppIntentAction()
    defer { plannerStore.endAppIntentAction() }
    try Task.checkCancellation()
    let (planner, session) = try await plannerStore.appIntentContext()
    try Task.checkCancellation()
    guard
      let sourceIdentifier = UUID(
        uuidString: try plannerResolveIntentIdentifier(identifier, store: plannerStore))
    else {
      throw PlannerDeferredContentFailure(message: "This saved choice has an invalid identity.")
    }
    switch await planner.read(
      session: session, request: .source(.init(kind: .list, id: sourceIdentifier)))
    {
    case .source(.list(let current)): return current
    case .failed(let reason): throw PlannerDeferredContentFailure(message: reason.message)
    default:
      throw PlannerDeferredContentFailure(message: "Planner could not read this List's content.")
    }
  }

  @MainActor
  func readPlannerDeferredItinerarySource(identifier: String) async throws
    -> PlannerItinerarySourceRead
  {
    @AppDependency var plannerStore: SavedPlannerStore
    try await plannerStore.beginAppIntentAction()
    defer { plannerStore.endAppIntentAction() }
    try Task.checkCancellation()
    let (planner, session) = try await plannerStore.appIntentContext()
    try Task.checkCancellation()
    guard
      let sourceIdentifier = UUID(
        uuidString: try plannerResolveIntentIdentifier(identifier, store: plannerStore))
    else {
      throw PlannerDeferredContentFailure(message: "This saved choice has an invalid identity.")
    }
    switch await planner.read(
      session: session, request: .source(.init(kind: .itinerary, id: sourceIdentifier)))
    {
    case .source(.itinerary(let current)): return current
    case .failed(let reason): throw PlannerDeferredContentFailure(message: reason.message)
    default:
      throw PlannerDeferredContentFailure(
        message: "Planner could not read this Itinerary's content.")
    }
  }

  func plannerDeferredPin(_ location: PlannerOwnedLocation?) -> PlaceDescriptor? {
    guard let coordinate = location?.coordinate else { return nil }
    return PlaceDescriptor(
      representations: [
        .coordinate(
          CLLocationCoordinate2D(
            latitude: coordinate.latitude, longitude: coordinate.longitude))
      ], commonName: nil)
  }

  private struct PlannerDeferredContentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
