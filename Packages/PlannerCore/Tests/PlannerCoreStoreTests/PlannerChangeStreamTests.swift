import Foundation
import PlannerCore
import Testing

#if os(macOS)
  import Darwin
#endif

struct PlannerChangeStreamTests {
  @Test(arguments: [false, true])
  func recoveryDirectoryRepairKeepsTheSubscriptionAndSavedContent(
    subscribeWhileUnavailable: Bool
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = configuration(directory: directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let saved, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      ).outcome,
      let source = saved.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    let existing = subscribeWhileUnavailable ? nil : await planner.changes(session: session)
    try await Task.sleep(for: .milliseconds(100))
    let recovery = configuration.recoveryDirectoryURL
    let retained = directory.appendingPathComponent("retained-recovery")
    try FileManager.default.moveItem(at: recovery, to: retained)
    try Data("Recovery is temporarily unavailable.".utf8).write(to: recovery)
    defer {
      if FileManager.default.fileExists(atPath: retained.path) {
        try? FileManager.default.removeItem(at: recovery)
        try? FileManager.default.moveItem(at: retained, to: recovery)
      }
    }
    let changes: AsyncThrowingStream<PlannerChange, any Error>
    if let existing {
      changes = existing
    } else {
      changes = await planner.changes(session: session)
    }
    if !subscribeWhileUnavailable {
      _ = try await waitForRecoveryObservation(changes) {
        if case .unavailable = $0 { return true }
        return false
      }
    }
    guard case .status(let unavailable) = await planner.read(session: session, request: .status),
      case .unavailable(let reason) = unavailable.recovery
    else { throw CancellationError() }
    #expect(!reason.message.isEmpty)
    try FileManager.default.removeItem(at: recovery)
    try FileManager.default.moveItem(at: retained, to: recovery)
    _ = try await waitForRecoveryObservation(changes) {
      if case .known(let generation, let incomplete, _, let blocked) = $0 {
        return generation == 1 && incomplete.isEmpty && !blocked
      }
      return false
    }
    guard
      case .source(.item(let current)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    #expect(current.source == source)
    #expect(current.content.title == "Hotel" && current.content.notes == "Original notes")
    #expect(current.updatedAt == original.updatedAt && current.fieldHashes == original.fieldHashes)
  }

  @Test func reviewedBulkInvalidatesLocalProgressAndCompleteReplayDoesNotInventADataChange()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = configuration(directory: directory)
    let reader = Planner(configuration: configuration)
    let writer = Planner(configuration: configuration)
    guard case .ready(let session) = await reader.bootstrap(),
      case .ready(let writerSession) = await writer.bootstrap()
    else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await writer.execute(
          .init(operationId: UUID(), session: writerSession, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let list = try #require(
      try await save(.createList(content: .init(name: "Weekend"))).generated.first)
    var items: [PlannerEntityReference] = []
    for title in ["Hotel", "Museum"] {
      let item = try #require(
        try await save(.createItem(content: .init(title: title, notes: "Retained notes")))
          .generated.first)
      items.append(item)
      _ = try await save(.addMembership(itemId: item.id, listId: list.id, placement: .last))
    }
    let changes = await reader.changes(session: session)
    guard
      case .snapshot(let initial) = await reader.query(
        .init(session: session, request: .items(.init(scope: .list(list.id))))),
      case .reviewed(let review) = await writer.prepareReview(
        session: writerSession,
        command: .setBulkCompletion(scope: .list(listId: list.id), done: true))
    else { throw CancellationError() }
    #expect(initial.progress.first?.doneCount == 0 && initial.progress.first?.totalCount == 2)
    let operation = PlannerOperation(
      operationId: UUID(), session: writerSession, command: review.command,
      reviewToken: review.reviewToken)
    guard case .applied(let saved, .complete) = await writer.execute(operation).outcome else {
      throw CancellationError()
    }
    try await waitForDataInvalidation(changes)
    _ = try await waitForRecoveryObservation(changes) {
      if case .known(let generation, _, _, _) = $0 { return generation == 6 }
      return false
    }
    guard
      case .snapshot(let final) = await reader.query(
        .init(session: session, request: .items(.init(scope: .list(list.id)))))
    else { throw CancellationError() }
    #expect(final.progress.first?.doneCount == 2 && final.progress.first?.totalCount == 2)
    for item in items {
      guard
        case .source(.item(let current)) = await reader.read(
          session: session, request: .source(item))
      else { throw CancellationError() }
      #expect(current.state.globalDone == false && current.content.notes == "Retained notes")
    }
    try await Task.sleep(for: .milliseconds(100))
    guard case .applied(let replayed, .complete) = await writer.execute(operation).outcome else {
      throw CancellationError()
    }
    #expect(replayed.generatedReferences == saved.generatedReferences)
    do {
      try await waitForDataInvalidation(changes)
      Issue.record("Replaying a complete receipt must not invent a new data invalidation.")
    } catch ChangeStreamTestFailure.noInvalidationBeforeTestDeadline {}
  }

  @Test func aBurstOverlappingInitialReadsStillInvalidatesTheFinalCanonicalGeneration() async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = configuration(directory: directory)
    let reader = Planner(configuration: configuration)
    let writer = Planner(configuration: configuration)
    guard case .ready(let session) = await reader.bootstrap(),
      case .ready(let writerSession) = await writer.bootstrap()
    else { throw CancellationError() }
    let changes = await reader.changes(session: session)
    async let initialRead = reader.query(.init(session: session, request: .items(.init())))
    var expectedSources: [PlannerEntityReference] = []
    for position in 0..<30 {
      guard
        case .applied(let saved, .complete) = await writer.execute(
          .init(
            operationId: UUID(), session: writerSession,
            command: .createItem(
              content: .init(
                title: String(format: "Stop %02d", position), notes: "Burst notes \(position)")))
        ).outcome,
        let source = saved.generated.first
      else { throw CancellationError() }
      expectedSources.append(source)
    }
    guard case .snapshot(let initial) = await initialRead else { throw CancellationError() }
    #expect((0...30).contains(initial.matchingCount))
    try await waitForDataInvalidation(changes)
    guard
      case .snapshot(let final) = await reader.query(
        .init(session: session, request: .items(.init()))),
      let finalSource = expectedSources.last,
      case .source(.item(let finalItem)) = await reader.read(
        session: session, request: .source(finalSource)),
      case .status(let status) = await reader.read(session: session, request: .status),
      case .known(let generation, let incomplete, _, let blocked) = status.recovery
    else { throw CancellationError() }
    #expect(final.matchingCount == 30 && final.rows.count == 30)
    #expect(final.rows == expectedSources.map { .source($0) })
    #expect(finalItem.content.title == "Stop 29" && finalItem.content.notes == "Burst notes 29")
    #expect(generation == 30 && incomplete.isEmpty && !blocked)
  }

  @Test func anotherDatasetAndRecoveryNamespaceCannotInvalidateTheSubscribedDataset() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let recoveryDirectory = directory.appendingPathComponent("recovery")
    let first = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("first/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/first"),
        recoveryDirectoryURL: recoveryDirectory, processRole: .mainApplication,
        storageMode: .localOnly))
    let second = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("second/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/second"),
        recoveryDirectoryURL: recoveryDirectory, processRole: .mainApplication,
        storageMode: .localOnly))
    guard case .ready(let firstSession) = await first.bootstrap(),
      case .ready(let secondSession) = await second.bootstrap()
    else { throw CancellationError() }
    let unrelated = await first.changes(session: firstSession)
    let surviving = await first.changes(session: firstSession)
    try await Task.sleep(for: .milliseconds(100))
    guard
      case .applied(_, .complete) = await second.execute(
        .init(
          operationId: UUID(), session: secondSession,
          command: .createItem(content: .init(title: "Other dataset")))
      ).outcome,
      case .listedNamespaces(let namespaces) = await second.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first(where: { $0.datasetId == secondSession.datasetId })
    else { throw CancellationError() }
    let checkpoint = recoveryDirectory.appendingPathComponent(namespace.namespaceId.uuidString)
      .appendingPathComponent("checkpoint-1.json")
    try Data("{ other namespace damage".utf8).write(to: checkpoint, options: .atomic)
    do {
      try await waitForAnyInvalidation(unrelated)
      Issue.record("Another dataset or recovery namespace must not invalidate this subscription.")
    } catch ChangeStreamTestFailure.noInvalidationBeforeTestDeadline {
      // This subscription is cancelled by the negative test deadline; the other remains live.
    }
    guard case .status(let status) = await first.read(session: firstSession, request: .status),
      case .known(let generation, let incomplete, _, let blocked) = status.recovery,
      case .status(let otherStatus) = await second.read(session: secondSession, request: .status),
      case .unavailable = otherStatus.recovery
    else { throw CancellationError() }
    #expect(generation == nil && incomplete.isEmpty && !blocked)
    guard
      case .applied(let saved, .complete) = await first.execute(
        .init(
          operationId: UUID(), session: firstSession,
          command: .createItem(content: .init(title: "Only the subscribed dataset")))
      ).outcome,
      let source = saved.generated.first
    else { throw CancellationError() }
    try await waitForDataInvalidation(surviving)
    guard
      case .snapshot(let snapshot) = await first.query(
        .init(session: firstSession, request: .items(.init())))
    else { throw CancellationError() }
    #expect(snapshot.rows == [.source(source)])
  }

  @Test func retainingAStreamDoesNotRetainItsDiscardedPlanner() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    var planner: Planner? = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner?.bootstrap(),
      let changes = await planner?.changes(session: session)
    else { throw CancellationError() }
    weak let retainedPlanner = planner
    planner = nil
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while retainedPlanner != nil, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    try #require(retainedPlanner == nil)
    var iterator = changes.makeAsyncIterator()
    #expect(try await iterator.next() == nil)
  }

  @Test func losingTheStoreEndsObservationWithoutRecreatingItAndCanReopenAfterRepair() async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = configuration(directory: directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let changes = await planner.changes(session: session)
    guard
      case .applied(let saved, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Kept during store repair")))
      ).outcome,
      let source = saved.generated.first
    else { throw CancellationError() }
    try await waitForDataInvalidation(changes)
    _ = try await waitForRecoveryObservation(changes) {
      if case .known(let generation, _, _, _) = $0 { return generation == 1 }
      return false
    }
    try await Task.sleep(for: .milliseconds(100))
    let storeDirectory = configuration.storeURL.deletingLastPathComponent()
    let retainedStore = directory.appendingPathComponent("retained-store")
    try FileManager.default.moveItem(at: storeDirectory, to: retainedStore)
    do {
      try await waitForDataInvalidation(changes)
      Issue.record(
        "Losing the configured store must terminate observation with a structured failure.")
    } catch let failure as PlannerFailure {
      #expect(failure.code == "observationUnavailable" || failure.code == "unavailable")
    }
    #expect(!FileManager.default.fileExists(atPath: configuration.storeURL.path))
    try FileManager.default.moveItem(at: retainedStore, to: storeDirectory)
    guard case .ready(let reopened) = await planner.bootstrap() else { throw CancellationError() }
    let resumed = await planner.changes(session: reopened)
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: reopened,
          command: .createItem(content: .init(title: "After store repair")))
      ).outcome
    else { throw CancellationError() }
    try await waitForDataInvalidation(resumed)
    guard
      case .source(.item(let original)) = await planner.read(
        session: reopened, request: .source(source)),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: reopened, request: .items(.init())))
    else { throw CancellationError() }
    #expect(original.source == source && original.content.title == "Kept during store repair")
    #expect(snapshot.matchingCount == 2)
  }

  @Test func changingTheControlBindingEndsTheStreamAndAValidatedReopeningCanObserve() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = configuration(directory: directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let changes = await planner.changes(session: session)
    guard
      case .applied(let saved, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Original binding", notes: "Retained notes")))
      ).outcome,
      let source = saved.generated.first
    else { throw CancellationError() }
    try await waitForDataInvalidation(changes)
    _ = try await waitForRecoveryObservation(changes) {
      if case .known(let generation, _, _, _) = $0 { return generation == 1 }
      return false
    }
    /// Separate the control-only edit from the setup write's native invalidations.
    try await Task.sleep(for: .milliseconds(100))
    let originalBytes = try Data(contentsOf: configuration.controlURL)
    var control = try #require(
      JSONSerialization.jsonObject(with: originalBytes) as? [String: Any])
    control["epochId"] = UUID().uuidString
    try JSONSerialization.data(withJSONObject: control).write(
      to: configuration.controlURL, options: .atomic)
    do {
      try await waitForDataInvalidation(changes)
      Issue.record("A changed ownership epoch must terminate the original subscription.")
    } catch let failure as PlannerFailure {
      #expect(failure.code == "staleDatasetSession")
    }
    try originalBytes.write(to: configuration.controlURL, options: .atomic)
    guard case .ready(let reopened) = await planner.bootstrap() else { throw CancellationError() }
    #expect(reopened.datasetId == session.datasetId && reopened.sessionId != session.sessionId)
    let resumed = await planner.changes(session: reopened)
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: reopened,
          command: .createItem(content: .init(title: "After validated reopening")))
      ).outcome
    else { throw CancellationError() }
    try await waitForDataInvalidation(resumed)
    guard
      case .snapshot(let snapshot) = await planner.query(
        .init(session: reopened, request: .items(.init()))),
      case .source(.item(let original)) = await planner.read(
        session: reopened, request: .source(source))
    else { throw CancellationError() }
    #expect(snapshot.matchingCount == 2)
    #expect(
      original.content.title == "Original binding" && original.content.notes == "Retained notes")
  }

  @Test(arguments: [true, false])
  func recoveryOnlyDamageAndRepairInvalidateStatusWithoutChangingTheItem(atomicReplacement: Bool)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = configuration(directory: directory)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let saved, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Hotel", notes: "Original notes")))
      ).outcome,
      let source = saved.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first(where: { $0.datasetId == session.datasetId })
    else { throw CancellationError() }
    let checkpointURL = configuration.recoveryDirectoryURL
      .appendingPathComponent(namespace.namespaceId.uuidString)
      .appendingPathComponent("checkpoint-1.json")
    let originalBytes = try Data(contentsOf: checkpointURL)
    let changes = await planner.changes(session: session)
    try writeCheckpoint(
      Data("{ invalid checkpoint".utf8), to: checkpointURL, atomicReplacement: atomicReplacement)
    let damaged = try await waitForRecoveryObservation(changes) {
      if case .unavailable = $0 { return true }
      return false
    }
    guard case .unavailable(let observedFailure) = damaged,
      case .status(let damagedStatus) = await planner.read(session: session, request: .status),
      case .unavailable(let canonicalFailure) = damagedStatus.recovery
    else { throw CancellationError() }
    #expect(observedFailure == canonicalFailure)
    #expect(!observedFailure.message.isEmpty)
    try writeCheckpoint(originalBytes, to: checkpointURL, atomicReplacement: atomicReplacement)
    _ = try await waitForRecoveryObservation(changes) {
      if case .known(let generation, let incomplete, _, let blocked) = $0 {
        return generation == 1 && incomplete.isEmpty && !blocked
      }
      return false
    }
    guard case .status(let repairedStatus) = await planner.read(session: session, request: .status),
      case .known(let generation, let incomplete, _, let blocked) = repairedStatus.recovery,
      case .source(.item(let current)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    #expect(generation == 1 && incomplete.isEmpty && !blocked)
    #expect(current.source == source)
    #expect(current.content.title == "Hotel" && current.content.notes == "Original notes")
    #expect(current.updatedAt == original.updatedAt && current.fieldHashes == original.fieldHashes)
  }

  private func writeCheckpoint(_ bytes: Data, to url: URL, atomicReplacement: Bool) throws {
    if atomicReplacement {
      try bytes.write(to: url, options: .atomic)
      return
    }
    let file = try FileHandle(forWritingTo: url)
    defer { try? file.close() }
    try file.truncate(atOffset: 0)
    try file.write(contentsOf: bytes)
    try file.synchronize()
  }

  #if os(macOS)
    @Test func anIndependentProcessInvalidatesTheSubscribedDataset() async throws {
      if let directory = ProcessInfo.processInfo.environment[
        "PLANNER_CHANGE_STREAM_WRITER_DIRECTORY"]
      {
        print("Independent stream child process: \(ProcessInfo.processInfo.processIdentifier)")
        let writer = Planner(
          configuration: configuration(directory: URL(fileURLWithPath: directory)))
        guard case .ready(let session) = await writer.bootstrap(),
          case .applied(_, .complete) = await writer.execute(
            .init(
              operationId: UUID(), session: session,
              command: .createItem(
                content: .init(title: "From another process", notes: "Child notes")))
          ).outcome
        else { throw CancellationError() }
        return
      }
      let directory = try makePlannerStoreFixtureDirectory()
      let reader = Planner(configuration: configuration(directory: directory))
      guard case .ready(let session) = await reader.bootstrap() else { throw CancellationError() }
      let changes = await reader.changes(session: session)
      let log = directory.deletingLastPathComponent().appendingPathComponent("writer.log")
      try Data().write(to: log)
      let output = try FileHandle(forWritingTo: log)
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
          "PlannerChangeStreamTests/anIndependentProcessInvalidatesTheSubscribedDataset",
        ]
      var environment = ProcessInfo.processInfo.environment
      environment["PLANNER_CHANGE_STREAM_WRITER_DIRECTORY"] = directory.path
      process.environment = environment
      process.standardOutput = output
      process.standardError = output
      let completion = AsyncStream<Int32>.makeStream()
      process.terminationHandler = { terminated in
        completion.continuation.yield(terminated.terminationStatus)
        completion.continuation.finish()
      }
      try process.run()
      print("Launched stream writer process: \(process.processIdentifier)")
      let deadline = Task {
        try await Task.sleep(for: .seconds(30))
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
      }
      defer {
        deadline.cancel()
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
      }
      var termination = completion.stream.makeAsyncIterator()
      let status = await termination.next()
      try output.close()
      print(
        "Independent stream writer transcript:\n\(try String(contentsOf: log, encoding: .utf8))")
      try #require(status == 0 && process.terminationReason == .exit)
      try await waitForDataInvalidation(changes)
      guard
        case .snapshot(let snapshot) = await reader.query(
          .init(session: session, request: .items(.init()))),
        case .source(let source)? = snapshot.rows.first,
        case .source(.item(let item)) = await reader.read(
          session: session, request: .source(source))
      else { throw CancellationError() }
      #expect(snapshot.matchingCount == 1)
      #expect(item.content.title == "From another process")
      #expect(item.content.notes == "Child notes")
    }

  #endif

  @Test func aForeignInstanceSessionFailsWithoutPoisoningTheValidSubscription() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = configuration(directory: directory)
    let reader = Planner(configuration: configuration)
    let other = Planner(configuration: configuration)
    guard case .ready(let session) = await reader.bootstrap(),
      case .ready(let foreignSession) = await other.bootstrap()
    else { throw CancellationError() }
    #expect(foreignSession.datasetId == session.datasetId)
    let valid = await reader.changes(session: session)
    let rejected = await reader.changes(session: foreignSession)
    do {
      try await waitForDataInvalidation(rejected)
      Issue.record("A session issued by another Planner must fail before observing changes.")
    } catch let failure as PlannerFailure {
      #expect(failure.code == "staleDatasetSession")
    }
    guard
      case .applied(_, .complete) = await other.execute(
        .init(
          operationId: UUID(), session: foreignSession,
          command: .createItem(content: .init(title: "Valid after foreign rejection")))
      ).outcome
    else { throw CancellationError() }
    try await waitForDataInvalidation(valid)
    guard
      case .snapshot(let snapshot) = await reader.query(
        .init(session: session, request: .items(.init())))
    else { throw CancellationError() }
    #expect(snapshot.matchingCount == 1)
  }

  @Test func cancellingOneSubscriberKeepsTheOtherLiveForOwnWrites() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let first = await planner.changes(session: session)
    let second = await planner.changes(session: session)
    let cancelledConsumer = Task {
      var iterator = first.makeAsyncIterator()
      do { return try await iterator.next() == nil } catch is CancellationError {
        return true
      } catch {
        Issue.record("Cancelling one consumer must not fail its dataset: \(error)")
        return false
      }
    }
    cancelledConsumer.cancel()
    #expect(await cancelledConsumer.value)
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Surviving subscription")))
      ).outcome,
      let source = result.generated.first
    else { throw CancellationError() }
    try await waitForDataInvalidation(second)
    guard
      case .source(.item(let item)) = await planner.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    #expect(item.content.title == "Surviving subscription")
  }

  @Test func anIndependentLocalWriterInvalidatesCanonicalReadsAfterSubscription() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = configuration(directory: directory)
    let reader = Planner(configuration: configuration)
    let writer = Planner(configuration: configuration)
    guard case .ready(let readerSession) = await reader.bootstrap(),
      case .ready(let writerSession) = await writer.bootstrap()
    else { throw CancellationError() }
    let changes = await reader.changes(session: readerSession)
    guard
      case .snapshot(let initial) = await reader.query(
        .init(session: readerSession, request: .items(.init())))
    else { throw CancellationError() }
    #expect(initial.rows.isEmpty)
    guard
      case .applied(let saved, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: writerSession,
          command: .createItem(content: .init(title: "From another writer", notes: "Live notes")))
      ).outcome,
      let source = saved.generated.first
    else { throw CancellationError() }
    try await waitForDataInvalidation(changes)
    guard
      case .snapshot(let refreshed) = await reader.query(
        .init(session: readerSession, request: .items(.init()))),
      case .source(.item(let item)) = await reader.read(
        session: readerSession, request: .source(source))
    else { throw CancellationError() }
    #expect(refreshed.rows == [.source(source)])
    #expect(item.source == source)
    #expect(item.content.title == "From another writer")
    #expect(item.content.notes == "Live notes")
  }
  private func configuration(directory: URL) -> PlannerStorageConfiguration {
    .init(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }

  private func waitForDataInvalidation(_ changes: AsyncThrowingStream<PlannerChange, any Error>)
    async throws
  {
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        for try await change in changes {
          if case .dataChanged = change.payload { return }
        }
        throw ChangeStreamTestFailure.endedWithoutInvalidation
      }
      group.addTask {
        try await Task.sleep(for: .seconds(5))
        throw ChangeStreamTestFailure.noInvalidationBeforeTestDeadline
      }
      defer { group.cancelAll() }
      try await group.next()
    }
  }

  private func waitForAnyInvalidation(_ changes: AsyncThrowingStream<PlannerChange, any Error>)
    async throws
  {
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        var iterator = changes.makeAsyncIterator()
        guard try await iterator.next() != nil else {
          throw ChangeStreamTestFailure.endedWithoutInvalidation
        }
      }
      group.addTask {
        try await Task.sleep(for: .seconds(5))
        throw ChangeStreamTestFailure.noInvalidationBeforeTestDeadline
      }
      defer { group.cancelAll() }
      try await group.next()
    }
  }

  private func waitForRecoveryObservation(
    _ changes: AsyncThrowingStream<PlannerChange, any Error>,
    matching matches: @escaping @Sendable (PlannerRecoveryObservation) -> Bool
  ) async throws -> PlannerRecoveryObservation {
    try await withThrowingTaskGroup(of: PlannerRecoveryObservation.self) { group in
      group.addTask {
        for try await change in changes {
          if case .recoveryStatusChanged(let value) = change.payload, matches(value) {
            return value
          }
        }
        throw ChangeStreamTestFailure.endedWithoutInvalidation
      }
      group.addTask {
        try await Task.sleep(for: .seconds(5))
        throw ChangeStreamTestFailure.noInvalidationBeforeTestDeadline
      }
      defer { group.cancelAll() }
      return try #require(await group.next())
    }
  }

}

private enum ChangeStreamTestFailure: Error {
  case endedWithoutInvalidation
  case noInvalidationBeforeTestDeadline
}
