import Foundation
import PlannerCore
import Testing

struct CategoryRecoveryTests {
  @Test func existingDomainCommandsRetainCategoryContentAndIdentityInEveryCheckpoint() async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createCategory(
            content: PlannerCategoryContentInput(
              name: "Food", color: PlannerColor(red: 0, green: 0.5, blue: 1, alpha: 1),
              iconName: "fork.knife")))
      ).outcome,
      let category = created.generated.first,
      case .source(.category(let original)) = await planner.read(
        session: session, request: .source(category))
    else {
      Issue.record("Save the shared Category before changing unrelated Planner data.")
      return
    }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let outcome = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: command)
      ).outcome
      guard case .applied(let result, .complete(let checkpoint)) = outcome,
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
        case .source(.category(let current)) = await planner.read(
          session: session, request: .source(category))
      else {
        Issue.record("Every domain command must save with complete recovery: \(outcome)")
        throw MissingSavedResult()
      }
      let recovered = recovery.decodedBackup.backup.sources.compactMap {
        source -> PlannerPortableCategory? in
        guard case .category(let value) = source else { return nil }
        return value
      }
      #expect(recovered.count == 1)
      #expect(recovered.first?.id == category.id)
      #expect(recovered.first?.lifetimeId == original.sourceLifetimeId)
      #expect(recovered.first?.content == original.content)
      #expect(recovered.first?.createdAt == original.createdAt)
      #expect(recovered.first?.updatedAt == original.updatedAt)
      #expect(current.fieldHashes == original.fieldHashes)
      #expect(current.updatedAt == original.updatedAt)
      #expect(namespace.preparedProposals.isEmpty)
      return result
    }
    let item = try #require(
      try await save(.createItem(content: PlannerItemContentInput(title: "Hotel"))).generated.first)
    let secondItem = try #require(
      try await save(.createItem(content: PlannerItemContentInput(title: "Museum"))).generated.first
    )
    let list = try #require(
      try await save(.createList(content: PlannerListContentInput(name: "Tokyo"))).generated.first)
    let destination = try #require(
      try await save(.createList(content: PlannerListContentInput(name: "Wishlist"))).generated
        .first)
    guard
      case .source(.item(let itemRead)) = await planner.read(
        session: session, request: .source(item)),
      case .source(.list(let listRead)) = await planner.read(
        session: session, request: .source(list))
    else {
      Issue.record("Read the current content guards before editing unrelated sources.")
      return
    }
    _ = try await save(
      .editItem(
        sourceId: item.id, changes: PlannerItemChanges(notes: .set("Keep")),
        expectedFieldHashes: itemRead.fieldHashes))
    _ = try await save(
      .editList(
        sourceId: list.id, changes: PlannerListChanges(notes: .set("Friday")),
        expectedFieldHashes: listRead.fieldHashes))
    _ = try await save(.setCompletion(scope: .globalItem(itemId: item.id), done: true))
    _ = try await save(.setArchive(source: item, archived: true))
    _ = try await save(.setArchive(source: list, archived: true))
    let membership = try #require(
      try await save(
        .addMembership(
          itemId: item.id, listId: list.id, placement: .last)
      ).generatedReferences.first)
    let secondMembership = try #require(
      try await save(
        .addMembership(
          itemId: secondItem.id, listId: list.id, placement: .last)
      ).generatedReferences.first)
    guard case .membership(let membershipId, _, _) = membership,
      case .membership(let secondMembershipId, _, _) = secondMembership
    else {
      Issue.record("Membership commands must return association identities.")
      return
    }
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .listMembership(
            listId: list.id, membershipId: membershipId)), done: true))
    _ = try await save(
      .reorderMembership(
        listId: list.id, membershipId: membershipId,
        placement: .after(associationId: secondMembershipId)))
    _ = try await save(
      .moveMembership(
        listId: list.id, membershipId: membershipId,
        destinationListId: destination.id, placement: .last))
    _ = try await save(.removeMembership(listId: list.id, membershipId: secondMembershipId))
    let schedule = try #require(
      try await save(
        .createSchedule(
          source: item,
          form: .timed(
            start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
            planningTimeZone: "Asia/Tokyo"))
      ).generated.first)
    guard
      case .source(.schedule(let beforeEdit)) = await planner.read(
        session: session, request: .source(schedule))
    else {
      Issue.record("Read the Schedule form guard before editing it.")
      return
    }
    _ = try await save(
      .editSchedule(
        scheduleId: schedule.id,
        changes: PlannerScheduleChanges(
          form: .timed(
            start: Date(timeIntervalSinceReferenceDate: 813_200_500), end: nil,
            planningTimeZone: "Asia/Tokyo")),
        expectedFieldHashes: beforeEdit.fieldHashes))
    guard
      case .source(.schedule(let beforeZone)) = await planner.read(
        session: session, request: .source(schedule))
    else {
      Issue.record("Read the changed Schedule before changing its planning zone.")
      return
    }
    _ = try await save(
      .changeScheduleZone(
        scheduleId: schedule.id, planningTimeZone: "Europe/Paris",
        expectedFieldHashes: beforeZone.fieldHashes))
    _ = try await save(.removeSchedule(scheduleId: schedule.id))
  }

  private struct MissingSavedResult: Error {}
}
