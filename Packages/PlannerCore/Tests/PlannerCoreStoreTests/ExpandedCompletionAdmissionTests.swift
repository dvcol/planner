import Foundation
import PlannerCore
import Testing

struct ExpandedCompletionAdmissionTests {
  @Test func missingAndCrossContextAppearancesRejectWithoutGlobalFallbackOrRecoveryChanges()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
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
    let firstList = try #require(
      try await save(.createList(content: .init(name: "A"))).generated.first)
    let secondList = try #require(
      try await save(.createList(content: .init(name: "B"))).generated.first)
    let itinerary = try #require(
      try await save(.createItinerary(content: .init(title: "Route"))).generated.first)
    let firstMembership = try #require(
      try await save(.addMembership(itemId: item.id, listId: firstList.id, placement: .last))
        .generatedReferences.first)
    let secondMembership = try #require(
      try await save(.addMembership(itemId: item.id, listId: secondList.id, placement: .last))
        .generatedReferences.first)
    var entryIds: [UUID] = []
    for source in [firstList, secondList, item] {
      let reference = try #require(
        try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last)
        ).generatedReferences.first)
      guard case .itineraryEntry(let identifier, _, _) = reference else {
        throw CancellationError()
      }
      entryIds.append(identifier)
    }
    guard case .membership(let firstMembershipId, _, _) = firstMembership,
      case .membership(let secondMembershipId, _, _) = secondMembership,
      case .source(.itinerary(let original)) = await planner.read(
        session: session, request: .source(itinerary))
    else { throw CancellationError() }
    let valid = PlannerAppearance.expandedListItem(
      itineraryId: itinerary.id, listEntryId: entryIds[0], membershipId: firstMembershipId)
    _ = try await save(.setCompletion(scope: .appearance(valid), done: false))
    let invalid = [
      PlannerAppearance.expandedListItem(
        itineraryId: UUID(), listEntryId: entryIds[0], membershipId: firstMembershipId),
      .expandedListItem(
        itineraryId: itinerary.id, listEntryId: UUID(), membershipId: firstMembershipId),
      .expandedListItem(
        itineraryId: itinerary.id, listEntryId: entryIds[2], membershipId: firstMembershipId),
      .expandedListItem(itineraryId: itinerary.id, listEntryId: entryIds[0], membershipId: UUID()),
      .expandedListItem(
        itineraryId: itinerary.id, listEntryId: entryIds[0], membershipId: secondMembershipId),
    ]
    for appearance in invalid {
      let operationId = UUID()
      guard
        case .failed(let readFailure) = await planner.read(
          session: session, request: .appearance(appearance)),
        case .rejected(let failure) = await planner.execute(
          .init(
            operationId: operationId, session: session,
            command: .setCompletion(scope: .appearance(appearance), done: true))
        ).outcome,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationId)
      else { throw CancellationError() }
      #expect(readFailure.code == "missingReference")
      #expect(failure.code == "missingReference")
    }
    guard
      case .source(.itinerary(let retained)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .source(.item(let itemRead)) = await planner.read(
        session: session, request: .source(item)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 10)
      )
    else { throw CancellationError() }
    #expect(retained.updatedAt == original.updatedAt)
    #expect(retained.fieldHashes == original.fieldHashes)
    #expect(retained.references == original.references)
    #expect(retained.progress.doneCount == 0)
    #expect(retained.progress.totalCount == 3)
    #expect(itemRead.state.globalDone == false)
    #expect(recovery.decodedBackup.backup.expandedCompletions.isEmpty)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == 10)
    #expect(namespace.preparedProposals.isEmpty)
  }
}
