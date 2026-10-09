import Foundation
import PlannerCore
import Testing

struct ItemLinkEditTests {
  @Test func staleOrForeignLinkReplacementRejectsTogetherAndOldReplayCannotRestoreRemovedLinks()
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
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Original notes",
              links: [PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu")])))
      )
      .outcome, let item = created.generated.first,
      case .source(let original) = await planner.read(session: session, request: .source(item)),
      case .applied(let otherCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Museum",
              links: [PlannerLinkInput(originalUrl: "https://example.com/museum", label: nil)])))
      )
      .outcome, let otherItem = otherCreated.generated.first,
      case .source(let otherOriginal) = await planner.read(
        session: session, request: .source(otherItem))
    else {
      Issue.record("Two Items must own separate saved link identities.")
      return
    }
    let originalIdentifier = try #require(original.content.links.first?.linkId)
    let foreignIdentifier = try #require(otherOriginal.content.links.first?.linkId)
    let replacement = [
      PlannerLinkInput(
        linkId: originalIdentifier, originalUrl: "https://example.com/dinner", label: "Dinner"),
      PlannerLinkInput(originalUrl: "https://example.com/gallery", label: nil),
    ]
    let editIdentifier = UUID()
    let editCommand = PlannerCommand.editItem(
      sourceId: item.id, changes: PlannerItemChanges(links: .set(replacement)),
      expectedFieldHashes: original.fieldHashes)
    guard
      case .applied(let applied, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(operationId: editIdentifier, session: session, command: editCommand)
      )
      .outcome,
      case .source(let current) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The intervening replacement must actually save.")
      return
    }
    #expect(checkpoint == 3)
    let stale = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id,
          changes: PlannerItemChanges(title: .set("Rejected title"), links: .set(replacement)),
          expectedFieldHashes: original.fieldHashes)))
    guard case .rejected(let reason) = stale.outcome,
      case .staleEdit(let fields, let values, let hashes) = reason.details
    else {
      Issue.record("A stale links guard must reject the complete title/links edit.")
      return
    }
    #expect(reason.code == "staleEdit")
    #expect(fields == [.links])
    #expect(values == [.links: .links(current.content.links)])
    #expect(hashes == [.links: try #require(current.fieldHashes[.links])])
    let invalid: [(change: PlannerFieldChange<[PlannerLinkInput]>, path: String)] = [
      (.clear, "/command/changes/links"),
      (
        .set([
          PlannerLinkInput(linkId: foreignIdentifier, originalUrl: "https://example.com/museum")
        ]),
        "/command/changes/links/0/linkId"
      ),
      (
        .set([replacement[0], replacement[0]]), "/command/changes/links/1/linkId"
      ),
      (
        .set([replacement[0], PlannerLinkInput(originalUrl: "file:///private/tmp/menu")]),
        "/command/changes/links/1/originalUrl"
      ),
    ]
    for expected in invalid {
      let rejectedIdentifier = UUID()
      guard
        case .rejected(let rejected) = await planner.execute(
          PlannerOperation(
            operationId: rejectedIdentifier, session: session,
            command: .editItem(
              sourceId: item.id,
              changes: PlannerItemChanges(notes: .set("Rejected notes"), links: expected.change),
              expectedFieldHashes: current.fieldHashes))
        )
        .outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: rejectedIdentifier)
      else {
        Issue.record("Invalid replacements must not save partial content or an applied receipt.")
        return
      }
      #expect(rejected.code == "invalidInput")
      #expect(rejected.propertyPath == expected.path)
    }
    let missingHash = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(links: .set([])), expectedFieldHashes: [:])
      ))
    guard case .rejected(let missingReason) = missingHash.outcome,
      case .source(let unchanged) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("Even empty replacements must require their previous field hash.")
      return
    }
    #expect(missingReason.code == "invalidInput")
    #expect(missingReason.propertyPath == "/command/expectedFieldHashes/links")
    #expect(unchanged.content.title == "Hotel")
    #expect(unchanged.content.notes == "Original notes")
    #expect(unchanged.content.links == current.content.links)
    #expect(unchanged.updatedAt == current.updatedAt)
    #expect(unchanged.fieldHashes == current.fieldHashes)
    guard
      case .applied(_, .complete(let emptyCheckpoint)) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: item.id, changes: PlannerItemChanges(links: .set([])),
            expectedFieldHashes: current.fieldHashes))
      )
      .outcome,
      case .source(let emptied) = await planner.read(session: session, request: .source(item)),
      case .applied(let replayed, .complete(let replayedCheckpoint)) = await planner.execute(
        PlannerOperation(operationId: editIdentifier, session: session, command: editCommand)
      )
      .outcome,
      case .source(let retained) = await planner.read(session: session, request: .source(item)),
      case .source(let otherRetained) = await planner.read(
        session: session, request: .source(otherItem)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let selection) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 4))
    else {
      Issue.record(
        "Empty replacement and replay must retain current data and independent recovery.")
      return
    }
    #expect(emptyCheckpoint == 4)
    #expect(replayed == applied)
    #expect(replayedCheckpoint == 3)
    #expect(retained.content.links.isEmpty)
    #expect(retained.updatedAt == emptied.updatedAt)
    #expect(retained.fieldHashes == emptied.fieldHashes)
    #expect(otherRetained.content.links == otherOriginal.content.links)
    #expect(otherRetained.updatedAt == otherOriginal.updatedAt)
    #expect(otherRetained.fieldHashes == otherOriginal.fieldHashes)
    let portable = try #require(
      JSONSerialization.jsonObject(with: selection.portableData) as? [String: Any])
    let recoveredLinks = try #require(portable["ownedLinks"] as? [[String: Any]])
    #expect(recoveredLinks.count == 1)
    #expect(recoveredLinks.first?["id"] as? String == foreignIdentifier.uuidString)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 4)
    #expect(namespace.preparedProposals.isEmpty)
    let changedReplay = await planner.execute(
      PlannerOperation(
        operationId: editIdentifier, session: session,
        command: .editItem(
          sourceId: item.id, changes: PlannerItemChanges(links: .set([])),
          expectedFieldHashes: original.fieldHashes)))
    guard case .rejected(let changedReason) = changedReplay.outcome else {
      Issue.record("A modified replacement cannot reuse an applied operation identity.")
      return
    }
    #expect(changedReason.code == "operationPayloadMismatch")
  }

  @Test func ownedLinkReplacementPreservesRetainedIdentitiesAndSurvivesReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let location = PlannerOwnedLocation(
      displayName: nil, formattedAddress: "Meeting point A", coordinate: nil)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Original notes", location: location,
              estimate: PlannerEstimate(minutes: 120, displayUnit: .hour),
              links: [
                PlannerLinkInput(originalUrl: "https://maps.apple.com/?q=Hotel", label: "Map"),
                PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu"),
                PlannerLinkInput(originalUrl: "https://booking.com/hotel", label: "Reservation"),
              ])))
      )
      .outcome, let item = created.generated.first,
      case .source(let original) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("Hotel must have three independently saved owned links.")
      return
    }
    let originalLinks = original.content.links
    try #require(originalLinks.count == 3)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: item.id, changes: PlannerItemChanges(notes: .set("Friday booking")),
            expectedFieldHashes: original.fieldHashes))
      )
      .outcome,
      case .source(let before) = await planner.read(session: session, request: .source(item)),
      case .snapshot(let oldSnapshot) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery())))
    else {
      Issue.record("An unrelated saved notes edit must retain the earlier link guard.")
      return
    }
    let editIdentifier = UUID()
    let replacement = [
      PlannerLinkInput(
        linkId: originalLinks[2].linkId, originalUrl: "https://booking.com/hotel", label: nil),
      PlannerLinkInput(
        linkId: originalLinks[1].linkId, originalUrl: "https://tabelog.com/menu", label: "Dinner"),
      PlannerLinkInput(originalUrl: "https://example.com/gallery", label: "Gallery"),
    ]
    let operation = PlannerOperation(
      operationId: editIdentifier, session: session,
      command: .editItem(
        sourceId: item.id, changes: PlannerItemChanges(links: .set(replacement)),
        expectedFieldHashes: original.fieldHashes))
    guard
      case .applied(let edited, .complete(let checkpoint)) = await planner.execute(operation)
        .outcome,
      case .source(let current) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("A complete guarded replacement must save after an unrelated edit.")
      return
    }
    #expect(checkpoint == 3)
    #expect(edited.affected == [item])
    #expect(
      current.content.links.map(\.originalUrl) == [
        "https://booking.com/hotel", "https://tabelog.com/menu", "https://example.com/gallery",
      ])
    #expect(current.content.links.map(\.label) == [nil, "Dinner", "Gallery"])
    #expect(current.content.links.map(\.kind) == [.booking, .tabelog, .website])
    let currentIdentifiers = current.content.links.map(\.linkId)
    try #require(currentIdentifiers.count == 3)
    #expect(
      Array(currentIdentifiers.prefix(2)) == [originalLinks[2].linkId, originalLinks[1].linkId])
    #expect(!originalLinks.map(\.linkId).contains(currentIdentifiers[2]))
    #expect(Set(currentIdentifiers).count == 3)
    #expect(current.content.title == "Hotel")
    #expect(current.content.notes == "Friday booking")
    #expect(current.content.location == location)
    #expect(current.content.estimate?.minutes == 120)
    #expect(current.state.globalDone == false)
    #expect(current.state.archived == false)
    #expect(current.createdAt == before.createdAt)
    #expect(current.fieldHashes[.title] == before.fieldHashes[.title])
    #expect(current.fieldHashes[.notes] == before.fieldHashes[.notes])
    #expect(current.fieldHashes[.location] == before.fieldHashes[.location])
    #expect(current.fieldHashes[.estimate] == before.fieldHashes[.estimate])
    #expect(current.fieldHashes[.links] != before.fieldHashes[.links])
    guard
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: oldSnapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record("A replacement must invalidate the previous row generation.")
      return
    }
    #expect(stale.code == "staleSnapshot")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(let retained) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .snapshot(let fresh) = await reopened.query(
        PlannerQuery(session: reopenedSession, request: .items(PlannerItemQuery()))),
      case .rows(let window) = await reopened.read(
        session: reopenedSession, request: .rows(generation: fresh.generation, offset: 0, limit: 1)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let selection) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 3)),
      case .selected(let originalSelection) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 1))
    else {
      Issue.record("Reopen, rows and independent recovery must retain the replacement.")
      return
    }
    #expect(retained.content.links.map(\.linkId) == currentIdentifiers)
    #expect(retained.content.links.map(\.originalUrl) == current.content.links.map(\.originalUrl))
    #expect(retained.fieldHashes == current.fieldHashes)
    #expect(retained.updatedAt == current.updatedAt)
    #expect(window.rows.first?.previewLink?.linkId == originalLinks[2].linkId)
    #expect(window.rows.first?.hasLinks == true)
    let backup = try #require(
      JSONSerialization.jsonObject(with: selection.portableData) as? [String: Any])
    let recoveredLinks = try #require(backup["ownedLinks"] as? [[String: Any]])
    #expect(
      Set(recoveredLinks.compactMap { $0["id"] as? String })
        == Set(currentIdentifiers.map(\.uuidString)))
    let originalBackup = try #require(
      JSONSerialization.jsonObject(with: originalSelection.portableData) as? [String: Any])
    let originalRecoveredLinks = try #require(originalBackup["ownedLinks"] as? [[String: Any]])
    for identifier in currentIdentifiers.prefix(2) {
      let originalLifetime = try #require(
        originalRecoveredLinks.first { $0["id"] as? String == identifier.uuidString }?["lifetimeId"]
          as? String)
      #expect(
        recoveredLinks.first { $0["id"] as? String == identifier.uuidString }?["lifetimeId"]
          as? String
          == originalLifetime)
    }
    #expect(!recoveredLinks.contains { $0["id"] as? String == originalLinks[0].linkId.uuidString })
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 3)
    #expect(namespace.preparedProposals.isEmpty)
  }
}
