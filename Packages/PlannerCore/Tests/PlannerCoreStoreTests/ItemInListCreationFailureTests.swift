import Foundation
import PlannerCore
import SwiftData

#if os(macOS)
  import Darwin
  import Testing

  struct ItemInListCreationFailureTests {
    @Test func failedNativeSaveRollsBackTheWholeCreationAndAllowsAnUnchangedRetry() async throws {
      guard ProcessInfo.processInfo.environment["PLANNER_Q93_WRITE_FAULT_CHILD"] == "1" else {
        try runIsolatedWriteFailure()
        return
      }
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "PlannerQ93Store-" + UUID().uuidString)
      let configuration = PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
      let planner = Planner(configuration: configuration)
      guard case .ready(let session) = await planner.bootstrap(),
        case .applied(let listCreation, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createList(content: .init(name: "Tokyo"))
          )
        ).outcome,
        let list = listCreation.generated.first,
        case .exported(let before) = await planner.exportData(session: session)
      else { throw CancellationError() }

      let obstruction = NativeSaveFileSizeObstruction(configuration: configuration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.willSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      let notes = String(repeating: "Planner fixture.\n", count: 131_072)
      let operationIdentifier = UUID()
      let command = PlannerCommand.createItem(
        content: .init(
          title: "Museum", notes: notes,
          links: [
            .init(originalUrl: "https://example.com/museum", label: "Tickets"),
            .init(originalUrl: "https://example.com/museum", label: "Exhibitions"),
          ]), listId: list.id)
      let failed = await planner.execute(
        .init(operationId: operationIdentifier, session: session, command: command))
      try obstruction.restore()
      #expect(obstruction.didObstruct && obstruction.failureMessage == nil)
      let reopened = Planner(configuration: configuration)
      guard case .rejected(let failure) = failed.outcome,
        case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .source(.list(let retained)) = await reopened.read(
          session: reopenedSession, request: .source(list)),
        case .snapshot(let empty) = await reopened.query(
          .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all)))),
        case .exported(let after) = await reopened.exportData(session: reopenedSession)
      else {
        Issue.record(
          "The genuine failed native save must leave the entire Item action unapplied: \(failed.outcome)"
        )
        return
      }
      #expect(failure.code == "persistenceFailure")
      #expect(retained.references.isEmpty && retained.progress.state == .empty)
      #expect(empty.matchingCount == 0)
      #expect(after == before)
      guard
        case .noReliableEvidence = await reopened.operationStatus(
          session: reopenedSession, operationId: operationIdentifier)
      else {
        Issue.record(
          "A known failed transaction must not retain applied or unverified operation evidence.")
        return
      }
      let retry = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command))
      guard case .applied(let applied, .complete(let checkpoint)) = retry.outcome,
        let item = applied.generated.first,
        case .source(.item(let saved)) = await reopened.read(
          session: reopenedSession, request: .source(item)),
        case .source(.list(let populated)) = await reopened.read(
          session: reopenedSession, request: .source(list))
      else {
        Issue.record(
          "After removing the real fault, unchanged retry must create the complete graph once: \(retry.outcome)"
        )
        return
      }
      #expect(checkpoint == 2)
      #expect(saved.content.links.map(\.label) == ["Tickets", "Exhibitions"])
      #expect(saved.content.notes == notes)
      #expect(populated.references.count == 1 && populated.progress.totalCount == 1)
    }

    private func runIsolatedWriteFailure() throws {
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlannerQ93WriteFailure-" + UUID().uuidString)
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
          "ItemInListCreationFailureTests/failedNativeSaveRollsBackTheWholeCreationAndAllowsAnUnchangedRetry",
        ]
      var environment = ProcessInfo.processInfo.environment
      environment["PLANNER_Q93_WRITE_FAULT_CHILD"] = "1"
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
      print("Q93 isolated write-fault child log: \(outputURL.path)")
      #expect(finished, "The isolated persistence fault must finish within its test deadline.")
      #expect(process.terminationReason == .exit)
      #expect(process.terminationStatus == 0, Comment(rawValue: String(transcript.suffix(12_000))))
      #expect(transcript.contains("Test run with 1 test"))
    }

  }

  /// The resource limit is armed at the real save boundary inside an isolated child process only.
  private final class NativeSaveFileSizeObstruction: @unchecked Sendable {
    private let lock = NSLock()
    private let storeURL: URL
    private var attempted = false
    private var originalLimit: rlimit?
    private var originalSignal: (@convention(c) (Int32) -> Void)?
    private var obstructed = false
    private var message: String?

    init(configuration: PlannerStorageConfiguration) {
      storeURL = configuration.storeURL.standardizedFileURL
    }

    var didObstruct: Bool { lock.withLock { obstructed } }
    var failureMessage: String? { lock.withLock { message } }

    func observe(_ notification: Notification) {
      guard let context = notification.object as? ModelContext,
        context.container.configurations.contains(where: { $0.url.standardizedFileURL == storeURL })
      else { return }
      lock.withLock {
        guard !attempted else { return }
        attempted = true
        var previousLimit = rlimit()
        guard getrlimit(RLIMIT_FSIZE, &previousLimit) == 0 else {
          message = "Could not read the isolated process file limit."
          return
        }
        let previousSignal = signal(SIGXFSZ, SIG_IGN)
        var limited = rlimit(rlim_cur: 1_048_576, rlim_max: previousLimit.rlim_max)
        guard setrlimit(RLIMIT_FSIZE, &limited) == 0 else {
          signal(SIGXFSZ, previousSignal)
          message = "Could not lower the isolated process file limit."
          return
        }
        originalLimit = previousLimit
        originalSignal = previousSignal
        obstructed = true
      }
    }

    func restore() throws {
      try lock.withLock {
        guard var previousLimit = originalLimit else { return }
        guard setrlimit(RLIMIT_FSIZE, &previousLimit) == 0 else {
          throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        signal(SIGXFSZ, originalSignal)
        originalLimit = nil
      }
    }
  }
#endif
