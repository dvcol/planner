import Foundation
import PlannerCore
import SwiftData
import Testing

struct OwnedAssociationUndoTests {
  @Test(arguments: [false, true])
  func committedGroupsRepairOnlyTheirRecoveryCheckpoint(restoring: Bool) async throws {
    let fixture = try await RemovalFixture()
    let command: PlannerCommand
    if restoring {
      command = .restoreAssociation(snapshot: fixture.snapshot)
    } else {
      _ = try await fixture.storage.save(.restoreAssociation(snapshot: fixture.snapshot))
      let current = try await fixture.readItem()
      command = .editItem(
        sourceId: fixture.storage.item.id,
        changes: .init(notes: .set("Committed notes"), links: .set([]), tagIds: .set([])),
        expectedFieldHashes: current.fieldHashes)
    }
    let operation = PlannerOperation(
      operationId: UUID(), session: fixture.storage.session, command: command)
    let obstruction = NativeSaveRecoveryObstruction(configuration: fixture.storage.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let response = await fixture.storage.planner.execute(operation)
    guard case .applied(let applied, .incomplete) = response.outcome else {
      Issue.record("A committed group must remain applied when independent recovery fails.")
      return
    }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    #expect((response.associationUndoSnapshot != nil) == !restoring)
    try obstruction.restore()
    let beforeRepair = try await fixture.storage.export()
    let blocked = await fixture.storage.planner.execute(
      .init(
        operationId: UUID(), session: fixture.storage.session,
        command: .createItem(content: .init(title: "Must remain blocked"))))
    guard case .rejected(let failure) = blocked.outcome else { throw CancellationError() }
    #expect(failure.code == "mutationBlocked")
    let repair = await fixture.storage.planner.retryRecovery(
      session: fixture.storage.session, operationId: operation.operationId)
    let replay = await fixture.storage.planner.execute(operation)
    guard case .applied(let repaired, .complete(let checkpoint)) = repair.outcome,
      case .applied(let replayed, .complete(let replayCheckpoint)) = replay.outcome
    else { throw CancellationError() }
    #expect(repaired == applied && replayed == applied)
    #expect(checkpoint == replayCheckpoint)
    #expect(try await fixture.storage.export() == beforeRepair)
    if !restoring {
      _ = try await fixture.storage.save(
        .restoreAssociation(snapshot: try #require(replay.associationUndoSnapshot)))
    }
    let restored = try await fixture.readItem()
    #expect(restored.content.links.map(\.linkId) == fixture.originalLinks.map(\.linkId))
    #expect(restored.content.tagIds == [fixture.tag.id])
  }

  @Test func groupIssuanceExpiresAcrossRunsAndDatasetsAndOldLineageCannotReplayAsNewUndo()
    async throws
  {
    let fixture = try await RemovalFixture()
    let other = try await AssociationUndoFixture()
    let otherBefore = try await other.export()
    let foreign = await other.planner.execute(
      .init(
        operationId: UUID(), session: other.session,
        command: .restoreAssociation(snapshot: fixture.snapshot)))
    guard case .rejected(let foreignFailure) = foreign.outcome else { throw CancellationError() }
    #expect(foreignFailure.code == "associationUndoUnavailable")
    #expect(try await other.export() == otherBefore)
    let replay = await fixture.storage.planner.execute(fixture.removalOperation)
    #expect(
      replay.associationUndoSnapshot?.closingOperationId == fixture.snapshot.closingOperationId)
    let reopened = Planner(configuration: fixture.storage.configuration)
    guard case .ready(let session) = await reopened.bootstrap() else { throw CancellationError() }
    let expired = await reopened.execute(
      .init(
        operationId: UUID(), session: session,
        command: .restoreAssociation(snapshot: fixture.snapshot)))
    guard case .rejected(let expiredFailure) = expired.outcome else { throw CancellationError() }
    #expect(expiredFailure.code == "associationUndoUnavailable")
    let removalReplay = await reopened.execute(
      .init(
        operationId: fixture.removalOperation.operationId, session: session,
        command: fixture.removalOperation.command))
    #expect(removalReplay.associationUndoSnapshot == nil)
    _ = try await fixture.storage.save(.restoreAssociation(snapshot: fixture.snapshot))
    let restored = try await fixture.readItem()
    let secondRemoval = await fixture.storage.planner.execute(
      .init(
        operationId: UUID(), session: fixture.storage.session,
        command: .editItem(
          sourceId: fixture.storage.item.id,
          changes: .init(links: .set([]), tagIds: .set([])),
          expectedFieldHashes: restored.fieldHashes)))
    let second = try #require(secondRemoval.associationUndoSnapshot)
    let before = try await fixture.storage.export()
    let superseded = await fixture.storage.planner.execute(
      .init(
        operationId: UUID(), session: fixture.storage.session,
        command: .restoreAssociation(snapshot: fixture.snapshot)))
    guard case .rejected(let supersededFailure) = superseded.outcome else {
      throw CancellationError()
    }
    #expect(supersededFailure.code == "associationUndoUnavailable")
    #expect(try await fixture.storage.export() == before)
    _ = try await fixture.storage.save(.restoreAssociation(snapshot: second))
    let final = try await fixture.readItem()
    #expect(final.content.links.map(\.linkId) == fixture.originalLinks.map(\.linkId))
    #expect(final.content.tagIds == [fixture.tag.id])
    guard
      case .decoded(let decoded) = fixture.storage.planner.decodeImport(
        try await fixture.storage.export())
    else { throw CancellationError() }
    #expect(decoded.backup.restorationFamilies.count == 8)
  }

  @Test(arguments: [
    "reordered anchors", "recreated label", "deleted label", "deleted owner",
    "restored label", "restored owner",
  ])
  func changedBindingsOrIncompatibleOrderRejectTheWholeRemovalGroup(change: String) async throws {
    let fixture = try await RemovalFixture()
    if change == "reordered anchors" || change == "recreated label" {
      let current = try await fixture.readItem()
      let changes: PlannerItemChanges
      if change == "reordered anchors" {
        changes = .init(
          notes: .set("Keep newer notes"),
          links: .set(
            current.content.links.reversed().map {
              .init(linkId: $0.linkId, originalUrl: $0.originalUrl)
            }))
      } else {
        changes = .init(notes: .set("Keep newer notes"), tagIds: .set([fixture.tag.id]))
      }
      _ = try await fixture.storage.save(
        .editItem(
          sourceId: fixture.storage.item.id, changes: changes,
          expectedFieldHashes: current.fieldHashes))
    } else {
      let source = change.hasSuffix("label") ? fixture.tag : fixture.storage.item
      guard
        case .decoded(let original) = fixture.storage.planner.decodeImport(
          try await fixture.storage.export())
      else { throw CancellationError() }
      let command = PlannerCommand.deleteSource(source: source)
      guard
        case .reviewed(let review) = await fixture.storage.planner.prepareReview(
          session: fixture.storage.session, command: command),
        case .applied(_, .complete) = await fixture.storage.planner.execute(
          .init(
            operationId: UUID(), session: fixture.storage.session, command: command,
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
      if change.hasPrefix("restored") {
        guard
          case .reviewed(let restoration) = await fixture.storage.planner.prepareReview(
            session: fixture.storage.session,
            command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true)),
          case .applied(_, .complete) = await fixture.storage.planner.execute(
            .init(
              operationId: UUID(), session: fixture.storage.session,
              command: restoration.command, reviewToken: restoration.reviewToken)
          ).outcome
        else { throw CancellationError() }
      }
    }
    let before = try await fixture.storage.export()
    let response = await fixture.storage.planner.execute(
      .init(
        operationId: UUID(), session: fixture.storage.session,
        command: .restoreAssociation(snapshot: fixture.snapshot)))
    guard case .rejected(let failure) = response.outcome else {
      Issue.record("An unsafe removal group must reject every restoration: \(response.outcome)")
      return
    }
    #expect(failure.code == "associationUndoUnavailable")
    #expect(try await fixture.storage.export() == before)
  }

  @Test func contentEditsAndIndependentAdditionsDoNotIssueRemovalHistory() async throws {
    let fixture = try await RemovalFixture()
    let current = try await fixture.readItem()
    let response = await fixture.storage.planner.execute(
      .init(
        operationId: UUID(), session: fixture.storage.session,
        command: .editItem(
          sourceId: fixture.storage.item.id,
          changes: .init(
            notes: .set("Independent notes"),
            links: .set(
              current.content.links.map {
                .init(linkId: $0.linkId, originalUrl: $0.originalUrl)
              } + [.init(originalUrl: "https://example.com/new")])),
          expectedFieldHashes: current.fieldHashes)))
    guard case .applied(_, .complete) = response.outcome else { throw CancellationError() }
    #expect(response.associationUndoSnapshot == nil)
    _ = try await fixture.storage.save(.restoreAssociation(snapshot: fixture.snapshot))
    let after = try await fixture.readItem()
    #expect(after.content.notes == "Independent notes")
    #expect(after.content.links.count == 5)
    #expect(after.content.links.last?.originalUrl == "https://example.com/new")
  }

  @Test(arguments: ["suffix", "no anchors", "missing anchor"])
  func restoredLinkRunsKeepIndependentAdditionsAndUseSurvivingAnchors(placement: String)
    async throws
  {
    let retained: Set<Int>
    switch placement {
    case "suffix": retained = [0, 1]
    case "no anchors": retained = []
    default: retained = [1, 3]
    }
    let fixture = try await RemovalFixture(retaining: retained)
    let beforeEdit = try await fixture.readItem()
    let original = fixture.originalLinks
    var inputs: [PlannerLinkInput] = []
    if placement == "suffix" {
      inputs = original.prefix(2).map {
        .init(linkId: $0.linkId, originalUrl: $0.originalUrl)
      }
    }
    inputs.append(.init(originalUrl: "https://example.com/x"))
    if placement == "no anchors" {
      inputs.append(.init(originalUrl: "https://example.com/y"))
    }
    if placement == "missing anchor" {
      inputs.append(.init(linkId: original[3].linkId, originalUrl: original[3].originalUrl))
    }
    _ = try await fixture.storage.save(
      .editItem(
        sourceId: fixture.storage.item.id, changes: .init(links: .set(inputs)),
        expectedFieldHashes: beforeEdit.fieldHashes))
    let beforeUndo = try await fixture.readItem()
    _ = try await fixture.storage.save(.restoreAssociation(snapshot: fixture.snapshot))
    let restored = try await fixture.readItem()
    let expected: [UUID]
    switch placement {
    case "suffix":
      expected = original.map(\.linkId) + [try #require(beforeUndo.content.links.last).linkId]
    case "no anchors":
      expected = beforeUndo.content.links.map(\.linkId) + original.map(\.linkId)
    default:
      expected = [
        try #require(beforeUndo.content.links.first).linkId,
        original[0].linkId, original[2].linkId, original[3].linkId,
      ]
    }
    #expect(restored.content.links.map(\.linkId) == expected)
    #expect(restored.content.tagIds == [fixture.tag.id])
  }

  @Test func labelOnlyUndoPreservesAnIndependentBookmarkReorder() async throws {
    let fixture = try await AssociationUndoFixture()
    let tagCreation = try await fixture.save(.createTag(content: .init(name: "Indoor")))
    let tag = try #require(tagCreation.generated.first)
    func readItem() async throws -> PlannerItemSourceRead {
      guard
        case .source(.item(let item)) = await fixture.planner.read(
          session: fixture.session, request: .source(fixture.item))
      else { throw CancellationError() }
      return item
    }
    let initial = try await readItem()
    _ = try await fixture.save(
      .editItem(
        sourceId: fixture.item.id,
        changes: .init(
          links: .set([
            .init(originalUrl: "https://example.com/a"),
            .init(originalUrl: "https://example.com/b"),
          ]), tagIds: .set([tag.id])), expectedFieldHashes: initial.fieldHashes))
    let tagged = try await readItem()
    let removal = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id, changes: .init(tagIds: .set([])),
          expectedFieldHashes: tagged.fieldHashes)))
    let snapshot = try #require(removal.associationUndoSnapshot)
    let untagged = try await readItem()
    _ = try await fixture.save(
      .editItem(
        sourceId: fixture.item.id,
        changes: .init(
          links: .set(
            untagged.content.links.reversed().map {
              .init(linkId: $0.linkId, originalUrl: $0.originalUrl, label: $0.label)
            })), expectedFieldHashes: untagged.fieldHashes))
    let beforeUndo = try await readItem()
    let restored = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .restoreAssociation(snapshot: snapshot)))
    guard case .applied(_, .complete) = restored.outcome else {
      Issue.record(
        "Restoring only a label must preserve the independent link order: \(restored.outcome)")
      return
    }
    let after = try await readItem()
    #expect(after.content.links == beforeUndo.content.links)
    #expect(after.content.tagIds == [tag.id])
  }

  @Test func itineraryGroupPreservesDuplicateLinksLiveLabelNamesCompletionAndItsBooking()
    async throws
  {
    let fixture = try await AssociationUndoFixture()
    let tagCreation = try await fixture.save(.createTag(content: .init(name: "Rainy day")))
    let tag = try #require(tagCreation.generated.first)
    let routeCreation = try await fixture.save(
      .createItinerary(
        content: .init(
          title: "Route", notes: "Original route notes",
          links: [
            .init(originalUrl: "https://example.com/guide", label: "First guide"),
            .init(originalUrl: "https://example.com/guide", label: "Second guide"),
          ], tagIds: [tag.id])))
    let route = try #require(routeCreation.generated.first)
    let addition = try await fixture.save(
      .addItineraryEntry(itineraryId: route.id, source: fixture.item, placement: .last))
    guard case .itineraryEntry(let entry, _, _)? = addition.generatedReferences.first else {
      throw CancellationError()
    }
    let appearance = PlannerAppearance.directItineraryItem(itineraryId: route.id, entryId: entry)
    _ = try await fixture.save(.setCompletion(scope: .appearance(appearance), done: true))
    let form = PlannerScheduleForm.timed(
      start: Date(timeIntervalSince1970: 1_000), end: Date(timeIntervalSince1970: 2_000),
      planningTimeZone: "UTC")
    let booking = try await fixture.save(.createSchedule(source: route, form: form))
    let schedule = try #require(booking.generated.first)
    guard
      case .source(.itinerary(let before)) = await fixture.planner.read(
        session: fixture.session, request: .source(route))
    else { throw CancellationError() }
    let removed = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .editItinerary(
          sourceId: route.id,
          changes: .init(
            notes: .set("Updated route notes"), links: .set([]), tagIds: .set([])),
          expectedFieldHashes: before.fieldHashes)))
    guard case .applied(_, .complete) = removed.outcome else { throw CancellationError() }
    let snapshot = try #require(removed.associationUndoSnapshot)
    guard
      case .source(.tag(let tagBefore)) = await fixture.planner.read(
        session: fixture.session, request: .source(tag))
    else { throw CancellationError() }
    _ = try await fixture.save(
      .editTag(
        sourceId: tag.id, changes: .init(name: .set("Renamed shared tag")),
        expectedFieldHashes: tagBefore.fieldHashes))
    _ = try await fixture.save(.restoreAssociation(snapshot: snapshot))
    guard
      case .source(.itinerary(let after)) = await fixture.planner.read(
        session: fixture.session, request: .source(route)),
      case .source(.schedule(let retainedBooking)) = await fixture.planner.read(
        session: fixture.session, request: .source(schedule)),
      case .appearance(let retainedEntry) = await fixture.planner.read(
        session: fixture.session, request: .appearance(appearance))
    else { throw CancellationError() }
    #expect(after.content.notes == "Updated route notes")
    #expect(after.content.links.map(\.linkId) == before.content.links.map(\.linkId))
    #expect(Set(after.content.links.map(\.linkId)).count == 2)
    #expect(
      after.content.links.map(\.originalUrl)
        == Array(repeating: "https://example.com/guide", count: 2))
    #expect(after.labels.first?.name == "Renamed shared tag")
    #expect(retainedBooking.content.form == form)
    #expect(retainedEntry.localDone && !retainedEntry.globalDone)
  }

  @Test func oneSaveRestoresItsRemovedLinksAndTagTogetherWithoutOverwritingLaterEdits()
    async throws
  {
    let fixture = try await AssociationUndoFixture()
    let tagCreation = try await fixture.save(.createTag(content: .init(name: "Rainy day")))
    let tag = try #require(tagCreation.generated.first)
    func readItem() async throws -> PlannerItemSourceRead {
      guard
        case .source(.item(let item)) = await fixture.planner.read(
          session: fixture.session, request: .source(fixture.item))
      else { throw CancellationError() }
      return item
    }
    let initial = try await readItem()
    _ = try await fixture.save(
      .editItem(
        sourceId: fixture.item.id,
        changes: .init(
          links: .set(
            ["a", "b", "c", "d"].map { .init(originalUrl: "https://example.com/\($0)") }),
          tagIds: .set([tag.id])), expectedFieldHashes: initial.fieldHashes))
    let beforeRemoval = try await readItem()
    let originalLinks = beforeRemoval.content.links
    #expect(originalLinks.count == 4)
    guard case .decoded(let originalData) = fixture.planner.decodeImport(try await fixture.export())
    else { throw CancellationError() }
    let originalTagAssociation = try #require(
      originalData.backup.labelAssociations.first {
        $0.owner == fixture.item && $0.label == tag
      })
    let removalIdentifier = UUID()
    let removal = await fixture.planner.execute(
      .init(
        operationId: removalIdentifier, session: fixture.session,
        command: .editItem(
          sourceId: fixture.item.id,
          changes: .init(
            notes: .set("Notes saved with removal"),
            links: .set(
              [originalLinks[1], originalLinks[3]].map {
                .init(linkId: $0.linkId, originalUrl: $0.originalUrl, label: $0.label)
              }), tagIds: .set([])),
          expectedFieldHashes: beforeRemoval.fieldHashes)))
    guard case .applied(_, .complete) = removal.outcome else { throw CancellationError() }
    let snapshot = try #require(removal.associationUndoSnapshot)
    let afterRemoval = try await readItem()
    _ = try await fixture.save(
      .editItem(
        sourceId: fixture.item.id,
        changes: .init(
          notes: .set("Later notes"),
          links: .set([
            .init(originalUrl: "https://example.com/x"),
            .init(
              linkId: originalLinks[1].linkId, originalUrl: originalLinks[1].originalUrl,
              label: "Updated retained bookmark"),
            .init(linkId: originalLinks[3].linkId, originalUrl: originalLinks[3].originalUrl),
          ])), expectedFieldHashes: afterRemoval.fieldHashes))
    let beforeUndo = try await readItem()
    let addedLink = try #require(beforeUndo.content.links.first)
    let operation = PlannerOperation(
      operationId: UUID(), session: fixture.session,
      command: .restoreAssociation(snapshot: snapshot))
    let restored = await fixture.planner.execute(operation)
    guard case .applied(let result, .complete) = restored.outcome else {
      throw CancellationError()
    }
    let item = try await readItem()
    #expect(item.content.notes == "Later notes")
    #expect(
      item.content.links.map(\.linkId)
        == [
          addedLink.linkId, originalLinks[0].linkId, originalLinks[1].linkId,
          originalLinks[2].linkId, originalLinks[3].linkId,
        ])
    #expect(item.content.links[2].label == "Updated retained bookmark")
    #expect(item.content.tagIds == [tag.id])
    guard case .decoded(let saved) = fixture.planner.decodeImport(try await fixture.export()) else {
      throw CancellationError()
    }
    let restoredTag = try #require(
      saved.backup.labelAssociations.first { $0.id == originalTagAssociation.id })
    #expect(restoredTag.lifetimeId != originalTagAssociation.lifetimeId)
    for removedIndex in [0, 2] {
      let original = try #require(
        originalData.backup.ownedLinks.first { $0.id == originalLinks[removedIndex].linkId })
      let restoredLink = try #require(saved.backup.ownedLinks.first { $0.id == original.id })
      #expect(restoredLink.lifetimeId != original.lifetimeId)
      #expect(restoredLink.originalUrl == original.originalUrl)
    }
    let beforeReplay = try await fixture.export()
    let replay = await fixture.planner.execute(operation)
    guard case .applied(let replayed, .complete) = replay.outcome else {
      throw CancellationError()
    }
    #expect(replayed == result)
    #expect(try await fixture.export() == beforeReplay)
  }

  private struct RemovalFixture {
    let storage: AssociationUndoFixture
    let tag: PlannerEntityReference
    let originalLinks: [PlannerOwnedLinkRead]
    let snapshot: PlannerAssociationUndoSnapshot
    let removalOperation: PlannerOperation

    init(retaining retained: Set<Int> = [1, 3]) async throws {
      let storage = try await AssociationUndoFixture()
      self.storage = storage
      let created = try await storage.save(.createTag(content: .init(name: "Indoor")))
      let tag = try #require(created.generated.first)
      self.tag = tag
      guard
        case .source(.item(let initial)) = await storage.planner.read(
          session: storage.session, request: .source(storage.item))
      else { throw CancellationError() }
      _ = try await storage.save(
        .editItem(
          sourceId: storage.item.id,
          changes: .init(
            links: .set(
              ["a", "b", "c", "d"].map { .init(originalUrl: "https://example.com/\($0)") }),
            tagIds: .set([tag.id])), expectedFieldHashes: initial.fieldHashes))
      guard
        case .source(.item(let before)) = await storage.planner.read(
          session: storage.session, request: .source(storage.item))
      else { throw CancellationError() }
      originalLinks = before.content.links
      let removalOperation = PlannerOperation(
        operationId: UUID(), session: storage.session,
        command: .editItem(
          sourceId: storage.item.id,
          changes: .init(
            notes: .set("Notes saved with removal"),
            links: .set(
              before.content.links.enumerated().filter { retained.contains($0.offset) }.map {
                .init(linkId: $0.element.linkId, originalUrl: $0.element.originalUrl)
              }), tagIds: .set([])), expectedFieldHashes: before.fieldHashes))
      self.removalOperation = removalOperation
      let response = await storage.planner.execute(removalOperation)
      guard case .applied(_, .complete) = response.outcome else { throw CancellationError() }
      snapshot = try #require(response.associationUndoSnapshot)
    }

    func readItem() async throws -> PlannerItemSourceRead {
      guard
        case .source(.item(let item)) = await storage.planner.read(
          session: storage.session, request: .source(storage.item))
      else { throw CancellationError() }
      return item
    }
  }
}
