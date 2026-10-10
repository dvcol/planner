import Foundation
import PlannerCore
import Testing

struct ItineraryEditTests {
  @Test func guardedItineraryEditsRetainLiveOwnedDataAcrossWritersReplayAndRecovery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Open the native dataset before editing Itinerary content.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      let outcome = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
      guard case .applied(let result, .complete) = outcome, let source = result.generated.first
      else {
        Issue.record("Create the source with complete recovery: \(outcome)")
        throw MissingResult()
      }
      return source
    }
    func read() async throws -> PlannerItinerarySourceRead {
      guard
        case .source(.itinerary(let value)) = await planner.read(
          session: session, request: .source(itinerary))
      else {
        Issue.record("Read the exact saved Itinerary.")
        throw MissingResult()
      }
      return value
    }
    let food = try await create(.createCategory(content: .init(name: "Food")))
    let rain = try await create(.createTag(content: .init(name: "Rain")))
    let itinerary = try await create(
      .createItinerary(
        content: .init(
          title: "Tokyo", notes: "Keep", color: .init(red: 0, green: 0, blue: 1, alpha: 1),
          iconName: "map",
          location: .init(displayName: "Hotel", formattedAddress: "Tokyo", coordinate: nil),
          links: [.init(originalUrl: "https://example.com/route", label: "Route")],
          categoryIds: [food.id], tagIds: [rain.id])))
    let item = try await create(
      .createItem(
        content: .init(
          title: "Shared source", links: [.init(originalUrl: "https://example.com/item")],
          categoryIds: [food.id])))
    let original = try await read()
    guard
      case .source(.item(let originalItem)) = await planner.read(
        session: session, request: .source(item))
    else {
      Issue.record("Retain the independent Item baseline.")
      return
    }
    let originalLink = try #require(original.content.links.first)
    let originalFoodAssociation = try #require(
      original.references.first {
        guard case .labelAssociation(_, _, let label) = $0 else { return false }
        return label == food
      })
    let otherWriter = Planner(configuration: configuration)
    guard case .ready(let otherSession) = await otherWriter.bootstrap() else {
      Issue.record("Open the actual second writer.")
      return
    }
    let titleOutcome = await otherWriter.execute(
      .init(
        operationId: UUID(), session: otherSession,
        command: .editItinerary(
          sourceId: itinerary.id, changes: .init(title: .set("  Tokyo café weekend  ")),
          expectedFieldHashes: original.fieldHashes))
    ).outcome
    guard case .applied(_, .complete) = titleOutcome else {
      Issue.record("A guarded Itinerary title edit must save: \(titleOutcome)")
      return
    }
    let editedTitle = try await read()
    let location = PlannerOwnedLocation(
      displayName: "Museum", formattedAddress: "Tokyo, Japan",
      coordinate: .init(latitude: 35, longitude: 139))
    let color = PlannerColor(red: 0.25, green: 0.5, blue: 1, alpha: 1)
    let operationIdentifier = UUID()
    let command = PlannerCommand.editItinerary(
      sourceId: itinerary.id,
      changes: .init(
        notes: .set("Friday booking"), color: .set(color), iconName: .set("tram"),
        location: .set(location),
        links: .set([
          .init(
            linkId: originalLink.linkId, originalUrl: "https://example.com/route?day=1",
            label: "Friday"),
          .init(originalUrl: "https://example.com/museum"),
        ]), categoryIds: .set([]), tagIds: .set([])),
      expectedFieldHashes: original.fieldHashes)
    let outcome = await planner.execute(
      .init(operationId: operationIdentifier, session: session, command: command)
    ).outcome
    guard case .applied(let editedResult, .complete(let editedCheckpoint)) = outcome else {
      Issue.record("Unchanged fields must not guard a complete independent patch: \(outcome)")
      return
    }
    let edited = try await read()
    #expect(editedCheckpoint == 6)
    #expect(edited.content.title == "  Tokyo café weekend  ")
    #expect(edited.content.notes == "Friday booking")
    #expect(edited.content.color == color)
    #expect(edited.content.iconName == "tram")
    #expect(edited.content.location == location)
    #expect(
      edited.content.links.map(\.originalUrl) == [
        "https://example.com/route?day=1", "https://example.com/museum",
      ])
    #expect(edited.content.links.first?.linkId == originalLink.linkId)
    #expect(edited.content.categoryIds.isEmpty && edited.content.tagIds.isEmpty)
    #expect(edited.labels.isEmpty && edited.references.isEmpty)
    #expect(edited.fieldHashes[.title] == editedTitle.fieldHashes[.title])
    #expect(edited.createdAt == original.createdAt)
    #expect(edited.updatedAt > editedTitle.updatedAt)
    #expect(edited.state.globalDone == nil && edited.state.archived == false)
    #expect(edited.progress.state == .empty)
    let staleIdentifier = UUID()
    let staleOutcome = await planner.execute(
      .init(
        operationId: staleIdentifier, session: session,
        command: .editItinerary(
          sourceId: itinerary.id, changes: .init(title: .set("Must not save"), notes: .clear),
          expectedFieldHashes: original.fieldHashes))
    ).outcome
    guard case .rejected(let stale) = staleOutcome,
      case .staleItineraryEdit(let fields, let values, let hashes) = stale.details,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: staleIdentifier)
    else {
      Issue.record(
        "A stale compound patch rejects atomically without an applied receipt: \(staleOutcome)")
      return
    }
    #expect(stale.code == "staleEdit")
    #expect(fields == [.notes, .title])
    #expect(
      values == [
        .notes: .optionalString("Friday booking"), .title: .string("  Tokyo café weekend  "),
      ])
    #expect(
      hashes == [
        .notes: try #require(edited.fieldHashes[.notes]),
        .title: try #require(edited.fieldHashes[.title]),
      ])
    let retained = try await read()
    #expect(retained.content == edited.content)
    #expect(retained.fieldHashes == edited.fieldHashes)
    #expect(retained.updatedAt == edited.updatedAt)
    let clearOutcome = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editItinerary(
          sourceId: itinerary.id,
          changes: .init(
            notes: .clear, color: .clear, iconName: .clear,
            location: .clear, links: .set([])), expectedFieldHashes: edited.fieldHashes))
    ).outcome
    guard case .applied(_, .complete) = clearOutcome else {
      Issue.record("Optional content clears and an empty link array must save: \(clearOutcome)")
      return
    }
    let cleared = try await read()
    #expect(
      cleared.content.notes == nil && cleared.content.color == nil
        && cleared.content.iconName == nil)
    #expect(cleared.content.location == nil && cleared.content.links.isEmpty)
    #expect(cleared.fieldHashes[.title] == edited.fieldHashes[.title])
    let readdedOutcome = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editItinerary(
          sourceId: itinerary.id,
          changes: .init(
            links: .set([.init(originalUrl: "https://example.com/route")]),
            categoryIds: .set([food.id])),
          expectedFieldHashes: cleared.fieldHashes))
    ).outcome
    guard case .applied(_, .complete(let finalCheckpoint)) = readdedOutcome else {
      Issue.record("Ordinary re-add must create new owned references: \(readdedOutcome)")
      return
    }
    let readded = try await read()
    #expect(finalCheckpoint == 8)
    #expect(readded.content.links.first?.linkId != originalLink.linkId)
    #expect(readded.content.categoryIds == [food.id])
    #expect(readded.labels.map(\.name) == ["Food"])
    #expect(!readded.references.contains(originalFoodAssociation))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayedResult, .complete(let replayedCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .source(.itinerary(let reopenedRead)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary)),
      case .source(.item(let retainedItem)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: finalCheckpoint)),
      let portableItinerary = recovery.decodedBackup.backup.sources.compactMap({
        source -> PlannerPortableItinerary? in
        if case .itinerary(let value) = source { return value }
        return nil
      }).first
    else {
      Issue.record("Reopen/replay must retain later edits and complete independent recovery.")
      return
    }
    #expect(replayedResult == editedResult && replayedCheckpoint == editedCheckpoint)
    #expect(reopenedRead.content == readded.content)
    #expect(reopenedRead.fieldHashes == readded.fieldHashes)
    #expect(reopenedRead.references == readded.references)
    #expect(retainedItem.content.title == originalItem.content.title)
    #expect(retainedItem.content.links == originalItem.content.links)
    #expect(retainedItem.content.categoryIds == originalItem.content.categoryIds)
    #expect(
      retainedItem.updatedAt == originalItem.updatedAt
        && retainedItem.fieldHashes == originalItem.fieldHashes)
    #expect(portableItinerary.content == readded.content)
    #expect(portableItinerary.id == itinerary.id)
    #expect(retainedItem.content.links.count + portableItinerary.content.links.count == 2)
    #expect(recovery.decodedBackup.backup.labelAssociations.count == 2)
    let graph = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    #expect((graph["deletionMarkers"] as? [[String: Any]])?.count == 2)
    #expect(namespace.preparedProposals.isEmpty)
  }
  private struct MissingResult: Error {}
}
