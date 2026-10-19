import Foundation
import PlannerCore
import SwiftData

#if os(macOS)
  import Darwin
  import Testing

  struct AssociationUndoSaveFailureTests {
    @Test func failedNativeMoveOrItsUndoPreservesBothListsAndCanRetry() async throws {
      guard ProcessInfo.processInfo.environment["PLANNER_UNDO_WRITE_FAULT_CHILD"] == "1" else {
        try runIsolatedWriteFailure(
          functionName: "failedNativeMoveOrItsUndoPreservesBothListsAndCanRetry")
        return
      }
      for restoring in [false, true] {
        let fixture = try await AssociationUndoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let creation = try await fixture.save(.createList(content: .init(name: "Destination")))
        let destination = try #require(creation.generated.first)
        let move = PlannerCommand.moveMembership(
          listId: fixture.list.id, membershipId: fixture.membershipIdentifier,
          destinationListId: destination.id, placement: .last)
        let command: PlannerCommand
        if restoring {
          let moved = await fixture.planner.execute(
            .init(operationId: UUID(), session: fixture.session, command: move))
          command = .restoreAssociation(snapshot: try #require(moved.associationUndoSnapshot))
        } else {
          command = move
        }
        let before = try await fixture.export()
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
        let response = await fixture.planner.execute(
          .init(operationId: operationIdentifier, session: fixture.session, command: command))
        try obstruction.restore()
        #expect(obstruction.didObstruct && obstruction.failureMessage == nil)
        guard case .rejected(let failure) = response.outcome else { throw CancellationError() }
        #expect(failure.code == "persistenceFailure")
        #expect(response.associationUndoSnapshot == nil)
        let reopened = Planner(configuration: fixture.configuration)
        guard case .ready(let reopenedSession) = await reopened.bootstrap(),
          case .exported(let retained) = await reopened.exportData(session: reopenedSession)
        else { throw CancellationError() }
        #expect(retained == before)
        guard
          case .noReliableEvidence = await reopened.operationStatus(
            session: reopenedSession, operationId: operationIdentifier)
        else {
          Issue.record("A known failed Move action must discard prepared evidence before retry.")
          return
        }
        let retry = await fixture.planner.execute(
          .init(operationId: operationIdentifier, session: fixture.session, command: command))
        guard case .applied(_, .complete) = retry.outcome,
          case .decoded(let saved) = fixture.planner.decodeImport(try await fixture.export())
        else { throw CancellationError() }
        #expect(saved.backup.memberships.count == 1)
        let membership = try #require(saved.backup.memberships.first)
        if restoring {
          #expect(membership.id == fixture.membershipIdentifier && membership.localDone)
          #expect(membership.list == fixture.list)
        } else {
          #expect(membership.id != fixture.membershipIdentifier && !membership.localDone)
          #expect(membership.list == destination)
          #expect(retry.associationUndoSnapshot != nil)
        }
      }
    }

    @Test func failedNativeRemovalSaveIssuesNoUndoAndRetainsOriginalAssociations() async throws {
      guard ProcessInfo.processInfo.environment["PLANNER_UNDO_WRITE_FAULT_CHILD"] == "1" else {
        try runIsolatedWriteFailure(
          functionName: "failedNativeRemovalSaveIssuesNoUndoAndRetainsOriginalAssociations")
        return
      }
      for removingEntry in [false, true] {
        let fixture = try await AssociationUndoFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let command: PlannerCommand
        if removingEntry {
          let itinerary = try #require(
            try await fixture.save(.createItinerary(content: .init(title: "Weekend")))
              .generated.first)
          let addition = try await fixture.save(
            .addItineraryEntry(itineraryId: itinerary.id, source: fixture.list, placement: .last))
          guard case .itineraryEntry(let identifier, _, _)? = addition.generatedReferences.first
          else { throw CancellationError() }
          command = .removeItineraryEntry(itineraryId: itinerary.id, entryId: identifier)
        } else {
          command = fixture.removalCommand
        }
        let before = try await fixture.export()
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
        let response = await fixture.planner.execute(
          .init(operationId: operationIdentifier, session: fixture.session, command: command))
        try obstruction.restore()
        #expect(obstruction.didObstruct && obstruction.failureMessage == nil)
        guard case .rejected(let failure) = response.outcome else { throw CancellationError() }
        #expect(failure.code == "persistenceFailure")
        #expect(response.associationUndoSnapshot == nil)
        #expect(try await fixture.export() == before)
        guard
          case .noReliableEvidence = await fixture.planner.operationStatus(
            session: fixture.session, operationId: operationIdentifier)
        else {
          Issue.record("A failed removal must discard its prepared evidence before retry.")
          return
        }
        let retry = await fixture.planner.execute(
          .init(operationId: operationIdentifier, session: fixture.session, command: command))
        guard case .applied(_, .complete) = retry.outcome else { throw CancellationError() }
        #expect(retry.associationUndoSnapshot != nil)
      }
    }

    @Test func failedNativeRestorationSaveRollsBackAndKeepsItsIssuedSnapshotRetryable() async throws
    {
      guard ProcessInfo.processInfo.environment["PLANNER_UNDO_WRITE_FAULT_CHILD"] == "1" else {
        try runIsolatedWriteFailure(
          functionName: "failedNativeRestorationSaveRollsBackAndKeepsItsIssuedSnapshotRetryable")
        return
      }
      let fixture = try await AssociationUndoFixture()
      defer { try? FileManager.default.removeItem(at: fixture.directory) }
      let removal = await fixture.remove()
      let command = PlannerCommand.restoreAssociation(
        snapshot: try #require(removal.associationUndoSnapshot))
      let before = try await fixture.export()
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
      let response = await fixture.planner.execute(
        .init(operationId: operationIdentifier, session: fixture.session, command: command))
      try obstruction.restore()
      #expect(obstruction.didObstruct && obstruction.failureMessage == nil)
      guard case .rejected(let failure) = response.outcome else {
        Issue.record("A genuine failed native save must reject the restoration.")
        return
      }
      #expect(failure.code == "persistenceFailure")
      #expect(response.associationUndoSnapshot == nil)
      let reopened = Planner(configuration: fixture.configuration)
      guard case .ready(let reopenedSession) = await reopened.bootstrap(),
        case .exported(let retained) = await reopened.exportData(session: reopenedSession)
      else { throw CancellationError() }
      #expect(retained == before)
      guard
        case .noReliableEvidence = await reopened.operationStatus(
          session: reopenedSession, operationId: operationIdentifier)
      else {
        Issue.record("The known failed save must discard its prepared restoration evidence.")
        return
      }
      let retry = await fixture.planner.execute(
        .init(operationId: operationIdentifier, session: fixture.session, command: command))
      guard case .applied(_, .complete) = retry.outcome,
        case .appearance(let restored) = await reopened.read(
          session: reopenedSession,
          request: .appearance(
            .listMembership(listId: fixture.list.id, membershipId: fixture.membershipIdentifier)))
      else { throw CancellationError() }
      #expect(restored.localDone && restored.effectiveDone)
    }

    private func runIsolatedWriteFailure(functionName: String) throws {
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "PlannerUndoWriteFailure-" + UUID().uuidString)
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
          "AssociationUndoSaveFailureTests/\(functionName)",
        ]
      var environment = ProcessInfo.processInfo.environment
      environment["PLANNER_UNDO_WRITE_FAULT_CHILD"] = "1"
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
      #expect(finished, "The isolated Undo save fault must finish within its deadline.")
      #expect(process.terminationReason == .exit)
      #expect(process.terminationStatus == 0, Comment(rawValue: String(transcript.suffix(12_000))))
      #expect(transcript.contains("Test run with 1 test"))
    }
  }
#endif
