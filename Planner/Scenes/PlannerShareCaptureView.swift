import PlannerCore
import SwiftUI

struct PlannerShareCaptureView: View {
  let providers: [NSItemProvider]
  let didCancel: () -> Void
  let didSave: (PlannerEntityReference) -> Void
  @State private var store: SavedPlannerStore
  @State private var loadedInputs: PlannerLoadedCaptureInputs?

  init(
    configuration: PlannerStorageConfiguration, providers: [NSItemProvider],
    didCancel: @escaping () -> Void, didSave: @escaping (PlannerEntityReference) -> Void
  ) {
    self.providers = providers
    self.didCancel = didCancel
    self.didSave = didSave
    _store = State(initialValue: SavedPlannerStore(configuration: configuration))
  }

  var body: some View {
    Group {
      if let loadedInputs, store.isReady {
        SavedCaptureForm(
          store: store, entryPoint: .share(loadedInputs),
          didSave: { source in
            guard !store.recoveryBlocked, store.alertMessage == nil else { return }
            didSave(source)
          }, didCancel: didCancel)
      } else {
        NavigationStack {
          Group {
            if let failure = store.openingFailure {
              ContentUnavailableView(
                "Open Plan 2Do to prepare Share", systemImage: "exclamationmark.triangle",
                description: Text(failure))
            } else if store.recoveryBlocked {
              ContentUnavailableView(
                "Open Plan 2Do to review recovery", systemImage: "exclamationmark.triangle",
                description: Text(
                  "Further changes are paused until Plan 2Do's local recovery is ready. Open Plan 2Do to review or retry recovery, then share again."
                ))
            } else {
              ProgressView("Loading shared content")
            }
          }
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel", action: didCancel)
                .accessibilityIdentifier("saved.share.cancel")
            }
          }
        }
      }
    }
    .task {
      await store.open()
      guard store.isReady, !store.recoveryBlocked, !Task.isCancelled, loadedInputs == nil else {
        return
      }
      let loaded = await PlannerNativeCaptureLoader.load(providers: providers)
      guard !Task.isCancelled else { return }
      loadedInputs = loaded
    }
  }
}
