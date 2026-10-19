import AppIntents
import Foundation
import PlannerCore
import SwiftData
import XCTest

@testable import Planner

@MainActor
final class PlannerItemIntentTests: XCTestCase {
  func testCreationCancelledBeforeInvocationLeavesNoSavedItem() async throws {
    let fixture = try makeStorage()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    AppDependencyManager.shared.add(dependency: fixture.store)
    var creation = CreatePlannerItemIntent()
    creation.title = "Cancelled before invocation"
    let request = Task { try await creation.callAsFunction(donate: false) }
    request.cancel()
    do {
      _ = try await request.value
      XCTFail("A cancelled invocation must not begin a new mutation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    var query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.suggestedEntities()
    XCTAssertTrue(choices.isEmpty)
    XCTAssertFalse(fixture.store.isSaving)
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testInvalidCreationAndMissingItemReadFailWithoutCreatingData() async throws {
    let fixture = try makeStorage()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    AppDependencyManager.shared.add(dependency: fixture.store)
    var creation = CreatePlannerItemIntent()
    creation.title = "   "
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("A blank title cannot produce a saved Item.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    var query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    let suggestions = try await query.suggestedEntities()
    XCTAssertTrue(suggestions.isEmpty)
    var reading = GetPlannerItemIntent()
    reading.item = PlannerItemEntity(id: UUID(), title: "Missing", done: false, archived: false)
    do {
      _ = try await reading.callAsFunction(donate: false)
      XCTFail("A cached entity cannot invent a missing Item.")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("no longer available"))
    }
    XCTAssertFalse(fixture.store.recoveryBlocked)
  }

  func testUnavailableStorageThrowsInsteadOfReturningEmptyChoicesOrClaimingCreation() async throws {
    let fixture = try makeStorage()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    try Data("The store parent is a file, not a directory.".utf8).write(
      to: fixture.directory.appending(path: "store"))
    AppDependencyManager.shared.add(dependency: fixture.store)
    var query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    do {
      _ = try await query.suggestedEntities()
      XCTFail("Unavailable storage must not become an empty successful result.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    var creation = CreatePlannerItemIntent()
    creation.title = "Cannot save here"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("Unavailable storage cannot acknowledge creation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    XCTAssertFalse(fixture.store.isReady)
    XCTAssertFalse(fixture.store.isSaving)
    XCTAssertNotNil(fixture.store.openingFailure)
  }

  func testEntityChoicesReadBeyondOnePageInCanonicalOrder() async throws {
    let fixture = try makeStorage()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let planner = PlannerCore.Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    var identities: [UUID] = []
    for index in 0..<65 {
      guard
        case .applied(let saved, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createItem(content: .init(title: String(format: "Visit %02d", index))))
        )
        .outcome,
        let item = saved.generated.first(where: { $0.kind == .item })
      else { return XCTFail("Every real fixture Item must save successfully.") }
      identities.append(item.id)
    }
    var query = PlannerItemEntityQuery()
    query.plannerStore = fixture.store
    let choices = try await query.entities(matching: "VISIT")
    XCTAssertEqual(choices.map(\.id), identities)
    XCTAssertEqual(choices.first?.title, "Visit 00")
    XCTAssertEqual(choices.last?.title, "Visit 64")
    XCTAssertEqual(Set(choices.map(\.id)).count, 65)
  }

  func testAppliedCreationWithIncompleteRecoveryReturnsItsItemAndBlocksFurtherIntentChanges()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    await store.open()
    XCTAssertTrue(store.isReady)
    let obstruction = IntentRecoverySaveObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    var creation = CreatePlannerItemIntent()
    creation.title = "Recovery museum"
    let applied = try await creation.callAsFunction(donate: false)
    XCTAssertEqual(applied.title, "Recovery museum")
    XCTAssertTrue(obstruction.didObstruct)
    XCTAssertTrue(store.recoveryBlocked)
    XCTAssertEqual(store.incompleteRecoveryOperationIdentifiers.count, 1)
    XCTAssertFalse(store.isSaving)
    creation.title = "Must not be created"
    do {
      _ = try await creation.callAsFunction(donate: false)
      XCTFail("An incomplete recovery copy must block a later Intent mutation.")
    } catch {
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    NotificationCenter.default.removeObserver(observer)
    try obstruction.restore()
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("The locally applied Item must remain readable.") }
    XCTAssertEqual(snapshot.rows, [.source(.init(kind: .item, id: applied.id))])
    await store.retryIncompleteRecovery()
    XCTAssertFalse(store.recoveryBlocked)
    XCTAssertTrue(store.incompleteRecoveryOperationIdentifiers.isEmpty)
    creation.title = "Allowed after recovery retry"
    let next = try await creation.callAsFunction(donate: false)
    XCTAssertNotEqual(next.id, applied.id)
    guard
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: applied.id)))
    else { return XCTFail("Recovery retry must not replace the original applied Item.") }
    XCTAssertEqual(original.content.title, "Recovery museum")
  }

  func testConcurrentCreateIntentsKeepBothRequestsAndAwaitTheSameStoreOpening() async throws {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var firstCreation = CreatePlannerItemIntent()
    firstCreation.title = "Train tickets"
    var secondCreation = CreatePlannerItemIntent()
    secondCreation.title = "Hotel check-in"
    func invoke(_ intent: CreatePlannerItemIntent) async -> Result<PlannerItemEntity, any Error> {
      do { return .success(try await intent.callAsFunction(donate: false)) } catch {
        return .failure(error)
      }
    }
    async let firstResult = invoke(firstCreation)
    async let secondResult = invoke(secondCreation)
    let (firstOutcome, secondOutcome) = await (firstResult, secondResult)
    let outcomes = XCTAttachment(
      string: "First: \(firstOutcome)\nSecond: \(secondOutcome)\nSaving: \(store.isSaving)")
    outcomes.name = "Both actual Intent requests finish before fixture cleanup"
    outcomes.lifetime = .keepAlways
    add(outcomes)
    let firstItem = try firstOutcome.get()
    let secondItem = try secondOutcome.get()
    XCTAssertEqual(firstItem.title, "Train tickets")
    XCTAssertEqual(secondItem.title, "Hotel check-in")
    XCTAssertNotEqual(firstItem.id, secondItem.id)
    XCTAssertTrue(store.isReady)
    XCTAssertFalse(store.isSaving)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all))))
    else { return XCTFail("Both real operations must remain readable after reopening.") }
    XCTAssertEqual(
      snapshot.rows,
      [
        .source(.init(kind: .item, id: secondItem.id)),
        .source(.init(kind: .item, id: firstItem.id)),
      ])
  }

  func testGlobalCompletionIntentPreservesIndependentListFlagsWhenTheItemIsReopened()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerItemIntent()
    creation.title = "Museum"
    creation.notes = "Keep the shared notes"
    let item = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      return XCTFail("The Item's current real dataset must be ready.")
    }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      let operation = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = operation.outcome else {
        throw CancellationError()
      }
      return result
    }
    var appearances: [PlannerAppearance] = []
    for name in ["Tokyo", "Wishlist"] {
      let listCreation = try await save(.createList(content: .init(name: name)))
      let list = try XCTUnwrap(listCreation.generated.first)
      let membership = try await save(
        .addMembership(itemId: item.id, listId: list.id, placement: .last))
      guard case .membership(let membershipIdentifier, _, _)? = membership.generatedReferences.first
      else { return XCTFail("The original List association must have its own identity.") }
      appearances.append(.listMembership(listId: list.id, membershipId: membershipIdentifier))
    }
    _ = try await save(.setCompletion(scope: .appearance(appearances[0]), done: true))
    var completion = SetPlannerItemCompletionIntent()
    completion.item = item
    completion.done = true
    let _: Void = try await completion.callAsFunction(donate: false)
    for (index, appearance) in appearances.enumerated() {
      guard
        case .appearance(let current) = await planner.read(
          session: session, request: .appearance(appearance))
      else { return XCTFail("The original appearance must remain readable.") }
      XCTAssertTrue(current.globalDone)
      XCTAssertTrue(current.effectiveDone)
      XCTAssertEqual(current.localDone, index == 0)
      XCTAssertEqual(current.content.notes, "Keep the shared notes")
    }
    completion.done = false
    let _: Void = try await completion.callAsFunction(donate: false)
    for (index, appearance) in appearances.enumerated() {
      guard
        case .appearance(let current) = await planner.read(
          session: session, request: .appearance(appearance))
      else { return XCTFail("Reopening cannot remove either original association.") }
      XCTAssertFalse(current.globalDone)
      XCTAssertEqual(current.localDone, index == 0)
      XCTAssertEqual(current.effectiveDone, index == 0)
      XCTAssertFalse(current.archived)
    }
  }

  func testEntityQueriesResolveCurrentValuesAndCanonicalSearchWithoutInventingMissingItems()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var creation = CreatePlannerItemIntent()
    creation.title = "Train tickets"
    creation.notes = "Collect at the station"
    let cached = try await creation.callAsFunction(donate: false)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .source(.item(let current)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: cached.id))),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: cached.id, changes: .init(title: .set("Revised tickets")),
            expectedFieldHashes: current.fieldHashes))
      )
      .outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: cached.id), done: true))
      )
      .outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setArchive(source: .init(kind: .item, id: cached.id), archived: true))
      )
      .outcome
    else { return XCTFail("Real Core edits must prepare the changed source.") }
    var query = PlannerItemEntityQuery()
    query.plannerStore = store
    let resolved = try await query.entities(for: [cached.id, cached.id, UUID()])
    XCTAssertEqual(resolved.map(\.id), [cached.id])
    XCTAssertEqual(resolved.first?.title, "Revised tickets")
    XCTAssertEqual(resolved.first?.done, true)
    XCTAssertEqual(resolved.first?.archived, true)
    let matches = try await query.entities(matching: "STATION")
    XCTAssertEqual(matches.map(\.id), [cached.id])
    let missing = try await query.entities(matching: "No such visit")
    XCTAssertTrue(missing.isEmpty)
    let suggestions = try await query.suggestedEntities()
    XCTAssertEqual(suggestions.map(\.id), [cached.id])
    var reading = GetPlannerItemIntent()
    reading.item = cached
    let refreshed = try await reading.callAsFunction(donate: false)
    XCTAssertEqual(refreshed.id, cached.id)
    XCTAssertEqual(refreshed.title, "Revised tickets")
    XCTAssertTrue(refreshed.done)
    XCTAssertTrue(refreshed.archived)
  }

  func testCreateIntentReturnsTheSingleSavedIdentityAndPreservesContentAndRecoveryAfterReopen()
    async throws
  {
    let (directory, configuration, store) = try makeStorage()
    defer { try? FileManager.default.removeItem(at: directory) }
    AppDependencyManager.shared.add(dependency: store)
    var intent = CreatePlannerItemIntent()
    intent.title = "Train tickets"
    intent.notes = "Collect at the station"
    let created = try await intent.callAsFunction(donate: false)
    XCTAssertEqual(created.title, "Train tickets")
    XCTAssertFalse(created.done)
    XCTAssertFalse(created.archived)
    XCTAssertTrue(store.isReady)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let saved)) = await reopened.read(
        session: session, request: .source(.init(kind: .item, id: created.id))),
      case .snapshot(let items) = await reopened.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all)))),
      case .status(let status) = await reopened.read(session: session, request: .status)
    else { return XCTFail("The returned Item must be readable from reopened real storage.") }
    XCTAssertEqual(items.rows, [.source(saved.source)])
    XCTAssertEqual(saved.source.id, created.id)
    XCTAssertEqual(saved.content.title, "Train tickets")
    XCTAssertEqual(saved.content.notes, "Collect at the station")
    guard case .known(let checkpoint, let incomplete, let blocked) = status.recovery else {
      return XCTFail("The actual recovery status must remain available.")
    }
    XCTAssertNotNil(checkpoint)
    XCTAssertTrue(incomplete.isEmpty)
    XCTAssertFalse(blocked)
  }
  private func makeStorage() throws -> (
    directory: URL, configuration: PlannerStorageConfiguration, store: SavedPlannerStore
  ) {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "PlannerItemIntentTests/\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appending(path: "store/Planner.sqlite"),
      controlURL: directory.appending(path: "control/writer"),
      recoveryDirectoryURL: directory.appending(path: "recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    return (directory, configuration, SavedPlannerStore(configuration: configuration))
  }

}

private final class IntentRecoverySaveObstruction: @unchecked Sendable {
  private let lock = NSLock()
  private let storeURL: URL
  private let recoveryURL: URL
  private let retainedURL: URL
  private var obstructed = false

  init(configuration: PlannerStorageConfiguration) {
    storeURL = configuration.storeURL.standardizedFileURL
    recoveryURL = configuration.recoveryDirectoryURL
    retainedURL = recoveryURL.deletingLastPathComponent()
      .appendingPathComponent("retained-after-native-save")
  }

  var didObstruct: Bool { lock.withLock { obstructed } }

  func observe(_ notification: Notification) {
    guard let context = notification.object as? ModelContext,
      context.container.configurations.contains(where: { $0.url.standardizedFileURL == storeURL })
    else { return }
    lock.withLock {
      guard !obstructed else { return }
      do {
        try FileManager.default.moveItem(at: recoveryURL, to: retainedURL)
        try Data("Obstruct recovery after native save.".utf8).write(to: recoveryURL)
        obstructed = true
      } catch { return }
    }
  }

  func restore() throws {
    guard FileManager.default.fileExists(atPath: retainedURL.path) else { return }
    if FileManager.default.fileExists(atPath: recoveryURL.path) {
      try FileManager.default.removeItem(at: recoveryURL)
    }
    try FileManager.default.moveItem(at: retainedURL, to: recoveryURL)
  }
}
