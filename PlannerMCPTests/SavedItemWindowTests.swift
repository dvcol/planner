import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class SavedItemWindowTests: XCTestCase {
  func testListOpensOnePageWithEveryMembershipIdentityAndItsFullHeader() async throws {
    let fixture = try await makeFixture(itemCount: 65, listName: "Museum route")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .list(listIdentifier), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "list-first-page", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 65)
    let expectedIdentities = fixture.identifiers.enumerated().map { index, identifier in
      PlannerRowIdentity.appearance(
        source: .init(kind: .item, id: identifier),
        appearance: .listMembership(
          listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index]))
    }
    XCTAssertEqual(window.rowIdentities, expectedIdentities)
    let list = try XCTUnwrap(window.listSource)
    XCTAssertEqual(list.source, .init(kind: .list, id: listIdentifier))
    XCTAssertEqual(list.content.name, "Museum route")
    XCTAssertEqual(list.progress.totalCount, 65)
    XCTAssertEqual(list.progress.doneCount, 0)
    XCTAssertEqual(list.references.count, 65)
    XCTAssertEqual(list.estimates.fullEstimate, .lowerBound(minutes: 0, missingEstimateCount: 65))
    for (index, title) in [(0, "Activity 000"), (63, "Activity 063")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("A ready List must include its first page of contextual Item presentations.")
        return
      }
      XCTAssertEqual(item.id, fixture.membershipIdentifiers[index])
      XCTAssertEqual(item.row.identity, expectedIdentities[index])
      XCTAssertEqual(item.row.title, title)
      XCTAssertFalse(item.row.effectiveDone == true)
    }
    guard case .loading = window.presentation(at: 64) else {
      XCTFail("Opening a List must not eagerly hydrate every membership.")
      return
    }
  }

  func testOpensWithOnePageAndKeepsEveryOrderedSourceIdentity() async throws {
    let fixture = try await makeFixture(itemCount: 65)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "first-page", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(
      window.rowIdentities, fixture.identifiers.map { .source(.init(kind: .item, id: $0)) })
    XCTAssertEqual(window.matchingCount, 65)
    for (index, title) in [(0, "Activity 000"), (63, "Activity 063")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("The initial page must be readable before the catalog is ready.")
        return
      }
      XCTAssertEqual(item.id, fixture.identifiers[index])
      XCTAssertEqual(item.row.title, title)
    }
    guard case .loading = window.presentation(at: 64) else {
      XCTFail("The catalog must not accumulate all matching row presentations.")
      return
    }
  }

  func testListReleasesAndRevisitsMembershipPagesWhileKeepingItsFullHeader() async throws {
    let fixture = try await makeFixture(itemCount: 193, listName: "Long route")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .list(listIdentifier), completion: .all, archive: .all, sort: .init(mode: .manual)),
      identity: .init(namespace: "list-page-traversal", savedRevision: UUID()))
    let originalIdentities = window.rowIdentities
    XCTAssertEqual(originalIdentities.count, 193)
    await window.requestRows(at: [192])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 193)
    XCTAssertEqual(window.rowIdentities, originalIdentities)
    XCTAssertEqual(window.listSource?.source.id, listIdentifier)
    XCTAssertEqual(window.listSource?.references.count, 193)
    XCTAssertEqual(window.listSource?.progress.totalCount, 193)
    XCTAssertEqual(
      window.listSource?.estimates.fullEstimate, .lowerBound(minutes: 0, missingEstimateCount: 193))
    for (index, title) in [(128, "Activity 128"), (192, "Activity 192")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Visible and neighboring List pages must load their contextual memberships.")
        return
      }
      XCTAssertEqual(item.id, fixture.membershipIdentifiers[index])
      XCTAssertEqual(item.row.title, title)
      XCTAssertEqual(
        item.row.identity,
        .appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index])))
    }
    for index in [0, 64] {
      guard case .loading = window.presentation(at: index) else {
        XCTFail("Distant List presentations must be released without dropping their identities.")
        return
      }
    }
    await window.requestRows(at: [0])
    for (index, title) in [(0, "Activity 000"), (64, "Activity 064")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Returning to the beginning must reread the same memberships.")
        return
      }
      XCTAssertEqual(item.id, fixture.membershipIdentifiers[index])
      XCTAssertEqual(item.row.title, title)
    }
    for index in [128, 192] {
      guard case .loading = window.presentation(at: index) else {
        XCTFail("Returning to the beginning must release the distant List pages.")
        return
      }
    }
    XCTAssertEqual(window.listSource?.progress.totalCount, 193)
  }

  func testLoadsVisibleAndNeighborPagesReleasesDistantRowsAndRevisitsTheirIdentities() async throws
  {
    let fixture = try await makeFixture(itemCount: 193)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "page-traversal", savedRevision: UUID()))
    await window.requestRows(at: [192])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(
      window.rowIdentities, fixture.identifiers.map { .source(.init(kind: .item, id: $0)) })
    for (index, title) in [(128, "Activity 128"), (192, "Activity 192")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Visible and neighboring pages must load through the same catalog.")
        return
      }
      XCTAssertEqual(item.id, fixture.identifiers[index])
      XCTAssertEqual(item.row.title, title)
    }
    for index in [0, 64] {
      guard case .loading = window.presentation(at: index) else {
        XCTFail("Distant row presentations must be released.")
        return
      }
    }
    await window.requestRows(at: [0])
    for (index, title) in [(0, "Activity 000"), (64, "Activity 064")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Revisiting a released page must reload its original Items.")
        return
      }
      XCTAssertEqual(item.id, fixture.identifiers[index])
      XCTAssertEqual(item.row.title, title)
    }
    for index in [128, 192] {
      guard case .loading = window.presentation(at: index) else {
        XCTFail("Returning to the beginning must release the distant pages.")
        return
      }
    }
  }

  func testEmptyAndFilteredListsKeepTheirOwnHeaderAndCancelClearsIt() async throws {
    let fixture = try await makeFixture(itemCount: 65, listName: "Filtered route")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .list(listIdentifier), text: "Absent museum", completion: .all, archive: .all),
      identity: .init(namespace: "filtered-list", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 0)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    XCTAssertEqual(window.listSource?.content.name, "Filtered route")
    XCTAssertEqual(window.listSource?.progress.totalCount, 65)
    XCTAssertEqual(window.listSource?.references.count, 65)
    XCTAssertEqual(
      window.listSource?.estimates.fullEstimate, .lowerBound(minutes: 0, missingEstimateCount: 65))
    let emptyList = await fixture.planner.execute(
      .init(
        operationId: UUID(), session: fixture.session,
        command: .createList(content: .init(name: "Empty route"))))
    guard case .applied(let created, .complete) = emptyList.outcome else {
      XCTFail("The real Planner must create the empty List fixture.")
      return
    }
    let emptyIdentifier = try XCTUnwrap(created.generated.first { $0.kind == .list }?.id)
    await window.reload(
      query: .init(scope: .list(emptyIdentifier), completion: .all, archive: .all),
      identity: .init(namespace: "empty-list", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 0)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    XCTAssertEqual(window.listSource?.source.id, emptyIdentifier)
    XCTAssertEqual(window.listSource?.content.name, "Empty route")
    XCTAssertEqual(window.listSource?.progress.state, .empty)
    XCTAssertEqual(window.listSource?.progress.totalCount, 0)
    XCTAssertEqual(window.listSource?.references.count, 0)
    XCTAssertEqual(window.listSource?.estimates.fullEstimate, .exact(minutes: 0))
    window.cancel()
    XCTAssertEqual(window.state, .idle)
    XCTAssertNil(window.listSource)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    await window.reload(
      query: .init(scope: .global, completion: .all, archive: .all),
      identity: .init(namespace: "global-after-list", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertNil(window.listSource)
    XCTAssertEqual(window.matchingCount, 65)
    XCTAssertEqual(
      window.rowIdentities, fixture.identifiers.map { .source(.init(kind: .item, id: $0)) })
  }

  func testRefreshesAStaleGenerationWithoutMixingItsRowsAndKeepsTheVisibleSource() async throws {
    let fixture = try await makeFixture(itemCount: 193)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .todo, archive: .all),
      identity: .init(namespace: "saved-mutation", savedRevision: UUID()))
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session,
          command: .setCompletion(scope: .globalItem(itemId: fixture.identifiers[0]), done: true))
      ).outcome
    else { throw CancellationError() }
    await window.requestRows(at: [192])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 192)
    XCTAssertEqual(
      window.rowIdentities,
      fixture.identifiers.dropFirst().map { .source(.init(kind: .item, id: $0)) })
    guard case .loaded(let lastItem) = window.presentation(at: 191) else {
      XCTFail("A stale page must refresh and retain the source that was visible before the change.")
      return
    }
    XCTAssertEqual(lastItem.id, fixture.identifiers[192])
    XCTAssertEqual(lastItem.row.title, "Activity 192")
    for index in window.rowIdentities.indices {
      if case .loaded(let item) = window.presentation(at: index) {
        XCTAssertEqual(item.id, fixture.identifiers[index + 1])
        XCTAssertFalse(item.row.globalDone == true)
      }
    }
  }

  func testSwitchingListsKeepsSharedItemMembershipsAndLocalCompletionIndependent() async throws {
    let fixture = try await makeFixture(itemCount: 65, listName: "First route")
    let firstListIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .list(firstListIdentifier), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "shared-item-lists", savedRevision: UUID()))
    _ = try await applyFixtureCommand(
      .setCompletion(
        scope: .appearance(
          .listMembership(
            listId: firstListIdentifier, membershipId: fixture.membershipIdentifiers[64])),
        done: true),
      fixture: fixture)
    await window.requestRows(at: [64])
    XCTAssertEqual(window.listSource?.progress.doneCount, 1)
    guard case .loaded(let firstAppearance) = window.presentation(at: 64) else {
      XCTFail("An unloaded stale page must refresh the List's completion and header together.")
      return
    }
    XCTAssertEqual(firstAppearance.id, fixture.membershipIdentifiers[64])
    XCTAssertTrue(firstAppearance.row.effectiveDone == true)
    XCTAssertFalse(firstAppearance.row.globalDone == true)
    let secondList = try await applyFixtureCommand(
      .createList(content: .init(name: "Second route")), fixture: fixture)
    let secondListIdentifier = try XCTUnwrap(secondList.generated.first { $0.kind == .list }?.id)
    let addition = try await applyFixtureCommand(
      .addMembership(
        itemId: fixture.identifiers[64], listId: secondListIdentifier, placement: .last),
      fixture: fixture)
    let secondMembershipIdentifier = try XCTUnwrap(
      addition.generatedReferences.compactMap {
        reference -> UUID? in
        guard case .membership(let identifier, let list, let item) = reference,
          list.id == secondListIdentifier, item.id == fixture.identifiers[64]
        else { return nil }
        return identifier
      }.first)
    await window.reload(
      query: .init(
        scope: .list(secondListIdentifier), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "shared-item-lists", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.listSource?.content.name, "Second route")
    XCTAssertEqual(window.listSource?.progress.totalCount, 1)
    XCTAssertEqual(window.listSource?.progress.doneCount, 0)
    XCTAssertEqual(
      window.rowIdentities,
      [
        .appearance(
          source: .init(kind: .item, id: fixture.identifiers[64]),
          appearance: .listMembership(
            listId: secondListIdentifier, membershipId: secondMembershipIdentifier))
      ])
    guard case .loaded(let secondAppearance) = window.presentation(at: 0) else {
      XCTFail("The replacement List must load its own membership of the shared Item.")
      return
    }
    XCTAssertEqual(secondAppearance.id, secondMembershipIdentifier)
    XCTAssertNotEqual(secondAppearance.id, firstAppearance.id)
    XCTAssertEqual(secondAppearance.row.title, "Activity 064")
    XCTAssertFalse(secondAppearance.row.effectiveDone == true)
    await window.reload(
      query: .init(
        scope: .list(firstListIdentifier), completion: .all, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "shared-item-lists", savedRevision: UUID()))
    await window.requestRows(at: [64])
    XCTAssertEqual(window.listSource?.content.name, "First route")
    XCTAssertEqual(window.listSource?.progress.totalCount, 65)
    XCTAssertEqual(window.listSource?.progress.doneCount, 1)
    guard case .loaded(let revisited) = window.presentation(at: 64) else {
      XCTFail("Returning to the first List must retain that membership's local completion.")
      return
    }
    XCTAssertEqual(revisited.id, fixture.membershipIdentifiers[64])
    XCTAssertTrue(revisited.row.effectiveDone == true)
    XCTAssertFalse(revisited.row.globalDone == true)
  }

  func testUnloadedListPageRefreshesManualOrderAndRemovedMembershipsWithItsHeader() async throws {
    let fixture = try await makeFixture(itemCount: 193, listName: "Changing route")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(
        scope: .list(listIdentifier), completion: .todo, archive: .all,
        sort: .init(mode: .manual)),
      identity: .init(namespace: "saved-list-order", savedRevision: UUID()))
    _ = try await applyFixtureCommand(
      .reorderMembership(
        listId: listIdentifier, membershipId: fixture.membershipIdentifiers[192], placement: .first),
      fixture: fixture)
    await window.requestRows(at: [192])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 193)
    let reorderedIndices = [192] + Array(0..<192)
    XCTAssertEqual(
      window.rowIdentities,
      reorderedIndices.map { index in
        .appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index]))
      })
    XCTAssertEqual(window.listSource?.progress.totalCount, 193)
    XCTAssertEqual(window.listSource?.references.count, 193)
    guard case .loaded(let moved) = window.presentation(at: 0) else {
      XCTFail("A moved visible membership must remain loaded at its refreshed position.")
      return
    }
    XCTAssertEqual(moved.id, fixture.membershipIdentifiers[192])
    XCTAssertEqual(moved.row.title, "Activity 192")
    _ = try await applyFixtureCommand(
      .removeMembership(listId: listIdentifier, membershipId: fixture.membershipIdentifiers[0]),
      fixture: fixture)
    await window.requestRows(at: [192])
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 192)
    let survivingIndices = [192] + Array(1..<192)
    XCTAssertEqual(
      window.rowIdentities,
      survivingIndices.map { index in
        .appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index]))
      })
    XCTAssertEqual(window.listSource?.progress.totalCount, 192)
    XCTAssertEqual(window.listSource?.references.count, 192)
    XCTAssertEqual(
      window.listSource?.estimates.fullEstimate,
      .lowerBound(minutes: 0, missingEstimateCount: 192))
    guard case .loaded(let surviving) = window.presentation(at: 191) else {
      XCTFail("A surviving visible membership must remain loaded after another is removed.")
      return
    }
    XCTAssertEqual(surviving.id, fixture.membershipIdentifiers[191])
    XCTAssertEqual(surviving.row.title, "Activity 191")
  }

  func testCancelsReleasesRowsAndReopensWithTheReplacementInboxQuery() async throws {
    let fixture = try await makeFixture(itemCount: 193)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "before-leaving", savedRevision: UUID()))
    await window.requestRows(at: [128])
    window.cancel()
    XCTAssertEqual(window.state, .idle)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    XCTAssertEqual(window.matchingCount, 0)
    await window.requestRows(at: [128])
    guard case .loading = window.presentation(at: 128) else {
      XCTFail("A canceled catalog must release presentations and ignore later page requests.")
      return
    }
    await window.reload(
      query: .init(
        scope: .inbox, text: "Activity 11", completion: .todo, archive: .all,
        sort: .init(mode: .title, direction: .descending)),
      identity: .init(namespace: "replacement", savedRevision: UUID()))
    let expectedIndices = [119, 118, 117, 116, 115, 114, 113, 112, 111, 110, 11]
    let expectedIdentifiers = expectedIndices.map { fixture.identifiers[$0] }
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(
      window.rowIdentities, expectedIdentifiers.map { .source(.init(kind: .item, id: $0)) })
    XCTAssertEqual(window.matchingCount, 11)
    for (index, title) in [(0, "Activity 119"), (10, "Activity 011")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Replacement queries must return their own filtered and sorted presentations.")
        return
      }
      XCTAssertEqual(item.id, expectedIdentifiers[index])
      XCTAssertEqual(item.row.title, title)
    }
    let canceledReload = Task { @MainActor in
      await window.reload(
        query: .init(text: "No result", completion: .all, archive: .all),
        identity: .init(namespace: "canceled", savedRevision: UUID()))
    }
    canceledReload.cancel()
    await canceledReload.value
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(
      window.rowIdentities, expectedIdentifiers.map { .source(.init(kind: .item, id: $0)) })
  }

  func testListCumulativeFiltersAndSortKeepFullProgressAndEstimateMetadata() async throws {
    let fixture = try await makeFixture(itemCount: 12, listName: "Mixed route")
    let listIdentifier = try XCTUnwrap(fixture.listIdentifier)
    _ = try await applyFixtureCommand(
      .setCompletion(
        scope: .appearance(
          .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[1])), done: true),
      fixture: fixture)
    _ = try await applyFixtureCommand(
      .setArchive(source: .init(kind: .item, id: fixture.identifiers[3]), archived: true),
      fixture: fixture)
    _ = try await applyFixtureCommand(
      .reorderMembership(
        listId: listIdentifier, membershipId: fixture.membershipIdentifiers[9], placement: .first),
      fixture: fixture)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    let examples: [(PlannerItemQuery.Sort, [Int])] = [
      (.init(mode: .title), [0, 2, 4, 5, 6, 7, 8, 9]),
      (.init(mode: .title, direction: .descending), [9, 8, 7, 6, 5, 4, 2, 0]),
      (.init(mode: .manual), [9, 0, 2, 4, 5, 6, 7, 8]),
    ]
    for (sort, expectedIndices) in examples {
      await window.reload(
        query: .init(
          scope: .list(listIdentifier), text: "ACTÍVITY 00", completion: .todo, archive: .active,
          sort: sort),
        identity: .init(namespace: "filtered-sorted-list", savedRevision: UUID()))
      XCTAssertEqual(window.state, .ready)
      XCTAssertEqual(window.matchingCount, 8)
      let expectedIdentities = expectedIndices.map { index in
        PlannerRowIdentity.appearance(
          source: .init(kind: .item, id: fixture.identifiers[index]),
          appearance: .listMembership(
            listId: listIdentifier, membershipId: fixture.membershipIdentifiers[index]))
      }
      XCTAssertEqual(window.rowIdentities, expectedIdentities)
      for (rowIndex, fixtureIndex) in expectedIndices.enumerated() {
        guard case .loaded(let item) = window.presentation(at: rowIndex) else {
          XCTFail("The filtered List must load the complete matching first page in Core order.")
          return
        }
        XCTAssertEqual(item.id, fixture.membershipIdentifiers[fixtureIndex])
        XCTAssertEqual(item.row.identity, expectedIdentities[rowIndex])
        XCTAssertFalse(item.row.effectiveDone == true)
        XCTAssertFalse(item.row.archived == true)
      }
      XCTAssertEqual(window.listSource?.progress.totalCount, 12)
      XCTAssertEqual(window.listSource?.progress.doneCount, 1)
      XCTAssertEqual(window.listSource?.progress.archivedCount, 1)
      XCTAssertEqual(window.listSource?.references.count, 12)
      XCTAssertEqual(
        window.listSource?.estimates.fullEstimate,
        .lowerBound(minutes: 0, missingEstimateCount: 12))
      XCTAssertEqual(
        window.listSource?.estimates.remainingEstimate,
        .lowerBound(minutes: 0, missingEstimateCount: 10))
    }
  }

  func testDistinguishesQueryFailureFromEmptyResultsAndAcceptsAValidRetry() async throws {
    let fixture = try await makeFixture(itemCount: 65)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all, sort: .init(mode: .manual)),
      identity: .init(namespace: "invalid-query", savedRevision: UUID()))
    guard case .failed(let explanation) = window.state else {
      XCTFail(
        "An unsupported global Manual query must expose its failure, rather than empty results.")
      return
    }
    XCTAssertFalse(explanation.isEmpty)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    await window.reload(
      query: .init(text: "Absent museum", completion: .all, archive: .all),
      identity: .init(namespace: "empty-query", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 0)
    XCTAssertTrue(window.rowIdentities.isEmpty)
    await window.requestRows(at: [0])
    XCTAssertEqual(window.state, .ready)
    await window.reload(
      query: .init(text: "ACTÍVITY 064", completion: .all, archive: .all),
      identity: .init(namespace: "corrected-query", savedRevision: UUID()))
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 1)
    XCTAssertEqual(window.rowIdentities, [.source(.init(kind: .item, id: fixture.identifiers[64]))])
    guard case .loaded(let item) = window.presentation(at: 0) else {
      XCTFail("A valid retry must show its own filtered Item rather than the prior query's page.")
      return
    }
    XCTAssertEqual(item.id, fixture.identifiers[64])
    XCTAssertEqual(item.row.title, "Activity 064")
  }

  func testConcurrentIdenticalVisibilityRequestsKeepOneConsistentWindow() async throws {
    let fixture = try await makeFixture(itemCount: 193)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "concurrent-page-requests", savedRevision: UUID()))
    async let firstRequest: Void = window.requestRows(at: [128])
    async let repeatedRequest: Void = window.requestRows(at: [128])
    _ = await (firstRequest, repeatedRequest)
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(
      window.rowIdentities, fixture.identifiers.map { .source(.init(kind: .item, id: $0)) })
    XCTAssertEqual(window.matchingCount, 193)
    for (index, title) in [(64, "Activity 064"), (128, "Activity 128"), (192, "Activity 192")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("Repeated visibility requests must leave one complete current window.")
        return
      }
      XCTAssertEqual(item.id, fixture.identifiers[index])
      XCTAssertEqual(item.row.title, title)
    }
    guard case .loading = window.presentation(at: 0) else {
      XCTFail("Concurrent requests must retain the same offscreen-page budget.")
      return
    }
  }

  func testPreCanceledVisibilityRequestPreservesTheCurrentWindow() async throws {
    let fixture = try await makeFixture(itemCount: 193)
    let window = SavedItemWindow(planner: fixture.planner, session: fixture.session)
    await window.reload(
      query: .init(completion: .all, archive: .all),
      identity: .init(namespace: "canceled-visibility", savedRevision: UUID()))
    await window.requestRows(at: [192])
    let canceledRequest = Task { @MainActor in await window.requestRows(at: [0]) }
    canceledRequest.cancel()
    await canceledRequest.value
    XCTAssertEqual(window.state, .ready)
    XCTAssertEqual(window.matchingCount, 193)
    XCTAssertEqual(
      window.rowIdentities, fixture.identifiers.map { .source(.init(kind: .item, id: $0)) })
    for (index, title) in [(128, "Activity 128"), (192, "Activity 192")] {
      guard case .loaded(let item) = window.presentation(at: index) else {
        XCTFail("A pre-canceled visibility request must not release the current presentations.")
        return
      }
      XCTAssertEqual(item.id, fixture.identifiers[index])
      XCTAssertEqual(item.row.title, title)
    }
    guard case .loading = window.presentation(at: 0) else {
      XCTFail("A pre-canceled visibility request must not replace the current window.")
      return
    }
  }

  private struct Fixture {
    let directory: URL
    let planner: PlannerCore.Planner
    let session: PlannerDatasetSession
    let identifiers: [UUID]
    let listIdentifier: UUID?
    let membershipIdentifiers: [UUID]
  }

  private func applyFixtureCommand(_ command: PlannerCommand, fixture: Fixture) async throws
    -> PlannerAppliedResult
  {
    let result = await fixture.planner.execute(
      .init(operationId: UUID(), session: fixture.session, command: command))
    guard case .applied(let applied, .complete) = result.outcome else {
      XCTFail("The public fixture command must save completely: \(result.outcome)")
      throw CancellationError()
    }
    return applied
  }

  private func makeFixture(itemCount: Int, listName: String? = nil) async throws -> Fixture {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerItemWindowFixtures", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    print("Planner Item-window fixture directory: \(directory.path)")
    let planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      throw CancellationError()
    }
    var expectedIdentifiers: [UUID] = []
    let listIdentifier = listName.map { _ in UUID() }
    let listLifetimeIdentifier = UUID()
    var membershipIdentifiers: [UUID] = []
    var memberships: [[String: Any]] = []
    var sources: [[String: Any]] = []
    for index in 0..<itemCount {
      let identifier = UUID()
      let lifetimeIdentifier = UUID()
      expectedIdentifiers.append(identifier)
      sources.append([
        "kind": "item", "id": identifier.uuidString, "lifetimeId": lifetimeIdentifier.uuidString,
        "createdAt": 813_000_000 + index, "updatedAt": 813_000_000 + index,
        "content": [
          "title": String(format: "Activity %03d", index), "subtitle": NSNull(),
          "notes": NSNull(), "location": NSNull(), "estimate": NSNull(),
        ],
        "globalDone": false, "archived": false, "contentOrigins": ["title": "independent"],
      ])
      if let listIdentifier {
        let membershipIdentifier = UUID()
        membershipIdentifiers.append(membershipIdentifier)
        memberships.append([
          "id": membershipIdentifier.uuidString, "lifetimeId": UUID().uuidString,
          "list": [
            "kind": "list", "id": listIdentifier.uuidString,
            "lifetimeId": listLifetimeIdentifier.uuidString,
          ],
          "item": [
            "kind": "item", "id": identifier.uuidString,
            "lifetimeId": lifetimeIdentifier.uuidString,
          ],
          "rank": String(index * 1024), "localDone": false,
        ])
      }
    }
    if let listIdentifier, let listName {
      sources.append([
        "kind": "list", "id": listIdentifier.uuidString,
        "lifetimeId": listLifetimeIdentifier.uuidString,
        "createdAt": 813_000_000, "updatedAt": 813_000_000,
        "content": [
          "name": listName, "notes": NSNull(), "color": NSNull(),
          "iconName": NSNull(), "manualEstimate": NSNull(),
        ],
        "globalDone": NSNull(), "archived": false, "contentOrigins": ["name": "independent"],
      ])
    }
    let data = try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 2, "sources": sources,
      "memberships": memberships, "itineraryEntries": [], "schedules": [],
      "labelAssociations": [], "ownedLinks": [], "completionChanges": [],
      "expandedCompletions": [], "contextAliases": [], "restorationFamilies": [],
      "deletionMarkers": [],
    ])
    let decoded = planner.decodeImport(data)
    guard case .decoded(let backup) = decoded else {
      XCTFail("The public fixture import must decode: \(decoded)")
      throw CancellationError()
    }
    let reviewed = await planner.prepareReview(
      session: datasetSession, command: .applyImport(backup: backup))
    guard case .reviewed(let review) = reviewed else {
      XCTFail("The public fixture import must be reviewable: \(reviewed)")
      throw CancellationError()
    }
    let executed = await planner.execute(
      .init(
        operationId: UUID(), session: datasetSession, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(_, .complete) = executed.outcome else {
      XCTFail("The public fixture import must save completely: \(executed.outcome)")
      throw CancellationError()
    }
    return Fixture(
      directory: directory, planner: planner, session: datasetSession,
      identifiers: expectedIdentifiers, listIdentifier: listIdentifier,
      membershipIdentifiers: membershipIdentifiers)
  }
}
