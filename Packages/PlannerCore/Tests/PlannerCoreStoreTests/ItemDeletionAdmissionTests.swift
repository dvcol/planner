import Foundation
import PlannerCore
import SwiftData
import Testing

struct ItemDeletionAdmissionTests {
  @Test(arguments: ["membership", "entry", "schedule", "link", "expanded"])
  func anotherWritersRemovalSetChangeRequiresFreshItemReview(_ change: String) async throws {
    let fixture = try await ItemDeletionFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let review = try await fixture.review()
    let writer = Planner(configuration: fixture.configuration)
    guard case .ready(let writerSession) = await writer.bootstrap() else {
      throw CancellationError()
    }
    let command: PlannerCommand
    switch change {
    case "membership":
      let otherList = try #require(
        try await fixture.save(.createList(content: .init(name: "Other"))).generated.first)
      command = .addMembership(itemId: fixture.item.id, listId: otherList.id, placement: .last)
    case "entry":
      command = .addItineraryEntry(
        itineraryId: fixture.itinerary.id, source: fixture.item, placement: .last)
    case "schedule":
      command = .createSchedule(
        source: fixture.item,
        form: .timed(
          start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
          planningTimeZone: "Asia/Tokyo"))
    case "link":
      let item = try await fixture.itemRead()
      command = .editItem(
        sourceId: fixture.item.id,
        changes: .init(
          links: .set([.init(originalUrl: "https://example.com/museum", label: "Tickets")])),
        expectedFieldHashes: item.fieldHashes)
    case "expanded":
      command = .setCompletion(scope: .appearance(fixture.expandedAppearance), done: true)
    default: throw CancellationError()
    }
    guard
      case .applied(_, .complete) = await writer.execute(
        .init(operationId: UUID(), session: writerSession, command: command)
      ).outcome
    else { throw CancellationError() }
    let before = try await fixture.recovery()
    let operationId = UUID()
    guard
      case .rejected(let stale) = await fixture.planner.execute(
        .init(
          operationId: operationId, session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationId)
    else { throw CancellationError() }
    #expect(stale.code == "staleReview")
    #expect(try await fixture.recovery().portableData == before.portableData)
    #expect(try await fixture.itemRead().content.notes == "Keep until confirmed")
    let fresh = try await fixture.review()
    #expect(fresh.targetCount == 3)
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: fresh.command,
          reviewToken: fresh.reviewToken)
      ).outcome
    else { throw CancellationError() }
    #expect(try await fixture.recovery().decodedBackup.backup.memberships.isEmpty)
  }

  @Test func unreviewedForeignAndChangedCommandsLeaveItemUnchangedAndReplayBindsTheDeletedSource()
    async throws
  {
    let fixture = try await ItemDeletionFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let otherItem = try #require(
      try await fixture.save(.createItem(content: .init(title: "Other"))).generated.first)
    let review = try await fixture.review()
    guard case .ready(let otherSession) = await fixture.planner.bootstrap() else {
      throw CancellationError()
    }
    let before = try await fixture.recovery()
    for (session, source, token) in [
      (fixture.session, fixture.item, nil),
      (fixture.session, fixture.item, PlannerReviewToken(opaqueValue: UUID().uuidString)),
      (otherSession, fixture.item, review.reviewToken),
      (fixture.session, otherItem, review.reviewToken),
    ] {
      let operationId = UUID()
      guard
        case .rejected(let rejected) = await fixture.planner.execute(
          .init(
            operationId: operationId, session: session, command: .deleteSource(source: source),
            reviewToken: token)
        ).outcome,
        case .noReliableEvidence = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationId)
      else { throw CancellationError() }
      #expect(rejected.code == "staleReview")
    }
    #expect(try await fixture.recovery().portableData == before.portableData)
    let operationId = UUID()
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: operationId, session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .rejected(let mismatch) = await fixture.planner.execute(
        .init(
          operationId: operationId, session: fixture.session,
          command: .deleteSource(source: otherItem))
      ).outcome
    else { throw CancellationError() }
    #expect(mismatch.code == "operationPayloadMismatch")
    for command in [
      PlannerCommand.addMembership(
        itemId: fixture.item.id, listId: fixture.list.id, placement: .last),
      .setCompletion(scope: .globalItem(itemId: fixture.item.id), done: true),
    ] {
      guard
        case .rejected(let missing) = await fixture.planner.execute(
          .init(operationId: UUID(), session: fixture.session, command: command)
        ).outcome
      else { throw CancellationError() }
      #expect(missing.code == "missingReference")
    }
    guard
      case .source(.item(let retained)) = await fixture.planner.read(
        session: fixture.session, request: .source(otherItem))
    else { throw CancellationError() }
    #expect(retained.content.title == "Other")
  }

  @Test func unavailableRecoveryBeforeSaveLeavesTheWholeItemClosureUnapplied() async throws {
    let fixture = try await ItemDeletionFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
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
    let operationId = UUID()
    guard
      case .rejected = await fixture.planner.execute(
        .init(
          operationId: operationId, session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retained, to: recoveryDirectory)
    #expect(try await fixture.recovery().portableData == before.portableData)
    #expect(try await fixture.itemRead().content.notes == "Keep until confirmed")
    guard
      case .appearance(let appearance) = await fixture.planner.read(
        session: fixture.session, request: .appearance(fixture.expandedAppearance)),
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationId)
    else { throw CancellationError() }
    #expect(appearance.localDone == false && appearance.effectiveDone == false)
  }

  @Test func postSaveRecoveryFailureRetainsTheDeletionAndBlocksLaterWritesAfterRelaunch()
    async throws
  {
    let fixture = try await ItemDeletionFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
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
    let operationId = UUID()
    guard
      case .applied(let applied, .incomplete(let failure)) = await fixture.planner.execute(
        .init(
          operationId: operationId, session: fixture.session, command: review.command,
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
        session: session, request: .source(fixture.item)),
      case .source(.list(let list)) = await reopened.read(
        session: session, request: .source(fixture.list)),
      case .source(.itinerary(let itinerary)) = await reopened.read(
        session: session, request: .source(fixture.itinerary)),
      case .appliedRecoveryIncomplete(let status, _) = await reopened.operationStatus(
        session: session, operationId: operationId),
      case .applied(let replay, .incomplete) = await reopened.execute(
        .init(operationId: operationId, session: session, command: review.command)
      ).outcome,
      case .rejected(let blocked) = await reopened.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Blocked")))
      ).outcome
    else { throw CancellationError() }
    #expect(missing.code == "missingReference")
    #expect(list.progress.state == .empty && itinerary.progress.state == .empty)
    #expect(status == applied && replay == applied)
    #expect(blocked.code == "mutationBlocked")
  }
}

private struct ItemDeletionFixture {
  let directory: URL
  let configuration: PlannerStorageConfiguration
  let planner: Planner
  let session: PlannerDatasetSession
  let item: PlannerEntityReference
  let list: PlannerEntityReference
  let itinerary: PlannerEntityReference
  let expandedAppearance: PlannerAppearance

  static func create() async throws -> Self {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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
      try await save(.createItem(content: .init(title: "Museum", notes: "Keep until confirmed")))
        .generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Wishlist"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Weekend"))).generated.first)
    guard
      case .membership(let membershipId, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first,
      case .itineraryEntry(let entryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    return .init(
      directory: directory, configuration: configuration, planner: planner, session: session,
      item: item, list: list, itinerary: itinerary,
      expandedAppearance: .expandedListItem(
        itineraryId: itinerary.id, listEntryId: entryId, membershipId: membershipId))
  }

  func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
    else { throw CancellationError() }
    return result
  }

  func review() async throws -> PlannerReview {
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: item))
    else { throw CancellationError() }
    return review
  }

  func itemRead() async throws -> PlannerItemSourceRead {
    guard
      case .source(.item(let item)) = await planner.read(session: session, request: .source(item))
    else { throw CancellationError() }
    return item
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
