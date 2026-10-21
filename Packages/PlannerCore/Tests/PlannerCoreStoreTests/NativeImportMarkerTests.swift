import Foundation
import PlannerCore
import Testing

struct NativeImportMarkerTests {
  @Test func actualMembershipRemovalExportsItsDeclaredClosureWithoutChangingRetainedData()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Hotel"))).generated.first)
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo Food"))).generated.first)
    let addition = try await save(
      .addMembership(itemId: item.id, listId: list.id, placement: .last))
    guard case .membership(let identifier, _, _)? = addition.generatedReferences.first,
      case .source(.item(let before)) = await planner.read(session: session, request: .source(item))
    else { throw CancellationError() }
    let removal = PlannerCommand.removeMembership(listId: list.id, membershipId: identifier)
    guard
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: removal)
      ).outcome,
      case .exported(let bytes) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let response = planner.decodeImport(bytes)
    guard case .decoded(let decoded) = response else {
      Issue.record("Decode the actual native membership closure: \(response)")
      return
    }
    #expect(decoded.backup.sources.count == 2 && decoded.backup.memberships.isEmpty)
    #expect(decoded.backup.deletionMarkers.count == 1)
    #expect(
      decoded.backup.deletionMarkers.first?.target
        == .membership(id: identifier, lifetimeId: identifier))
    #expect(decoded.externalBindings.isEmpty)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let after)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .status(let status) = await reopened.read(session: reopenedSession, request: .status),
      case .known(let acknowledged, let incomplete, let blocked) = status.recovery,
      case .exported(let reopenedBytes) = await reopened.exportData(session: reopenedSession),
      case .decoded(let reopenedBackup) = reopened.decodeImport(reopenedBytes)
    else { throw CancellationError() }
    #expect(
      after.content.title == "Hotel" && after.updatedAt == before.updatedAt
        && after.fieldHashes == before.fieldHashes)
    #expect(acknowledged == checkpoint && incomplete.isEmpty && !blocked)
    #expect(
      reopenedBackup.backup.deletionMarkers.first?.target
        == decoded.backup.deletionMarkers.first?.target)
  }
}
