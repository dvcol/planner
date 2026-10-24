import Foundation
import PlannerCore
import Testing

struct NativeImportReviewTests {
  @Test func identicalExportReviewsWholeOwnersAsUnchangedIncludingLocalMembershipState()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let createdItem, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Museum")))
      ).outcome,
      let item = createdItem.generated.first,
      case .applied(let createdList, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Weekend")))
      ).outcome,
      let list = createdList.generated.first
    else { throw CancellationError() }
    guard
      case .applied(let added, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let membershipId, _, _)? = added.generatedReferences.first,
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(
            scope: .appearance(.listMembership(listId: list.id, membershipId: membershipId)),
            done: true))
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let decoded) = planner.decodeImport(before)
    else { throw CancellationError() }
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: decoded))
    guard case .reviewed(let review) = response else {
      Issue.record("Review identical exported owners without changing them: \(response)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.isEmpty && details.unchanged.count == 2)
    #expect(details.skippedConflicts.isEmpty && details.skippedDependents.isEmpty)
    #expect(details.replacements.isEmpty && details.restorations.isEmpty)
    #expect(details.incomingDeletions.isEmpty)
    #expect(details.unchanged.allSatisfy { $0.reasonCode == "unchanged" })
    #expect(details.unchanged.allSatisfy { $0.before?.changedFieldNames.isEmpty == true })
    let retainedList = try #require(details.unchanged.first { $0.owner.id == list.id })
    #expect(retainedList.before?.title == "Weekend" && retainedList.after?.title == "Weekend")
    #expect(retainedList.before?.associationIds == [membershipId])
    #expect(retainedList.after?.associationIds == [membershipId])
    #expect(
      details.referenceChanges.count == 1 && details.referenceChanges.first?.change == .retain)
    guard case .exported(let after) = await planner.exportData(session: session),
      case .status(let status) = await planner.read(session: session, request: .status),
      case .known(let afterCheckpoint, let incomplete, _, let blocked) = status.recovery
    else { throw CancellationError() }
    #expect(before == after && afterCheckpoint == checkpoint)
    #expect(incomplete.isEmpty && !blocked)
  }

  @Test func completeBackupReviewDescribesEveryOwnerAndReferenceWithoutApplyingData() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(try nativeImportFixtureData()),
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded))
    else {
      Issue.record(
        "Review the complete decoded backup in the current empty dataset before applying it.")
      return
    }
    #expect(review.impact.kind == .importData)
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.count == 7)
    #expect(details.unchanged.isEmpty && details.skippedConflicts.isEmpty)
    #expect(details.skippedDependents.isEmpty && details.replacements.isEmpty)
    #expect(details.restorations.isEmpty && details.incomingDeletions.count == 1)
    let museum = try #require(details.imports.first { $0.owner.id.uuidString.hasSuffix("101") })
    #expect(museum.owner.kind == .item && museum.owner.lifetimeId.uuidString.hasSuffix("811"))
    #expect(museum.before == nil && museum.after?.title == "Nezu Museum")
    #expect(museum.reasonCode == nil && museum.propertyPaths.contains("/sources/0"))
    #expect(
      Set(museum.after?.associationIds.map { String($0.uuidString.suffix(3)) } ?? []) == [
        "551", "651", "701", "751", "752",
      ])
    let food = try #require(details.imports.first { $0.owner.id.uuidString.hasSuffix("201") })
    #expect(food.after?.title == "Tokyo Food")
    #expect(
      Set(food.after?.associationIds.map { String($0.uuidString.suffix(3)) } ?? []) == [
        "401", "402",
      ])
    #expect(Set(food.dependencies.map { String($0.id.uuidString.suffix(3)) }) == ["101", "102"])
    #expect(details.referenceChanges.count == 15)
    #expect(details.referenceChanges.allSatisfy { $0.change == .add })
    #expect(review.impact.sourceDeletes.isEmpty && review.impact.referenceRemovals.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session),
      case .status(let status) = await planner.read(session: session, request: .status)
    else { throw CancellationError() }
    #expect(before == after)
    guard case .known(let checkpoint, let incomplete, _, let blocked) = status.recovery else {
      Issue.record("Review must retain readable, unchanged recovery status.")
      return
    }
    #expect(checkpoint == nil && incomplete.isEmpty && !blocked)
  }
}
