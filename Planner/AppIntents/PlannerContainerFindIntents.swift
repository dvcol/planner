#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  enum PlannerCatalogFindArchive: String, AppEnum, CaseIterable {
    case all, active, archived
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Plan archive filter")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .all: .init(title: "All"), .active: .init(title: "Active"),
      .archived: .init(title: "Archived"),
    ]

    var queryValue: PlannerItemQuery.Archive {
      switch self {
      case .all: .all
      case .active: .active
      case .archived: .archived
      }
    }
  }

  enum PlannerCatalogFindSort: String, AppEnum, CaseIterable {
    case title, created, lastUpdated, fullEstimate
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Plan sort")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .title: .init(title: "Title"), .created: .init(title: "Created"),
      .lastUpdated: .init(title: "Last updated"), .fullEstimate: .init(title: "Full estimate"),
    ]

    var queryValue: PlannerCatalogQuery.Sort.Mode {
      switch self {
      case .title: .title
      case .created: .created
      case .lastUpdated: .lastUpdated
      case .fullEstimate: .fullEstimate
      }
    }
  }

  enum PlannerCatalogFindDirection: String, AppEnum, CaseIterable {
    case ascending, descending
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Plan sort direction")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .ascending: .init(title: "Ascending"), .descending: .init(title: "Descending"),
    ]

    var queryValue: PlannerCatalogQuery.Sort.Direction {
      switch self {
      case .ascending: .ascending
      case .descending: .descending
      }
    }
  }

  struct FindPlannerListsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Planner Lists"
    static let description = IntentDescription(
      "Find Lists by text and archive state, with your chosen catalog sort.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Search text", default: "") var text: String
    @Parameter(title: "Archive", default: .all) var archive: PlannerCatalogFindArchive
    @Parameter(title: "Sort by", default: .title) var sort: PlannerCatalogFindSort
    @Parameter(title: "Direction", default: .ascending) var direction: PlannerCatalogFindDirection
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerListEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let query = PlannerListEntityQuery()
      query.plannerStore = plannerStore
      let lists = try await query.loadLists(
        query: .init(
          sourceKind: .list, text: text, archive: archive.queryValue,
          sort: .init(mode: sort.queryValue, direction: direction.queryValue)))
      return .result(value: lists)
    }
  }

  struct FindPlannerItinerariesIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Planner Itineraries"
    static let description = IntentDescription(
      "Find Itineraries by text and archive state, with your chosen catalog sort.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Search text", default: "") var text: String
    @Parameter(title: "Archive", default: .all) var archive: PlannerCatalogFindArchive
    @Parameter(title: "Sort by", default: .title) var sort: PlannerCatalogFindSort
    @Parameter(title: "Direction", default: .ascending) var direction: PlannerCatalogFindDirection
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerItineraryEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let query = PlannerItineraryEntityQuery()
      query.plannerStore = plannerStore
      let itineraries = try await query.loadItineraries(
        query: .init(
          sourceKind: .itinerary, text: text, archive: archive.queryValue,
          sort: .init(mode: sort.queryValue, direction: direction.queryValue)))
      return .result(value: itineraries)
    }
  }
#endif
