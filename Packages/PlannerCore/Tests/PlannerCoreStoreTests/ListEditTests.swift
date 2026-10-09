import CryptoKit
import Foundation
import PlannerCore
import Testing

struct ListEditTests {
  @Test func guardedNotesEditPreservesTheListAndOriginalReplayAcrossReopening() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(
            content: PlannerListContentInput(
              name: "Tokyo Food", notes: "Original notes",
              color: PlannerColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1),
              iconName: "fork.knife")))
      ).outcome,
      let list = created.generated.first,
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list)), let notesHash = original.fieldHashes[.notes]
    else {
      Issue.record("The List must save before its guarded notes edit.")
      return
    }
    let operationIdentifier = UUID()
    let command = PlannerCommand.editList(
      sourceId: list.id, changes: PlannerListChanges(notes: .set(" Friday booking ")),
      expectedFieldHashes: [.notes: notesHash])
    guard
      case .applied(let edited, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(operationId: operationIdentifier, session: session, command: command)
      ).outcome
    else {
      Issue.record("A current List notes guard must permit a durable notes-only edit.")
      return
    }
    #expect(edited.generated.isEmpty)
    #expect(edited.affected == [list])
    #expect(checkpoint == 2)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let read)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .applied(let replay, .complete(let replayCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      let portableList = recovery.decodedBackup.backup.lists.first
    else {
      Issue.record("Reopening must retain edited notes, the original receipt and independent data.")
      return
    }
    #expect(read.source == list)
    #expect(read.content.name == "Tokyo Food")
    #expect(read.content.notes == " Friday booking ")
    #expect(read.content.color == original.content.color)
    #expect(read.content.iconName == original.content.iconName)
    #expect(read.createdAt == original.createdAt)
    #expect(read.updatedAt >= original.updatedAt)
    #expect(read.fieldHashes[.notes] != notesHash)
    #expect(read.fieldHashes[.name] == original.fieldHashes[.name])
    #expect(read.fieldHashes[.color] == original.fieldHashes[.color])
    #expect(read.fieldHashes[.iconName] == original.fieldHashes[.iconName])
    #expect(read.state.globalDone == nil)
    #expect(read.state.archived == false)
    #expect(read.progress.state == .empty)
    #expect(read.progress.totalCount == 0)
    #expect(read.references.isEmpty)
    #expect(replay == edited)
    #expect(replayCheckpoint == checkpoint)
    #expect(portableList.id == list.id)
    #expect(portableList.content == read.content)
    #expect(portableList.updatedAt == read.updatedAt)
    #expect(namespace.preparedProposals.isEmpty)
  }
  @Test func unchangedFieldsDoNotGuardEditsAndStalePatchesDoNotPartiallyApply() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    guard let fixture = try await makeFixture(directory: directory) else { return }
    let planner = fixture.planner
    let session = fixture.session
    let list = fixture.list
    let original = fixture.original
    let notesOperationIdentifier = UUID()
    let notesCommand = PlannerCommand.editList(
      sourceId: list.id, changes: PlannerListChanges(notes: .set("Friday booking")),
      expectedFieldHashes: original.fieldHashes)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editList(
            sourceId: list.id, changes: PlannerListChanges(name: .set(" Tokyo restaurants ")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .applied(let savedResult, .complete(let savedCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: notesOperationIdentifier, session: session, command: notesCommand)
      ).outcome,
      case .source(.list(let before)) = await planner.read(session: session, request: .source(list))
    else {
      Issue.record("Changing a name must not invalidate an unchanged notes guard.")
      return
    }
    #expect(savedCheckpoint == 3)
    #expect(before.content.name == " Tokyo restaurants ")
    #expect(before.content.notes == "Friday booking")
    let staleOperationIdentifier = UUID()
    guard
      case .rejected(let stale) = await planner.execute(
        PlannerOperation(
          operationId: staleOperationIdentifier, session: session,
          command: .editList(
            sourceId: list.id,
            changes: PlannerListChanges(name: .set("Must not save"), notes: .set("Monday booking")),
            expectedFieldHashes: [
              .name: try #require(before.fieldHashes[.name]),
              .notes: try #require(original.fieldHashes[.notes]),
            ]))
      ).outcome,
      case .staleListEdit(let fields, let values, let hashes) = stale.details,
      case .source(.list(let after)) = await planner.read(session: session, request: .source(list)),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: staleOperationIdentifier),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("A stale notes field must reject both changed fields without applied evidence.")
      return
    }
    #expect(stale.code == "staleEdit")
    #expect(fields == [.notes])
    #expect(values == [.notes: .optionalString("Friday booking")])
    #expect(hashes == [.notes: try #require(before.fieldHashes[.notes])])
    #expect(after.content == before.content)
    #expect(after.updatedAt == before.updatedAt)
    #expect(after.fieldHashes == before.fieldHashes)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == savedCheckpoint)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
    guard
      case .applied(_, .complete(let laterCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editList(
            sourceId: list.id, changes: PlannerListChanges(notes: .set("Saturday booking")),
            expectedFieldHashes: before.fieldHashes))
      ).outcome,
      case .applied(let replay, .complete(let replayCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: notesOperationIdentifier, session: session,
          command: .editList(
            sourceId: list.id, changes: PlannerListChanges(notes: .set("Friday booking")),
            expectedFieldHashes: [.notes: try #require(original.fieldHashes[.notes])]))
      ).outcome,
      case .rejected(let mismatch) = await planner.execute(
        PlannerOperation(
          operationId: notesOperationIdentifier, session: session,
          command: .editList(
            sourceId: list.id, changes: PlannerListChanges(notes: .set("Changed replay")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .source(.list(let latest)) = await planner.read(session: session, request: .source(list))
    else {
      Issue.record("Exact replay must ignore unused echoed hashes and retain a later notes edit.")
      return
    }
    #expect(laterCheckpoint == 4)
    #expect(replay == savedResult)
    #expect(replayCheckpoint == savedCheckpoint)
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(latest.content.notes == "Saturday booking")
    #expect(latest.content.name == " Tokyo restaurants ")
  }

  @Test func nullablePresentationFieldsPreserveExactValuesAndMixedSourceRecovery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    guard let fixture = try await makeFixture(directory: directory) else { return }
    let planner = fixture.planner
    let session = fixture.session
    let list = fixture.list
    guard
      case .applied(let itemResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      ).outcome,
      let item = itemResult.generated.first,
      case .applied(let scheduleResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(
            source: item,
            form: .allDay(start: PlannerCivilDate(year: 2026, month: 10, day: 9), end: nil)))
      ).outcome,
      let schedule = scheduleResult.generated.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.schedule(let originalSchedule)) = await planner.read(
        session: session, request: .source(schedule)),
      case .applied(_, .complete(let editedCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editList(
            sourceId: list.id,
            changes: PlannerListChanges(
              name: .set("  Café 東京  "), notes: .set(""),
              color: .set(PlannerColor(red: 0, green: 0, blue: 1, alpha: 1)), iconName: .set("")),
            expectedFieldHashes: fixture.original.fieldHashes))
      ).outcome,
      case .source(.list(let edited)) = await planner.read(session: session, request: .source(list)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let selection) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: editedCheckpoint)),
      let portableList = selection.decodedBackup.backup.lists.first
    else {
      Issue.record(
        "Every declared List content field must edit without rewriting Items or Schedules.")
      return
    }
    #expect(editedCheckpoint == 4)
    #expect(edited.content.name == "  Café 東京  ")
    #expect(edited.content.notes == "")
    #expect(edited.content.iconName == "")
    #expect(edited.content.color == PlannerColor(red: 0, green: 0, blue: 1, alpha: 1))
    #expect(portableList.content == edited.content)
    // The accepted blue-List fixture fixes all value bytes; only real context UUIDs are substituted.
    let literalInput =
      "506c616e6e65724669656c64486173680000000001000000000000400080000000000008010200000000000040008000000000000201000000000000400080000000000008210000000000000005636f6c6f7215011800000000000000040000000000000005616c706861133ff00000000000000000000000000004626c7565133ff00000000000000000000000000005677265656e1300000000000000000000000000000003726564130000000000000000"
    let boundInput = literalInput.replacingOccurrences(
      of: "00000000000040008000000000000801",
      with: session.datasetId.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    ).replacingOccurrences(
      of: "00000000000040008000000000000201",
      with: list.id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    ).replacingOccurrences(
      of: "00000000000040008000000000000821",
      with: portableList.lifetimeId.uuidString.replacingOccurrences(of: "-", with: "").lowercased())
    let characters = Array(boundInput)
    let input = try Data(
      stride(from: 0, to: characters.count, by: 2).map { index in
        try #require(UInt8(String(characters[index...index + 1]), radix: 16))
      })
    let expectedHash = SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    #expect(edited.fieldHashes[.color]?.value == "sha256-v1:" + expectedHash)
    guard
      case .applied(_, .complete(let clearedCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editList(
            sourceId: list.id,
            changes: PlannerListChanges(notes: .clear, color: .clear, iconName: .clear),
            expectedFieldHashes: edited.fieldHashes))
      ).outcome
    else {
      Issue.record("Clearing optional List fields must save independently of its name.")
      return
    }
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let cleared)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.schedule(let retainedSchedule)) = await reopened.read(
        session: reopenedSession, request: .source(schedule)),
      case .selected(let clearedSelection) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: clearedCheckpoint))
    else {
      Issue.record(
        "Cleared optional fields and unrelated content must survive reopening and recovery.")
      return
    }
    #expect(clearedCheckpoint == 5)
    #expect(cleared.content.name == edited.content.name)
    #expect(cleared.content.notes == nil)
    #expect(cleared.content.color == nil)
    #expect(cleared.content.iconName == nil)
    #expect(cleared.fieldHashes[.name] == edited.fieldHashes[.name])
    #expect(cleared.fieldHashes[.notes] != edited.fieldHashes[.notes])
    #expect(cleared.fieldHashes[.color] != edited.fieldHashes[.color])
    #expect(cleared.fieldHashes[.iconName] != edited.fieldHashes[.iconName])
    #expect(cleared.createdAt == fixture.original.createdAt)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedSchedule.content == originalSchedule.content)
    #expect(retainedSchedule.fieldHashes == originalSchedule.fieldHashes)
    #expect(clearedSelection.decodedBackup.backup.sources.count == 2)
    #expect(clearedSelection.decodedBackup.backup.schedules.count == 1)
    #expect(clearedSelection.decodedBackup.backup.lists.first?.content == cleared.content)
    #expect(
      clearedSelection.decodedBackup.backup.lists.first?.contentOrigins == ["name": "independent"])
  }

  @Test func invalidEditsAndRecoveryObstructionLeaveNoAppliedEvidence() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    guard let fixture = try await makeFixture(directory: directory) else { return }
    let planner = fixture.planner
    let session = fixture.session
    let list = fixture.list
    let hash = try #require(fixture.original.fieldHashes[.notes])
    let cases: [(PlannerListChanges, [PlannerListField: PlannerFieldHash], String)] = [
      (PlannerListChanges(), [:], "/command/changes"),
      (PlannerListChanges(name: .clear), fixture.original.fieldHashes, "/command/changes/name"),
      (
        PlannerListChanges(name: .set(" \n\t")), fixture.original.fieldHashes,
        "/command/changes/name"
      ),
      (PlannerListChanges(notes: .set("New")), [:], "/command/expectedFieldHashes/notes"),
      (
        PlannerListChanges(notes: .set("New")),
        [.notes: PlannerFieldHash(value: "sha256-v1:" + String(repeating: "A", count: 64))],
        "/command/expectedFieldHashes/notes"
      ),
      (
        PlannerListChanges(notes: .set("New")),
        [.notes: hash, .color: PlannerFieldHash(value: "bad")],
        "/command/expectedFieldHashes/color"
      ),
      (
        PlannerListChanges(color: .set(PlannerColor(red: .nan, green: 0, blue: 0, alpha: 1))),
        fixture.original.fieldHashes, "/command/changes/color/red"
      ),
      (
        PlannerListChanges(color: .set(PlannerColor(red: 0, green: 1.01, blue: 0, alpha: 1))),
        fixture.original.fieldHashes, "/command/changes/color/green"
      ),
      (
        PlannerListChanges(color: .set(PlannerColor(red: 0, green: 0, blue: -.infinity, alpha: 1))),
        fixture.original.fieldHashes, "/command/changes/color/blue"
      ),
      (
        PlannerListChanges(color: .set(PlannerColor(red: 0, green: 0, blue: 0, alpha: -0.01))),
        fixture.original.fieldHashes, "/command/changes/color/alpha"
      ),
    ]
    for (changes, hashes, path) in cases {
      let operationIdentifier = UUID()
      guard
        case .rejected(let reason) = await planner.execute(
          PlannerOperation(
            operationId: operationIdentifier, session: session,
            command: .editList(sourceId: list.id, changes: changes, expectedFieldHashes: hashes))
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier)
      else {
        Issue.record("Invalid List edits must reject without applied evidence at \(path).")
        return
      }
      #expect(reason.code == "invalidInput")
      #expect(reason.propertyPath == path)
    }
    let recoveryDirectory = fixture.configuration.recoveryDirectoryURL
    let retainedDirectory = directory.appendingPathComponent("retained-recovery")
    try FileManager.default.moveItem(at: recoveryDirectory, to: retainedDirectory)
    try Data("A file obstructs recovery.".utf8).write(to: recoveryDirectory)
    let obstructedIdentifier = UUID()
    let obstructed = await planner.execute(
      PlannerOperation(
        operationId: obstructedIdentifier, session: session,
        command: .editList(
          sourceId: list.id, changes: PlannerListChanges(notes: .set("Must not save")),
          expectedFieldHashes: fixture.original.fieldHashes)))
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retainedDirectory, to: recoveryDirectory)
    guard case .rejected(let reason) = obstructed.outcome,
      case .source(.list(let retained)) = await planner.read(
        session: session, request: .source(list)),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: obstructedIdentifier),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record(
        "Obstructed independent recovery must reject the List edit before committing it.")
      return
    }
    #expect(reason.code == "persistenceFailure")
    #expect(retained.content == fixture.original.content)
    #expect(retained.fieldHashes == fixture.original.fieldHashes)
    #expect(retained.updatedAt == fixture.original.updatedAt)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 1)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
    let missingIdentifier = UUID()
    guard
      case .rejected(let missing) = await planner.execute(
        PlannerOperation(
          operationId: missingIdentifier, session: session,
          command: .editList(
            sourceId: UUID(), changes: PlannerListChanges(notes: .set("New")),
            expectedFieldHashes: [.notes: hash]))
      ).outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: missingIdentifier)
    else {
      Issue.record("An absent List identity must not create data or applied evidence.")
      return
    }
    #expect(missing.code == "missingReference")
  }

  @Test func competingFacadesResolveOneWinnerAtTheSharedWriterBoundary() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    guard let fixture = try await makeFixture(directory: directory) else { return }
    let second = Planner(configuration: fixture.configuration)
    guard case .ready(let secondSession) = await second.bootstrap() else {
      Issue.record("A second real facade must bind the existing dataset before contention.")
      return
    }
    async let first = fixture.planner.execute(
      PlannerOperation(
        operationId: UUID(), session: fixture.session,
        command: .editList(
          sourceId: fixture.list.id, changes: PlannerListChanges(notes: .set("Friday booking")),
          expectedFieldHashes: fixture.original.fieldHashes)))
    async let other = second.execute(
      PlannerOperation(
        operationId: UUID(), session: secondSession,
        command: .editList(
          sourceId: fixture.list.id, changes: PlannerListChanges(notes: .set("Monday booking")),
          expectedFieldHashes: fixture.original.fieldHashes)))
    let results = await [first, other]
    var appliedCount = 0
    var staleCount = 0
    for result in results {
      switch result.outcome {
      case .applied(_, .complete(let checkpoint)):
        appliedCount += 1
        #expect(checkpoint == 2)
      case .rejected(let reason):
        staleCount += 1
        #expect(reason.code == "staleEdit")
      default: Issue.record("Each competing edit must either save or reject its now-stale guard.")
      }
    }
    #expect(appliedCount == 1)
    #expect(staleCount == 1)
    guard
      case .source(.list(let current)) = await second.read(
        session: secondSession, request: .source(fixture.list)),
      case .listedNamespaces(let namespaces) = await second.inspectRecovery(request: .namespaces)
    else {
      Issue.record("The winning List value and its one new checkpoint must remain readable.")
      return
    }
    #expect(["Friday booking", "Monday booking"].contains(current.content.notes ?? ""))
    #expect(current.content.name == "Tokyo Food")
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 2)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  private struct Fixture {
    let configuration: PlannerStorageConfiguration
    let planner: Planner
    let session: PlannerDatasetSession
    let list: PlannerEntityReference
    let original: PlannerListSourceRead
  }

  private func makeFixture(directory: URL) async throws -> Fixture? {
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let result, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createList(
            content: PlannerListContentInput(name: "Tokyo Food", notes: "Original notes")))
      ).outcome,
      let list = result.generated.first,
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("A List must save and expose current hashes through the public facade.")
      return nil
    }
    return Fixture(
      configuration: configuration, planner: planner, session: session, list: list,
      original: original)
  }
}
