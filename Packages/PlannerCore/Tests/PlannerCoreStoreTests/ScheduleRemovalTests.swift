import Foundation
import PlannerCore
import Testing

struct ScheduleRemovalTests {
  @Test func laterOrdinaryWritesRetainDeletionHistoryAndRemovingLastAssignmentShowsNoSchedule()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400)
    let form = PlannerScheduleForm.timed(start: start, end: nil, planningTimeZone: "Asia/Tokyo")
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel")))
      ).outcome,
      let item = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createSchedule(source: item, form: form))
      ).outcome,
      let oldSchedule = scheduled.generated.first,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .removeSchedule(scheduleId: oldSchedule.id))
      ).outcome,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let originalRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 3)),
      let marker = originalRecovery.decodedBackup.backup.deletionMarkers.first
    else {
      Issue.record("A removed appointment's real metadata must exist before later writes.")
      return
    }
    let missingIdentifier = UUID()
    guard
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery()))),
      case .rejected(let missing) = await planner.execute(
        PlannerOperation(
          operationId: missingIdentifier, session: session,
          command: .removeSchedule(scheduleId: oldSchedule.id))
      ).outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: missingIdentifier),
      case .rows(let unscheduled) = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record(
        "A fresh operation for an absent Schedule must reject without invalidating current rows.")
      return
    }
    #expect(missing.code == "missingReference")
    #expect(unscheduled.rows.first?.scheduleSummary == PlannerRowScheduleSummary.none)
    let commands: [PlannerCommand] = [
      .createItem(content: PlannerItemContentInput(title: "Museum")),
      .editItem(
        sourceId: item.id, changes: PlannerItemChanges(title: .set("Tokyo Hotel")),
        expectedFieldHashes: originalItem.fieldHashes),
      .setArchive(source: item, archived: true),
      .setCompletion(scope: .globalItem(itemId: item.id), done: true),
    ]
    for (index, command) in commands.enumerated() {
      guard
        case .applied(_, .complete(let checkpoint)) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session, command: command)
        ).outcome,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else {
        Issue.record("Every ordinary Item writer must preserve the existing deletion history.")
        return
      }
      #expect(checkpoint == Int64(index + 4))
      #expect(recovery.decodedBackup.backup.deletionMarkers == [marker])
    }
    guard
      case .applied(let added, .complete(let addedCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .createSchedule(source: item, form: form))
      ).outcome,
      let newSchedule = added.generated.first,
      case .source(.schedule(let originalSchedule)) = await planner.read(
        session: session, request: .source(newSchedule)),
      case .selected(let addedRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 8))
    else {
      Issue.record("A newly created assignment must retain the closed old identity and metadata.")
      return
    }
    #expect(addedCheckpoint == 8)
    #expect(newSchedule.id != oldSchedule.id)
    #expect(addedRecovery.decodedBackup.backup.deletionMarkers == [marker])
    let laterForm = PlannerScheduleForm.timed(
      start: start.addingTimeInterval(3600),
      end: start.addingTimeInterval(7200), planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(_, .complete(let editedCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editSchedule(
            scheduleId: newSchedule.id, changes: PlannerScheduleChanges(form: laterForm),
            expectedFieldHashes: originalSchedule.fieldHashes))
      ).outcome,
      case .source(.schedule(let editedSchedule)) = await planner.read(
        session: session, request: .source(newSchedule)),
      case .selected(let editedRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 9)),
      case .applied(_, .complete(let zoneCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .changeScheduleZone(
            scheduleId: newSchedule.id, planningTimeZone: "Europe/Paris",
            expectedFieldHashes: editedSchedule.fieldHashes))
      ).outcome,
      case .selected(let zoneRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 10)),
      case .source(.item(let beforeLastRemoval)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Both guarded Schedule writers must retain earlier deletion markers.")
      return
    }
    #expect(editedCheckpoint == 9)
    #expect(zoneCheckpoint == 10)
    #expect(editedRecovery.decodedBackup.backup.deletionMarkers == [marker])
    #expect(zoneRecovery.decodedBackup.backup.deletionMarkers == [marker])
    guard
      case .applied(_, .complete(let removedCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .removeSchedule(scheduleId: newSchedule.id))
      ).outcome,
      case .source(.item(let retained)) = await planner.read(
        session: session, request: .source(item)),
      case .selected(let finalRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 11)),
      case .snapshot(let finalSnapshot) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(PlannerItemQuery(completion: .all, archive: .all)))),
      case .rows(let rows) = await planner.read(
        session: session,
        request: .rows(generation: finalSnapshot.generation, offset: 0, limit: 2)),
      case .listedNamespaces(let latestNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record(
        "Last-assignment removal must preserve the complete Item and both deletion identities.")
      return
    }
    #expect(removedCheckpoint == 11)
    #expect(retained.content.title == "Tokyo Hotel")
    #expect(retained.fieldHashes == beforeLastRemoval.fieldHashes)
    #expect(retained.updatedAt == beforeLastRemoval.updatedAt)
    #expect(retained.state.globalDone == true)
    #expect(retained.state.archived == true)
    #expect(
      rows.rows.first { $0.identity == .source(item) }?.scheduleSummary
        == PlannerRowScheduleSummary.none)
    #expect(finalRecovery.decodedBackup.backup.schedules.isEmpty)
    #expect(finalRecovery.decodedBackup.backup.deletionMarkers.count == 2)
    #expect(finalRecovery.decodedBackup.backup.deletionMarkers.contains(marker))
    #expect(latestNamespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 11)
    #expect(latestNamespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func selectedScheduleRemovalKeepsSourceOtherAssignmentAndMinimalRecoveryMarker()
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
    let start = Date(timeIntervalSinceReferenceDate: 813_200_400)
    let firstForm = PlannerScheduleForm.timed(
      start: start, end: nil, planningTimeZone: "Asia/Tokyo")
    let secondForm = PlannerScheduleForm.timed(
      start: start.addingTimeInterval(3600), end: nil, planningTimeZone: "Asia/Tokyo")
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Keep",
              links: [PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu")])))
      ).outcome,
      let item = created.generated.first,
      case .applied(let firstCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: firstForm))
      ).outcome,
      let first = firstCreated.generated.first,
      case .applied(let secondCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(source: item, form: secondForm))
      ).outcome,
      let second = secondCreated.generated.first,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .setArchive(source: item, archived: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
      ).outcome,
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.schedule(let originalSecond)) = await planner.read(
        session: session, request: .source(second)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(
          session: session,
          request: .items(
            PlannerItemQuery(
              completion: .all, archive: .all,
              rowPresentation: PlannerRowPresentationContext(
                referenceInstant: start, displayTimeZone: "Asia/Tokyo")))))
    else {
      Issue.record(
        "The archived/completed Item and two retained Schedules must exist before removal.")
      return
    }
    let operationIdentifier = UUID()
    let command = PlannerCommand.removeSchedule(scheduleId: first.id)
    guard
      case .applied(let removed, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: session, command: command)
      ).outcome
    else {
      Issue.record(
        "Removal must save exactly the selected Schedule and minimal deletion metadata together.")
      return
    }
    #expect(checkpoint == 6)
    #expect(removed.generated.isEmpty)
    #expect(removed.affected == [first, item])
    guard
      case .failed(let stale) = await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record("Removal must invalidate the prior date projection.")
      return
    }
    #expect(stale.code == "staleSnapshot")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .failed(let missing) = await reopened.read(
        session: reopenedSession, request: .source(first)),
      case .source(.schedule(let retainedSecond)) = await reopened.read(
        session: reopenedSession, request: .source(second)),
      case .snapshot(let currentSnapshot) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .items(
            PlannerItemQuery(
              completion: .all, archive: .all,
              rowPresentation: PlannerRowPresentationContext(
                referenceInstant: start, displayTimeZone: "Europe/Paris"))))),
      case .rows(let currentRows) = await reopened.read(
        session: reopenedSession,
        request: .rows(generation: currentSnapshot.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let before) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 5)),
      case .selected(let after) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 6))
    else {
      Issue.record(
        "Removal, preserved source/assignment and independent metadata must survive reopen.")
      return
    }
    #expect(missing.code == "missingReference")
    #expect(retainedItem.content.title == "Hotel")
    #expect(retainedItem.content.notes == "Keep")
    #expect(retainedItem.content.links == originalItem.content.links)
    #expect(retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(retainedItem.updatedAt == originalItem.updatedAt)
    #expect(retainedItem.state.globalDone == true)
    #expect(retainedItem.state.archived == true)
    #expect(
      retainedItem.references.filter {
        if case .schedule = $0 { return true }
        return false
      } == [.schedule(id: second.id, source: item)])
    #expect(retainedSecond.content.form == secondForm)
    #expect(retainedSecond.fieldHashes == originalSecond.fieldHashes)
    #expect(
      currentRows.rows.first?.scheduleSummary
        == .directItem(schedule: second, owner: item, form: secondForm, additionalCount: 0))
    #expect(before.decodedBackup.backup.schedules.count == 2)
    #expect(before.decodedBackup.backup.deletionMarkers.isEmpty)
    #expect(after.decodedBackup.backup.schedules.map(\.id) == [second.id])
    let originalSchedule = try #require(
      before.decodedBackup.backup.schedules.first { $0.id == first.id })
    let marker = try #require(after.decodedBackup.backup.deletionMarkers.first)
    #expect(after.decodedBackup.backup.deletionMarkers.count == 1)
    #expect(marker.operationId == operationIdentifier)
    #expect(marker.target == .source(first, lifetimeId: originalSchedule.lifetimeId))
    #expect(marker.closedFamilyId == nil)
    let portable = try #require(
      JSONSerialization.jsonObject(with: after.portableData) as? [String: Any])
    let encodedMarker = try #require((portable["deletionMarkers"] as? [[String: Any]])?.first)
    #expect(Set(encodedMarker.keys) == ["deletionId", "operationId", "target", "closedFamilyId"])
    #expect(encodedMarker["closedFamilyId"] is NSNull)
    #expect(
      NSDictionary(dictionary: try #require(encodedMarker["target"] as? [String: Any])).isEqual(
        to: [
          "kind": "source",
          "source": [
            "kind": "schedule", "id": first.id.uuidString,
            "lifetimeId": originalSchedule.lifetimeId.uuidString,
          ],
        ]))
    guard
      case .applied(_, .complete(let laterCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: UUID(), session: reopenedSession,
          command: .editItem(
            sourceId: item.id, changes: PlannerItemChanges(notes: .set("Later notes")),
            expectedFieldHashes: retainedItem.fieldHashes))
      ).outcome,
      case .applied(let replayed, .complete(let originalCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .rejected(let mismatch) = await reopened.execute(
        PlannerOperation(
          operationId: operationIdentifier, session: reopenedSession,
          command: .removeSchedule(scheduleId: second.id))
      ).outcome,
      case .source(.schedule) = await reopened.read(
        session: reopenedSession, request: .source(second)),
      case .selected(let latest) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 7)),
      case .source(.item(let latestItem)) = await reopened.read(
        session: reopenedSession, request: .source(item))
    else {
      Issue.record(
        "Replay must retain its original removal and marker without removing a different Schedule.")
      return
    }
    #expect(laterCheckpoint == 7)
    #expect(replayed == removed)
    #expect(originalCheckpoint == 6)
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(latestItem.content.notes == "Later notes")
    #expect(latest.decodedBackup.backup.deletionMarkers == [marker])
    #expect(namespace.preparedProposals.isEmpty)
  }
}
