import Foundation
import PlannerCore
import Testing

struct ItineraryEditAdmissionTests {
  @Test func invalidItineraryPatchesLeaveSourceReferencesAndRecoveryUnchanged() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Open the native admission dataset.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      let outcome = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
      guard case .applied(let result, .complete) = outcome, let source = result.generated.first
      else {
        Issue.record("Create each source before invalid edit admission.")
        throw MissingResult()
      }
      return source
    }
    let category = try await create(.createCategory(content: .init(name: "Food")))
    let tag = try await create(.createTag(content: .init(name: "Rain")))
    let item = try await create(
      .createItem(
        content: .init(
          title: "Other owner", links: [.init(originalUrl: "https://example.com/item")])))
    let itinerary = try await create(
      .createItinerary(
        content: .init(
          title: "Saved Tokyo", notes: "Keep",
          links: [.init(originalUrl: "https://example.com/route")], categoryIds: [category.id],
          tagIds: [tag.id])))
    guard
      case .source(.itinerary(let original)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.item(let other)) = await planner.read(session: session, request: .source(item)),
      let ownedLink = original.content.links.first, let foreignLink = other.content.links.first
    else {
      Issue.record("Read exact owner/link identities before invalid edits.")
      return
    }
    let invalidChanges: [(PlannerItineraryChanges, String, String)] = [
      (.init(), "invalidInput", "/command/changes"),
      (.init(title: .clear), "invalidInput", "/command/changes/title"),
      (.init(title: .set(" \n ")), "invalidInput", "/command/changes/title"),
      (
        .init(color: .set(.init(red: .nan, green: 0, blue: 0, alpha: 1))), "invalidInput",
        "/command/changes/color/red"
      ),
      (
        .init(color: .set(.init(red: 0, green: 0, blue: 0, alpha: 2))), "invalidInput",
        "/command/changes/color/alpha"
      ),
      (
        .init(
          location: .set(
            .init(
              displayName: nil, formattedAddress: nil, coordinate: .init(latitude: 91, longitude: 0)
            ))), "invalidInput", "/command/changes/location/coordinate"
      ),
      (
        .init(
          location: .set(
            .init(
              displayName: nil, formattedAddress: nil,
              coordinate: .init(latitude: 0, longitude: .infinity)))), "invalidInput",
        "/command/changes/location/coordinate"
      ),
      (.init(links: .clear), "invalidInput", "/command/changes/links"),
      (.init(categoryIds: .clear), "invalidInput", "/command/changes/categoryIds"),
      (.init(tagIds: .clear), "invalidInput", "/command/changes/tagIds"),
      (
        .init(links: .set([.init(originalUrl: "file:///private/tmp/route")])), "invalidInput",
        "/command/changes/links/0/originalUrl"
      ),
      (
        .init(
          links: .set([
            .init(linkId: ownedLink.linkId, originalUrl: "https://example.com/route"),
            .init(linkId: ownedLink.linkId, originalUrl: "https://example.com/route"),
          ])), "invalidInput", "/command/changes/links/1/linkId"
      ),
      (
        .init(
          links: .set([.init(linkId: foreignLink.linkId, originalUrl: "https://example.com/item")])),
        "invalidInput", "/command/changes/links/0/linkId"
      ),
      (
        .init(links: .set([.init(linkId: UUID(), originalUrl: "https://example.com/route")])),
        "invalidInput", "/command/changes/links/0/linkId"
      ),
      (
        .init(notes: .set("Must not save"), categoryIds: .set([UUID()])), "missingReference",
        "/command/changes/categoryIds"
      ),
      (.init(categoryIds: .set([tag.id])), "missingReference", "/command/changes/categoryIds"),
      (.init(tagIds: .set([category.id])), "missingReference", "/command/changes/tagIds"),
    ]
    for (changes, code, path) in invalidChanges {
      let operationIdentifier = UUID()
      let outcome = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session,
          command: .editItinerary(
            sourceId: itinerary.id, changes: changes, expectedFieldHashes: original.fieldHashes))
      ).outcome
      guard case .rejected(let reason) = outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier)
      else {
        Issue.record("An invalid edit must reject without a receipt: \(outcome)")
        return
      }
      #expect(reason.code == code)
      #expect(reason.propertyPath == path)
    }
    let badGuards: [([PlannerItineraryField: PlannerFieldHash], String)] = [
      ([:], "/command/expectedFieldHashes/notes"),
      ([.notes: .init(value: "sha256-v1:short")], "/command/expectedFieldHashes/notes"),
      (
        [.notes: .init(value: "sha256-v2:" + String(repeating: "a", count: 64))],
        "/command/expectedFieldHashes/notes"
      ),
      (
        [.notes: try #require(original.fieldHashes[.notes]), .title: .init(value: "bad")],
        "/command/expectedFieldHashes/title"
      ),
    ]
    for (hashes, path) in badGuards {
      let operationIdentifier = UUID()
      let outcome = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session,
          command: .editItinerary(
            sourceId: itinerary.id, changes: .init(notes: .set("Must not save")),
            expectedFieldHashes: hashes))
      ).outcome
      guard case .rejected(let reason) = outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier)
      else {
        Issue.record("Invalid field guards must leave no applied evidence.")
        return
      }
      #expect(reason.code == "invalidInput")
      #expect(reason.propertyPath == path)
    }
    let missingSource = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editItinerary(
          sourceId: UUID(), changes: .init(notes: .set("Must not save")),
          expectedFieldHashes: original.fieldHashes))
    ).outcome
    guard case .rejected(let missing) = missingSource,
      case .source(.itinerary(let retained)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 4))
    else {
      Issue.record("All admission failures must retain the source and acknowledged snapshot.")
      return
    }
    #expect(missing.code == "missingReference")
    #expect(retained.content == original.content)
    #expect(retained.labels == original.labels)
    #expect(retained.references == original.references)
    #expect(retained.fieldHashes == original.fieldHashes)
    #expect(retained.createdAt == original.createdAt && retained.updatedAt == original.updatedAt)
    #expect(retained.state.globalDone == nil && retained.state.archived == false)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 4)
    #expect(namespace.preparedProposals.isEmpty)
    #expect(recovery.decodedBackup.backup.labelAssociations.count == 2)
    #expect(recovery.decodedBackup.backup.deletionMarkers.isEmpty)
  }
  private struct MissingResult: Error {}
}
