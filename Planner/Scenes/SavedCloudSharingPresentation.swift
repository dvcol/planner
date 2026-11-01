import CloudKit
import SwiftUI

#if os(iOS)
  import UIKit

  struct SavedCloudSharingPresentation: UIViewControllerRepresentable {
    let invitation: SavedCloudInvitation
    let store: SavedPlannerStore

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIViewController(context: Context) -> UICloudSharingController {
      let controller = UICloudSharingController(
        share: invitation.share, container: invitation.container)
      controller.availablePermissions = [
        .allowPrivate, invitation.canEdit ? .allowReadWrite : .allowReadOnly,
      ]
      controller.delegate = context.coordinator
      controller.view.accessibilityIdentifier = "saved.sharing.invitation"
      return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    @MainActor final class Coordinator: NSObject, UICloudSharingControllerDelegate {
      let store: SavedPlannerStore
      init(store: SavedPlannerStore) { self.store = store }

      func itemTitle(for controller: UICloudSharingController) -> String? { "Plan 2Do" }

      func cloudSharingController(
        _ controller: UICloudSharingController, failedToSaveShareWithError error: any Error
      ) {
        store.alertMessage = error.localizedDescription
      }

      func cloudSharingControllerDidSaveShare(_ controller: UICloudSharingController) {
        Task { await store.refreshSharing() }
      }

      func cloudSharingControllerDidStopSharing(_ controller: UICloudSharingController) {
        Task {
          await store.synchronize()
          await store.refreshSharing()
        }
      }
    }
  }
#else
  import AppKit

  struct SavedCloudSharingPresentation: View {
    @Environment(\.dismiss) private var dismiss
    let invitation: SavedCloudInvitation
    let store: SavedPlannerStore

    var body: some View {
      VStack(spacing: 20) {
        Text("Invite people").font(.title2)
        Text("Use Apple's sharing controls to invite people or manage their access.")
        SavedCloudSharingButton(invitation: invitation, store: store).frame(height: 32)
        Button("Done") { dismiss() }
      }
      .padding(28).frame(width: 420)
    }
  }

  private struct SavedCloudSharingButton: NSViewRepresentable {
    let invitation: SavedCloudInvitation
    let store: SavedPlannerStore

    func makeCoordinator() -> Coordinator { Coordinator(invitation: invitation, store: store) }

    func makeNSView(context: Context) -> NSButton {
      NSButton(
        title: "Invite or manage people", target: context.coordinator,
        action: #selector(Coordinator.show))
    }

    func updateNSView(_ view: NSButton, context: Context) {}

    @MainActor final class Coordinator: NSObject, @preconcurrency NSCloudSharingServiceDelegate {
      let invitation: SavedCloudInvitation
      let store: SavedPlannerStore
      private var service: NSSharingService?
      init(invitation: SavedCloudInvitation, store: SavedPlannerStore) {
        self.invitation = invitation
        self.store = store
      }

      @objc func show() {
        guard let service = NSSharingService(named: .cloudSharing) else {
          store.alertMessage = "Apple's sharing controls are unavailable."
          return
        }
        self.service = service
        service.delegate = self
        let provider = NSItemProvider()
        provider.registerCloudKitShare(invitation.share, container: invitation.container)
        service.perform(withItems: [provider])
      }

      func options(for sharingService: NSSharingService, shareProvider: NSItemProvider)
        -> NSSharingService.CloudKitOptions
      {
        [.allowPrivate, invitation.canEdit ? .allowReadWrite : .allowReadOnly]
      }

      func sharingService(_ sharingService: NSSharingService, didSave share: CKShare) {
        Task { await store.refreshSharing() }
      }

      func sharingService(_ sharingService: NSSharingService, didStopSharing share: CKShare) {
        Task {
          await store.synchronize()
          await store.refreshSharing()
        }
      }

      func sharingService(
        _ sharingService: NSSharingService, didCompleteForItems items: [Any], error: (any Error)?
      ) {
        if let error { store.alertMessage = error.localizedDescription }
        service = nil
      }
    }
  }
#endif
