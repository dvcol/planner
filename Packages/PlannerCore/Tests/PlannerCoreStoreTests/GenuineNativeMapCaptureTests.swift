import Foundation
import MapKit
import PlannerCore
import Testing

struct GenuineNativeMapCaptureTests {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["PLANNER_GENUINE_MAP_FIXTURE"] != nil))
  @MainActor
  func nativeApplePlaceReferenceRemainsTemporaryAfterOwnedCaptureSave() async throws {
    let fixturePath = try #require(
      ProcessInfo.processInfo.environment["PLANNER_GENUINE_MAP_FIXTURE"])
    let data = try Data(contentsOf: URL(fileURLWithPath: fixturePath))
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: MKMapItemTypeIdentifier, visibility: .all
    ) { completion in
      completion(data, nil)
      return nil
    }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerGenuineNativeMapCaptureTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session,
        input: .loaded(
          await PlannerNativeCaptureLoader.load(providers: [provider])))
    else { throw CancellationError() }
    let candidate = try #require(prepared.preview.candidate)
    #expect(candidate.providerReference?.kind == .applePlaceId)
    #expect(candidate.providerReference?.value == "ID40BC454B39E9696")
    #expect(candidate.displayName == "Nezu Museum")
    #expect(
      prepared.content.title.isEmpty && prepared.content.location == nil && prepared.links.isEmpty
    )
    guard
      case .draft(let edited) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        edit: .init(changes: .init(title: .set("My museum")))),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyCapture(
          draftId: edited.draftId, draftGeneration: edited.generation,
          choice: .createNew, listIds: [])),
      case .applied(let result, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      let savedReference = result.generated.first,
      case .source(.item(let saved)) = await planner.read(
        session: session, request: .source(savedReference)),
      case .exported(let backup) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(edited.preview.candidate?.providerReference?.value == "ID40BC454B39E9696")
    #expect(
      saved.content.title == "My museum" && saved.content.location == nil
        && saved.content.links.isEmpty)
    let backupText = String(decoding: backup, as: UTF8.self)
    #expect(backupText.contains("My museum") && !backupText.contains("Nezu Museum"))
    #expect(!backupText.contains("ID40BC454B39E9696"))
  }
}
