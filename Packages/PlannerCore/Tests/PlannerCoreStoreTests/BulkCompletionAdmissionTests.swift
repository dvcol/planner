import Foundation
import PlannerCore
import SwiftData
import Testing

#if os(macOS)
  import Darwin
#endif

struct BulkCompletionAdmissionTests {
  #if os(macOS)
    @Test func failedNativeSaveRollsBackEveryBulkTargetAndAllowsTheReviewedRetry() async throws {
      guard ProcessInfo.processInfo.environment["PLANNER_BULK_WRITE_FAULT_CHILD"] == "1" else {
        try runIsolatedWriteFailure()
        return
      }
      for scopeName in ["list", "itinerary", "itineraryListEntry"] {
        let fixture = try await BulkCompletionFixture.create()
        let scope: PlannerBulkScope
        let expectedListDone: Int64
        let expectedItineraryDone: Int64
        switch scopeName {
        case "list":
          scope = .list(listId: fixture.list.id)
          expectedListDone = 2
          expectedItineraryDone = 0
        case "itinerary":
          scope = .itinerary(itineraryId: fixture.itinerary.id)
          expectedListDone = 0
          expectedItineraryDone = 3
        default:
          scope = .itineraryListEntry(
            itineraryId: fixture.itinerary.id, listEntryId: fixture.listEntryId)
          expectedListDone = 0
          expectedItineraryDone = 2
        }
        let command = PlannerCommand.setBulkCompletion(scope: scope, done: true)
        let review = try await fixture.review(command)
        guard
          case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
        else { throw CancellationError() }
        let beforeRecovery = try await fixture.recovery()
        let obstruction = NativeSaveFileSizeObstruction(
          configuration: fixture.configuration, maximumFileSize: 1)
        let observer = NotificationCenter.default.addObserver(
          forName: ModelContext.willSave, object: nil, queue: nil
        ) { notification in obstruction.observe(notification) }
        defer {
          NotificationCenter.default.removeObserver(observer)
          try? obstruction.restore()
        }
        let operationIdentifier = UUID()
        let operation = PlannerOperation(
          operationId: operationIdentifier, session: fixture.session, command: command,
          reviewToken: review.reviewToken)
        let failed = await fixture.planner.execute(operation)
        try obstruction.restore()
        #expect(obstruction.didObstruct && obstruction.failureMessage == nil)
        guard case .rejected(let failure) = failed.outcome else {
          Issue.record(
            "A genuine failed native save must reject the whole \(scopeName) completion.")
          return
        }
        #expect(failure.code == "persistenceFailure")
        let reopened = Planner(configuration: fixture.configuration)
        let reopenedBootstrap = await reopened.bootstrap()
        guard case .ready(let reopenedSession) = reopenedBootstrap else {
          Issue.record("Bulk failed-save reopen must remain ready: \(reopenedBootstrap)")
          return
        }
        let reopenedExport = await reopened.exportData(session: reopenedSession)
        guard case .exported(let after) = reopenedExport else {
          Issue.record("Bulk failed-save export must remain readable: \(reopenedExport)")
          return
        }
        let status = await reopened.operationStatus(
          session: reopenedSession, operationId: operationIdentifier)
        guard case .noReliableEvidence = status else {
          Issue.record("A known failed bulk save must discard its prepared evidence: \(status)")
          return
        }
        #expect(after == before)
        #expect(try await fixture.recovery() == beforeRecovery)
        try await fixture.expectProgress(
          listDone: 0, listTotal: 2, itineraryDone: 0, itineraryTotal: 3)
        let retry = await fixture.planner.execute(operation)
        guard case .applied(let applied, .complete) = retry.outcome else {
          Issue.record(
            "The unchanged reviewed \(scopeName) action must succeed after fault removal.")
          return
        }
        try await fixture.expectProgress(
          listDone: expectedListDone, listTotal: 2, itineraryDone: expectedItineraryDone,
          itineraryTotal: 3)
        guard case .exported(let saved) = await reopened.exportData(session: reopenedSession),
          case .applied(let replayed, .complete) = await fixture.planner.execute(operation).outcome,
          case .exported(let replayedData) = await reopened.exportData(session: reopenedSession)
        else { throw CancellationError() }
        #expect(replayed == applied)
        #expect(replayedData == saved && saved != before)
        let savedRecovery = try await fixture.recovery()
        let savedGraph = try #require(JSONSerialization.jsonObject(with: saved) as? NSDictionary)
        let recoveryGraph = try #require(
          JSONSerialization.jsonObject(with: savedRecovery) as? NSDictionary)
        #expect(recoveryGraph == savedGraph)
      }
    }

    private func runIsolatedWriteFailure() throws {
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "PlannerBulkWriteFailure-" + UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let outputURL = directory.appendingPathComponent("child.log")
      try Data().write(to: outputURL)
      let output = try FileHandle(forWritingTo: outputURL)
      defer { try? output.close() }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      var runnerArguments: [String] = []
      if let index = CommandLine.arguments.firstIndex(of: "--test-bundle-path"),
        CommandLine.arguments.indices.contains(index + 1)
      {
        runnerArguments = ["--test-bundle-path", CommandLine.arguments[index + 1]]
      }
      process.arguments =
        runnerArguments + [
          "--testing-library", "swift-testing", "--filter",
          "BulkCompletionAdmissionTests/failedNativeSaveRollsBackEveryBulkTargetAndAllowsTheReviewedRetry",
        ]
      var environment = ProcessInfo.processInfo.environment
      environment["PLANNER_BULK_WRITE_FAULT_CHILD"] = "1"
      process.environment = environment
      process.standardOutput = output
      process.standardError = output
      let completion = DispatchSemaphore(value: 0)
      process.terminationHandler = { _ in completion.signal() }
      try process.run()
      let finished = completion.wait(timeout: .now() + 45) == .success
      if !finished {
        kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
      }
      try output.close()
      let transcript = try String(contentsOf: outputURL, encoding: .utf8)
      print("Bulk isolated write-fault child log: \(outputURL.path)")
      for line in transcript.split(separator: "\n") where line.hasPrefix("PLANNER_STORE_FIXTURE ") {
        print(line)
      }
      #expect(finished, "The isolated bulk save fault must finish within its deadline.")
      #expect(process.terminationReason == .exit)
      #expect(process.terminationStatus == 0, Comment(rawValue: String(transcript.suffix(12_000))))
      #expect(transcript.contains("Test run with 1 test"))
    }
  #endif

  @Test(arguments: ["list", "itinerary", "itineraryListEntry"])
  func postSaveRecoveryFailureRetainsEveryAppliedChildAndBlocksLaterMutation(_ scopeName: String)
    async throws
  {
    let fixture = try await BulkCompletionFixture.create()
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
