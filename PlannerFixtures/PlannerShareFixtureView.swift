import PlannerCore
import SwiftUI
import UniformTypeIdentifiers

struct PlannerShareFixtureView: View {
  @State private var configuration: PlannerStorageConfiguration?
  @State private var mainStore: SavedPlannerStore?
  @State private var failure: String?
  @State private var captureIdentifier: UUID? = UUID()

  var body: some View {
    Group {
      if let mainStore, captureIdentifier == nil {
        SavedPlannerView(store: mainStore)
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
        PlannerShareCaptureView(
          configuration: configuration, providers: providers(), didCancel: finishCapture,
          didSave: { _ in finishCapture() }
        )
        .id(captureIdentifier)
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
    let mainConfiguration = makeConfiguration(directory, role: .mainApplication)
    let planner = PlannerCore.Planner(configuration: mainConfiguration)
    if !arguments.contains("--share-without-main-setup") {
      guard case .ready = await planner.bootstrap() else { throw CancellationError() }
    }
    mainStore = SavedPlannerStore(configuration: mainConfiguration)
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
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    {
      completion in
      completion(Data("https://example.com/museum".utf8), nil)
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
    captureIdentifier = nil
    guard let configuration else { return }
    mainStore = SavedPlannerStore(
      configuration: .init(
        storeURL: configuration.storeURL, controlURL: configuration.controlURL,
        recoveryDirectoryURL: configuration.recoveryDirectoryURL, processRole: .mainApplication,
        storageMode: .localOnly))
  }
}
