#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  enum PlannerItemFindCompletion: String, AppEnum, CaseIterable {
    case all, todo, done
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item completion filter")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .all: .init(title: "All"), .todo: .init(title: "Todo"), .done: .init(title: "Done"),
    ]

    var queryValue: PlannerItemQuery.Completion {
      switch self {
      case .all: .all
      case .todo: .todo
      case .done: .done
      }
    }
  }

  enum PlannerItemFindArchive: String, AppEnum, CaseIterable {
    case all, active, archived
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item archive filter")
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

  enum PlannerItemFindScope: String, AppEnum, CaseIterable {
    case allItems, inbox
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item search scope")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .allItems: .init(title: "All Items"), .inbox: .init(title: "Inbox"),
    ]

    var queryValue: PlannerItemQuery.Scope {
      switch self {
      case .allItems: .global
      case .inbox: .inbox
      }
    }
  }

  enum PlannerItemFindSort: String, AppEnum, CaseIterable {
    case title, created, lastUpdated, duration
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item sort")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .title: .init(title: "Title"), .created: .init(title: "Created"),
      .lastUpdated: .init(title: "Last updated"), .duration: .init(title: "Estimate"),
    ]

    var queryValue: PlannerItemQuery.Sort.Mode {
      switch self {
      case .title: .title
      case .created: .created
      case .lastUpdated: .lastUpdated
      case .duration: .duration
      }
    }
  }

  enum PlannerItemFindDirection: String, AppEnum, CaseIterable {
    case ascending, descending
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item sort direction")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .ascending: .init(title: "Ascending"), .descending: .init(title: "Descending"),
    ]

    var queryValue: PlannerItemQuery.Sort.Direction {
      switch self {
      case .ascending: .ascending
      case .descending: .descending
      }
    }
  }

  enum PlannerItemFindMatch: String, AppEnum, CaseIterable {
    case any, all
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Filter matching")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .any: .init(title: "Any selected"), .all: .init(title: "All selected"),
    ]

    var queryValue: PlannerItemQuery.IdentityGroup.Match {
      switch self {
      case .any: .any
      case .all: .all
      }
    }
  }

  enum PlannerItemFindScheduling: String, AppEnum, CaseIterable {
    case all, scheduled, unscheduled
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item scheduling filter")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .all: .init(title: "All"), .scheduled: .init(title: "Scheduled"),
      .unscheduled: .init(title: "Unscheduled"),
    ]

    var queryValue: PlannerItemQuery.Scheduling {
      switch self {
      case .all: .all
      case .scheduled: .scheduled
      case .unscheduled: .unscheduled
      }
    }
  }

  struct FindPlannerItemsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Planner Items"
    static let description = IntentDescription(
      "Find Items with cumulative filters. Completion uses the Item's Done everywhere setting.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Search text", default: "") var text: String
    @Parameter(title: "Scope", default: .allItems) var scope: PlannerItemFindScope
    @Parameter(title: "Completion", default: .all) var completion: PlannerItemFindCompletion
    @Parameter(title: "Archive", default: .all) var archive: PlannerItemFindArchive
    @Parameter(title: "Sort by", default: .title) var sort: PlannerItemFindSort
    @Parameter(title: "Direction", default: .ascending) var direction: PlannerItemFindDirection
    @Parameter(title: "Categories") var categories: [PlannerCategoryEntity]?
    @Parameter(title: "Category matching", default: .any) var categoryMatch: PlannerItemFindMatch
    @Parameter(title: "Tags") var tags: [PlannerTagEntity]?
    @Parameter(title: "Tag matching", default: .any) var tagMatch: PlannerItemFindMatch
    @Parameter(title: "Lists") var lists: [PlannerListEntity]?
    @Parameter(title: "List matching", default: .any) var listMatch: PlannerItemFindMatch
    @Parameter(title: "Has address", default: false) var hasAddress: Bool
    @Parameter(title: "Has links", default: false) var hasLinks: Bool
    @Parameter(title: "Scheduling", default: .all) var scheduling: PlannerItemFindScheduling
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerItemEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let query = PlannerItemEntityQuery()
      query.plannerStore = plannerStore
      let items = try await query.loadItems(
        query: .init(
          scope: scope.queryValue, text: text, completion: completion.queryValue,
          archive: archive.queryValue,
          categories: categories.map {
            .init(ids: Set($0.map(\.id)), match: categoryMatch.queryValue)
          },
          tags: tags.map { .init(ids: Set($0.map(\.id)), match: tagMatch.queryValue) },
          lists: lists.map { .init(ids: Set($0.map(\.id)), match: listMatch.queryValue) },
          hasAddress: hasAddress, hasLinks: hasLinks, scheduled: scheduling.queryValue,
          sort: .init(mode: sort.queryValue, direction: direction.queryValue)))
      return .result(value: items)
    }
  }
#endif
