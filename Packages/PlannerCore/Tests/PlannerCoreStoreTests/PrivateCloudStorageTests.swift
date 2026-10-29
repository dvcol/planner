import Foundation
import PlannerCore
import Testing

struct PrivateCloudStorageTests {
  @Test(arguments: ["", "dvcol.planner", "iCloud.", "iCloud.a/b", "iCloud.a..b"])
  func invalidPrivateConfigurationPreservesExistingLocalPlans(containerIdentifier: String)
    async throws
  {
    try await verifyRejectedPrivateConfiguration(
      containerIdentifier: containerIdentifier, expectedCode: "invalidInput")
  }

  @Test func privateConfigurationRequiresTheSignedCloudEnvironment() async throws {
    #expect(Bundle.main.object(forInfoDictionaryKey: "PlannerCloudEnvironment") == nil)
    try await verifyRejectedPrivateConfiguration(
      containerIdentifier: "iCloud.dvcol.planner", expectedCode: "cloudConfigurationRequired")
  }

  private func verifyRejectedPrivateConfiguration(
    containerIdentifier: String, expectedCode: String
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let localConfiguration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let local = Planner(configuration: localConfiguration)
    guard case .ready(let session) = await local.bootstrap(),
      case .applied(let saved, .complete) = await local.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Retained local plan", notes: "Device only")))
      ).outcome,
      let source = saved.generated.first,
      case .source(.item(let original)) = await local.read(
        session: session, request: .source(source))
    else { throw CancellationError() }
    let control = try Data(contentsOf: localConfiguration.controlURL)
    let privateConfiguration = PlannerStorageConfiguration(
      storeURL: localConfiguration.storeURL, controlURL: localConfiguration.controlURL,
      recoveryDirectoryURL: localConfiguration.recoveryDirectoryURL,
      processRole: .mainApplication,
      storageMode: .privateCloud(containerIdentifier: containerIdentifier))
    let cloud = Planner(configuration: privateConfiguration)
    guard case .unavailable(let reason) = await cloud.bootstrap() else {
      Issue.record("An unconfigured private account must not silently open or upload local plans.")
      return
    }
    #expect(reason.code == expectedCode)
    #expect(try Data(contentsOf: localConfiguration.controlURL) == control)
    let reopened = Planner(configuration: localConfiguration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let current)) = await reopened.read(
        session: reopenedSession, request: .source(source))
    else { throw CancellationError() }
    #expect(reopenedSession.datasetId == session.datasetId)
    #expect(reopenedSession.ownershipBinding == session.ownershipBinding)
    #expect(current.content.title == original.content.title)
    #expect(current.content.notes == original.content.notes)
    #expect(current.createdAt == original.createdAt && current.updatedAt == original.updatedAt)
    #expect(current.fieldHashes == original.fieldHashes)
  }
}
