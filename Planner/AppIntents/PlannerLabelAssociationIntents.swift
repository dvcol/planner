#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct GetPlannerItemCategoriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Item Categories"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerCategoryEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let labels = try await readPlannerAssignedLabels(
        owner: .init(kind: .item, id: item.id), store: plannerStore)
      return .result(
        value: labels.filter { $0.reference.kind == .category }.map {
          PlannerCategoryEntity(id: $0.reference.id, name: $0.name)
        })
    }
  }

  struct GetPlannerItemTagsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Item Tags"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerTagEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let labels = try await readPlannerAssignedLabels(
        owner: .init(kind: .item, id: item.id), store: plannerStore)
      return .result(
        value: labels.filter { $0.reference.kind == .tag }.map {
          PlannerTagEntity(id: $0.reference.id, name: $0.name)
        })
    }
  }

  struct GetPlannerItineraryCategoriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Itinerary Categories"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerCategoryEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let labels = try await readPlannerAssignedLabels(
        owner: .init(kind: .itinerary, id: itinerary.id), store: plannerStore)
      return .result(
        value: labels.filter { $0.reference.kind == .category }.map {
          PlannerCategoryEntity(id: $0.reference.id, name: $0.name)
        })
    }
  }

  struct GetPlannerItineraryTagsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Itinerary Tags"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerTagEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let labels = try await readPlannerAssignedLabels(
        owner: .init(kind: .itinerary, id: itinerary.id), store: plannerStore)
      return .result(
        value: labels.filter { $0.reference.kind == .tag }.map {
          PlannerTagEntity(id: $0.reference.id, name: $0.name)
        })
    }
  }

  struct SetPlannerItemCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Item Category"
    static let description = IntentDescription(
      "Assign or unassign this shared Category. Other labels and Item data stay unchanged.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Category") var category: PlannerCategoryEntity
    @Parameter(title: "Assigned", default: true) var assigned: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await setPlannerLabelAssignment(
        owner: .init(kind: .item, id: item.id), label: .init(kind: .category, id: category.id),
        assigned: assigned, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct SetPlannerItemTagIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Item Tag"
    static let description = IntentDescription(
      "Assign or unassign this shared Tag. Other labels and Item data stay unchanged.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Tag") var tag: PlannerTagEntity
    @Parameter(title: "Assigned", default: true) var assigned: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await setPlannerLabelAssignment(
        owner: .init(kind: .item, id: item.id), label: .init(kind: .tag, id: tag.id),
        assigned: assigned, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct SetPlannerItineraryCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Itinerary Category"
    static let description = IntentDescription(
      "Assign or unassign this shared Category. Other labels, route entries and shared Items stay unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Category") var category: PlannerCategoryEntity
    @Parameter(title: "Assigned", default: true) var assigned: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await setPlannerLabelAssignment(
        owner: .init(kind: .itinerary, id: itinerary.id),
        label: .init(kind: .category, id: category.id), assigned: assigned, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  struct SetPlannerItineraryTagIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Itinerary Tag"
    static let description = IntentDescription(
      "Assign or unassign this shared Tag. Other labels, route entries and shared Items stay unchanged."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Tag") var tag: PlannerTagEntity
    @Parameter(title: "Assigned", default: true) var assigned: Bool
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let dialog = try await setPlannerLabelAssignment(
        owner: .init(kind: .itinerary, id: itinerary.id),
        label: .init(kind: .tag, id: tag.id), assigned: assigned, store: plannerStore)
      return .result(dialog: dialog)
    }
  }

  @MainActor
  private func readPlannerAssignedLabels(
    owner: PlannerEntityReference, store: SavedPlannerStore
  ) async throws -> [PlannerLabelRead] {
    let (planner, session) = try await store.appIntentContext()
    try Task.checkCancellation()
    switch await planner.read(session: session, request: .source(owner)) {
    case .source(.item(let source)) where owner.kind == .item: return source.labels
    case .source(.itinerary(let source)) where owner.kind == .itinerary: return source.labels
    case .failed(let reason): throw PlannerLabelAssociationIntentFailure(message: reason.message)
    default:
      throw PlannerLabelAssociationIntentFailure(
        message: "Planner could not read this label's owner.")
    }
  }

  @MainActor
  private func setPlannerLabelAssignment(
    owner: PlannerEntityReference, label: PlannerEntityReference, assigned: Bool,
    store: SavedPlannerStore
  ) async throws -> IntentDialog {
    let (planner, session) = try await store.appIntentContext()
    try Task.checkCancellation()
    switch await planner.read(
      session: session, request: .source(label))
    {
    case .source(.category) where label.kind == .category: break
    case .source(.tag) where label.kind == .tag: break
    case .failed(let reason): throw PlannerLabelAssociationIntentFailure(message: reason.message)
    default:
      throw PlannerLabelAssociationIntentFailure(message: "Planner could not read this label.")
    }
    let command: PlannerCommand
    switch await planner.read(session: session, request: .source(owner)) {
    case .source(.item(let source)) where owner.kind == .item:
      var identifiers = label.kind == .category ? source.content.categoryIds : source.content.tagIds
      if assigned {
        identifiers.insert(label.id)
      } else {
        identifiers.remove(label.id)
      }
      let changes: PlannerItemChanges
      if label.kind == .category {
        changes = .init(categoryIds: .set(identifiers))
      } else {
        changes = .init(tagIds: .set(identifiers))
      }
      command = .editItem(
        sourceId: source.source.id, changes: changes, expectedFieldHashes: source.fieldHashes)
    case .source(.itinerary(let source)) where owner.kind == .itinerary:
      var identifiers = label.kind == .category ? source.content.categoryIds : source.content.tagIds
      if assigned {
        identifiers.insert(label.id)
      } else {
        identifiers.remove(label.id)
      }
      let changes: PlannerItineraryChanges
      if label.kind == .category {
        changes = .init(categoryIds: .set(identifiers))
      } else {
        changes = .init(tagIds: .set(identifiers))
      }
      command = .editItinerary(
        sourceId: source.source.id, changes: changes, expectedFieldHashes: source.fieldHashes)
    case .failed(let reason): throw PlannerLabelAssociationIntentFailure(message: reason.message)
    default:
      throw PlannerLabelAssociationIntentFailure(
        message: "Planner could not read this label's owner.")
    }
    let result = try await store.executeAppIntent(command)
    switch result.outcome {
    case .rejected(let reason): throw PlannerLabelAssociationIntentFailure(message: reason.message)
    case .unverified:
      throw PlannerLabelAssociationIntentFailure(
        message:
          "Planner could not verify this change. Open Planner to review recovery before making another change."
      )
    case .applied(_, let recovery):
      switch recovery {
      case .complete:
        if assigned { return "Assigned the shared label. Other labels are preserved." }
        return "Unassigned the label. The shared label and its other uses are preserved."
      case .incomplete:
        return
          "The label assignment changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
      }
    }
  }

  private struct PlannerLabelAssociationIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
