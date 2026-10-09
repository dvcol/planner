import Foundation
import PlannerCore
import Testing

struct ItemLocationEditTests {
  @Test func staleOrInvalidLocationsRejectWholePatchesAndOldReplayCannotUndoClear() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let firstLocation = PlannerOwnedLocation(
      displayName: nil, formattedAddress: "Meeting point A", coordinate: nil)
    let secondLocation = PlannerOwnedLocation(
      displayName: "Entrance", formattedAddress: "Meeting point B", coordinate: nil)
    let thirdLocation = PlannerOwnedLocation(
      displayName: nil, formattedAddress: "Meeting point C", coordinate: nil)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize.")
      return
    }
    let creation = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(
            title: "Hotel", notes: "Original notes", location: firstLocation))))
    guard case .applied(let created, .complete) = creation.outcome,
      let item = created.generated.first,
      case .source(let original) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The first owned address must be saved.")
      return
    }
    let editIdentifier = UUID()
    let secondCommand = PlannerCommand.editItem(
      sourceId: item.id, changes: PlannerItemChanges(location: .set(secondLocation)),
      expectedFieldHashes: original.fieldHashes)
    guard
      case .applied(_, .complete(let editedCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: editIdentifier, session: session, command: secondCommand)
      ).outcome,
      case .source(let current) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The intervening address must be saved.")
      return
    }
    let staleIdentifier = UUID()
    let staleEdit = await planner.execute(
      PlannerOperation(
        operationId: staleIdentifier, session: session,
        command: .editItem(
          sourceId: item.id,
          changes: PlannerItemChanges(title: .set("Tokyo Hotel"), location: .set(thirdLocation)),
          expectedFieldHashes: original.fieldHashes)))
    guard case .rejected(let reason) = staleEdit.outcome,
      case .staleEdit(let fields, let values, let hashes) = reason.details,
      case .source(let unchanged) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("One stale location must reject the complete title/location patch.")
      return
    }
    #expect(reason.code == "staleEdit")
    #expect(fields == [.location])
    #expect(values == [.location: .optionalLocation(secondLocation)])
    #expect(hashes == [.location: try #require(current.fieldHashes[.location])])
    #expect(unchanged.content.title == "Hotel")
    #expect(unchanged.content.location == secondLocation)
    #expect(unchanged.fieldHashes == current.fieldHashes)
    #expect(unchanged.updatedAt == current.updatedAt)
    guard
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: staleIdentifier)
    else {
      Issue.record("A stale patch must not create an applied receipt.")
      return
    }
    for coordinate in [
      PlannerCoordinate(latitude: .nan, longitude: 139),
      PlannerCoordinate(latitude: 35, longitude: .infinity),
      PlannerCoordinate(latitude: 90.01, longitude: 139),
      PlannerCoordinate(latitude: 35, longitude: -180.01),
    ] {
      let invalid = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: item.id,
            changes: PlannerItemChanges(
              notes: .set("Rejected notes"),
              location: .set(
                PlannerOwnedLocation(
                  displayName: nil, formattedAddress: nil, coordinate: coordinate))),
            expectedFieldHashes: current.fieldHashes)))
      guard case .rejected(let invalidReason) = invalid.outcome else {
        Issue.record("Invalid coordinates must reject the whole compound patch.")
        return
      }
      #expect(invalidReason.code == "invalidInput")
      #expect(invalidReason.propertyPath == "/command/changes/location/coordinate")
    }
    let missingHash = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(location: .clear), expectedFieldHashes: [:]
        )))
    guard case .rejected(let missingHashReason) = missingHash.outcome else {
      Issue.record("Location Clear must require its current hash.")
      return
    }
    #expect(missingHashReason.code == "invalidInput")
    #expect(missingHashReason.propertyPath == "/command/expectedFieldHashes/location")
    guard
      case .applied(_, .complete(let clearCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: item.id, changes: PlannerItemChanges(location: .clear),
            expectedFieldHashes: current.fieldHashes))
      )
      .outcome,
      case .source(let cleared) = await planner.read(session: session, request: .source(item)),
      case .applied(_, .complete(let replayedCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: editIdentifier, session: session, command: secondCommand)
      ).outcome,
      case .source(let retained) = await planner.read(session: session, request: .source(item)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery()))),
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record(
        "Clear must save, while replay returns the old evidence without restoring its address.")
      return
    }
    #expect(editedCheckpoint == 2)
    #expect(clearCheckpoint == 3)
    #expect(replayedCheckpoint == 2)
    #expect(retained.content.location == nil)
    #expect(retained.content.notes == "Original notes")
    #expect(retained.content.title == "Hotel")
    #expect(retained.fieldHashes == cleared.fieldHashes)
    #expect(retained.updatedAt == cleared.updatedAt)
    #expect(window.rows.first?.hasLocation == false)
    #expect(window.rows.first?.ownedLocation == nil)
    let changedReplay = await planner.execute(
      PlannerOperation(
        operationId: editIdentifier, session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(location: .set(thirdLocation)),
          expectedFieldHashes: original.fieldHashes)))
    guard case .rejected(let changedReason) = changedReplay.outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Changed payload replay must preserve the last complete checkpoint.")
      return
    }
    #expect(changedReason.code == "operationPayloadMismatch")
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 3)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func locationEditKeepsUnrelatedFieldsAndInvalidatesTheOldRowAfterReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let originalLocation = PlannerOwnedLocation(
      displayName: "Meeting point", formattedAddress: "Meeting point A",
      coordinate: PlannerCoordinate(latitude: 35, longitude: 139))
    let changedLocation = PlannerOwnedLocation(
      displayName: "Museum entrance", formattedAddress: "Meeting point B",
      coordinate: PlannerCoordinate(latitude: 35.25, longitude: 139.5))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The local dataset must initialize.")
      return
    }
    let creation = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(
            title: "Hotel", notes: "Original notes", location: originalLocation,
            estimate: PlannerEstimate(minutes: 120, displayUnit: .hour),
            links: [PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu")]))))
    guard case .applied(let created, .complete) = creation.outcome,
      let item = created.generated.first,
      case .source(let original) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("Hotel and its original owned location must be saved.")
      return
    }
    for command in [
      PlannerCommand.setCompletion(scope: .globalItem(itemId: item.id), done: true),
      .setArchive(source: item, archived: true),
      .editItem(
        sourceId: item.id, changes: PlannerItemChanges(notes: .set("Monday booking")),
        expectedFieldHashes: original.fieldHashes),
    ] {
      guard
        case .applied(_, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome
      else {
        Issue.record("The intervening independent Item actions must be saved.")
        return
      }
    }
    guard case .source(let before) = await planner.read(session: session, request: .source(item)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(
          session: session, request: .items(PlannerItemQuery(completion: .all, archive: .all))))
    else {
      Issue.record("The current Item and old row generation must be readable.")
      return
    }
    let locationHash = try #require(original.fieldHashes[.location])
    let edit = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(location: .set(changedLocation)),
          expectedFieldHashes: [.location: locationHash])))
    guard case .applied(_, .complete(let checkpoint)) = edit.outcome else {
      Issue.record("A current location hash must permit a complete owned-location edit.")
      return
    }
    #expect(checkpoint == 5)
    guard
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record("The old generation must not mix current map data with old row values.")
      return
    }
    #expect(stale.code == "staleSnapshot")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(let after) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .snapshot(let refreshed) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .items(PlannerItemQuery(completion: .all, archive: .all)))),
      case .rows(let window) = await reopened.read(
        session: reopenedSession,
        request: .rows(generation: refreshed.generation, offset: 0, limit: 1))
    else {
      Issue.record("The saved location and a fresh row must survive reopening the real store.")
      return
    }
    #expect(after.content.location == changedLocation)
    #expect(window.rows.first?.ownedLocation == changedLocation)
    #expect(after.content.title == "Hotel")
    #expect(after.content.notes == "Monday booking")
    #expect(after.content.estimate == original.content.estimate)
    #expect(after.content.links.map(\.linkId) == original.content.links.map(\.linkId))
    #expect(after.state.globalDone == true)
    #expect(after.state.archived == true)
    #expect(after.createdAt == original.createdAt)
    #expect(after.updatedAt != before.updatedAt)
    #expect(after.fieldHashes[.location] != original.fieldHashes[.location])
    for field in PlannerItemField.allCases where field != .location {
      #expect(after.fieldHashes[field] == before.fieldHashes[field])
    }
    guard
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Independent recovery must retain the changed location and unrelated values.")
      return
    }
    let recovered = try #require(recovery.decodedBackup.backup.sources.first)
    #expect(recovered.content.location == changedLocation)
    #expect(recovered.content.notes == "Monday booking")
    #expect(recovered.content.links.map(\.linkId) == original.content.links.map(\.linkId))
    #expect(recovered.globalDone)
    #expect(recovered.archived)
  }
}
