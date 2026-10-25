import Foundation
import PlannerCore

@MainActor
enum PlannerPostClosureCompletionFixture {
  static func makeStore(directory: URL) async throws -> SavedPlannerStore {
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let existing) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { throw CancellationError() }
    if existing.matchingCount == 0 {
      try await seed(planner: planner, session: session)
    }
    return SavedPlannerStore(configuration: configuration)
  }

  private static func seed(planner: PlannerCore.Planner, session: PlannerDatasetSession)
    async throws
  {
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let result = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let applied, .complete) = result.outcome else {
        throw CancellationError()
      }
      return applied
    }
    guard
      let item = try await save(
        .createItem(content: .init(title: "Post-closure museum", notes: "Keep the museum notes"))
      )
      .generated.first,
      let list = try await save(.createList(content: .init(name: "Post-closure food")))
        .generated.first,
      let itinerary = try await save(.createItinerary(content: .init(title: "Post-closure route")))
        .generated.first,
      case .membership(let membershipIdentifier, _, _)? = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    var entryIdentifiers: [UUID] = []
    for source in [list, list, item] {
      guard
        case .itineraryEntry(let identifier, _, _)? = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first
      else { throw CancellationError() }
      entryIdentifiers.append(identifier)
    }
    let first = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entryIdentifiers[0],
      membershipId: membershipIdentifier)
    _ = try await save(.setCompletion(scope: .appearance(first), done: true))
    guard case .exported(let data) = await planner.exportData(session: session),
      var incoming = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { throw CancellationError() }
    incoming["expandedCompletions"] = []
    incoming["contextAliases"] = []
    incoming["completionChanges"] = []
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .appearance(let cleared) = await planner.read(
        session: session, request: .appearance(first)),
      case .exported(let clearedData) = await planner.exportData(session: session),
      case .decoded(let clearedBackup) = planner.decodeImport(clearedData)
    else { throw CancellationError() }
    guard !cleared.localDone, !cleared.globalDone,
      clearedBackup.backup.deletionMarkers.contains(where: { marker in
        if case .expandedCompletion = marker.target { return true }
        return false
      })
    else { throw CancellationError() }
  }
}
