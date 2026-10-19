import PlannerCore
import SwiftUI

struct PlannerShareRootView: View {
  let providers: [NSItemProvider]
  let didCancel: () -> Void
  let didSave: (PlannerEntityReference) -> Void
  private let configuration: Result<PlannerStorageConfiguration, any Error>

  init(
    providers: [NSItemProvider], didCancel: @escaping () -> Void,
    didSave: @escaping (PlannerEntityReference) -> Void
  ) {
    self.providers = providers
    self.didCancel = didCancel
    self.didSave = didSave
    configuration = Result { try Self.sharedConfiguration() }
  }

  var body: some View {
    switch configuration {
    case .success(let configuration):
      PlannerShareCaptureView(
        configuration: configuration, providers: providers,
        didCancel: didCancel, didSave: didSave)
    case .failure(let error):
      NavigationStack {
        ContentUnavailableView(
          "Share unavailable", systemImage: "exclamationmark.triangle",
          description: Text(error.localizedDescription)
        )
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: didCancel)
          }
        }
      }
    }
  }

  private static func sharedConfiguration() throws -> PlannerStorageConfiguration {
    guard
      let groupIdentifier = Bundle.main.object(forInfoDictionaryKey: "PlannerAppGroupIdentifier")
        as? String,
      !groupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let directory = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: groupIdentifier)
    else {
      throw CocoaError(
        .fileReadNoPermission,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Shared storage is not configured or accessible. Open Planner to complete setup."
        ])
    }
    let plannerDirectory = directory.appending(path: "Planner", directoryHint: .isDirectory)
    return .init(
      storeURL: plannerDirectory.appending(path: "store/Planner.sqlite"),
      controlURL: plannerDirectory.appending(path: "control/writer"),
      recoveryDirectoryURL: plannerDirectory.appending(path: "recovery"),
      processRole: .shareExtension, storageMode: .localOnly)
  }
}
