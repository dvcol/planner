import PlannerCore
import SwiftUI

struct SavedMembershipMoveDraft: Identifiable {
  let sourceListIdentifier: UUID
  let membershipIdentifier: UUID
  let sourceListName: String
  let itemTitle: String
  var id: UUID { membershipIdentifier }
}

struct SavedMoveItemForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let draft: SavedMembershipMoveDraft
  let didMove: (PlannerOperationResult, String) -> Void
  @State private var selectedListIdentifier: UUID?
  @State private var operationIdentifier = UUID()
  @State private var window: SavedItemWindow?
  @State private var loadedIdentity: SavedItemWindowIdentity?
  @State private var loadingFailure: String?
  @State private var isPreparingMove = false

  private var loadIdentity: SavedItemWindowIdentity? {
    guard let namespace = store.devicePreferenceNamespace else { return nil }
    return .init(namespace: namespace, savedRevision: store.changeRevision)
  }

  private var selectedDestinationIdentifier: UUID? {
    guard loadedIdentity == loadIdentity, loadIdentity != nil, window?.state == .ready,
      let selectedListIdentifier, selectedListIdentifier != draft.sourceListIdentifier,
      window?.rowIdentities.contains(.source(.init(kind: .list, id: selectedListIdentifier)))
        == true
    else { return nil }
    return selectedListIdentifier
  }

  var body: some View {
    NavigationStack {
      List(selection: $selectedListIdentifier) {
        Section {
          Text(draft.itemTitle).font(.headline)
          Text("From \(draft.sourceListName)").foregroundStyle(.secondary)
        }
        Section {
          if let window {
            SavedContainerWindowRows(
              window: window, sourceKind: .list, excludedIdentifiers: [draft.sourceListIdentifier],
              selectionTag: { $0.id }
            ) { row in
              if case .source(let source) = row.identity {
                Label(row.title, systemImage: "list.bullet.rectangle")
                  .accessibilityIdentifier("saved.membership.destination.\(source.id.uuidString)")
              }
            }
          }
        } header: {
          Text("Destination List")
        } footer: {
          Text(
            "New entries start to do unless the Item is completed in Items. Existing entries keep their completion and position."
          )
        }
      }
      .disabled(store.isSaving || isPreparingMove)
      .accessibilityIdentifier("saved.membership.destinations")
      .overlay {
        if let loadingFailure {
          ContentUnavailableView {
            Label("Lists unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(loadingFailure)
          } actions: {
            Button("Try Again") { Task { await loadLists() } }
          }
        } else if case .failed(let reason) = window?.state {
          ContentUnavailableView {
            Label("Lists unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(reason)
          } actions: {
            Button("Try Again") { Task { await loadLists() } }
          }
        } else if window?.state != .ready || loadedIdentity != loadIdentity {
          ProgressView("Loading Lists")
        } else if destinationCount == 0 {
          ContentUnavailableView(
            "No other Lists", systemImage: "list.bullet.rectangle",
            description: Text("Create another List before moving this Item."))
        }
      }
      .navigationTitle("Move Item")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving || isPreparingMove)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.membership.move.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Move") { Task { await moveSelection() } }
            .disabled(!store.canCreate || isPreparingMove || selectedDestinationIdentifier == nil)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("saved.membership.move")
        }
      }
      .overlay {
        if store.isSaving || isPreparingMove { ProgressView("Moving Item") }
      }
    }
    .task(id: loadIdentity) { await loadLists() }
    .onDisappear { window?.cancel() }
    .interactiveDismissDisabled(store.isSaving || isPreparingMove)
    #if os(macOS)
      .frame(minWidth: 400, minHeight: 320)
    #endif
  }

  private var destinationCount: Int {
    window?.rowIdentities.filter {
      $0 != .source(.init(kind: .list, id: draft.sourceListIdentifier))
    }.count ?? 0
  }

  private func moveSelection() async {
    guard !isPreparingMove, let destinationIdentifier = selectedDestinationIdentifier,
      let identity = loadedIdentity
    else { return }
    isPreparingMove = true
    defer { isPreparingMove = false }
    guard let destination = await store.readList(destinationIdentifier), !Task.isCancelled,
      loadIdentity == identity, selectedDestinationIdentifier == destinationIdentifier
    else { return }
    let result = await store.moveMembership(
      draft.membershipIdentifier, listIdentifier: draft.sourceListIdentifier,
      destinationListIdentifier: destinationIdentifier, operationIdentifier: operationIdentifier)
    if let result, case .applied = result.outcome, loadIdentity?.namespace == identity.namespace {
      didMove(result, destination.content.name)
      dismiss()
    }
  }

  private func loadLists() async {
    guard !Task.isCancelled else { return }
    let identity = loadIdentity
    window?.cancel()
    loadedIdentity = nil
    loadingFailure = nil
    guard let identity, let window = store.makeItemWindow() else {
      self.window = nil
      loadingFailure = "Planner is not ready to load its Lists."
      return
    }
    self.window = window
    await window.reload(
      catalogQuery: .init(sourceKind: .list, archive: .active), identity: identity)
    guard !Task.isCancelled, loadIdentity == identity, self.window === window else { return }
    loadedIdentity = identity
  }

}
