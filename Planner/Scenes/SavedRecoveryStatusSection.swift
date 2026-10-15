import SwiftUI

struct SavedRecoveryStatusSection: View {
  let store: SavedPlannerStore

  var body: some View {
    Section {
      Label(
        store.recoveryStatusTitle,
        systemImage: store.recoveryBlocked ? "exclamationmark.triangle" : "checkmark.shield"
      )
      .accessibilityIdentifier("saved.recovery.status")
      if store.isCheckingRecovery {
        ProgressView("Checking local recovery")
      }
      if store.isRetryingRecovery {
        ProgressView("Finishing recovery copy")
      }
      if !store.incompleteRecoveryOperationIdentifiers.isEmpty {
        Button("Retry Recovery Copy", systemImage: "arrow.clockwise") {
          Task { await store.retryIncompleteRecovery() }
        }
        .disabled(!store.canRetryRecovery)
        .accessibilityIdentifier("saved.recovery.retry")
      }
      if let failure = store.recoveryStatusFailure {
        Text(
          "Planner could not verify or update the recovery copy. Review the details, then try again."
        )
        .foregroundStyle(.red)
        .accessibilityIdentifier("saved.recovery.failure")
        DisclosureGroup("Details") {
          Text(failure).font(.caption).textSelection(.enabled)
            .accessibilityIdentifier("saved.recovery.failure.details")
        }
        Button("Check Again") { Task { await store.refreshRecoveryStatus() } }
          .disabled(store.isSaving || store.isCheckingRecovery)
          .accessibilityIdentifier("saved.recovery.status.refresh")
      }
    } header: {
      Text("On-device recovery")
    } footer: {
      if !store.incompleteRecoveryOperationIdentifiers.isEmpty {
        Text(
          "Your changes are in local storage. Finish the recovery copy before making further changes. Retrying does not repeat your changes."
        )
      } else if store.recoveryBlocked {
        Text(
          "Check the recovery evidence before making further changes.")
      }
    }
  }
}
