import Foundation
import PlannerCore
import Testing

#if os(macOS)
  import Darwin
#endif

struct PlannerChangeStreamTests {
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

    private func configuration(directory: URL) -> PlannerStorageConfiguration {
      .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
    }
  #endif

  @Test func aForeignInstanceSessionFailsWithoutPoisoningTheValidSubscription() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
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
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
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

}

private enum ChangeStreamTestFailure: Error {
  case endedWithoutInvalidation
  case noInvalidationBeforeTestDeadline
}
