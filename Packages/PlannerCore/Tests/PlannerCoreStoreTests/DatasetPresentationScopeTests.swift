import Foundation
import PlannerCore
import Testing

struct DatasetPresentationScopeTests {
  @Test func presentationOwnershipSurvivesReopenAndRemainsSeparateFromAnotherDataset()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = Planner(
      configuration: configuration(at: directory.appendingPathComponent("first")))
    guard case .ready(let first) = await original.bootstrap() else {
      Issue.record("The first dataset must open before choosing device presentation preferences.")
      return
    }
    let reopened = Planner(
      configuration: configuration(at: directory.appendingPathComponent("first")))
    let separate = Planner(
      configuration: configuration(at: directory.appendingPathComponent("second")))
    guard case .ready(let returning) = await reopened.bootstrap(),
      case .ready(let other) = await separate.bootstrap()
    else {
      Issue.record("The reopened and separate datasets must issue their own valid sessions.")
      return
    }
    #expect(!first.ownershipBinding.isEmpty)
    #expect(returning.datasetId == first.datasetId)
    #expect(returning.ownershipBinding == first.ownershipBinding)
    #expect(returning.sessionId != first.sessionId)
    #expect(other.datasetId != first.datasetId)
    #expect(other.ownershipBinding != first.ownershipBinding)
  }

  private func configuration(at directory: URL) -> PlannerStorageConfiguration {
    PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }
}
