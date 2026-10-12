import Foundation
import PlannerCore
import Testing

struct MissingStoreOperationTests {
  @Test(arguments: [
    "source", "appearance", "rows", "query", "review", "replay", "shareRead",
    "shareBootstrap", "mainBootstrap", "unknownStatus", "unknownRetry",
  ])
  func ordinaryOperationsRefuseMissingStorageAndResumeOnlyAfterOriginalStoreReturns(
    _ action: String
  )
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeDirectory = directory.appendingPathComponent("store")
    let retainedDirectory = directory.appendingPathComponent("retained-store")
    let configuration = PlannerStorageConfiguration(
      storeURL: storeDirectory.appendingPathComponent("Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let creationIdentifier = UUID()
    let creationCommand = PlannerCommand.createItem(
      content: .init(title: "Hotel", notes: "Original notes"))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        .init(operationId: creationIdentifier, session: session, command: creationCommand)
      ).outcome,
      let source = creation.generated.first,
      case .applied(let listCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createList(content: .init(name: "Wishlist")))
      ).outcome,
      let list = listCreation.generated.first,
      case .applied(let membershipCreation, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: source.id, listId: list.id, placement: .last))
      ).outcome,
      let reference = membershipCreation.generatedReferences.first,
      case .membership(let membershipIdentifier, _, _) = reference,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(source)),
      case .snapshot(let query) = await planner.query(
        .init(session: session, request: .items(.init()))),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let shareConfiguration = PlannerStorageConfiguration(
      storeURL: configuration.storeURL, controlURL: configuration.controlURL,
      recoveryDirectoryURL: configuration.recoveryDirectoryURL,
      processRole: .shareExtension, storageMode: .localOnly)
    let share = Planner(configuration: shareConfiguration)
    guard case .ready(let shareSession) = await share.bootstrap() else { throw CancellationError() }
    try FileManager.default.moveItem(at: storeDirectory, to: retainedDirectory)
    try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    let reason: PlannerFailure
    switch action {
    case "source", "appearance", "rows", "shareRead":
      let request: PlannerReadRequest
      switch action {
      case "appearance":
        request = .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier))
      case "rows": request = .rows(generation: query.generation, offset: 0, limit: 1)
      default: request = .source(source)
      }
      let result: PlannerReadResult
      if action == "shareRead" {
        result = await share.read(session: shareSession, request: request)
      } else {
        result = await planner.read(session: session, request: request)
      }
      guard case .failed(let failure) = result else { throw CancellationError() }
      reason = failure
    case "query":
      guard
        case .failed(let failure) = await planner.query(
          .init(session: session, request: .items(.init())))
      else { throw CancellationError() }
      reason = failure
    case "review":
      guard
        case .failed(let failure) = await planner.prepareReview(
          session: session, command: .setBulkCompletion(scope: .list(listId: list.id), done: true))
      else { throw CancellationError() }
      reason = failure
    case "replay":
      guard
        case .rejected(let failure) = await planner.execute(
          .init(operationId: creationIdentifier, session: session, command: creationCommand)
        ).outcome
      else { throw CancellationError() }
      reason = failure
    case "shareBootstrap", "mainBootstrap":
      let reopening = Planner(
        configuration: action == "shareBootstrap" ? shareConfiguration : configuration)
      guard case .unavailable(let failure) = await reopening.bootstrap() else {
        throw CancellationError()
      }
      reason = failure
    case "unknownStatus":
      guard
        case .unavailable(let failure) = await planner.operationStatus(
          session: session, operationId: UUID())
      else { throw CancellationError() }
      reason = failure
    case "unknownRetry":
      guard
        case .rejected(let failure) = await planner.retryRecovery(
          session: session, operationId: UUID()
        ).outcome
      else { throw CancellationError() }
      reason = failure
    default: throw CancellationError()
    }
    #expect(reason.code == (action == "unknownRetry" ? "readUnavailable" : "unavailable"))
    #expect(!reason.message.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: configuration.storeURL.path))
    guard
      case .selected(let retained) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint)),
      case .listed(let retainedNamespace) = await planner.inspectRecovery(
        request: .namespace(namespaceId: namespace.namespaceId)),
      case .status(let status) = await planner.read(session: session, request: .status),
      case .unavailable = status.recovery
    else { throw CancellationError() }
    #expect(retained.portableData == recovery.portableData)
    #expect(retainedNamespace.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    #expect(retainedNamespace.preparedProposals.isEmpty)
    try FileManager.default.removeItem(at: storeDirectory)
    try FileManager.default.moveItem(at: retainedDirectory, to: storeDirectory)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let restored)) = await reopened.read(
        session: reopenedSession, request: .source(source)),
      case .appearance(let appearance) = await reopened.read(
        session: reopenedSession,
        request: .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier))),
      case .applied(_, .complete(let nextCheckpoint)) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .editItem(
            sourceId: source.id, changes: .init(notes: .set("Friday booking")),
            expectedFieldHashes: [.notes: try #require(restored.fieldHashes[.notes])]))
      ).outcome
    else { throw CancellationError() }
    #expect(restored.source == source && restored.sourceLifetimeId == original.sourceLifetimeId)
    #expect(
      restored.updatedAt == original.updatedAt && restored.fieldHashes == original.fieldHashes)
    #expect(restored.content.title == "Hotel" && restored.content.notes == "Original notes")
    #expect(appearance.source == source && !appearance.localDone && !appearance.globalDone)
    #expect(nextCheckpoint == checkpoint + 1)
  }

  @Test func freshShareRequiresExplicitMainSetupWhileAcknowledgedEvidenceSurvivesStoreLoss()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeDirectory = directory.appendingPathComponent("store")
    let storeURL = storeDirectory.appendingPathComponent("Planner.sqlite")
    let controlURL = directory.appendingPathComponent("control/writer")
    let recoveryURL = directory.appendingPathComponent("recovery")
    let shareConfiguration = PlannerStorageConfiguration(
      storeURL: storeURL, controlURL: controlURL, recoveryDirectoryURL: recoveryURL,
      processRole: .shareExtension, storageMode: .localOnly)
    let share = Planner(configuration: shareConfiguration)
    guard case .mainAppSetupRequired = await share.bootstrap() else { throw CancellationError() }
    #expect(!FileManager.default.fileExists(atPath: storeURL.path))
    let main = Planner(
      configuration: .init(
        storeURL: storeURL, controlURL: controlURL, recoveryDirectoryURL: recoveryURL,
        processRole: .mainApplication, storageMode: .localOnly))
    let operationIdentifier = UUID()
    guard case .ready(let session) = await main.bootstrap(),
      case .ready = await share.bootstrap(),
      case .applied(let originalResult, .complete(let checkpoint)) = await main.execute(
        .init(
          operationId: operationIdentifier, session: session,
          command: .createItem(content: .init(title: "Hotel")))
      ).outcome
    else { throw CancellationError() }
    try FileManager.default.moveItem(
      at: storeDirectory, to: directory.appendingPathComponent("retained-store"))
    try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    guard
      case .appliedRecoveryComplete(let statusResult, let statusCheckpoint) =
        await main.operationStatus(
          session: session, operationId: operationIdentifier),
      case .applied(let retryResult, .complete(let retryCheckpoint)) = await main.retryRecovery(
        session: session, operationId: operationIdentifier
      ).outcome
    else { throw CancellationError() }
    #expect(statusResult == originalResult && retryResult == originalResult)
    #expect(statusCheckpoint == checkpoint && retryCheckpoint == checkpoint)
    #expect(!FileManager.default.fileExists(atPath: storeURL.path))
  }
}
