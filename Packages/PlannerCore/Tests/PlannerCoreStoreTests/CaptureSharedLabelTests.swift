import Foundation
import SwiftData
import Testing

@testable import PlannerCore

struct CaptureSharedLabelTests {
  @Test func sharedLabelsRemainCompleteAcrossCapturePreparationEditingReviewAndApply() async throws
  {
    let fixture = try await SharedLabelFixture.create()
    guard case .draft(let prepared) = await fixture.prepare(),
      case .draft(let edited) = await fixture.edit(prepared),
      case .reviewed(let review) = await fixture.planner.prepareReview(
        session: fixture.session,
        command: .applyCapture(
          draftId: edited.draftId, draftGeneration: edited.generation,
          choice: .createNew, listIds: [])),
      case .applied(let applied, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      let created = applied.generated.first,
      case .source(.item(let item)) = await fixture.planner.read(
        session: fixture.session, request: .source(created)),
      case .draft(let next) = await fixture.prepare()
    else { throw CancellationError() }
    #expect(Set(prepared.reuseCandidates.map(\.itemId)) == Set(fixture.items.map(\.id)))
    #expect(edited.reuseCandidates == prepared.reuseCandidates)
    #expect(review.impact.captureDetails?.createContent?.categoryIds == [fixture.category.id])
    #expect(review.impact.captureDetails?.createContent?.tagIds == [fixture.tag.id])
    #expect(Set(item.labels.map(\.reference)) == [fixture.category, fixture.tag])
    #expect(Set(item.labels.map(\.name)) == ["Shared Category", "Shared Tag"])
    #expect(Set(next.reuseCandidates.map(\.itemId)) == Set((fixture.items + [created]).map(\.id)))
    guard
      case .source(.category(let category)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.category)),
      case .source(.tag(let tag)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.tag))
    else { throw CancellationError() }
    #expect(category.references.count == fixture.items.count + 1)
    #expect(tag.references.count == fixture.items.count + 1)
  }

  @Test(arguments: [false, true])
  func anotherRequestRevalidatesChangedLabelContentAndAllowsRepair(category: Bool) async throws {
    let fixture = try await SharedLabelFixture.create()
    guard case .draft(let prepared) = await fixture.prepare() else { throw CancellationError() }
    try await fixture.changeLabelName(category: category, name: " ")
    guard case .rejected(let failure) = await fixture.edit(prepared, selectingLabels: false),
      case .draft(let retained) = await fixture.planner.readCapture(
        session: fixture.session, draftId: prepared.draftId)
    else {
      Issue.record("A previous read cannot authorize newly malformed label content.")
      return
    }
    #expect(failure.code == "invalidInput")
    #expect(retained.generation == prepared.generation && retained.content == prepared.content)
    try await fixture.changeLabelName(category: category, name: "Repaired label")
    guard case .draft(let repaired) = await fixture.edit(prepared),
      case .source(.item(let item)) = await fixture.planner.read(
        session: fixture.session, request: .source(try #require(fixture.items.first)))
    else { throw CancellationError() }
    #expect(repaired.reuseCandidates == prepared.reuseCandidates)
    let reference = category ? fixture.category : fixture.tag
    #expect(item.labels.first { $0.reference == reference }?.name == "Repaired label")
  }

  enum GraphFault: CaseIterable {
    case itemAssociation, unrelatedAssociation, duplicateTag, duplicateCategory
  }

  @Test(arguments: GraphFault.allCases)
  func sharedLabelsCannotHideMalformedAssociationsOrDuplicatePhysicalModels(_ fault: GraphFault)
    async throws
  {
    let fixture = try await SharedLabelFixture.create()
    guard case .draft(let prepared) = await fixture.prepare() else { throw CancellationError() }
    try await fixture.damageGraph(fault)
    guard case .rejected(let failure) = await fixture.edit(prepared, selectingLabels: false),
      case .draft(let retained) = await fixture.planner.readCapture(
        session: fixture.session, draftId: prepared.draftId)
    else {
      Issue.record("Every association and every physical label must retain its validation.")
      return
    }
    switch fault {
    case .itemAssociation, .unrelatedAssociation: #expect(failure.code == "readUnavailable")
    case .duplicateTag, .duplicateCategory: #expect(failure.code == "invalidInput")
    }
    #expect(retained.generation == prepared.generation && retained.content == prepared.content)
  }
}

struct SharedLabelRowWindowTests {
  @Test func listPagesKeepEverySharedLabelAndRefreshAfterAnotherWriterRenamesThem() async throws {
    let fixture = try await SharedLabelFixture.create()
    guard
      case .applied(let creation, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createList(content: .init(name: "Shared-label List")))
      ).outcome, let list = creation.generated.first
    else { throw CancellationError() }
    for item in fixture.items {
      guard
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome
      else { throw CancellationError() }
    }
    let request = PlannerQueryRequest.items(
      .init(scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual)))
    let snapshot = try await fixture.itemQuery(request)
    let first = try await fixture.rowWindow(snapshot, offset: 0, limit: 2)
    let second = try await fixture.rowWindow(snapshot, offset: 2, limit: 64)
    #expect(first.rows.count == 2 && second.rows.count == 2)
    #expect(first.matchingCount == 4 && second.matchingCount == 4)
    for row in first.rows + second.rows {
      #expect(Set(row.labels.map(\.reference)) == [fixture.category, fixture.tag])
      #expect(Set(row.labels.map(\.name)) == ["Shared Category", "Shared Tag"])
    }
    guard
      case .source(.category(let category)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.category)),
      case .source(.tag(let tag)) = await fixture.planner.read(
        session: fixture.session, request: .source(fixture.tag))
    else { throw CancellationError() }
    let other = Planner(configuration: fixture.configuration)
    guard case .ready(let otherSession) = await other.bootstrap() else { throw CancellationError() }
    for command: PlannerCommand in [
      .editCategory(
        sourceId: fixture.category.id, changes: .init(name: .set("Renamed Category")),
        expectedFieldHashes: category.fieldHashes),
      .editTag(
        sourceId: fixture.tag.id, changes: .init(name: .set("Renamed Tag")),
        expectedFieldHashes: tag.fieldHashes),
    ] {
      guard
        case .applied(_, .complete) = await other.execute(
          .init(operationId: UUID(), session: otherSession, command: command)
        ).outcome
      else { throw CancellationError() }
    }
    guard
      case .failed(let stale) = await fixture.planner.read(
        session: fixture.session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 64))
    else { throw CancellationError() }
    #expect(stale.code == "staleSnapshot")
    let refreshed = try await fixture.rowWindow(fixture.itemQuery(request))
    #expect(refreshed.rows.count == 4)
    for row in refreshed.rows {
      #expect(row.labels.first { $0.reference == fixture.category }?.name == "Renamed Category")
      #expect(row.labels.first { $0.reference == fixture.tag }?.name == "Renamed Tag")
    }
  }

  @Test(arguments: [false, true])
  func rowWindowsRevalidateMalformedSharedLabelsAndObserveTheirRepair(category: Bool) async throws {
    let fixture = try await SharedLabelFixture.create()
    let original = try await fixture.rowWindow(fixture.itemQuery())
    #expect(original.rows.count == 4 && original.rows.allSatisfy { $0.labels.count == 2 })
    try await fixture.changeLabelName(category: category, name: " ")
    let damaged = try await fixture.itemQuery()
    guard
      case .failed(let failure) = await fixture.planner.read(
        session: fixture.session,
        request: .rows(generation: damaged.generation, offset: 0, limit: 64))
    else {
      Issue.record("A previous row window cannot authorize changed malformed label content.")
      return
    }
    #expect(failure.code == "invalidInput")
    try await fixture.changeLabelName(category: category, name: "Repaired row label")
    let repaired = try await fixture.rowWindow(fixture.itemQuery())
    let reference = category ? fixture.category : fixture.tag
    #expect(repaired.rows.count == 4)
    #expect(
      repaired.rows.allSatisfy {
        $0.labels.first { $0.reference == reference }?.name == "Repaired row label"
      })
  }
}

struct SourceProjectionSharedLabelTests {
  @Test(arguments: [false, true]) @MainActor
  func projectedBatchesObserveRenamesMalformedNamesAndRepairs(category: Bool) async throws {
    let fixture = try await SharedLabelFixture.create()
    let initial = try fixture.projectedItems()
    #expect(Set(initial.map(\.id)) == Set(fixture.items.map(\.id)))
    for item in initial {
      #expect(Set(item.labels.map(\.reference)) == [fixture.category, fixture.tag])
      #expect(Set(item.labels.map(\.name)) == ["Shared Category", "Shared Tag"])
    }
    try fixture.changeLabelName(category: category, name: "Renamed projected label")
    let reference = category ? fixture.category : fixture.tag
    for item in try fixture.projectedItems() {
      #expect(item.labels.first { $0.reference == reference }?.name == "Renamed projected label")
    }
    try fixture.changeLabelName(category: category, name: " ")
    do {
      _ = try fixture.projectedItems()
      Issue.record("A previous projection cannot authorize a newly malformed label.")
    } catch let failure as PlannerFailure {
      #expect(failure.code == "invalidInput")
    }
    try fixture.changeLabelName(category: category, name: "Repaired projected label")
    for item in try fixture.projectedItems() {
      #expect(item.labels.first { $0.reference == reference }?.name == "Repaired projected label")
    }
  }

  @Test(arguments: [CaptureSharedLabelTests.GraphFault.itemAssociation, .unrelatedAssociation])
  @MainActor func projectedBatchesRetainEveryAssociationCheck(
    fault: CaptureSharedLabelTests.GraphFault
  ) async throws {
    let fixture = try await SharedLabelFixture.create()
    #expect(try fixture.projectedItems().count == 4)
    try fixture.damageGraph(fault)
    do {
      _ = try fixture.projectedItems()
      Issue.record("Shared projected labels cannot hide malformed associations.")
    } catch let failure as PlannerFailure {
      #expect(failure.code == "readUnavailable")
    }
  }
}

private struct SharedLabelFixture: Sendable {
  let planner: Planner
  let session: PlannerDatasetSession
  let configuration: PlannerStorageConfiguration
  let category: PlannerEntityReference
  let tag: PlannerEntityReference
  let items: [PlannerEntityReference]
  private static let originalUrl = "https://example.com/shared-label-capture"

  static func create() async throws -> Self {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome, let generated = result.generated.first
      else { throw CancellationError() }
      return generated
    }
    let category = try await save(.createCategory(content: .init(name: "Shared Category")))
    let tag = try await save(.createTag(content: .init(name: "Shared Tag")))
    var items: [PlannerEntityReference] = []
    for index in 0..<4 {
      items.append(
        try await save(
          .createItem(
            content: .init(
              title: "Existing Item \(index)", links: [.init(originalUrl: originalUrl)],
              categoryIds: [category.id], tagIds: [tag.id]))))
    }
    return .init(
      planner: planner, session: session, configuration: configuration,
      category: category, tag: tag, items: items)
  }

  func prepare() async -> PlannerCaptureDraftResult {
    await planner.prepareCapture(session: session, input: .direct([.url(Self.originalUrl)]))
  }

  func itemQuery(
    _ request: PlannerQueryRequest = .items(.init(completion: .all, archive: .all))
  ) async throws -> PlannerQuerySnapshot {
    guard
      case .snapshot(let snapshot) = await planner.query(.init(session: session, request: request))
    else { throw CancellationError() }
    return snapshot
  }

  func rowWindow(_ snapshot: PlannerQuerySnapshot, offset: Int64 = 0, limit: Int64 = 64)
    async throws -> PlannerRowWindow
  {
    guard
      case .rows(let window) = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: offset, limit: limit))
    else { throw CancellationError() }
    return window
  }

  func edit(_ draft: PlannerCaptureDraftRead, selectingLabels: Bool = true) async
    -> PlannerCaptureDraftResult
  {
    await planner.updateCapture(
      session: session, draftId: draft.draftId, generation: draft.generation,
      edit: .init(
        changes: .init(
          title: .set("Captured Item"),
          categoryIds: selectingLabels ? .set([category.id]) : .unchanged,
          tagIds: selectingLabels ? .set([tag.id]) : .unchanged)))
  }

  @MainActor func changeLabelName(category: Bool, name: String) throws {
    let context = try nativeContext()
    if category {
      let record = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).first {
          $0.id == self.category.id
        })
      record.name = name
    } else {
      let record = try #require(
        context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).first { $0.id == tag.id })
      record.name = name
    }
    try context.save()
  }

  @MainActor func projectedItems() throws -> [ItemSnapshot] {
    let context = try nativeContext()
    let projection = try PlannerSourceRestorationConsolidation(context: context, markers: [])
    return try projection.itemValues(context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()))
  }

  @MainActor func damageGraph(_ fault: CaptureSharedLabelTests.GraphFault) throws {
    let context = try nativeContext()
    let tag = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).first { $0.id == self.tag.id })
    let category = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).first {
        $0.id == self.category.id
      })
    let item = try #require(
      context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first { $0.id == items.last?.id })
    switch fault {
    case .itemAssociation:
      let association = try #require(item.labelAssociations?.first { $0.tag != nil })
      association.ownerLifetimeId = UUID()
    case .unrelatedAssociation:
      let dangling = PlannerSchemaV18.LabelAssociation()
      dangling.id = UUID()
      dangling.lifetimeId = UUID()
      dangling.ownerId = UUID()
      dangling.ownerLifetimeId = UUID()
      dangling.labelKind = "tag"
      dangling.labelId = tag.id
      dangling.labelLifetimeId = tag.lifetimeId
      dangling.tag = tag
      context.insert(dangling)
    case .duplicateTag:
      let duplicate = try PlannerSchemaV18.Tag(content: .init(name: "Other physical Tag"))
      duplicate.id = tag.id
      duplicate.lifetimeId = tag.lifetimeId
      duplicate.name = " "
      context.insert(duplicate)
      let association = try #require(item.labelAssociations?.first { $0.tag != nil })
      association.tag = duplicate
    case .duplicateCategory:
      let duplicate = try PlannerSchemaV18.Category(content: .init(name: "Other physical Category"))
      duplicate.id = category.id
      duplicate.lifetimeId = category.lifetimeId
      duplicate.name = " "
      context.insert(duplicate)
      let association = try #require(item.labelAssociations?.first { $0.category != nil })
      association.category = duplicate
    }
    try context.save()
  }

  /// Fault injection uses the same persisted native model boundary as sync-delivery tests.
  @MainActor private func nativeContext() throws -> ModelContext {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [
        ModelConfiguration(schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
      ])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    return context
  }
}
