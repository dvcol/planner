import CloudKit
import PlannerCore
import SwiftUI

private enum SavedSharingMode: String, CaseIterable {
  case off = "Off"
  case whole = "Whole library"
  case lists = "Selected Lists"
}

private struct SavedSharingPreviewIdentity: Equatable {
  let scope: PlannerSharingScope
  let namespace: String?
  let revision: UUID
}

struct SavedCloudInvitation: Identifiable {
  let share: CKShare
  let container: CKContainer
  let canEdit: Bool
  var id: String { share.recordID.recordName }
}

struct SavedLibrarySharingView: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  @State private var mode = SavedSharingMode.off
  @State private var lists: Set<UUID> = []
  @State private var showListPicker = false
  @State private var confirmScopeChange = false
  @State private var invitation: SavedCloudInvitation?
  @State private var invitationURL = ""
  @State private var invitationCanEdit = true
  @State private var isLoading = false
  @State private var preview: PlannerSharingPreview?
  @State private var previewFailure: String?
  @State private var invitationWorkflowIdentifier = UUID()

  private var proposedScope: PlannerSharingScope {
    switch mode {
    case .off: .off
    case .whole: .wholeLibrary
    case .lists: .selectedLists(lists)
    }
  }

  private var previewIdentity: SavedSharingPreviewIdentity {
    .init(
      scope: proposedScope, namespace: store.devicePreferenceNamespace,
      revision: store.changeRevision)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          libraryButton(nil)
          ForEach(store.receivedLibraries) { library in libraryButton(library) }
          Button("Refresh libraries", systemImage: "arrow.clockwise") {
            Task { await reload() }
          }
          .disabled(isLoading || store.isManagingSharing)
        } header: {
          Text("Current library")
        } footer: {
          Text(
            "Received libraries stay separate from your personal plans. Finish open editors before switching."
          )
        }
        if store.activeLibrary == nil, store.isReady {
          Section {
            Picker("Share", selection: $mode) {
              ForEach(SavedSharingMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .accessibilityIdentifier("saved.sharing.scope")
            if mode == .lists {
              Button {
                showListPicker = true
              } label: {
                LabeledContent("Shared Lists", value: "\(lists.count) selected")
              }
              .accessibilityIdentifier("saved.sharing.lists")
              Text(
                "Items stay live everywhere they are used. Content edits and global completion also affect your private plans; private List memberships remain hidden. Only the owner can delete shared Items, Lists and labels globally."
              )
              .font(.footnote).foregroundStyle(.secondary)
            }
            if let preview, mode != .off {
              let count = preview.sources.filter { $0.kind == .item }.count
              Text("\(count) Items · \(preview.membershipCount) List entries")
                .font(.footnote).foregroundStyle(.secondary)
            }
            if let previewFailure { Text(previewFailure).foregroundStyle(.red) }
            Button("Apply sharing", systemImage: "person.2") {
              if store.sharingScope == .off {
                Task { await apply() }
              } else {
                confirmScopeChange = true
              }
            }
            .disabled(
              !store.canChangeLibrary || proposedScope == store.sharingScope || preview == nil
                || (mode == .lists && lists.isEmpty)
            )
            .accessibilityIdentifier("saved.sharing.apply")
            if store.sharingScope != .off {
              Picker("Invitation access", selection: $invitationCanEdit) {
                Text("Can edit").tag(true)
                Text("Read only").tag(false)
              }
              Button("Invite or manage people", systemImage: "person.badge.plus") {
                Task { await present(await store.currentSharingInvitation()) }
              }
              .disabled(!store.canChangeLibrary)
              .accessibilityIdentifier("saved.sharing.invite")
              Button("Stop sharing", role: .destructive) {
                mode = .off
                confirmScopeChange = true
              }
              .disabled(!store.canChangeLibrary)
              .accessibilityIdentifier("saved.sharing.stop")
            }
            if store.isManagingSharing { ProgressView("Preparing sharing") }
          } header: {
            Text("Share personal library")
          } footer: {
            Text(
              "Sharing is invitation only and uses the owner's personal iCloud storage. There is no public or developer-funded storage fallback. Changing the mode or selected Lists ends existing invitations; invite people again afterward."
            )
          }
        }
        Section("Join a library") {
          TextField("iCloud invitation link", text: $invitationURL)
            .autocorrectionDisabled()
            .accessibilityIdentifier("saved.sharing.join.url")
          Button("Accept invitation") {
            guard let url = URL(string: invitationURL) else { return }
            Task {
              await store.acceptSharingInvitation(url: url)
              invitationURL = ""
            }
          }
          .disabled(!store.canChangeLibrary || URL(string: invitationURL)?.scheme != "https")
        }
      }
      .formStyle(.grouped)
      .disabled(isLoading || store.isManagingSharing)
      .navigationTitle("Sharing")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
      .task { await reload() }
      .onChange(of: invitation != nil, initial: true) {
        store.setLibrarySwitchBlocked(invitation != nil, window: invitationWorkflowIdentifier)
      }
      .onDisappear {
        store.setLibrarySwitchBlocked(false, window: invitationWorkflowIdentifier)
      }
      .task(id: previewIdentity) {
        preview = nil
        previewFailure = nil
        let identity = previewIdentity
        guard store.activeLibrary == nil, store.isReady, mode != .lists || !lists.isEmpty else {
          return
        }
        do {
          let result = try await store.previewSharing(identity.scope)
          guard !Task.isCancelled, identity == previewIdentity else { return }
          preview = result
        } catch {
          guard !Task.isCancelled, identity == previewIdentity else { return }
          previewFailure = (error as? PlannerFailure)?.message ?? error.localizedDescription
        }
      }
      .sheet(isPresented: $showListPicker) {
        NavigationStack {
          SavedListSelectionView(
            store: store, selection: $lists, title: "Shared Lists",
            identifierPrefix: "saved.sharing")
        }
      }
      .sheet(item: $invitation) { SavedCloudSharingPresentation(invitation: $0, store: store) }
      .confirmationDialog("Replace current sharing?", isPresented: $confirmScopeChange) {
        Button(mode == .off ? "Stop sharing" : "Replace sharing", role: .destructive) {
          Task { await apply() }
        }
        .accessibilityIdentifier("saved.sharing.scope.confirm")
      } message: {
        Text(
          "Existing participants lose access. Your plans stay saved. You can invite people again with the new scope."
        )
      }
      .alert(
        "Sharing",
        isPresented: Binding(
          get: { store.alertMessage != nil }, set: { if !$0 { store.alertMessage = nil } })
      ) {
        Button("OK") { store.alertMessage = nil }
      } message: {
        Text(store.alertMessage ?? "")
      }
    }
    #if os(macOS)
      .frame(minWidth: 460, minHeight: 500)
    #endif
  }

  private func libraryButton(_ library: PlannerSharedLibrary?) -> some View {
    Button {
      Task {
        await store.switchLibrary(to: library)
        await reload()
      }
    } label: {
      HStack {
        VStack(alignment: .leading) {
          Text(library?.title ?? "Personal library")
          if let library {
            Text(library.canEdit ? "Can edit" : "Read only").font(.caption).foregroundStyle(
              .secondary)
          }
        }
        Spacer()
        if store.activeLibrary?.id == library?.id {
          Image(systemName: "checkmark").foregroundStyle(.tint)
        }
      }
    }
    .disabled(
      !store.canChangeLibrary
        || (store.isReady && store.activeLibrary == library
          && store.changeObservationFailure == nil)
    )
    .accessibilityIdentifier("saved.sharing.library." + (library?.id ?? "personal"))
  }

  private func reload() async {
    isLoading = true
    await store.refreshSharing()
    switch store.sharingScope {
    case .off: mode = .off
    case .wholeLibrary: mode = .whole
    case .selectedLists(let identifiers):
      mode = .lists
      lists = identifiers
    }
    isLoading = false
  }

  private func apply() async { await present(await store.changeSharing(to: proposedScope)) }

  private func present(_ share: CKShare?) async {
    guard let share,
      let identifier = Bundle.main.object(forInfoDictionaryKey: "PlannerCloudContainerIdentifier")
        as? String
    else { return }
    invitation = .init(
      share: share, container: CKContainer(identifier: identifier), canEdit: invitationCanEdit)
  }
}
