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
    configuration = Result { try PlannerNativeStorage.sharedConfiguration() }
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

}
