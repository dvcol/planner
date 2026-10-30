import Foundation
import PlannerCore
import XCTest

@testable import Planner

@MainActor
final class NativeSharedStorageTests: XCTestCase {
  func testConfiguredAppGroupIsWritableAndMainAndShareSelectTheSamePaths() throws {
    let sharedDirectory = try XCTUnwrap(PlannerNativeStorage.configuredSharedDirectory())
    let shared = try PlannerNativeStorage.sharedConfiguration()
    let main = try PlannerNativeStorage.mainConfiguration(
      localDirectory: FileManager.default.temporaryDirectory.appending(
        path: UUID().uuidString, directoryHint: .isDirectory),
      sharedDirectory: sharedDirectory)
    XCTAssertEqual(main.storeURL, shared.storeURL)
    XCTAssertEqual(main.controlURL, shared.controlURL)
    XCTAssertEqual(main.recoveryDirectoryURL, shared.recoveryDirectoryURL)
    XCTAssertEqual(main.processRole, .mainApplication)
    XCTAssertEqual(shared.processRole, .shareExtension)
    guard case .privateCloud(let containerIdentifier) = shared.storageMode else {
      return XCTFail("The deployed Share extension must select private synchronization.")
    }
    XCTAssertEqual(containerIdentifier, "iCloud.dvcol.planner")
    let privateMain = try PlannerNativeStorage.privateConfiguration(main)
    guard case .privateCloud(let mainContainer) = privateMain.storageMode else {
      return XCTFail("The main app must use the same private configuration.")
    }
    XCTAssertEqual(mainContainer, containerIdentifier)

    let fixture = sharedDirectory.deletingLastPathComponent().appending(
      path: "PlannerSharedStorageQualification-" + UUID().uuidString,
      directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
    defer {
      do {
        try FileManager.default.removeItem(at: fixture)
      } catch {
        XCTFail("The App Group write fixture could not be removed: \(error)")
      }
    }
    let file = fixture.appending(path: "shared-access.txt")
    let content = Data("Planner shared storage qualification".utf8)
    try content.write(to: file, options: .atomic)
    XCTAssertEqual(try Data(contentsOf: file), content)
  }

  func testMainAndShareReadEachOthersSavesFromOneInitializedDataset() async throws {
    let fixture = try makePlannerIntentStorage()
    let sharedDirectory = fixture.directory.appending(
      path: "Shared/Planner", directoryHint: .isDirectory)
    let mainConfiguration = try PlannerNativeStorage.mainConfiguration(
      localDirectory: fixture.directory.appending(path: "Local", directoryHint: .isDirectory),
      sharedDirectory: sharedDirectory)
    let share = PlannerCore.Planner(
      configuration: PlannerNativeStorage.configuration(
        directory: sharedDirectory, processRole: .shareExtension))
    guard case .mainAppSetupRequired = await share.bootstrap() else {
      return XCTFail("Share must wait for the main app to initialize the selected dataset.")
    }
    let main = try await seededStorage(mainConfiguration, title: "Main museum")
    guard case .ready(let shareSession) = await share.bootstrap(),
      case .source(.item(let mainItem)) = await share.read(
        session: shareSession, request: .source(main.source))
    else { return XCTFail("Share must read the main app's saved Item.") }
    XCTAssertEqual(shareSession.datasetId, main.session.datasetId)
    XCTAssertEqual(shareSession.ownershipBinding, main.session.ownershipBinding)
    XCTAssertEqual(mainItem.source, main.source)
    XCTAssertEqual(mainItem.content.title, "Main museum")
    XCTAssertEqual(mainItem.content.notes, "Keep the original notes")
    guard
      case .applied(let creation, .complete) = await share.execute(
        .init(
          operationId: UUID(), session: shareSession,
          command: .createItem(content: .init(title: "Shared guide", notes: "From the extension")))
      ).outcome,
      let source = creation.generated.first,
      case .source(.item(let sharedItem)) = await main.planner.read(
        session: main.session, request: .source(source))
    else { return XCTFail("The main app must read the extension's acknowledged save.") }
    XCTAssertEqual(sharedItem.source, source)
    XCTAssertNotEqual(sharedItem.source, main.source)
    XCTAssertEqual(sharedItem.content.title, "Shared guide")
    XCTAssertEqual(sharedItem.content.notes, "From the extension")
  }

  func testWithoutAnAppGroupTheExistingLocalDatasetReopensUnchanged() async throws {
    let fixture = try makePlannerIntentStorage()
    let original = try await seededStorage(fixture.configuration, title: "Local museum")
    let configuration = try PlannerNativeStorage.mainConfiguration(
      localDirectory: fixture.directory, sharedDirectory: nil)
    let reopened = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await reopened.bootstrap(),
      case .source(.item(let item)) = await reopened.read(
        session: session, request: .source(original.source))
    else { return XCTFail("Unconfigured shared storage must retain the existing local dataset.") }
    XCTAssertEqual(session.datasetId, original.session.datasetId)
    XCTAssertEqual(session.ownershipBinding, original.session.ownershipBinding)
    XCTAssertEqual(item.content.title, "Local museum")
    XCTAssertEqual(item.content.notes, "Keep the original notes")
  }

  func testNewSharedStorageCannotSilentlyAbandonExistingLocalData() async throws {
    let fixture = try makePlannerIntentStorage()
    let original = try await seededStorage(fixture.configuration, title: "Local museum")
    let sharedDirectory = fixture.directory.appending(
      path: "Shared/Planner", directoryHint: .isDirectory)
    XCTAssertThrowsError(
      try PlannerNativeStorage.mainConfiguration(
        localDirectory: fixture.directory, sharedDirectory: sharedDirectory)
    ) { error in
      XCTAssertTrue(error.localizedDescription.contains("existing local data"))
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: sharedDirectory.path))
    guard
      case .source(.item(let retained)) = await original.planner.read(
        session: original.session, request: .source(original.source))
    else { return XCTFail("Declining the storage transition must preserve the local Item.") }
    XCTAssertEqual(retained.source, original.source)
    XCTAssertEqual(retained.content.title, "Local museum")
    XCTAssertEqual(retained.content.notes, "Keep the original notes")
  }

  func testAnInitializedSharedDatasetStaysSeparateFromAnExistingLocalCopy() async throws {
    let fixture = try makePlannerIntentStorage()
    let original = try await seededStorage(fixture.configuration, title: "Local museum")
    let sharedDirectory = fixture.directory.appending(
      path: "Shared/Planner", directoryHint: .isDirectory)
    let shared = try await seededStorage(
      PlannerNativeStorage.configuration(directory: sharedDirectory, processRole: .mainApplication),
      title: "Shared museum")
    let selected = PlannerCore.Planner(
      configuration: try PlannerNativeStorage.mainConfiguration(
        localDirectory: fixture.directory, sharedDirectory: sharedDirectory))
    guard case .ready(let session) = await selected.bootstrap(),
      case .source(.item(let sharedItem)) = await selected.read(
        session: session, request: .source(shared.source)),
      case .source(.item(let localItem)) = await original.planner.read(
        session: original.session, request: .source(original.source))
    else { return XCTFail("Selecting initialized shared storage must preserve both datasets.") }
    XCTAssertEqual(session.datasetId, shared.session.datasetId)
    XCTAssertNotEqual(session.datasetId, original.session.datasetId)
    XCTAssertEqual(sharedItem.content.title, "Shared museum")
    XCTAssertEqual(localItem.content.title, "Local museum")
    XCTAssertEqual(localItem.content.notes, "Keep the original notes")
  }

  func testDeviceOnlyPlansRequireReviewAndConfirmationBeforePrivateCopy() async throws {
    let fixture = try makePlannerIntentStorage()
    let original = try await seededStorage(
      fixture.configuration, title: "Device-only copy qualification")
    guard case .exported(let before) = await original.planner.exportData(session: original.session)
    else {
      return XCTFail("The original device-only plan must be readable.")
    }
    let store = SavedPlannerStore(
      configuration: try PlannerNativeStorage.privateConfiguration(fixture.configuration))
    await store.open()
    XCTAssertTrue(store.isReady)
    XCTAssertTrue(store.hasPrivateSynchronization)
    XCTAssertTrue(
      store.canCopyDevicePlans, "This signed check requires an available private account.")
    let (privatePlanner, privateSession) = try await store.appIntentContext()
    guard
      case .failed(let absent) = await privatePlanner.read(
        session: privateSession, request: .source(original.source))
    else { return XCTFail("Opening private plans must not silently copy device-only content.") }
    XCTAssertEqual(absent.code, "missingReference")

    let backup = try await store.prepareDevicePlansCopy()
    XCTAssertEqual(backup.backup.items.count, 1)
    XCTAssertEqual(backup.backup.items.first?.content.title, "Device-only copy qualification")
    let draft = SavedBackupImportDraft(devicePlans: backup)
    XCTAssertTrue(draft.isDeviceCopy)
    XCTAssertFalse(draft.isRecovery)
    let review = try await store.prepareBackupImport(
      backup, mode: .skip, restoreDeletedData: false)
    guard
      case .failed = await privatePlanner.read(
        session: privateSession, request: .source(original.source))
    else { return XCTFail("Preparing the copy must not save it.") }
    guard case .applied = await store.applyReviewedChange(review, operationIdentifier: UUID()),
      case .source(.item(let copied)) = await privatePlanner.read(
        session: privateSession, request: .source(original.source)),
      case .exported(let after) = await original.planner.exportData(session: original.session)
    else { return XCTFail("Explicit confirmation must copy the represented plan.") }
    XCTAssertEqual(copied.content.title, "Device-only copy qualification")
    XCTAssertEqual(copied.content.notes, "Keep the original notes")
    XCTAssertEqual(before, after, "Copying must preserve the complete original device-only store.")

    let deletion = PlannerCommand.deleteSource(source: original.source)
    guard
      case .reviewed(let removal) = await privatePlanner.prepareReview(
        session: privateSession, command: deletion),
      case .applied(_, .complete) = await privatePlanner.execute(
        .init(
          operationId: UUID(), session: privateSession, command: deletion,
          reviewToken: removal.reviewToken)
      ).outcome
    else { return XCTFail("Only the copied qualification Item must be removed afterward.") }
    let deadline = Date().addingTimeInterval(60)
    while Date() < deadline {
      if case .status(let status) = await privatePlanner.read(
        session: privateSession, request: .status),
        case .idle = status.cloud.state
      {
        return
      }
      try await Task.sleep(for: .milliseconds(250))
    }
    XCTFail("The synthetic copied Item's removal must finish syncing.")
  }

  private func seededStorage(_ configuration: PlannerStorageConfiguration, title: String)
    async throws -> (
      planner: PlannerCore.Planner, session: PlannerDatasetSession, source: PlannerEntityReference
    )
  {
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(title: title, notes: "Keep the original notes")))
      ).outcome,
      let source = creation.generated.first
    else {
      XCTFail("The real native store must acknowledge the seed Item.")
      throw CancellationError()
    }
    return (planner, session, source)
  }
}
