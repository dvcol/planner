import CloudKit
import Foundation
import Testing

@testable import PlannerCore

struct LibrarySharingTests {
  @Test func atomicSavesPreserveTheSpecificFailureAndRejectCancelledBatches() throws {
    let record = CKRecord(recordType: "PlannerNode_v1")
    let peer = CKRecord.ID(recordName: "peer")
    let atomic = CKError(.batchRequestFailed)
    let specific = CKError(
      .serverRejectedRequest, userInfo: [NSLocalizedDescriptionKey: "The root record is invalid."])
    do {
      try PlannerLibrarySharing.validateSaveResults([
        peer: .failure(atomic), record.recordID: .failure(specific),
      ])
      Issue.record("A rejected atomic save must not report success.")
    } catch {
      #expect((error as? CKError)?.code == .serverRejectedRequest)
      #expect(error.localizedDescription == "The root record is invalid.")
    }
    #expect(throws: CKError.self) {
      try PlannerLibrarySharing.validateSaveResults([peer: .failure(atomic)])
    }
    try PlannerLibrarySharing.validateSaveResults([record.recordID: .success(record)])
  }

  @Test func selectedListsKeepLiveItemsAndExcludePrivateRelationships() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      let operation = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = operation.outcome,
        let source = result.generated.first
      else {
        Issue.record("Save sharing fixtures through the durable writer.")
        throw CancellationError()
      }
      return source
    }
    func apply(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let operation = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = operation.outcome else {
        Issue.record("Apply the contextual change before reading sharing scope.")
        throw CancellationError()
      }
      return result
    }
    let first = try await create(.createList(content: .init(name: "Shared morning")))
    let second = try await create(.createList(content: .init(name: "Shared evening")))
    let secret = try await create(.createList(content: .init(name: "Private plans")))
    let label = try await create(.createTag(content: .init(name: "Outdoors")))
    let shared = try await create(
      .createItem(content: .init(title: "Museum", tagIds: [label.id]), listId: first.id))
    let privateItem = try await create(
      .createItem(
        content: .init(title: "Private appointment", notes: "Private notes"), listId: secret.id))
    let route = try await create(.createItinerary(content: .init(title: "Private route")))
    _ = try await apply(.addMembership(itemId: shared.id, listId: second.id, placement: .last))
    _ = try await apply(.addMembership(itemId: shared.id, listId: secret.id, placement: .last))
    _ = try await apply(.addItineraryEntry(itineraryId: route.id, source: shared, placement: .last))
    let scope = PlannerSharingScope.selectedLists([first.id, second.id])
    let before = try await planner.previewSharing(session: session, scope: scope)
    #expect(Set(before.sources) == [first, second, shared, label])
    #expect(before.membershipCount == 2)
    #expect(
      !before.sources.contains(secret) && !before.sources.contains(privateItem)
        && !before.sources.contains(route))
    guard
      case .source(.item(let item)) = await planner.read(session: session, request: .source(shared))
    else {
      throw CancellationError()
    }
    _ = try await apply(
      .editItem(
        sourceId: shared.id, changes: .init(notes: .set("Live shared edit")),
        expectedFieldHashes: [.notes: try #require(item.fieldHashes[.notes])]))
    let after = try await planner.previewSharing(session: session, scope: scope)
    #expect(Set(after.sources) == Set(before.sources))
    #expect(after.recordCount == before.recordCount)
    guard
      case .source(.list(let list)) = await planner.read(session: session, request: .source(first))
    else {
      throw CancellationError()
    }
    let membership = try #require(
      list.references.compactMap { reference -> UUID? in
        if case .membership(let identifier, _, _) = reference { return identifier }
        return nil
      }.first)
    _ = try await apply(
      .setCompletion(
        scope: .appearance(.listMembership(listId: first.id, membershipId: membership)), done: true)
    )
    _ = try await apply(.removeMembership(listId: first.id, membershipId: membership))
    let removed = try await planner.previewSharing(session: session, scope: scope)
    #expect(removed.membershipCount == 1)
    #expect(Set(removed.sources) == [first, second, shared, label])
    _ = try await apply(.addMembership(itemId: shared.id, listId: first.id, placement: .last))
    #expect(try await planner.previewSharing(session: session, scope: scope).membershipCount == 2)
    #expect(try await planner.previewSharing(session: session, scope: .off).recordCount == 0)
    let complete = try await planner.previewSharing(session: session, scope: .wholeLibrary)
    #expect(Set(complete.sources).isSuperset(of: [secret, privateItem, route]))
    #expect(complete.membershipCount == 4)
    await planner.close()
    await #expect(throws: PlannerFailure.self) {
      try await planner.previewSharing(session: session, scope: scope)
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let ready) = await reopened.bootstrap() else { throw CancellationError() }
    #expect(ready.datasetId == session.datasetId)
    #expect(try await reopened.previewSharing(session: ready, scope: scope).membershipCount == 2)
    guard
      case .source(.item(let current)) = await reopened.read(
        session: ready, request: .source(shared))
    else { throw CancellationError() }
    let removal = await reopened.execute(
      .init(
        operationId: UUID(), session: ready,
        command: .editItem(
          sourceId: shared.id, changes: .init(tagIds: .set([])),
          expectedFieldHashes: [.tagIds: try #require(current.fieldHashes[.tagIds])]))
    )
    guard case .applied = removal.outcome else { throw CancellationError() }
    let withoutUnusedLabel = try await reopened.previewSharing(session: ready, scope: scope)
    #expect(!withoutUnusedLabel.sources.contains(label))
    guard case .source(.tag) = await reopened.read(session: ready, request: .source(label)) else {
      Issue.record("Leaving the sharing projection must not delete the owner's label.")
      return
    }
  }

  @Test func scopedAndReadOnlyPermissionsRejectInapplicableCommands() throws {
    let list = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000001"))
    let source = PlannerEntityReference(kind: .item, id: UUID())
    let scoped = try library(scope: .selectedLists([list]), canEdit: true)
    #expect(throws: PlannerFailure.self) {
      try PlannerSharingPermissions.validate(.deleteSource(source: source), library: scoped)
    }
    #expect(throws: PlannerFailure.self) {
      try PlannerSharingPermissions.validate(
        .createItem(content: .init(title: "Inbox")), library: scoped)
    }
    try PlannerSharingPermissions.validate(
      .createItem(content: .init(title: "Shared"), listId: list), library: scoped)
    try PlannerSharingPermissions.validate(
      .removeMembership(listId: list, membershipId: UUID()), library: scoped)
    try PlannerSharingPermissions.validate(
      .deleteSource(source: source), library: library(scope: .wholeLibrary, canEdit: true))
    let readOnly = try library(scope: .wholeLibrary, canEdit: false)
    #expect(throws: PlannerFailure.self) {
      try PlannerSharingPermissions.validate(
        .setCompletion(scope: .globalItem(itemId: source.id), done: true), library: readOnly)
    }
  }

  @Test func cloudRecordsRetainTheirOwnerZoneAndSharingParent() throws {
    let encoder = JSONEncoder()
    let node = try PlannerCloudNode(
      kind: "item", identity: [encoder.encode(UUID())], fields: ["title": encoder.encode("Live")])
    let zone = CKRecordZone.ID(zoneName: "Planner-v1", ownerName: "another-owner")
    let original = try node.record(base: nil, zoneID: zone)
    original.setParent(CKRecord.ID(recordName: "sharing-root", zoneID: zone))
    #expect(throws: PlannerFailure.self) { try PlannerCloudNode(record: original) }
    #expect(try PlannerCloudNode(record: original, zoneID: zone) == node)
    let updated = try node.record(base: original, zoneID: zone)
    #expect(updated.recordID.zoneID == zone)
    #expect(updated.parent?.recordID == original.parent?.recordID)
    #expect(throws: PlannerFailure.self) { try node.record(base: original) }
  }

  @Test func receivedRecordsMustBelongToTheirExactInvitationHierarchy() throws {
    let selected = try library(scope: .selectedLists([UUID()]), canEdit: true)
    let record = CKRecord(
      recordType: PlannerCloudNode.recordType,
      recordID: .init(recordName: "place", zoneID: selected.zoneID))
    #expect(!selected.contains(record))
    record.setParent(CKRecord.ID(recordName: "sharing_someone-else", zoneID: selected.zoneID))
    #expect(!selected.contains(record))
    record.setParent(try #require(selected.rootID))
    #expect(selected.contains(record))
    record.setParent(nil as CKRecord.ID?)
    let whole = try library(scope: .wholeLibrary, canEdit: true)
    #expect(whole.contains(record))
    let unrelated = CKRecord(
      recordType: PlannerCloudNode.recordType,
      recordID: .init(
        recordName: "place", zoneID: .init(zoneName: "Planner-v1", ownerName: "owner-b")))
    #expect(!whole.contains(unrelated))
    let replacement = try library(scope: .wholeLibrary, canEdit: true)
    #expect(whole.shareID == replacement.shareID)
    #expect(whole.generation != replacement.generation)
    #expect(whole.id != replacement.id)
  }

  private func library(scope: PlannerSharingScope, canEdit: Bool) throws -> PlannerSharedLibrary {
    struct StoredLibrary: Encodable {
      let ownerName = "owner-a"
      let zoneName = "Planner-v1"
      let shareName = "invitation_a"
      let generation = UUID()
      let title = "Shared plans"
      let scope: PlannerSharingScope
      let canEdit: Bool
    }
    return try JSONDecoder().decode(
      PlannerSharedLibrary.self,
      from: JSONEncoder().encode(StoredLibrary(scope: scope, canEdit: canEdit)))
  }
}
