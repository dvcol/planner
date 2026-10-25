import Foundation
import PlannerCore
import SwiftData
import Testing

struct ItineraryDeletionAdmissionTests {
  @Test(arguments: ["entry", "expanded", "link", "schedule", "label"])
  func anotherWritersRemovalSetChangeRequiresFreshItineraryReview(_ change: String) async throws {
    let fixture = try await ItineraryDeletionFixture.create()
    let review = try await fixture.review()
    let writer = Planner(configuration: fixture.configuration)
    guard case .ready(let writerSession) = await writer.bootstrap() else {
      throw CancellationError()
    }
    let command: PlannerCommand
    switch change {
    case "entry":
      command = .addItineraryEntry(
        itineraryId: fixture.itinerary.id, source: fixture.item, placement: .last)
    case "expanded":
      command = .setCompletion(scope: .appearance(fixture.appearance), done: true)
    case "link":
      let itinerary = try await fixture.itineraryRead()
      command = .editItinerary(
        sourceId: fixture.itinerary.id,
        changes: .init(
          links: .set([.init(originalUrl: "https://example.com/booking", label: "Booking")])),
        expectedFieldHashes: itinerary.fieldHashes)
    case "schedule":
      command = .createSchedule(
        source: fixture.itinerary,
        form: .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil))
    case "label":
      let category = try #require(
        try await fixture.save(.createCategory(content: .init(name: "Culture"))).generated.first)
      let itinerary = try await fixture.itineraryRead()
      command = .editItinerary(
        sourceId: fixture.itinerary.id, changes: .init(categoryIds: .set([category.id])),
        expectedFieldHashes: itinerary.fieldHashes)
    default: throw CancellationError()
    }
    guard
      case .applied(_, .complete) = await writer.execute(
        .init(operationId: UUID(), session: writerSession, command: command)
      ).outcome
    else { throw CancellationError() }
    let before = try await fixture.recovery()
    let operationIdentifier = UUID()
    guard
      case .rejected(let stale) = await fixture.planner.execute(
        .init(
          operationId: operationIdentifier, session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(stale.code == "staleReview")
    #expect(try await fixture.recovery().portableData == before.portableData)
    #expect(try await fixture.itineraryRead().content.notes == "Keep until confirmed")
    let fresh = try await fixture.review()
    #expect(fresh.targetCount == 3)
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: fresh.command,
          reviewToken: fresh.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let backup = try await fixture.recovery().decodedBackup.backup
    #expect(backup.itineraryEntries.isEmpty && backup.expandedCompletions.isEmpty)
    #expect(backup.memberships.count == 1 && backup.schedules.isEmpty)
    #expect(try await fixture.itemRead().content.notes == "Keep the Item")
    #expect(try await fixture.listRead().progress.totalCount == 1)
  }

  @Test func unreviewedForeignAndChangedCommandsPreserveTheItineraryAndReplayBindsItsIdentity()
    async throws
  {
    let fixture = try await ItineraryDeletionFixture.create()
    let otherItinerary = try #require(
      try await fixture.save(.createItinerary(content: .init(title: "Other"))).generated.first)
    let review = try await fixture.review()
    guard case .ready(let otherSession) = await fixture.planner.bootstrap() else {
      throw CancellationError()
    }
    let before = try await fixture.recovery()
    for (session, source, token) in [
      (fixture.session, fixture.itinerary, nil),
      (fixture.session, fixture.itinerary, PlannerReviewToken(opaqueValue: UUID().uuidString)),
      (otherSession, fixture.itinerary, review.reviewToken),
      (fixture.session, otherItinerary, review.reviewToken),
    ] {
      let operationIdentifier = UUID()
      guard
        case .rejected(let rejected) = await fixture.planner.execute(
          .init(
            operationId: operationIdentifier, session: session,
            command: .deleteSource(source: source),
            reviewToken: token)
        ).outcome,
        case .noReliableEvidence = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationIdentifier)
      else { throw CancellationError() }
      #expect(rejected.code == "staleReview")
    }
    #expect(try await fixture.recovery().portableData == before.portableData)
    let operationIdentifier = UUID()
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: operationIdentifier, session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .rejected(let mismatch) = await fixture.planner.execute(
        .init(
          operationId: operationIdentifier, session: fixture.session,
          command: .deleteSource(source: otherItinerary))
      ).outcome
    else { throw CancellationError() }
    #expect(mismatch.code == "operationPayloadMismatch")
    for command in [
      PlannerCommand.addItineraryEntry(
        itineraryId: fixture.itinerary.id, source: fixture.item, placement: .last),
      .createSchedule(
        source: fixture.itinerary,
        form: .allDay(start: .init(year: 2026, month: 10, day: 9), end: nil)),
    ] {
      guard
        case .rejected(let missing) = await fixture.planner.execute(
          .init(operationId: UUID(), session: fixture.session, command: command)
        ).outcome
      else { throw CancellationError() }
      #expect(missing.code == "missingReference")
    }
    #expect(try await fixture.itemRead().content.notes == "Keep the Item")
    #expect(try await fixture.listRead().progress.totalCount == 1)
    guard
      case .source(.itinerary(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(otherItinerary))
    else { throw CancellationError() }
    #expect(retained.content.title == "Other" && retained.progress.state == .empty)
  }

  @Test func unavailableRecoveryBeforeSaveLeavesTheWholeItineraryClosureUnapplied() async throws {
    let fixture = try await ItineraryDeletionFixture.create()
    let before = try await fixture.recovery()
    let review = try await fixture.review()
    let recoveryDirectory = fixture.configuration.recoveryDirectoryURL
    let retained = fixture.directory.appendingPathComponent("retained-recovery")
    try FileManager.default.moveItem(at: recoveryDirectory, to: retained)
    try Data("Obstruct recovery before deletion".utf8).write(to: recoveryDirectory)
    defer {
      try? FileManager.default.removeItem(at: recoveryDirectory)
      try? FileManager.default.moveItem(at: retained, to: recoveryDirectory)
    }
    let operationIdentifier = UUID()
    guard
      case .rejected = await fixture.planner.execute(
        .init(
          operationId: operationIdentifier, session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retained, to: recoveryDirectory)
    #expect(try await fixture.recovery().portableData == before.portableData)
    #expect(try await fixture.itineraryRead().content.notes == "Keep until confirmed")
    guard
      case .appearance(let appearance) = await fixture.planner.read(
        session: fixture.session, request: .appearance(fixture.appearance)),
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(appearance.localDone == false && appearance.effectiveDone == false)
  }

  @Test func postSaveRecoveryFailureKeepsSourcesAndBlocksLaterWritesAfterRelaunch() async throws {
    let fixture = try await ItineraryDeletionFixture.create()
    let before = try await fixture.recovery()
    let review = try await fixture.review()
    let obstruction = NativeSaveRecoveryObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    guard
      case .applied(let applied, .incomplete(let failure)) = await fixture.planner.execute(
        .init(
          operationId: operationIdentifier, session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    #expect(failure.code == "recoveryIncomplete")
    try obstruction.restore()
    #expect(try await fixture.recovery().portableData == before.portableData)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .failed(let missing) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .source(.list(let list)) = await reopened.read(
        session: session, request: .source(fixture.list)),
      case .appliedRecoveryIncomplete(let status, _) = await reopened.operationStatus(
        session: session, operationId: operationIdentifier),
      case .applied(let replay, .incomplete) = await reopened.execute(
        .init(operationId: operationIdentifier, session: session, command: review.command)
      ).outcome,
      case .rejected(let blocked) = await reopened.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Blocked")))
      ).outcome
    else { throw CancellationError() }
    #expect(missing.code == "missingReference")
    #expect(item.content.notes == "Keep the Item" && list.progress.totalCount == 1)
    #expect(status == applied && replay == applied)
    #expect(blocked.code == "mutationBlocked")
  }

  @Test func emptyItineraryDeletionKeepsUnrelatedMembershipsAndSourceState() async throws {
    let fixture = try await ItineraryDeletionFixture.create()
    let emptyItinerary = try #require(
      try await fixture.save(.createItinerary(content: .init(title: "Empty"))).generated.first)
    let before = try await fixture.recovery()
    let itineraryBefore = try await fixture.itineraryRead()
    let itemBefore = try await fixture.itemRead()
    guard
      case .reviewed(let review) = await fixture.planner.prepareReview(
        session: fixture.session, command: .deleteSource(source: emptyItinerary)),
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    #expect(review.targetCount == 1 && review.impact.referenceRemovals.isEmpty)
    #expect(review.impact.sourceDeletes == [emptyItinerary])
    let after = try await fixture.recovery()
    #expect(
      after.decodedBackup.backup.memberships.count == before.decodedBackup.backup.memberships.count)
    #expect(
      after.decodedBackup.backup.itineraryEntries.count
        == before.decodedBackup.backup.itineraryEntries.count)
    #expect(try await fixture.itemRead().fieldHashes == itemBefore.fieldHashes)
    #expect(try await fixture.itineraryRead().fieldHashes == itineraryBefore.fieldHashes)
  }
}

private struct ItineraryDeletionFixture {
  let directory: URL
  let configuration: PlannerStorageConfiguration
  let planner: Planner
  let session: PlannerDatasetSession
  let item: PlannerEntityReference
  let list: PlannerEntityReference
  let itinerary: PlannerEntityReference
  let appearance: PlannerAppearance

  static func create() async throws -> Self {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Museum", notes: "Keep the Item")))
        .generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Wishlist", notes: "Keep the List")))
        .generated.first)
    let itinerary = try #require(
      try await save(
        .createItinerary(content: .init(title: "Weekend", notes: "Keep until confirmed"))
      )
      .generated.first)
    guard
      case .membership(let membershipIdentifier, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let entryIdentifier, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
      )
      .generatedReferences.first
    else { throw CancellationError() }
    return .init(
      directory: directory, configuration: configuration, planner: planner, session: session,
      item: item, list: list, itinerary: itinerary,
      appearance: .expandedListItem(
        itineraryId: itinerary.id, listEntryId: entryIdentifier, membershipId: membershipIdentifier)
    )
  }

  func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
    let outcome = await planner.execute(
      .init(operationId: UUID(), session: session, command: command)
    ).outcome
    guard case .applied(let result, .complete) = outcome else {
      Issue.record("Create the fixture through public commands: \(outcome)")
      throw CancellationError()
    }
    return result
  }

  func review() async throws -> PlannerReview {
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: itinerary))
    else { throw CancellationError() }
    return review
  }

  func itineraryRead() async throws -> PlannerItinerarySourceRead {
    guard
      case .source(.itinerary(let value)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    return value
  }

  func listRead() async throws -> PlannerListSourceRead {
    guard
      case .source(.list(let value)) = await planner.read(
        session: session, request: .source(list))
    else { throw CancellationError() }
    return value
  }

  func itemRead() async throws -> PlannerItemSourceRead {
    guard
      case .source(.item(let value)) = await planner.read(
        session: session, request: .source(item))
    else { throw CancellationError() }
    return value
  }

  func recovery() async throws -> PlannerRecoverySelection {
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let selection) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    return selection
  }
}
