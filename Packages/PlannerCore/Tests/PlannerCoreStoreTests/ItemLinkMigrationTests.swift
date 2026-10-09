import Foundation
import PlannerCore
import Testing

struct ItemLinkMigrationTests {
  @Test func genuineV5MigrationPreservesBothScheduleFormsBeforeShareCreatesAnEmptyList()
    async throws
  {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(forResource: "SchemaV5", withExtension: nil, subdirectory: "Fixtures"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      LinkedManifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json"))
    )
    let assignment = try JSONDecoder().decode(
      CivilManifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    let share = Planner(configuration: configuration(directory, role: .shareExtension))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share cannot migrate the genuine schema-5 store.")
      return
    }
    let planner = Planner(configuration: configuration(directory, role: .mainApplication))
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    let timed = PlannerEntityReference(kind: .schedule, id: assignment.retainedScheduleId)
    let civil = PlannerEntityReference(kind: .schedule, id: assignment.allDayScheduleId)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.schedule(let timedRead)) = await planner.read(
        session: session, request: .source(timed)),
      case .source(.schedule(let civilRead)) = await planner.read(
        session: session, request: .source(civil)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let before) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: assignment.latestCheckpoint))
    else {
      Issue.record("Migration must preserve both schedule forms and historical schema-5 recovery.")
      return
    }
    #expect(session.datasetId == manifest.datasetId)
    #expect(original.content.title == "Hotel")
    #expect(original.content.notes == "Original notes")
    #expect(original.updatedAt.timeIntervalSinceReferenceDate == manifest.updatedAt)
    #expect(original.createdAt.timeIntervalSinceReferenceDate == manifest.createdAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues: original.fieldHashes.map { ($0.key.rawValue, $0.value.value) })
        == manifest.fieldHashes)
    #expect(
      original.content.links.map(\.linkId)
        == manifest.ownedLinks.sorted { $0.rank < $1.rank }.map(\.id))
    #expect(original.state.globalDone == true)
    #expect(original.state.archived == true)
    #expect(timedRead.fieldHashes[.form]?.value == assignment.retainedScheduleHash)
    #expect(
      timedRead.content.form
        == .timed(
          start: Date(timeIntervalSinceReferenceDate: 813_200_400.25),
          end: Date(timeIntervalSinceReferenceDate: 813_204_000.75), planningTimeZone: "Asia/Tokyo")
    )
    #expect(civilRead.fieldHashes[.form]?.value == assignment.allDayScheduleHash)
    #expect(
      civilRead.content.form
        == .allDay(
          start: PlannerCivilDate(year: 2026, month: 10, day: 9),
          end: PlannerCivilDate(year: 2026, month: 10, day: 11)))
    #expect(namespace.acknowledgedSnapshot?.storageSchemaVersion == 5)
    #expect(before.decodedBackup.backup.lists.isEmpty)
    #expect(before.decodedBackup.backup.deletionMarkers.count == 1)
    let operationIdentifier = UUID()
    let command = PlannerCommand.createList(
      content: PlannerListContentInput(name: "Tokyo Food", notes: "Keep List"))
    guard case .ready(let shareSession) = await share.bootstrap(),
      case .applied(let created, .complete(let checkpoint)) = await share.execute(
        PlannerOperation(operationId: operationIdentifier, session: shareSession, command: command)
      ).outcome,
      let list = created.generated.first,
      case .source(.list(let listRead)) = await planner.read(
        session: session, request: .source(list)),
      case .source(.item(let retained)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.schedule(let currentTimed)) = await planner.read(
        session: session, request: .source(timed)),
      case .source(.schedule(let currentCivil)) = await planner.read(
        session: session, request: .source(civil)),
      case .selected(let after) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .selected(let beforeAgain) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: assignment.latestCheckpoint)),
      case .listedNamespaces(let afterNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record("Share-role List creation must preserve every migrated owned record.")
      return
    }
    #expect(checkpoint == 8)
    #expect(listRead.content.name == "Tokyo Food")
    #expect(listRead.progress.state == .empty)
    #expect(listRead.state.globalDone == nil)
    #expect(retained.fieldHashes == original.fieldHashes)
    #expect(retained.updatedAt == original.updatedAt)
    #expect(retained.content.links == original.content.links)
    #expect(currentTimed.content == timedRead.content)
    #expect(currentTimed.fieldHashes == timedRead.fieldHashes)
    #expect(currentCivil.content == civilRead.content)
    #expect(currentCivil.fieldHashes == civilRead.fieldHashes)
    #expect(after.decodedBackup.backup.items.count == 1)
    #expect(after.decodedBackup.backup.lists.count == 1)
    #expect(after.decodedBackup.backup.schedules.count == 2)
    #expect(
      after.decodedBackup.backup.deletionMarkers == before.decodedBackup.backup.deletionMarkers)
    #expect(beforeAgain.portableData == before.portableData)
    #expect(afterNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 7)
    #expect(afterNamespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func mainMigratesGenuineV4RetainingDeletionHistoryBeforeShareSavesAllDay() async throws {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(forResource: "SchemaV4", withExtension: nil, subdirectory: "Fixtures"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      LinkedManifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json"))
    )
    let assignment = try JSONDecoder().decode(
      DeletionManifest.self,
      from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    let share = Planner(configuration: configuration(directory, role: .shareExtension))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share cannot migrate the original schema-4 store.")
      return
    }
    let planner = Planner(configuration: configuration(directory, role: .mainApplication))
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    let retainedSchedule = PlannerEntityReference(
      kind: .schedule, id: assignment.retainedScheduleId)
    let deletedSchedule = PlannerEntityReference(kind: .schedule, id: assignment.scheduleId)
    let timedForm = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400.25),
      end: Date(timeIntervalSinceReferenceDate: 813_204_000.75), planningTimeZone: "Asia/Tokyo")
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.schedule(let retained)) = await planner.read(
        session: session, request: .source(retainedSchedule)),
      case .failed(let missing) = await planner.read(
        session: session, request: .source(deletedSchedule)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let before) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: assignment.latestCheckpoint))
    else {
      Issue.record(
        "Migration must preserve source, remaining Schedule and independent schema-4 recovery.")
      return
    }
    #expect(session.datasetId == manifest.datasetId)
    #expect(original.content.title == "Hotel")
    #expect(original.content.notes == "Original notes")
    #expect(original.updatedAt.timeIntervalSinceReferenceDate == manifest.updatedAt)
    #expect(original.createdAt.timeIntervalSinceReferenceDate == manifest.createdAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues: original.fieldHashes.map { ($0.key.rawValue, $0.value.value) })
        == manifest.fieldHashes)
    #expect(
      original.content.links.map(\.linkId)
        == manifest.ownedLinks.sorted { $0.rank < $1.rank }.map(\.id))
    #expect(original.state.globalDone == true)
    #expect(original.state.archived == true)
    #expect(retained.content.form == timedForm)
    #expect(retained.fieldHashes[.form]?.value == assignment.retainedScheduleHash)
    #expect(missing.code == "missingReference")
    #expect(namespace.acknowledgedSnapshot?.storageSchemaVersion == 4)
    #expect(before.decodedBackup.backup.schedules.count == 1)
    #expect(before.decodedBackup.backup.deletionMarkers.count == 1)
    #expect(
      before.decodedBackup.backup.deletionMarkers.first?.operationId
        == UUID(uuidString: "00000000-0000-4000-8000-000000000945"))
    let civilForm = PlannerScheduleForm.allDay(
      start: PlannerCivilDate(year: 2026, month: 10, day: 9),
      end: PlannerCivilDate(year: 2026, month: 10, day: 11))
    guard case .ready(let shareSession) = await share.bootstrap(),
      case .applied(let added, .complete(let checkpoint)) = await share.execute(
        PlannerOperation(
          operationId: UUID(), session: shareSession,
          command: .createSchedule(source: item, form: civilForm))
      ).outcome,
      let allDay = added.generated.first,
      case .source(.schedule(let newRead)) = await planner.read(
        session: session, request: .source(allDay)),
      case .applied(let replay, .complete(let originalCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: assignment.scheduleOperationId, session: session,
          command: .createSchedule(source: item, form: timedForm))
      ).outcome,
      case .failed(let stillDeleted) = await planner.read(
        session: session, request: .source(deletedSchedule)),
      case .source(.item(let current)) = await planner.read(
        session: session, request: .source(item)),
      case .listedNamespaces(let afterNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      case .selected(let after) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .selected(let beforeAgain) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: assignment.latestCheckpoint))
    else {
      Issue.record(
        "Share-role all-day saving must retain deletion and earlier operation evidence without resurrection."
      )
      return
    }
    #expect(checkpoint == 7)
    #expect(originalCheckpoint == 4)
    #expect(replay.generated == [deletedSchedule])
    #expect(stillDeleted.code == "missingReference")
    #expect(newRead.content.form == civilForm)
    #expect(current.fieldHashes == original.fieldHashes)
    #expect(current.updatedAt == original.updatedAt)
    #expect(current.content.links == original.content.links)
    #expect(afterNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 7)
    #expect(afterNamespaces.first?.preparedProposals.isEmpty == true)
    #expect(after.decodedBackup.backup.schedules.count == 2)
    #expect(
      after.decodedBackup.backup.deletionMarkers == before.decodedBackup.backup.deletionMarkers)
    #expect(beforeAgain.portableData == before.portableData)
  }

  @Test func mainAppMigratesV3ThenShareRemovesScheduleWithoutLosingItemOrHistoricalReceipt()
    async throws
  {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(forResource: "SchemaV3", withExtension: nil, subdirectory: "Fixtures"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifestData = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
    let manifest = try JSONDecoder().decode(LinkedManifest.self, from: manifestData)
    let assignment = try JSONDecoder().decode(ScheduledManifest.self, from: manifestData)
    let share = Planner(configuration: configuration(directory, role: .shareExtension))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share must leave the genuine V3 store for main-app migration.")
      return
    }
    let planner = Planner(configuration: configuration(directory, role: .mainApplication))
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    let schedule = PlannerEntityReference(kind: .schedule, id: assignment.scheduleId)
    let form = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400.25),
      end: Date(timeIntervalSinceReferenceDate: 813_204_000.75), planningTimeZone: "Asia/Tokyo")
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let source)) = await planner.read(session: session, request: .source(item)),
      case .source(.schedule(let scheduleRead)) = await planner.read(
        session: session, request: .source(schedule)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let oldRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: assignment.latestCheckpoint))
    else {
      Issue.record(
        "Migration must preserve Item/Schedule identities, complete forms and old recovery.")
      return
    }
    #expect(session.datasetId == manifest.datasetId)
    #expect(source.content.title == "Hotel")
    #expect(source.content.notes == "Original notes")
    #expect(source.createdAt.timeIntervalSinceReferenceDate == manifest.createdAt)
    #expect(source.updatedAt.timeIntervalSinceReferenceDate == manifest.updatedAt)
    #expect(
      Dictionary(uniqueKeysWithValues: source.fieldHashes.map { ($0.key.rawValue, $0.value.value) })
        == manifest.fieldHashes)
    #expect(source.state.globalDone == true)
    #expect(source.state.archived == true)
    #expect(
      source.content.links.map(\.linkId)
        == manifest.ownedLinks.sorted { $0.rank < $1.rank }.map(\.id))
    #expect(scheduleRead.content.source == item)
    #expect(scheduleRead.content.form == form)
    #expect(scheduleRead.fieldHashes[.form]?.value == assignment.scheduleHash)
    #expect(namespace.acknowledgedSnapshot?.storageSchemaVersion == 3)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 4)
    #expect(oldRecovery.decodedBackup.backup.deletionMarkers.isEmpty)
    let removalIdentifier = UUID()
    guard case .ready(let shareSession) = await share.bootstrap(),
      case .applied(_, .complete(let checkpoint)) = await share.execute(
        PlannerOperation(
          operationId: removalIdentifier, session: shareSession,
          command: .removeSchedule(scheduleId: schedule.id))
      ).outcome,
      case .applied(let replayedCreation, .complete(let originalCheckpoint)) =
        await planner.execute(
          PlannerOperation(
            operationId: assignment.scheduleOperationId, session: session,
            command: .createSchedule(source: item, form: form))
        ).outcome,
      case .failed(let missing) = await planner.read(session: session, request: .source(schedule)),
      case .source(.item(let retained)) = await planner.read(
        session: session, request: .source(item)),
      case .listedNamespaces(let updatedNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      case .selected(let newRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .selected(let oldAgain) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: assignment.latestCheckpoint))
    else {
      Issue.record(
        "Share-role removal must preserve the source and original creation receipt without resurrection."
      )
      return
    }
    #expect(checkpoint == 5)
    #expect(originalCheckpoint == 4)
    #expect(replayedCreation.generated == [schedule])
    #expect(missing.code == "missingReference")
    #expect(retained.fieldHashes == source.fieldHashes)
    #expect(retained.updatedAt == source.updatedAt)
    #expect(retained.content.links == source.content.links)
    #expect(retained.state.globalDone == true)
    #expect(retained.state.archived == true)
    #expect(updatedNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 7)
    #expect(newRecovery.decodedBackup.backup.schedules.isEmpty)
    #expect(newRecovery.decodedBackup.backup.deletionMarkers.count == 1)
    #expect(
      newRecovery.decodedBackup.backup.deletionMarkers.first?.operationId == removalIdentifier)
    #expect(oldAgain.portableData == oldRecovery.portableData)
  }

  @Test func mainAppMigratesV1WithoutChangingItemIdentityStateOrAcknowledgedHistory() async throws {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(forResource: "SchemaV1", withExtension: nil, subdirectory: "Fixtures"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    let share = Planner(configuration: configuration(directory, role: .shareExtension))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share must ask the main app to migrate an existing V1 store.")
      return
    }
    let planner = Planner(configuration: configuration(directory, role: .mainApplication))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The main app must migrate the real V1 fixture.")
      return
    }
    #expect(session.datasetId == manifest.datasetId)
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    guard
      case .source(.item(let source)) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The migrated Item must remain retrievable by its original identity.")
      return
    }
    #expect(source.content.title == "Hotel")
    #expect(source.content.notes == "Original notes")
    #expect(source.createdAt.timeIntervalSinceReferenceDate == manifest.createdAt)
    #expect(source.updatedAt.timeIntervalSinceReferenceDate == manifest.updatedAt)
    #expect(source.state.globalDone == true)
    #expect(source.state.archived == true)
    #expect(source.content.links.isEmpty)
    #expect(
      source.fieldHashes.mapValues(\.value).reduce(into: [String: String]()) { result, field in
        result[field.key.rawValue] = field.value
      } == manifest.fieldHashes)
    let originalContent = PlannerItemContentInput(
      title: "Hotel", notes: "Original notes",
      location: PlannerOwnedLocation(
        displayName: "Meeting point", formattedAddress: "Meeting point A",
        coordinate: PlannerCoordinate(latitude: 35, longitude: 139)),
      estimate: PlannerEstimate(minutes: 120, displayUnit: .hour))
    #expect(source.content.location == originalContent.location)
    #expect(source.content.estimate == originalContent.estimate)
    guard
      case .applied(let replayed, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: manifest.creationOperationId, session: session,
          command: .createItem(content: originalContent))
      ).outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let oldRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: manifest.latestCheckpoint))
    else {
      Issue.record("Migration must retain original replay receipts and recovery checkpoints.")
      return
    }
    #expect(replayed.generated == [item])
    #expect(checkpoint == manifest.creationCheckpoint)
    #expect(namespace.acknowledgedSnapshot?.storageSchemaVersion == 1)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 3)
    #expect(oldRecovery.decodedBackup.backup.items.first?.id == item.id)
    #expect(oldRecovery.decodedBackup.backup.items.first?.globalDone == true)
    #expect(oldRecovery.decodedBackup.backup.items.first?.archived == true)
    guard case .ready(let shareSession) = await share.bootstrap(),
      case .applied(let created, .complete(let nextCheckpoint)) = await share.execute(
        PlannerOperation(
          operationId: UUID(), session: shareSession,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Museum", links: [PlannerLinkInput(originalUrl: "https://example.com/menu")])))
      ).outcome,
      case .listedNamespaces(let updatedNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      case .selected(let newRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: nextCheckpoint))
    else {
      Issue.record("After main-app migration, Share must save owned links without losing V1 data.")
      return
    }
    #expect(nextCheckpoint == 4)
    #expect(updatedNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 7)
    #expect(newRecovery.decodedBackup.backup.items.count == 2)
    #expect(newRecovery.decodedBackup.backup.items.first { $0.id == item.id }?.globalDone == true)
    #expect(newRecovery.decodedBackup.backup.items.first { $0.id == item.id }?.archived == true)
    #expect(
      newRecovery.decodedBackup.backup.items.first { $0.id == created.generated.first?.id }?
        .content.links.first?.originalUrl == "https://example.com/menu")
  }

  @Test func mainAppMigratesV2BookmarksThenShareSavesScheduleWithoutChangingOldHistory()
    async throws
  {
    #if SWIFT_PACKAGE
      let fixtureBundle = Bundle.module
    #else
      let fixtureBundle = Bundle(for: NativeFixtureBundle.self)
    #endif
    let fixture = try #require(
      fixtureBundle.url(forResource: "SchemaV2", withExtension: nil, subdirectory: "Fixtures"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: fixture, to: directory)
    let manifest = try JSONDecoder().decode(
      LinkedManifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json"))
    )
    let share = Planner(configuration: configuration(directory, role: .shareExtension))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share must leave the real V2 store for the main app to migrate.")
      return
    }
    let planner = Planner(configuration: configuration(directory, role: .mainApplication))
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let source)) = await planner.read(
        session: session,
        request: .source(PlannerEntityReference(kind: .item, id: manifest.itemId)))
    else {
      Issue.record("The main app must migrate the real V2 store without losing Hotel.")
      return
    }
    let item = PlannerEntityReference(kind: .item, id: manifest.itemId)
    #expect(session.datasetId == manifest.datasetId)
    #expect(source.content.title == "Hotel")
    #expect(source.content.notes == "Original notes")
    #expect(source.state.globalDone == true)
    #expect(source.state.archived == true)
    #expect(source.references.count == 2)
    #expect(source.createdAt.timeIntervalSinceReferenceDate == manifest.createdAt)
    #expect(source.updatedAt.timeIntervalSinceReferenceDate == manifest.updatedAt)
    #expect(
      Dictionary(
        uniqueKeysWithValues:
          source.fieldHashes.map { ($0.key.rawValue, $0.value.value) }) == manifest.fieldHashes)
    let expectedLinks = [
      try #require(manifest.ownedLinks.first { $0.rank == "0" }),
      try #require(manifest.ownedLinks.first { $0.rank == "1" }),
    ]
    #expect(source.content.links.map(\.linkId) == expectedLinks.map(\.id))
    #expect(
      source.content.links.map(\.originalUrl) == [
        "https://maps.apple.com/?q=Hotel", "https://example.com/menu",
      ])
    #expect(source.content.links.map(\.label) == ["Map", "Menu"])
    let originalContent = PlannerItemContentInput(
      title: "Hotel", notes: "Original notes",
      location: PlannerOwnedLocation(
        displayName: "Meeting point", formattedAddress: "Meeting point A",
        coordinate: PlannerCoordinate(latitude: 35, longitude: 139)),
      estimate: PlannerEstimate(minutes: 120, displayUnit: .hour),
      links: [
        PlannerLinkInput(originalUrl: "https://maps.apple.com/?q=Hotel", label: "Map"),
        PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu"),
      ])
    #expect(source.content.location == originalContent.location)
    #expect(source.content.estimate == originalContent.estimate)
    guard
      case .applied(let replayed, .complete(let oldCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: manifest.creationOperationId, session: session,
          command: .createItem(content: originalContent))
      ).outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let oldRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 3)),
      case .ready(let shareSession) = await share.bootstrap()
    else {
      Issue.record("Migration must preserve old replay/checkpoint evidence and then permit Share.")
      return
    }
    #expect(replayed.generated == [item])
    #expect(oldCheckpoint == 1)
    #expect(namespace.acknowledgedSnapshot?.storageSchemaVersion == 2)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 3)
    #expect(oldRecovery.decodedBackup.backup.schedules.isEmpty)
    let oldItem = try #require(oldRecovery.decodedBackup.backup.items.first)
    #expect(oldItem.lifetimeId == manifest.ownedLinks.first?.owner.lifetimeId)
    let form = PlannerScheduleForm.timed(
      start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
      planningTimeZone: "Asia/Tokyo")
    guard
      case .applied(let scheduled, .complete(let nextCheckpoint)) = await share.execute(
        PlannerOperation(
          operationId: UUID(), session: shareSession,
          command: .createSchedule(source: item, form: form))
      ).outcome,
      let assignment = scheduled.generated.first,
      case .source(.item(let retained)) = await planner.read(
        session: session, request: .source(item)),
      case .listedNamespaces(let updatedNamespaces) = await planner.inspectRecovery(
        request: .namespaces),
      case .selected(let newRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 4)),
      case .selected(let retainedOldRecovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 3))
    else {
      Issue.record(
        "The migrated writer must save a new Schedule and retain both old and new recovery.")
      return
    }
    #expect(nextCheckpoint == 4)
    #expect(updatedNamespaces.first?.acknowledgedSnapshot?.storageSchemaVersion == 7)
    #expect(retained.content.links == source.content.links)
    #expect(retained.fieldHashes == source.fieldHashes)
    #expect(retained.updatedAt == source.updatedAt)
    #expect(retained.state.globalDone == true)
    #expect(retained.state.archived == true)
    #expect(retained.references == source.references + [.schedule(id: assignment.id, source: item)])
    #expect(newRecovery.decodedBackup.backup.schedules.first?.form == form)
    #expect(newRecovery.decodedBackup.backup.schedules.first?.id == assignment.id)
    #expect(
      newRecovery.decodedBackup.backup.schedules.first?.sourceLifetimeId == oldItem.lifetimeId)
    #expect(retainedOldRecovery.portableData == oldRecovery.portableData)
    let portable = try #require(
      JSONSerialization.jsonObject(with: newRecovery.portableData) as? [String: Any])
    let links = try #require(portable["ownedLinks"] as? [[String: Any]])
    #expect(links.count == 2)
    for expected in manifest.ownedLinks {
      let actual = try #require(links.first { $0["id"] as? String == expected.id.uuidString })
      let owner = try #require(actual["owner"] as? [String: Any])
      #expect(actual["lifetimeId"] as? String == expected.lifetimeId.uuidString)
      #expect(owner["lifetimeId"] as? String == expected.owner.lifetimeId.uuidString)
      #expect(actual["rank"] as? String == expected.rank)
    }
  }

  private struct LinkedManifest: Decodable {
    let datasetId: UUID
    let itemId: UUID
    let createdAt: Double
    let updatedAt: Double
    let fieldHashes: [String: String]
    let creationOperationId: UUID
    let ownedLinks: [Link]

    struct Link: Decodable {
      let id: UUID
      let lifetimeId: UUID
      let rank: String
      let owner: Owner
      struct Owner: Decodable { let lifetimeId: UUID }
    }
  }

  private func configuration(_ directory: URL, role: PlannerStorageConfiguration.ProcessRole)
    -> PlannerStorageConfiguration
  {
    PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: role, storageMode: .localOnly)
  }

  private struct CivilManifest: Decodable {
    let latestCheckpoint: Int64
    let retainedScheduleId: UUID
    let retainedScheduleHash: String
    let allDayScheduleId: UUID
    let allDayScheduleHash: String
  }

  private struct DeletionManifest: Decodable {
    let latestCheckpoint: Int64
    let scheduleId: UUID
    let scheduleOperationId: UUID
    let retainedScheduleId: UUID
    let retainedScheduleHash: String
  }

  private struct ScheduledManifest: Decodable {
    let latestCheckpoint: Int64
    let scheduleId: UUID
    let scheduleOperationId: UUID
    let scheduleHash: String
  }

  private struct Manifest: Decodable {
    let datasetId: UUID
    let itemId: UUID
    let createdAt: Double
    let updatedAt: Double
    let fieldHashes: [String: String]
    let creationOperationId: UUID
    let creationCheckpoint: Int64
    let latestCheckpoint: Int64
  }

  #if !SWIFT_PACKAGE
    private final class NativeFixtureBundle: NSObject {}
  #endif
}
