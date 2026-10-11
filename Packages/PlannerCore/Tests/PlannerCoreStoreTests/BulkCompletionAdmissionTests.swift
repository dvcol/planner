import Foundation
import PlannerCore
import SwiftData
import Testing

struct BulkCompletionAdmissionTests {
  @Test(arguments: ["list", "itinerary", "itineraryListEntry"])
  func postSaveRecoveryFailureRetainsEveryAppliedChildAndBlocksLaterMutation(_ scopeName: String)
    async throws
  {
    let fixture = try await BulkCompletionFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let scope: PlannerBulkScope
    let listDone: Int64
    let itineraryDone: Int64
    switch scopeName {
    case "list":
      scope = .list(listId: fixture.list.id)
      listDone = 2
      itineraryDone = 0
    case "itinerary":
      scope = .itinerary(itineraryId: fixture.itinerary.id)
      listDone = 0
      itineraryDone = 3
    default:
      scope = .itineraryListEntry(
        itineraryId: fixture.itinerary.id, listEntryId: fixture.listEntryId)
      listDone = 0
      itineraryDone = 2
    }
    let command = PlannerCommand.setBulkCompletion(scope: scope, done: true)
    let review = try await fixture.review(command)
    let beforeRecovery = try await fixture.recovery()
    let obstruction = NativeSaveRecoveryObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let operationIdentifier = UUID()
    let result = await fixture.planner.execute(
      .init(
        operationId: operationIdentifier, session: fixture.session, command: command,
        reviewToken: review.reviewToken))
    #expect(obstruction.didObstruct, "The scoped native save notification must trigger the fault.")
    #expect(obstruction.failure == nil)
    guard case .applied(_, .incomplete(let reason)) = result.outcome else {
      throw CancellationError()
    }
    #expect(reason.code == "recoveryIncomplete")
    try obstruction.restore()
    try await fixture.expectProgress(
      listDone: listDone, listTotal: 2, itineraryDone: itineraryDone, itineraryTotal: 3)
    #expect(try await fixture.recovery() == beforeRecovery)
    guard
      case .appliedRecoveryIncomplete = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationIdentifier),
      case .rejected(let blocked) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .createItem(content: .init(title: "Must stay unapplied")))
      )
      .outcome
    else { throw CancellationError() }
    #expect(blocked.code == "mutationBlocked")
    try await fixture.expectProgress(
      listDone: listDone, listTotal: 2, itineraryDone: itineraryDone, itineraryTotal: 3)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      throw CancellationError()
    }
    for (queryScope, done, total) in [
      (PlannerItemQuery.Scope.list(fixture.list.id), listDone, Int64(2)),
      (.itinerary(fixture.itinerary.id), itineraryDone, Int64(3)),
    ] {
      guard
        case .snapshot(let snapshot) = await reopened.query(
          .init(session: reopenedSession, request: .items(.init(scope: queryScope))))
      else { throw CancellationError() }
      #expect(
        snapshot.progress.first?.doneCount == done && snapshot.progress.first?.totalCount == total)
    }
  }

  @Test func canceledMissingChangedAndForeignReviewsNeverMutateThePlanner() async throws {
    let fixture = try await BulkCompletionFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let originalRecovery = try await fixture.recovery()
    let command = PlannerCommand.setBulkCompletion(
      scope: .list(listId: fixture.list.id), done: true)
    let review = try await fixture.review(command)
    let canceledRecovery = try await fixture.recovery()
    #expect(canceledRecovery == originalRecovery)
    let noReviewId = UUID()
    guard
      case .rejected(let noReview) = await fixture.planner.execute(
        .init(operationId: noReviewId, session: fixture.session, command: command)
      ).outcome,
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: noReviewId),
      case .failed(let ordinary) = await fixture.planner.prepareReview(
        session: fixture.session, command: .createItem(content: .init(title: "Not saved"))),
      case .failed(let missing) = await fixture.planner.prepareReview(
        session: fixture.session,
        command: .setBulkCompletion(scope: .list(listId: UUID()), done: true)),
      case .failed(let invalidEntry) = await fixture.planner.prepareReview(
        session: fixture.session,
        command: .setBulkCompletion(
          scope: .itineraryListEntry(
            itineraryId: fixture.itinerary.id, listEntryId: fixture.directEntryId), done: true))
    else { throw CancellationError() }
    #expect(noReview.code == "staleReview" && noReview.propertyPath == "/reviewToken")
    #expect(ordinary.code == "invalidInput" && ordinary.propertyPath == "/command/type")
    #expect(missing.code == "missingReference" && invalidEntry.code == "missingReference")
    guard case .ready(let anotherSession) = await fixture.planner.bootstrap() else {
      throw CancellationError()
    }
    for (session, changedCommand) in [
      (anotherSession, command),
      (fixture.session, .setBulkCompletion(scope: .list(listId: fixture.list.id), done: false)),
      (
        fixture.session,
        .setBulkCompletion(scope: .itinerary(itineraryId: fixture.itinerary.id), done: true)
      ),
    ] {
      guard
        case .rejected(let stale) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: session, command: changedCommand,
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
      #expect(stale.code == "staleReview")
    }
    let writer = Planner(configuration: fixture.configuration)
    guard case .ready(let writerSession) = await writer.bootstrap(),
      case .applied(let created, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: writerSession,
          command: .createItem(content: .init(title: "New child")))
      ).outcome,
      let child = created.generated.first,
      case .applied(_, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: writerSession,
          command: .addMembership(itemId: child.id, listId: fixture.list.id, placement: .last))
      ).outcome
    else { throw CancellationError() }
    let beforeRejection = try await fixture.recovery()
    guard
      case .rejected(let changedTargets) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    #expect(changedTargets.code == "staleReview")
    try await fixture.expectProgress(listDone: 0, listTotal: 3, itineraryDone: 0, itineraryTotal: 4)
    #expect(try await fixture.recovery() == beforeRejection)
    let fresh = try await fixture.review(command)
    #expect(fresh.targetCount == 3)
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: command,
          reviewToken: fresh.reviewToken)
      ).outcome
    else { throw CancellationError() }
    try await fixture.expectProgress(listDone: 3, listTotal: 3, itineraryDone: 0, itineraryTotal: 4)
  }

  @Test func emptyReviewsRemainNoItemsAndBlockedRecoveryLeavesAllTargetsUnchanged() async throws {
    let fixture = try await BulkCompletionFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    for command in [
      PlannerCommand.createList(content: .init(name: "Empty")),
      .createItinerary(content: .init(title: "Empty")),
    ] {
      let source = try #require(try await fixture.save(command).generated.first)
      let scope: PlannerBulkScope
      let queryScope: PlannerItemQuery.Scope
      if source.kind == .list {
        scope = .list(listId: source.id)
        queryScope = .list(source.id)
      } else {
        scope = .itinerary(itineraryId: source.id)
        queryScope = .itinerary(source.id)
      }
      let review = try await fixture.review(.setBulkCompletion(scope: scope, done: true))
      #expect(review.targets.isEmpty && review.targetCount == 0 && !review.globalFlagsChanged)
      guard
        case .applied(_, .complete) = await fixture.planner.execute(
          .init(
            operationId: UUID(), session: fixture.session, command: review.command,
            reviewToken: review.reviewToken)
        ).outcome,
        case .snapshot(let empty) = await fixture.planner.query(
          .init(session: fixture.session, request: .items(.init(scope: queryScope))))
      else { throw CancellationError() }
      #expect(empty.progress.first?.state == .empty && empty.progress.first?.totalCount == 0)
    }
    let command = PlannerCommand.setBulkCompletion(
      scope: .itinerary(itineraryId: fixture.itinerary.id), done: true)
    let review = try await fixture.review(command)
    let originalRecovery = try await fixture.recovery()
    let recovery = fixture.configuration.recoveryDirectoryURL
    let retained = fixture.directory.appendingPathComponent("retained-recovery")
    try FileManager.default.moveItem(at: recovery, to: retained)
    try Data("Obstruct independent recovery.".utf8).write(to: recovery)
    let operationId = UUID()
    let attempted = await fixture.planner.execute(
      .init(
        operationId: operationId, session: fixture.session, command: command,
        reviewToken: review.reviewToken))
    try FileManager.default.removeItem(at: recovery)
    try FileManager.default.moveItem(at: retained, to: recovery)
    guard case .rejected(let failure) = attempted.outcome,
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: operationId)
    else { throw CancellationError() }
    #expect(failure.code == "persistenceFailure")
    #expect(try await fixture.recovery() == originalRecovery)
    try await fixture.expectProgress(listDone: 0, listTotal: 2, itineraryDone: 0, itineraryTotal: 3)
  }
}

private struct BulkCompletionFixture {
  let directory: URL
  let configuration: PlannerStorageConfiguration
  let planner: Planner
  let session: PlannerDatasetSession
  let list: PlannerEntityReference
  let itinerary: PlannerEntityReference
  let directEntryId: UUID
  let listEntryId: UUID

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
    let hotel = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let museum = try #require(
      try await save(.createItem(content: .init(title: "Museum"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Food"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    for item in [hotel, museum] {
      _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    }
    guard
      case .itineraryEntry(let directEntryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: hotel, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    guard
      case .itineraryEntry(let listEntryId, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    return .init(
      directory: directory, configuration: configuration, planner: planner,
      session: session, list: list, itinerary: itinerary, directEntryId: directEntryId,
      listEntryId: listEntryId)
  }

  func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
    else { throw CancellationError() }
    return result
  }

  func review(_ command: PlannerCommand) async throws -> PlannerReview {
    guard
      case .reviewed(let review) = await planner.prepareReview(session: session, command: command)
    else { throw CancellationError() }
    return review
  }

  func recovery() async throws -> Data {
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let selection) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    return selection.portableData
  }

  func expectProgress(
    listDone: Int64, listTotal: Int64, itineraryDone: Int64, itineraryTotal: Int64
  )
    async throws
  {
    for (scope, done, total) in [
      (PlannerItemQuery.Scope.list(list.id), listDone, listTotal),
      (.itinerary(itinerary.id), itineraryDone, itineraryTotal),
    ] {
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(session: session, request: .items(.init(scope: scope))))
      else { throw CancellationError() }
      #expect(
        snapshot.progress.first?.doneCount == done && snapshot.progress.first?.totalCount == total)
    }
  }
}

final class NativeSaveRecoveryObstruction: @unchecked Sendable {
  private let lock = NSLock()
  private let storeURL: URL
  private let recoveryURL: URL
  private let retainedURL: URL
  private var obstructed = false
  private var obstructionFailure: String?

  init(configuration: PlannerStorageConfiguration) {
    storeURL = configuration.storeURL.standardizedFileURL
    recoveryURL = configuration.recoveryDirectoryURL
    retainedURL = recoveryURL.deletingLastPathComponent()
      .appendingPathComponent("retained-after-native-save")
  }

  var didObstruct: Bool { lock.withLock { obstructed } }
  var failure: String? { lock.withLock { obstructionFailure } }

  func observe(_ notification: Notification) {
    guard let context = notification.object as? ModelContext,
      context.container.configurations.contains(where: { $0.url.standardizedFileURL == storeURL })
    else { return }
    lock.withLock {
      guard !obstructed else { return }
      obstructed = true
      do {
        try FileManager.default.moveItem(at: recoveryURL, to: retainedURL)
        try Data("Obstruct recovery after native save.".utf8).write(to: recoveryURL)
      } catch {
        obstructionFailure = String(describing: error)
      }
    }
  }

  func restore() throws {
    guard FileManager.default.fileExists(atPath: retainedURL.path) else { return }
    if FileManager.default.fileExists(atPath: recoveryURL.path) {
      try FileManager.default.removeItem(at: recoveryURL)
    }
    try FileManager.default.moveItem(at: retainedURL, to: recoveryURL)
  }
}
