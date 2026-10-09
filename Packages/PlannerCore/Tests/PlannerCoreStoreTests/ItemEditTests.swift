import Foundation
import PlannerCore
import Testing

struct ItemEditTests {
  @Test func oneStaleFieldRejectsEntireTitleAndNotesPatch() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly
    )
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The local dataset must initialize.")
      return
    }
    let created = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))
      ))
    guard case .applied(let result, .complete) = created.outcome else {
      Issue.record("Hotel creation failed: \(created)")
      return
    }
    let item = try #require(result.generated.first)
    guard case .source(let original) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("Original field hashes must be readable.")
      return
    }
    let friday = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(notes: .set("Friday booking")),
          expectedFieldHashes: original.fieldHashes)
      ))
    guard case .applied(_, .complete(let checkpoint)) = friday.outcome else {
      Issue.record("Friday booking must save: \(friday)")
      return
    }
    guard case .source(let before) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The current Item must be readable.")
      return
    }
    let patch = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id,
          changes: PlannerItemChanges(title: .set("Tokyo Hotel"), notes: .set("Monday booking")),
          expectedFieldHashes: original.fieldHashes)
      ))
    guard case .rejected(let reason) = patch.outcome else {
      Issue.record("One stale field must reject the complete patch: \(patch)")
      return
    }
    #expect(reason.code == "staleEdit")
    guard case .staleEdit(let fields, let currentValues, _) = reason.details else {
      Issue.record("Stale rejection must identify only the conflicting field.")
      return
    }
    #expect(fields == [.notes])
    #expect(currentValues == [.notes: .optionalString("Friday booking")])
    guard case .source(let after) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The retained Item must be readable.")
      return
    }
    #expect(after.content.title == "Hotel")
    #expect(after.content.notes == "Friday booking")
    #expect(after.updatedAt == before.updatedAt)
    #expect(after.fieldHashes == before.fieldHashes)
    let catalog = await planner.inspectRecovery(request: .namespaces)
    guard case .listedNamespaces(let namespaces) = catalog else {
      Issue.record("The recovery checkpoint must remain readable: \(catalog)")
      return
    }
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func unrelatedTitleEditDoesNotInvalidatePriorNotesHash() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly
    )
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The local dataset must initialize.")
      return
    }
    let created = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))
      ))
    guard case .applied(let createdResult, .complete) = created.outcome else {
      Issue.record("Hotel creation failed: \(created)")
      return
    }
    let item = try #require(createdResult.generated.first)
    guard case .source(let original) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("Original content hashes must be readable.")
      return
    }
    let originalTitleHash = try #require(original.fieldHashes[.title])
    let originalNotesHash = try #require(original.fieldHashes[.notes])
    let titleEdit = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(title: .set("Tokyo Hotel")),
          expectedFieldHashes: [.title: originalTitleHash])
      ))
    guard case .applied(_, .complete) = titleEdit.outcome else {
      Issue.record("The title edit must save independently: \(titleEdit)")
      return
    }
    guard case .source(let renamed) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("Renamed Hotel must be readable.")
      return
    }
    #expect(renamed.content.title == "Tokyo Hotel")
    #expect(renamed.content.notes == "Original notes")
    #expect(renamed.fieldHashes[.notes] == originalNotesHash)
    #expect(renamed.fieldHashes[.title] != originalTitleHash)
    let notesEdit = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(notes: .set("Friday booking")),
          expectedFieldHashes: original.fieldHashes)
      ))
    guard case .applied(_, .complete) = notesEdit.outcome else {
      Issue.record("A stale unchanged title hash must not reject the notes-only edit: \(notesEdit)")
      return
    }
    let reopenedPlanner = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopenedPlanner.bootstrap() else {
      Issue.record("The completed dataset must reopen.")
      return
    }
    guard
      case .source(let current) = await reopenedPlanner.read(
        session: reopenedSession, request: .source(item))
    else {
      Issue.record("The Item must remain readable.")
      return
    }
    #expect(current.content.title == "Tokyo Hotel")
    #expect(current.content.notes == "Friday booking")
    #expect(current.fieldHashes[.title] == renamed.fieldHashes[.title])
    #expect(current.fieldHashes[.notes] != originalNotesHash)
    #expect(current.createdAt == original.createdAt)
    #expect(current.state.globalDone == false)
    #expect(current.state.archived == false)
  }

  @Test func replayingNotesEditReturnsOriginalEvidenceWithoutReapplyingOldValue() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly
    )
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real local fixture must initialize.")
      return
    }
    let created = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))
      ))
    guard case .applied(let creationResult, .complete) = created.outcome else {
      Issue.record("Hotel creation failed: \(created)")
      return
    }
    let item = try #require(creationResult.generated.first)
    guard case .source(let original) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The original read must be available.")
      return
    }
    let originalHash = try #require(original.fieldHashes[.notes])
    let operationId = UUID()
    let friday = await planner.execute(
      PlannerOperation(
        operationId: operationId, session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(notes: .set("Friday booking")),
          expectedFieldHashes: [.notes: originalHash])
      ))
    guard case .applied(let originalResult, .complete(let originalCheckpoint)) = friday.outcome
    else {
      Issue.record("Friday booking failed: \(friday)")
      return
    }
    guard
      case .source(let fridayRead) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("Friday booking must supply its current hash.")
      return
    }
    let fridayHash = try #require(fridayRead.fieldHashes[.notes])
    let saturday = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(notes: .set("Saturday booking")),
          expectedFieldHashes: [.notes: fridayHash])
      ))
    guard case .applied(_, .complete(let latestCheckpoint)) = saturday.outcome else {
      Issue.record("The later independent edit must save: \(saturday)")
      return
    }
    let reopenedPlanner = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopenedPlanner.bootstrap() else {
      Issue.record("The dataset must reopen before replay.")
      return
    }
    let replay = await reopenedPlanner.execute(
      PlannerOperation(
        operationId: operationId, session: reopenedSession,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(notes: .set("Friday booking")),
          expectedFieldHashes: original.fieldHashes)
      ))
    guard case .applied(let replayResult, .complete(let replayCheckpoint)) = replay.outcome else {
      Issue.record("Known identical replay must resolve before stale-value guards: \(replay)")
      return
    }
    #expect(replayResult == originalResult)
    #expect(replayCheckpoint == originalCheckpoint)
    #expect(replayCheckpoint < latestCheckpoint)
    guard
      case .source(let current) = await reopenedPlanner.read(
        session: reopenedSession, request: .source(item))
    else {
      Issue.record("The current Item must remain readable.")
      return
    }
    #expect(current.content.notes == "Saturday booking")
    let catalog = await reopenedPlanner.inspectRecovery(request: .namespaces)
    guard case .listedNamespaces(let namespaces) = catalog else {
      Issue.record("Current recovery must remain readable: \(catalog)")
      return
    }
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == latestCheckpoint)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func staleNotesEditPreservesFridayBookingAndReportsCurrentField() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly
    )
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real local fixture must initialize.")
      return
    }
    let created = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))
      ))
    guard case .applied(let result, .complete) = created.outcome else {
      Issue.record("Hotel creation must be acknowledged: \(created)")
      return
    }
    let item = try #require(result.generated.first)
    guard case .source(let original) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The original notes hash must be readable.")
      return
    }
    let originalHash = try #require(original.fieldHashes[.notes])
    let saved = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(notes: .set("Friday booking")),
          expectedFieldHashes: [.notes: originalHash])
      ))
    guard case .applied(_, .complete(let savedCheckpoint)) = saved.outcome else {
      Issue.record("Friday booking must be saved before the competing edit: \(saved)")
      return
    }
    guard case .source(let friday) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("Friday booking must be readable.")
      return
    }
    let stale = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(notes: .set("Monday booking")),
          expectedFieldHashes: [.notes: originalHash])
      ))
    guard case .rejected(let reason) = stale.outcome else {
      Issue.record("Monday booking from the old read must reject: \(stale)")
      return
    }
    #expect(reason.code == "staleEdit")
    guard case .staleEdit(let fields, let currentValues, let currentHashes) = reason.details else {
      Issue.record("Stale rejection must identify current conflicting fields, values and hashes.")
      return
    }
    #expect(fields == [.notes])
    #expect(currentValues == [.notes: .optionalString("Friday booking")])
    #expect(currentHashes == [.notes: try #require(friday.fieldHashes[.notes])])
    guard case .source(let unchanged) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The retained current Item must remain readable.")
      return
    }
    #expect(unchanged.content.title == "Hotel")
    #expect(unchanged.content.notes == "Friday booking")
    #expect(unchanged.updatedAt == friday.updatedAt)
    #expect(unchanged.fieldHashes == friday.fieldHashes)
    let catalog = await planner.inspectRecovery(request: .namespaces)
    guard case .listedNamespaces(let namespaces) = catalog else {
      Issue.record("The recovery catalog must remain readable: \(catalog)")
      return
    }
    let namespace = try #require(namespaces.first)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == savedCheckpoint)
    #expect(namespace.preparedProposals.isEmpty)
  }

  @Test func notesEditPreservesOtherFieldsAndSurvivesReopenWithRecovery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly
    )
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real local fixture must initialize.")
      return
    }
    let created = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))
      ))
    guard case .applied(let createdResult, .complete(let originalCheckpoint)) = created.outcome
    else {
      Issue.record("Hotel creation must be independently acknowledged: \(created)")
      return
    }
    let item = try #require(createdResult.generated.first)
    let originalRead = await planner.read(session: session, request: .source(item))
    guard case .source(let original) = originalRead else {
      Issue.record("Hotel must supply its current notes hash: \(originalRead)")
      return
    }
    let notesHash = try #require(original.fieldHashes[.notes])
    let operationId = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000902"))
    let edited = await planner.execute(
      PlannerOperation(
        operationId: operationId, session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(notes: .set("Friday booking")),
          expectedFieldHashes: [.notes: notesHash]
        )
      ))
    guard case .applied(let editResult, .complete(let editCheckpoint)) = edited.outcome else {
      Issue.record("A guarded notes edit must establish independent recovery: \(edited)")
      return
    }
    #expect(editResult.generated.isEmpty)
    #expect(editResult.affected == [item])
    #expect(editCheckpoint > originalCheckpoint)
    let reopenedPlanner = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopenedPlanner.bootstrap() else {
      Issue.record("The edited dataset must reopen.")
      return
    }
    let read = await reopenedPlanner.read(session: reopenedSession, request: .source(item))
    guard case .source(let current) = read else {
      Issue.record("The edited Item must remain readable: \(read)")
      return
    }
    #expect(current.content.title == "Hotel")
    #expect(current.content.notes == "Friday booking")
    #expect(current.content.subtitle == nil)
    #expect(current.content.location == nil)
    #expect(current.content.estimate == nil)
    #expect(current.content.links.isEmpty)
    #expect(current.content.categoryIds.isEmpty)
    #expect(current.content.tagIds.isEmpty)
    #expect(current.labels.isEmpty)
    #expect(current.references.isEmpty)
    #expect(current.state.globalDone == false)
    #expect(current.state.archived == false)
    #expect(current.createdAt == original.createdAt)
    #expect(current.updatedAt >= original.updatedAt)
    #expect(current.fieldHashes[.title] == original.fieldHashes[.title])
    #expect(current.fieldHashes[.notes] != notesHash)
    let status = await reopenedPlanner.operationStatus(
      session: reopenedSession, operationId: operationId)
    guard case .appliedRecoveryComplete(let statusResult, let statusCheckpoint) = status else {
      Issue.record("The notes operation must retain completed evidence: \(status)")
      return
    }
    #expect(statusResult == editResult)
    #expect(statusCheckpoint == editCheckpoint)
    let catalog = await reopenedPlanner.inspectRecovery(request: .namespaces)
    guard case .listedNamespaces(let namespaces) = catalog else {
      Issue.record("The independent recovery namespace must be discoverable: \(catalog)")
      return
    }
    let namespace = try #require(namespaces.first)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == editCheckpoint)
    let inspected = await reopenedPlanner.inspectRecovery(
      request: .acknowledgedSnapshot(
        namespaceId: namespace.namespaceId, checkpointGeneration: editCheckpoint
      ))
    guard case .selected(let selection) = inspected else {
      Issue.record("The edited content must be independently recovered: \(inspected)")
      return
    }
    #expect(selection.decodedBackup.backup.sources.count == 1)
    #expect(selection.decodedBackup.backup.sources.first?.id == item.id)
    #expect(selection.decodedBackup.backup.sources.first?.content.title == "Hotel")
    #expect(selection.decodedBackup.backup.sources.first?.content.notes == "Friday booking")
  }
}
