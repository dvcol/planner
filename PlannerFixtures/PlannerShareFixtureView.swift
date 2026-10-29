import PlannerCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PlannerShareFixtureView: View {
  let planOpening: SavedPlanOpeningCoordinator
  let windowIdentifier: UUID
  @State private var configuration: PlannerStorageConfiguration?
  @State private var mainStore: SavedPlannerStore?
  @State private var failure: String?
  @State private var captureIdentifier: UUID? = UUID()
  @State private var recoveryObstruction: FixtureRecoverySaveObstruction?
  @State private var recoveryObserver: NSObjectProtocol?

  var body: some View {
    Group {
      if let mainStore, captureIdentifier == nil {
        SavedPlannerMainWindow(
          store: mainStore, planOpening: planOpening, windowIdentifier: windowIdentifier
        )
        .id(ObjectIdentifier(mainStore))
        .environment(mainStore)
      } else if let failure {
        ContentUnavailableView(
          "Share fixture unavailable", systemImage: "exclamationmark.triangle",
          description: Text(failure))
      } else {
        ProgressView("Preparing Share fixture")
      }
    }
    .sheet(isPresented: capturePresented) {
      if let configuration {
        if ProcessInfo.processInfo.arguments.contains("--share-without-group-configuration") {
          PlannerShareRootView(
            providers: providers(), didCancel: finishCapture, didSave: { _ in finishCapture() })
        } else {
          PlannerShareCaptureView(
            configuration: configuration, providers: providers(), didCancel: finishCapture,
            didSave: { _ in finishCapture() }
          )
          .id(captureIdentifier)
        }
      }
    }
    .task {
      guard configuration == nil else { return }
      do { try await prepare() } catch { failure = error.localizedDescription }
    }
  }

  private var capturePresented: Binding<Bool> {
    Binding(
      get: { configuration != nil && captureIdentifier != nil },
      set: { presented in if !presented { finishCapture() } })
  }

  private func prepare() async throws {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "--fixture-dataset"),
      arguments.indices.contains(index + 1),
      let identifier = UUID(uuidString: arguments[index + 1])
    else { throw CancellationError() }
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "PlannerShareFixtures/\(identifier.uuidString)", directoryHint: .isDirectory)
    let startsBeforeMigration = arguments.contains("--share-before-main-migration")
    if startsBeforeMigration, !FileManager.default.fileExists(atPath: directory.path) {
      guard let archivedStore = Bundle.main.url(forResource: "SchemaV1", withExtension: nil) else {
        throw CocoaError(.fileNoSuchFile)
      }
      try FileManager.default.createDirectory(
        at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
      try FileManager.default.copyItem(at: archivedStore, to: directory)
    }
    let mainConfiguration = makeConfiguration(directory, role: .mainApplication)
    let obstruction = FixtureRecoverySaveObstruction(configuration: mainConfiguration)
    try obstruction.restore()
    let planner = PlannerCore.Planner(configuration: mainConfiguration)
    if !arguments.contains("--share-without-main-setup"), !startsBeforeMigration {
      guard case .ready = await planner.bootstrap() else { throw CancellationError() }
    }
    if arguments.contains("--share-recovery-failure") {
      recoveryObstruction = obstruction
      recoveryObserver = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
    }
    if arguments.contains("--share-existing-recovery-failure") {
      mainStore = try await PlannerRecoveryFixture.makeStore(
        directory: directory, access: .writable)
    } else {
      mainStore = SavedPlannerStore(configuration: mainConfiguration)
    }
    configuration = makeConfiguration(directory, role: .shareExtension)
  }

  private func makeConfiguration(
    _ directory: URL, role: PlannerStorageConfiguration.ProcessRole
  ) -> PlannerStorageConfiguration {
    .init(
      storeURL: directory.appending(path: "store/Planner.sqlite"),
      controlURL: directory.appending(path: "control/writer"),
      recoveryDirectoryURL: directory.appending(path: "recovery"), processRole: role,
      storageMode: .localOnly)
  }

  private func providers() -> [NSItemProvider] {
    let provider = NSItemProvider()
    let urlInput = FixtureShareURLInput(
      failsFirstLoad: ProcessInfo.processInfo.arguments.contains("--share-retry-url-input"))
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    {
      completion in
      do { completion(try urlInput.load(), nil) } catch { completion(nil, error) }
      return nil
    }
    provider.registerDataRepresentation(
      forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all
    ) {
      completion in
      completion(Data("Museum visit".utf8), nil)
      return nil
    }
    return [provider]
  }

  private func finishCapture() {
    guard captureIdentifier != nil else { return }
    if let recoveryObserver { NotificationCenter.default.removeObserver(recoveryObserver) }
    recoveryObserver = nil
    do { try recoveryObstruction?.restore() } catch { failure = error.localizedDescription }
    recoveryObstruction = nil
    captureIdentifier = nil
    guard let configuration else { return }
    mainStore = SavedPlannerStore(
      configuration: .init(
        storeURL: configuration.storeURL, controlURL: configuration.controlURL,
        recoveryDirectoryURL: configuration.recoveryDirectoryURL, processRole: .mainApplication,
        storageMode: .localOnly))
  }
}

private final class FixtureShareURLInput: @unchecked Sendable {
  private let lock = NSLock()
  private var failsNextLoad: Bool

  init(failsFirstLoad: Bool) {
    failsNextLoad = failsFirstLoad
  }

  func load() throws -> Data {
    try lock.withLock {
      if failsNextLoad {
        failsNextLoad = false
        throw CocoaError(.fileReadUnknown)
      }
      return Data("https://example.com/museum".utf8)
    }
  }
}
