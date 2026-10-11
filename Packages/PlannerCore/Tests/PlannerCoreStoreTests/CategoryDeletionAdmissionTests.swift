import Foundation
import PlannerCore
import SwiftData
import Testing

struct CategoryDeletionAdmissionTests {
  @Test func postSaveRecoveryFailureRetainsDeletionAndBlocksLaterWritesAfterRelaunch() async throws
  {
    let fixture = try await CategoryDeletionFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let before = try await fixture.recovery()
    let review = try await fixture.review()
    let obstruction = NativeSaveRecoveryObstruction(configuration: fixture.configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let operationId = UUID()
    let outcome = await fixture.planner.execute(
      .init(
        operationId: operationId, session: fixture.session, command: review.command,
        reviewToken: review.reviewToken)
    ).outcome
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    guard case .applied(let applied, .incomplete(let failure)) = outcome else {
      Issue.record(
        "A saved deletion must remain applied when checkpoint publication fails: \(outcome)")
      return
    }
    #expect(failure.code == "recoveryIncomplete")
    try obstruction.restore()
    #expect(try await fixture.itemRead().content.categoryIds.isEmpty)
    #expect(try await fixture.recovery().portableData == before.portableData)
    let reopened = Planner(configuration: fixture.configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .failed(let missing) = await reopened.read(
        session: session, request: .source(fixture.category)),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(fixture.item)),
      case .appliedRecoveryIncomplete(let statusResult, _) = await reopened.operationStatus(
        session: session, operationId: operationId),
      case .applied(let replay, .incomplete) = await reopened.execute(
        .init(
          operationId: operationId, session: session, command: review.command)
      ).outcome,
      case .rejected(let blocked) = await reopened.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createTag(content: .init(name: "Must remain unapplied")))
      ).outcome
    else { throw CancellationError() }
    #expect(missing.code == "missingReference")
    #expect(item.content.categoryIds.isEmpty && item.content.notes == "Keep notes")
    #expect(statusResult == applied && replay == applied)
    #expect(blocked.code == "mutationBlocked")
  }

  @Test func canceledMissingForeignAndChangedCommandReviewsLeaveTheCategoryUnchanged() async throws
  {
    let fixture = try await CategoryDeletionFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let before = try await fixture.recovery()
    let review = try await fixture.review()
    #expect(try await fixture.recovery().portableData == before.portableData)
    let other = try #require(
      try await fixture.save(.createCategory(content: .init(name: "Other"))).generated.first)
    guard case .ready(let otherSession) = await fixture.planner.bootstrap() else {
      throw CancellationError()
    }
    let beforeRejection = try await fixture.recovery()
    for (session, source, token) in [
      (fixture.session, fixture.category, nil),
      (fixture.session, fixture.category, PlannerReviewToken(opaqueValue: UUID().uuidString)),
      (otherSession, fixture.category, review.reviewToken),
      (fixture.session, other, review.reviewToken),
    ] {
      let operationId = UUID()
      let outcome = await fixture.planner.execute(
        .init(
          operationId: operationId, session: session, command: .deleteSource(source: source),
          reviewToken: token)
      ).outcome
      guard case .rejected(let failure) = outcome,
        case .noReliableEvidence = await fixture.planner.operationStatus(
          session: fixture.session, operationId: operationId)
      else {
        Issue.record(
          "An unreviewed deletion must leave no applied or prepared evidence: \(outcome)")
        return
      }
      #expect(failure.code == "staleReview")
    }
    #expect(try await fixture.recovery().portableData == beforeRejection.portableData)
    let item = try await fixture.itemRead()
    #expect(item.content.categoryIds == [fixture.category.id])
    guard
      case .failed(let invalid) = await fixture.planner.prepareReview(
        session: fixture.session,
        command: .deleteSource(source: .init(kind: .schedule, id: UUID())))
    else { throw CancellationError() }
    #expect(invalid.code == "invalidInput" && invalid.propertyPath == "/command/source/kind")
  }

  @Test(arguments: ["add", "remove"])
  func anotherWritersAssociationChangeRequiresFreshDeletionReview(_ change: String) async throws {
    let fixture = try await CategoryDeletionFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let review = try await fixture.review()
    let writer = Planner(configuration: fixture.configuration)
    guard case .ready(let writerSession) = await writer.bootstrap() else {
      throw CancellationError()
    }
    let command: PlannerCommand
    if change == "add" {
      command = .createItem(
        content: .init(title: "Added elsewhere", categoryIds: [fixture.category.id]))
    } else {
      let item = try await fixture.itemRead()
      command = .editItem(
        sourceId: fixture.item.id, changes: .init(categoryIds: .set([])),
        expectedFieldHashes: item.fieldHashes)
    }
    guard
      case .applied(_, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: writerSession, command: command)
      ).outcome
    else { throw CancellationError() }
    let before = try await fixture.recovery()
    guard
      case .rejected(let failure) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    #expect(failure.code == "staleReview")
    #expect(try await fixture.recovery().portableData == before.portableData)
    let fresh = try await fixture.review()
    #expect(fresh.targetCount == (change == "add" ? 3 : 1))
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: UUID(), session: fixture.session, command: fresh.command,
          reviewToken: fresh.reviewToken)
      ).outcome
    else { throw CancellationError() }
    _ = try await fixture.save(.createTag(content: .init(name: "Later unrelated write")))
    let recovered = try await fixture.recovery()
    #expect(recovered.decodedBackup.backup.deletionMarkers.count == (change == "add" ? 3 : 2))
    #expect(recovered.decodedBackup.backup.labelAssociations.isEmpty)
    #expect(try await fixture.itemRead().content.notes == "Keep notes")
  }

  @Test func changedReplayPayloadAndUnavailableRecoveryDoNotPartiallyDelete() async throws {
    let fixture = try await CategoryDeletionFixture.create()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let before = try await fixture.recovery()
    let review = try await fixture.review()
    let recoveryDirectory = fixture.configuration.recoveryDirectoryURL
    let retained = fixture.directory.appendingPathComponent("retained-recovery")
    try FileManager.default.moveItem(at: recoveryDirectory, to: retained)
    try Data("Obstruct recovery before deletion.".utf8).write(to: recoveryDirectory)
    let failedOperationId = UUID()
    let failed = await fixture.planner.execute(
      .init(
        operationId: failedOperationId, session: fixture.session, command: review.command,
        reviewToken: review.reviewToken)
    ).outcome
    try FileManager.default.removeItem(at: recoveryDirectory)
    try FileManager.default.moveItem(at: retained, to: recoveryDirectory)
    guard case .rejected(let failure) = failed,
      case .noReliableEvidence = await fixture.planner.operationStatus(
        session: fixture.session, operationId: failedOperationId)
    else { throw CancellationError() }
    #expect(failure.code == "persistenceFailure")
    #expect(try await fixture.recovery().portableData == before.portableData)
    #expect(try await fixture.itemRead().content.categoryIds == [fixture.category.id])
    let operationId = UUID()
    guard
      case .applied(_, .complete) = await fixture.planner.execute(
        .init(
          operationId: operationId, session: fixture.session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let deleted = try await fixture.recovery()
    guard
      case .rejected(let mismatch) = await fixture.planner.execute(
        .init(
          operationId: operationId, session: fixture.session,
          command: .deleteSource(source: fixture.item))
      ).outcome
    else { throw CancellationError() }
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(try await fixture.recovery().portableData == deleted.portableData)
    let payload = try #require(
      JSONSerialization.jsonObject(with: deleted.portableData) as? [String: Any])
    let markers = try #require(payload["deletionMarkers"] as? [[String: Any]])
    #expect(markers.count == 2)
    for marker in markers {
      #expect(Set(marker.keys) == ["deletionId", "operationId", "target", "closedFamilyId"])
      let encoded = String(
        decoding: try JSONSerialization.data(withJSONObject: marker), as: UTF8.self)
      #expect(!encoded.contains("Food") && !encoded.contains("Keep notes"))
    }
  }
}

private struct CategoryDeletionFixture {
  let directory: URL
  let configuration: PlannerStorageConfiguration
  let planner: Planner
  let session: PlannerDatasetSession
  let category: PlannerEntityReference
  let item: PlannerEntityReference

  static func create() async throws -> Self {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let createdCategory, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createCategory(content: .init(name: "Food"))
        )
      ).outcome,
      let category = createdCategory.generated.first,
      case .applied(let createdItem, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(
              title: "Museum", notes: "Keep notes", categoryIds: [category.id])))
      ).outcome,
      let item = createdItem.generated.first
    else { throw CancellationError() }
    return .init(
      directory: directory, configuration: configuration, planner: planner, session: session,
      category: category, item: item)
  }

  func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
    guard
      case .applied(let result, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: command)
      ).outcome
    else { throw CancellationError() }
    return result
  }

  func review() async throws -> PlannerReview {
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .deleteSource(source: category))
    else { throw CancellationError() }
    return review
  }

  func itemRead() async throws -> PlannerItemSourceRead {
    guard
      case .source(.item(let read)) = await planner.read(session: session, request: .source(item))
    else { throw CancellationError() }
    return read
  }

  func recovery() async throws -> PlannerRecoverySelection {
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      let checkpoint = namespace.acknowledgedSnapshot?.checkpointGeneration,
      case .selected(let selection) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    return selection
  }
}
