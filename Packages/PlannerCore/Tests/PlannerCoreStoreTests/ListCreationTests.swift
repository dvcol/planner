import CryptoKit
import Foundation
import PlannerCore
import Testing

struct ListCreationTests {
  @Test func emptyListSavesOwnedMetadataWithoutCompletingOrChangingExistingPlannerData()
    async throws
  {
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
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      ).outcome,
      let item = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(
            source: item,
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
              planningTimeZone: "Asia/Tokyo")))
      ).outcome,
      let deletedSchedule = scheduled.generated.first,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .removeSchedule(scheduleId: deletedSchedule.id))
      ).outcome,
      case .applied(let civilCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(
            source: item,
            form: .allDay(start: PlannerCivilDate(year: 2026, month: 10, day: 9), end: nil)))
      ).outcome,
      let civilSchedule = civilCreated.generated.first,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.schedule(let originalSchedule)) = await planner.read(
        session: session, request: .source(civilSchedule))
    else {
      Issue.record(
        "Existing Item, retained all-day Schedule and deletion history must be saved before the List."
      )
      return
    }
    let content = PlannerListContentInput(
      name: " Tokyo Food ", notes: "Keep exact notes",
      color: PlannerColor(red: 0.125, green: 0.5, blue: 0.75, alpha: 1), iconName: "fork.knife")
    let operationIdentifier = UUID()
    let command = PlannerCommand.createList(content: content)
    guard
      case .applied(let created, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(operationId: operationIdentifier, session: session, command: command)
      ).outcome,
      let list = created.generated.first
    else {
      Issue.record("Creating a List must durably save an empty independent container.")
      return
    }
    #expect(list.kind == .list)
    #expect(checkpoint == 5)
    #expect(created.generated == [list])
    #expect(created.affected == [list])
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let read)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.schedule(let retainedSchedule)) = await reopened.read(
        session: reopenedSession, request: .source(civilSchedule)),
      case .failed(let missing) = await reopened.read(
        session: reopenedSession, request: .source(deletedSchedule)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record(
        "List metadata and every existing source must remain independently recoverable after reopening."
      )
      return
    }
    #expect(read.source == list)
    #expect(read.content == content)
    #expect(Set(read.fieldHashes.keys) == [.name, .notes, .color, .iconName])
    #expect(read.state.globalDone == nil)
    #expect(read.state.archived == false)
    #expect(read.progress.container == list)
    #expect(read.progress.state == .empty)
    #expect(read.progress.doneCount == 0)
    #expect(read.progress.totalCount == 0)
    #expect(read.references.isEmpty)
    #expect(retainedItem.content.notes == "Keep")
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedSchedule.content == originalSchedule.content)
    #expect(retainedSchedule.fieldHashes == originalSchedule.fieldHashes)
    #expect(missing.code == "missingReference")
    #expect(recovery.decodedBackup.backup.sources.count == 2)
    #expect(recovery.decodedBackup.backup.schedules.count == 1)
    #expect(recovery.decodedBackup.backup.deletionMarkers.count == 1)
    #expect(namespace.preparedProposals.isEmpty)
    let portable = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    let record = try #require(
      (portable["sources"] as? [[String: Any]])?.first { $0["kind"] as? String == "list" })
    #expect(record["id"] as? String == list.id.uuidString)
    let lifetimeIdentifier = try #require(record["lifetimeId"] as? String)
    // Literal bytes follow the accepted version-1 List/name field framing and exact padded name.
    let fixtureInput =
      "506c616e6e65724669656c644861736800000000010000000000004000800000000000080102000000000000400080000000000002010000000000004000800000000000082100000000000000046e616d6510000000000000000c20546f6b796f20466f6f6420"
    let boundInput = fixtureInput.replacingOccurrences(
      of: "00000000000040008000000000000801",
      with: session.datasetId.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    ).replacingOccurrences(
      of: "00000000000040008000000000000201",
      with: list.id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    ).replacingOccurrences(
      of: "00000000000040008000000000000821",
      with: lifetimeIdentifier.replacingOccurrences(of: "-", with: "").lowercased())
    let characters = Array(boundInput)
    let input = try Data(
      stride(from: 0, to: characters.count, by: 2).map { index in
        try #require(UInt8(String(characters[index...index + 1]), radix: 16))
      })
    let expectedHash = SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    #expect(read.fieldHashes[.name]?.value == "sha256-v1:" + expectedHash)

    #expect(record["globalDone"] is NSNull)
    #expect(record["archived"] as? Bool == false)
    let savedContent = try #require(record["content"] as? [String: Any])
    #expect(Set(savedContent.keys) == ["name", "notes", "color", "iconName"])
    #expect(savedContent["name"] as? String == " Tokyo Food ")
    #expect(savedContent["notes"] as? String == "Keep exact notes")
    #expect(savedContent["iconName"] as? String == "fork.knife")
    #expect(
      NSDictionary(dictionary: try #require(savedContent["color"] as? [String: Any])).isEqual(to: [
        "red": 0.125, "green": 0.5, "blue": 0.75, "alpha": 1,
      ]))
    guard
      case .applied(let replay, .complete(let originalCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .rejected(let mismatch) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession,
          command: .createList(content: PlannerListContentInput(name: "Different")))
      ).outcome
    else {
      Issue.record("List creation replay must reuse its identity and reject a changed payload.")
      return
    }
    #expect(replay.generated == [list])
    #expect(originalCheckpoint == 5)
    #expect(mismatch.code == "operationPayloadMismatch")
  }
  @Test func everyExistingWriterKeepsListsInAcknowledgedRecovery() async throws {
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
          command: .createList(content: PlannerListContentInput(name: "Wishlist")))
      ).outcome,
      let list = created.generated.first,
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list)),
      case .applied(let itemCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel")))
      ).outcome,
      let item = itemCreated.generated.first,
      case .source(.item(let beforeEdit)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("The empty List must save before writes to independent Items and Schedules.")
      return
    }
    let commands: [PlannerCommand] = [
      .editItem(
        sourceId: item.id, changes: PlannerItemChanges(notes: .set("Keep")),
        expectedFieldHashes: beforeEdit.fieldHashes), .setArchive(source: item, archived: true),
      .setCompletion(scope: .globalItem(itemId: item.id), done: true),
    ]
    for command in commands {
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome
      else {
        Issue.record("Existing Item writes must remain available with saved Lists.")
        return
      }
    }
    let form = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
      planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createSchedule(source: item, form: form))
      ).outcome,
      let schedule = scheduled.generated.first,
      case .source(.schedule(let beforeZone)) = await planner.read(
        session: session, request: .source(schedule)),
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .changeScheduleZone(
            scheduleId: schedule.id, planningTimeZone: "Europe/Paris",
            expectedFieldHashes: beforeZone.fieldHashes))
      ).outcome,
      case .source(.schedule(let beforeForm)) = await planner.read(
        session: session, request: .source(schedule)),
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editSchedule(
            scheduleId: schedule.id,
            changes: PlannerScheduleChanges(
              form: .allDay(start: PlannerCivilDate(year: 2026, month: 10, day: 9), end: nil)),
            expectedFieldHashes: beforeForm.fieldHashes))
      ).outcome,
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .removeSchedule(scheduleId: schedule.id))
      ).outcome,
      case .source(.list(let retained)) = await planner.read(
        session: session, request: .source(list)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else {
      Issue.record("Schedule creation/zone/edit/removal must preserve the independent List.")
      return
    }
    #expect(checkpoint == 9)
    #expect(retained.content == original.content)
    #expect(retained.fieldHashes == original.fieldHashes)
    #expect(retained.updatedAt == original.updatedAt)
    #expect(retained.progress.state == .empty)
    #expect(namespace.preparedProposals.isEmpty)
    for generation in 1...checkpoint {
      guard
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: generation)),
        let recoveredList = recovery.decodedBackup.backup.lists.first
      else {
        Issue.record("Every acknowledged writer checkpoint must retain the List.")
        return
      }
      #expect(recovery.decodedBackup.backup.lists.count == 1)
      #expect(recoveredList.id == list.id)
      #expect(recoveredList.content == original.content)
      #expect(recoveredList.updatedAt == original.updatedAt)
      #expect(recoveredList.archived == false)
    }
    let final = try #require(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration)
    #expect(final == 9)
  }

  @Test func invalidListNamesAndColorsCannotSaveOrCreateAppliedEvidence() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The empty dataset must initialize before invalid List requests.")
      return
    }
    let invalid: [(PlannerListContentInput, String)] = [
      (PlannerListContentInput(name: ""), "/command/content/name"),
      (PlannerListContentInput(name: " \n\t"), "/command/content/name"),
      (
        PlannerListContentInput(
          name: "List", color: PlannerColor(red: -.infinity, green: 0, blue: 0, alpha: 1)),
        "/command/content/color/red"
      ),
      (
        PlannerListContentInput(
          name: "List", color: PlannerColor(red: 0, green: .nan, blue: 0, alpha: 1)),
        "/command/content/color/green"
      ),
      (
        PlannerListContentInput(
          name: "List", color: PlannerColor(red: 0, green: 0, blue: 1.01, alpha: 1)),
        "/command/content/color/blue"
      ),
      (
        PlannerListContentInput(
          name: "List", color: PlannerColor(red: 0, green: 0, blue: 0, alpha: -0.01)),
        "/command/content/color/alpha"
      ),
    ]
    for (content, path) in invalid {
      let identifier = UUID()
      guard
        case .rejected(let reason) = await planner.execute(
          PlannerOperation(
            operationId: identifier, session: session, command: .createList(content: content))
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: identifier)
      else {
        Issue.record("Invalid List content cannot save or create applied evidence.")
        return
      }
      #expect(reason.code == "invalidInput")
      #expect(reason.propertyPath == path)
    }
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else {
      Issue.record("The initialized namespace must remain inspectable after invalid creations.")
      return
    }
    #expect(namespace.acknowledgedSnapshot == nil)
    #expect(namespace.preparedProposals.isEmpty)
  }

}
