import Foundation
import PlannerCore
import Testing

struct ItemInListCreationTests {
  @Test func ordinaryCreationKeepsRepeatedBookmarksAndOneTodoMembershipAcrossReplayAndReopen()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "PlannerQ93Store-" + UUID().uuidString)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The disposable dataset must initialize.")
      return
    }
    let destination = try await save(
      .createList(content: .init(name: "Tokyo")), planner: planner, session: session)
    let other = try await save(
      .createList(content: .init(name: "Wishlist")), planner: planner, session: session)
    let list = try #require(destination.result.generated.first)
    let otherList = try #require(other.result.generated.first)
    let operationIdentifier = UUID()
    let command = PlannerCommand.createItem(
      content: .init(
        title: "Museum", notes: "Keep both authored bookmarks",
        links: [
          .init(originalUrl: "https://example.com/museum", label: "Tickets"),
          .init(originalUrl: "https://example.com/museum", label: "Exhibitions"),
        ]), listId: list.id)
    let created = try await save(
      command, planner: planner, session: session, operationIdentifier: operationIdentifier)
    let item = try #require(created.result.generated.first)
    guard
      case .membership(let membershipIdentifier, let owner, let source)? =
        created.result.generatedReferences.first
    else {
      Issue.record("Ordinary creation must also return its new List membership.")
      return
    }
    #expect(owner == list && source == item)
    #expect(created.result.generatedReferences.count == 1)
    #expect(created.result.affected.contains(list))
    #expect(created.checkpoint == 3)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.list(let populated)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.list(let untouched)) = await reopened.read(
        session: reopenedSession, request: .source(otherList)),
      case .appearance(let appearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(
          .listMembership(listId: list.id, membershipId: membershipIdentifier)))
    else {
      Issue.record("The complete ordinary Item and its contextual appearance must survive reopen.")
      return
    }
    #expect(retained.content.title == "Museum")
    #expect(retained.content.notes == "Keep both authored bookmarks")
    #expect(
      retained.content.links.map(\.originalUrl) == [
        "https://example.com/museum", "https://example.com/museum",
      ])
    #expect(retained.content.links.map(\.label) == ["Tickets", "Exhibitions"])
    #expect(Set(retained.content.links.map(\.linkId)).count == 2)
    #expect(populated.references == created.result.generatedReferences)
    #expect(populated.progress.totalCount == 1 && populated.progress.doneCount == 0)
    #expect(untouched.references.isEmpty && untouched.progress.state == .empty)
    #expect(!appearance.localDone && !appearance.globalDone && !appearance.effectiveDone)
    let replay = try await save(
      command, planner: reopened, session: reopenedSession,
      operationIdentifier: operationIdentifier)
    #expect(replay.result == created.result)
    #expect(replay.checkpoint == created.checkpoint)
    guard
      case .source(.item(let replayed)) = await reopened.read(
        session: reopenedSession, request: .source(item))
    else {
      Issue.record("Replay must keep the original owned links.")
      return
    }
    #expect(replayed.content.links == retained.content.links)
  }

  @Test func destinationReviewRejectsRenamesButAllowsIndependentMembershipChanges() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "PlannerQ93Store-" + UUID().uuidString)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      throw FixtureFailure.unexpectedOutcome
    }
    let creation = try await save(
      .createList(content: .init(name: "Tokyo")), planner: planner, session: session)
    let list = try #require(creation.result.generated.first)
    let command = PlannerCommand.createItem(content: .init(title: "Museum"), listId: list.id)
    guard
      case .reviewed(let originalReview) = await planner.prepareReview(
        session: session, command: command),
      case .source(.list(let original)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Review ordinary creation against the selected List before saving.")
      return
    }
    #expect(originalReview.impact.kind.rawValue == "itemCreation")
    #expect(originalReview.targets == [.source(list)])
    #expect(originalReview.targetCount == 1 && !originalReview.globalFlagsChanged)
    _ = try await save(
      .editList(
        sourceId: list.id, changes: .init(name: .set("Kyoto")),
        expectedFieldHashes: original.fieldHashes),
      planner: planner, session: session)
    let staleIdentifier = UUID()
    guard
      case .rejected(let stale) = await planner.execute(
        .init(
          operationId: staleIdentifier, session: session, command: command,
          reviewToken: originalReview.reviewToken)
      ).outcome,
      case .snapshot(let empty) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all)))),
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: staleIdentifier)
    else {
      Issue.record(
        "A renamed destination must invalidate review without creating an Item or receipt.")
      return
    }
    #expect(stale.code == "staleReview")
    #expect(empty.matchingCount == 0)
    guard
      case .reviewed(let refreshedReview) = await planner.prepareReview(
        session: session, command: command)
    else { throw FixtureFailure.unexpectedOutcome }
    let anchor = try await save(
      .createItem(content: .init(title: "Zoo Hotel")), planner: planner, session: session)
    let anchorItem = try #require(anchor.result.generated.first)
    _ = try await save(
      .addMembership(itemId: anchorItem.id, listId: list.id, placement: .last), planner: planner,
      session: session)
    let applied = await planner.execute(
      .init(
        operationId: UUID(), session: session, command: command,
        reviewToken: refreshedReview.reviewToken))
    guard case .applied(let result, .complete) = applied.outcome,
      case .source(.list(let retained)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record(
        "Independent membership changes must not invalidate a reviewed destination: \(applied.outcome)"
      )
      return
    }
    let item = try #require(result.generated.first)
    #expect(retained.content.name == "Kyoto")
    #expect(retained.progress.totalCount == 2)
    #expect(
      retained.references.contains { reference in
        guard case .membership(_, let owner, let source) = reference else { return false }
        return owner == list && source == item
      })
    guard
      case .snapshot(let ordered) = await planner.query(
        .init(
          session: session,
          request: .items(
            .init(
              scope: .list(list.id), completion: .all, archive: .all, sort: .init(mode: .manual)))))
    else { throw FixtureFailure.unexpectedOutcome }
    let orderedSources = ordered.rows.compactMap { row -> PlannerEntityReference? in
      if case .appearance(let source, _) = row { return source }
      return nil
    }
    #expect(orderedSources == [anchorItem, item])
  }

  @Test func replayCannotChangeDestinationRestoreRemovedMembershipOrResetItsReplacement()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "PlannerQ93Store-" + UUID().uuidString)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      throw FixtureFailure.unexpectedOutcome
    }
    let destination = try await save(
      .createList(content: .init(name: "Tokyo")), planner: planner, session: session)
    let other = try await save(
      .createList(content: .init(name: "Wishlist")), planner: planner, session: session)
    let categoryCreation = try await save(
      .createCategory(content: .init(name: "Museum")), planner: planner, session: session)
    let tagCreation = try await save(
      .createTag(content: .init(name: "Rainy day")), planner: planner, session: session)
    let list = try #require(destination.result.generated.first)
    let otherList = try #require(other.result.generated.first)
    let category = try #require(categoryCreation.result.generated.first)
    let tag = try #require(tagCreation.result.generated.first)
    let content = PlannerItemContentInput(
      title: "Museum", subtitle: "Permanent collection", notes: "Keep all authored content",
      location: .init(displayName: "Museum", formattedAddress: "Tokyo", coordinate: nil),
      estimate: .init(minutes: 125, displayUnit: .hour),
      links: [
        .init(originalUrl: "https://example.com/museum", label: "Tickets"),
        .init(originalUrl: "https://example.com/museum", label: "Exhibitions"),
      ], categoryIds: [category.id], tagIds: [tag.id])
    let operationIdentifier = UUID()
    let command = PlannerCommand.createItem(content: content, listId: list.id)
    let creation = try await save(
      command, planner: planner, session: session, operationIdentifier: operationIdentifier)
    let item = try #require(creation.result.generated.first)
    let membership = try #require(
      creation.result.generatedReferences.first { reference in
        if case .membership = reference { return true }
        return false
      })
    guard case .membership(let membershipIdentifier, _, _) = membership,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item))
    else { throw FixtureFailure.unexpectedOutcome }
    for destinationIdentifier in [otherList.id, nil] {
      guard
        case .rejected(let mismatch) = await planner.execute(
          .init(
            operationId: operationIdentifier, session: session,
            command: .createItem(content: content, listId: destinationIdentifier))
        ).outcome
      else {
        Issue.record("An applied operation cannot be reused with another or omitted destination.")
        return
      }
      #expect(mismatch.code == "operationPayloadMismatch")
    }
    _ = try await save(
      .removeMembership(listId: list.id, membershipId: membershipIdentifier), planner: planner,
      session: session)
    let replay = try await save(
      command, planner: planner, session: session, operationIdentifier: operationIdentifier)
    #expect(replay.result == creation.result && replay.checkpoint == creation.checkpoint)
    guard
      case .source(.list(let empty)) = await planner.read(session: session, request: .source(list)),
      case .failed(let missing) = await planner.read(
        session: session,
        request: .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier)))
    else { throw FixtureFailure.unexpectedOutcome }
    #expect(empty.references.isEmpty && missing.code == "missingReference")
    let addition = try await save(
      .addMembership(itemId: item.id, listId: list.id, placement: .last), planner: planner,
      session: session)
    guard
      case .membership(let replacementIdentifier, _, _)? = addition.result.generatedReferences.first
    else { throw FixtureFailure.unexpectedOutcome }
    #expect(replacementIdentifier != membershipIdentifier)
    let replacement = PlannerAppearance.listMembership(
      listId: list.id, membershipId: replacementIdentifier)
    _ = try await save(
      .setCompletion(scope: .appearance(replacement), done: true), planner: planner,
      session: session)
    _ = try await save(
      command, planner: planner, session: session, operationIdentifier: operationIdentifier)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .appearance(let retainedAppearance) = await reopened.read(
        session: reopenedSession, request: .appearance(replacement)),
      case .source(.item(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .source(.list(let untouched)) = await reopened.read(
        session: reopenedSession, request: .source(otherList)),
      case .snapshot(let items) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all))))
    else { throw FixtureFailure.unexpectedOutcome }
    #expect(retainedAppearance.localDone && !retainedAppearance.globalDone)
    #expect(retained.content.subtitle == "Permanent collection")
    #expect(retained.content.notes == "Keep all authored content")
    #expect(
      retained.content.location == content.location && retained.content.estimate == content.estimate
    )
    #expect(retained.content.links == original.content.links)
    #expect(retained.content.categoryIds == [category.id] && retained.content.tagIds == [tag.id])
    #expect(retained.labels.count == 2)
    #expect(untouched.references.isEmpty && items.matchingCount == 1)
  }

  private func save(
    _ command: PlannerCommand, planner: Planner, session: PlannerDatasetSession,
    operationIdentifier: UUID = UUID()
  ) async throws -> (result: PlannerAppliedResult, checkpoint: Int64) {
    let result = await planner.execute(
      .init(operationId: operationIdentifier, session: session, command: command))
    guard case .applied(let applied, .complete(let checkpoint)) = result.outcome else {
      Issue.record("Expected a recoverable complete action: \(result.outcome)")
      throw FixtureFailure.unexpectedOutcome
    }
    return (applied, checkpoint)
  }

  private enum FixtureFailure: Error { case unexpectedOutcome }
}
