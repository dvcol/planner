import Foundation
import PlannerCore
import Testing

struct ItemInListCreationAdmissionTests {
  @Test func invalidContentAndUnavailableDestinationsRejectBeforeAnyGraphOrReceiptChange()
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
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let list = try #require(
      try await save(.createList(content: .init(name: "Tokyo"))).generated.first)
    let archived = try #require(
      try await save(.createList(content: .init(name: "Archived"))).generated.first)
    let deleted = try #require(
      try await save(.createList(content: .init(name: "Deleted"))).generated.first)
    _ = try await save(.setArchive(source: archived, archived: true))
    guard
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: deleted)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let missingIdentifier = UUID()
    let attempts: [(PlannerCommand, String)] = [
      (
        .createItem(content: .init(title: "Missing destination"), listId: missingIdentifier),
        "missingReference"
      ),
      (
        .createItem(content: .init(title: "Archived destination"), listId: archived.id),
        "missingReference"
      ),
      (
        .createItem(content: .init(title: "Deleted destination"), listId: deleted.id),
        "missingReference"
      ),
      (.createItem(content: .init(title: " \n\t"), listId: list.id), "invalidInput"),
      (
        .createItem(
          content: .init(
            title: "Invalid coordinates",
            location: .init(
              displayName: nil, formattedAddress: nil, coordinate: .init(latitude: 91, longitude: 0)
            )), listId: list.id), "invalidInput"
      ),
      (
        .createItem(
          content: .init(
            title: "Invalid link", links: [.init(originalUrl: "file:///private/tmp/invalid")]),
          listId: list.id), "invalidInput"
      ),
      (
        .createItem(
          content: .init(title: "Invalid label", categoryIds: [missingIdentifier]), listId: list.id),
        "missingReference"
      ),
    ]
    for (command, code) in attempts {
      let operationIdentifier = UUID()
      guard
        case .rejected(let failure) = await planner.execute(
          .init(operationId: operationIdentifier, session: session, command: command)
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier),
        case .exported(let unchanged) = await planner.exportData(session: session)
      else {
        Issue.record(
          "Reject the entire invalid ordinary creation before saving data or operation evidence.")
        return
      }
      #expect(failure.code == code)
      #expect(unchanged == before)
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let retained) = await reopened.exportData(session: reopenedSession),
      case .snapshot(let empty) = await reopened.query(
        .init(session: reopenedSession, request: .items(.init(completion: .all, archive: .all)))),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    #expect(retained == before && empty.matchingCount == 0)
    #expect(namespace.preparedProposals.isEmpty)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 5)
  }
  @Test func restoredDestinationChangesItsBindingAndOldReplayCannotRestoreMembership() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "PlannerQ93Store-" + UUID().uuidString)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func apply(
      _ command: PlannerCommand, operationIdentifier: UUID = UUID(),
      reviewToken: PlannerReviewToken? = nil
    ) async throws -> (result: PlannerAppliedResult, checkpoint: Int64) {
      guard
        case .applied(let result, .complete(let checkpoint)) = await planner.execute(
          .init(
            operationId: operationIdentifier, session: session, command: command,
            reviewToken: reviewToken)
        ).outcome
      else { throw CancellationError() }
      return (result, checkpoint)
    }
    let listCreation = try await apply(.createList(content: .init(name: "Tokyo")))
    let list = try #require(listCreation.result.generated.first)
    guard
      case .source(.list(let originalList)) = await planner.read(
        session: session, request: .source(list)),
      case .exported(let emptyListData) = await planner.exportData(session: session),
      case .decoded(let backup) = planner.decodeImport(emptyListData)
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    let originalCommand = PlannerCommand.createItem(
      content: .init(title: "Hotel", notes: "Keep original source"), listId: list.id)
    let creation = try await apply(originalCommand, operationIdentifier: operationIdentifier)
    let hotel = try #require(creation.result.generated.first)
    let pendingCommand = PlannerCommand.createItem(content: .init(title: "Museum"), listId: list.id)
    guard
      case .reviewed(let originalReview) = await planner.prepareReview(
        session: session, command: pendingCommand),
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: list))
    else { throw CancellationError() }
    _ = try await apply(deletion.command, reviewToken: deletion.reviewToken)
    guard
      case .reviewed(let restoration) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true))
    else { throw CancellationError() }
    _ = try await apply(restoration.command, reviewToken: restoration.reviewToken)
    guard
      case .source(.list(let restored)) = await planner.read(
        session: session, request: .source(list)),
      case .exported(let restoredData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(restored.source == list && restored.content.name == "Tokyo")
    #expect(restored.fieldHashes[.name] != originalList.fieldHashes[.name])
    #expect(restored.references.isEmpty)
    let replay = try await apply(originalCommand, operationIdentifier: operationIdentifier)
    #expect(replay.result == creation.result && replay.checkpoint == creation.checkpoint)
    let staleIdentifier = UUID()
    guard
      case .rejected(let stale) = await planner.execute(
        .init(
          operationId: staleIdentifier, session: session, command: pendingCommand,
          reviewToken: originalReview.reviewToken)
      ).outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: staleIdentifier),
      case .exported(let unchanged) = await planner.exportData(session: session),
      case .snapshot(let beforeCreation) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { throw CancellationError() }
    #expect(stale.code == "staleReview")
    #expect(unchanged == restoredData && beforeCreation.matchingCount == 1)
    guard
      case .reviewed(let freshReview) = await planner.prepareReview(
        session: session, command: pendingCommand)
    else { throw CancellationError() }
    #expect(freshReview.targets == [.source(list)])
    let newCreation = try await apply(freshReview.command, reviewToken: freshReview.reviewToken)
    let museum = try #require(newCreation.result.generated.first)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let populated)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.item(let retainedHotel)) = await reopened.read(
        session: reopenedSession, request: .source(hotel))
    else { throw CancellationError() }
    #expect(
      retainedHotel.content.title == "Hotel"
        && retainedHotel.content.notes == "Keep original source")
    #expect(populated.progress.totalCount == 1 && populated.progress.doneCount == 0)
    #expect(populated.references.count == 1)
    #expect(
      populated.references.contains { reference in
        guard case .membership(_, let owner, let source) = reference else { return false }
        return owner == list && source == museum
      })
  }
  @Test func creationReviewCannotAuthorizeChangedContentAnotherListOrAnOmittedDestination()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "PlannerQ93Store-" + UUID().uuidString)
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let first, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      case .applied(let second, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Wishlist")))
      ).outcome,
      let list = first.generated.first, let other = second.generated.first,
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .createItem(content: .init(title: "Museum"), listId: list.id)),
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let changes: [PlannerCommand] = [
      .createItem(content: .init(title: "Changed title"), listId: list.id),
      .createItem(content: .init(title: "Museum"), listId: other.id),
      .createItem(content: .init(title: "Museum")),
    ]
    for command in changes {
      let operationIdentifier = UUID()
      let response = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session, command: command,
          reviewToken: review.reviewToken))
      guard case .rejected(let failure) = response.outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier),
        case .exported(let after) = await planner.exportData(session: session)
      else {
        Issue.record(
          "A changed reviewed command must not create data, including a destination-free Item: \(response.outcome)"
        )
        return
      }
      #expect(failure.code == "staleReview")
      #expect(after == before)
    }
  }
}
