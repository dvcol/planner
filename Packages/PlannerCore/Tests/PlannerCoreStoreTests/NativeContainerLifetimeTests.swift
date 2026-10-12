import Foundation
import PlannerCore
import Testing

struct NativeContainerLifetimeTests {
  @Test func retainedContainersReadAnotherFacadesEditsThroughFreshContexts() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeContainerLifetimeTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let writer = Planner(configuration: configuration)
    let reader = Planner(configuration: configuration)
    guard case .ready(let writerSession) = await writer.bootstrap(),
      case .applied(let created, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: writerSession,
          command: .createItem(content: .init(title: "Original", notes: "Original notes")))
      ).outcome, let source = created.generated.first,
      case .ready(let readerSession) = await reader.bootstrap(),
      case .source(.item(let original)) = await reader.read(
        session: readerSession, request: .source(source)),
      case .applied(_, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: writerSession,
          command: .editItem(
            sourceId: source.id, changes: .init(title: .set("Updated elsewhere")),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .applied(_, .complete) = await writer.execute(
        .init(
          operationId: UUID(), session: writerSession,
          command: .setCompletion(scope: .globalItem(itemId: source.id), done: true))
      ).outcome,
      case .source(.item(let refreshed)) = await reader.read(
        session: readerSession, request: .source(source))
    else { throw CancellationError() }
    #expect(refreshed.source == original.source)
    #expect(refreshed.content.title == "Updated elsewhere")
    #expect(refreshed.content.notes == "Original notes")
    #expect(refreshed.state.globalDone == true)
    #expect(refreshed.fieldHashes[.title] != original.fieldHashes[.title])
  }
}
