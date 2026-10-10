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
  let didMove: (SavedPlannerList) -> Void
  @State private var selectedListIdentifier: UUID?
  @State private var operationIdentifier = UUID()

  private var destinations: [SavedPlannerList] {
    store.lists.filter { $0.id != draft.sourceListIdentifier }
  }

  private var selectedDestination: SavedPlannerList? {
    destinations.first { $0.id == selectedListIdentifier }
  }

  var body: some View {
    NavigationStack {
      List(selection: $selectedListIdentifier) {
        Section {
          Text(draft.itemTitle).font(.headline)
          Text("From \(draft.sourceListName)").foregroundStyle(.secondary)
        }
        Section {
          ForEach(destinations) { destination in
            Label(destination.name, systemImage: "list.bullet.rectangle")
              .tag(destination.id)
              .accessibilityIdentifier("saved.membership.destination.\(destination.id.uuidString)")
          }
        } header: {
          Text("Destination List")
        } footer: {
          Text(
            "New entries start to do unless the Item is completed in Items. Existing entries keep their completion and position."
          )
        }
      }
      .overlay {
        if destinations.isEmpty {
          ContentUnavailableView(
            "No other Lists", systemImage: "list.bullet.rectangle",
            description: Text("Create another List before moving this Item."))
        }
      }
      .navigationTitle("Move Item")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.membership.move.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Move") {
            guard let destination = selectedDestination else { return }
            Task {
              if await store.moveMembership(
                draft.membershipIdentifier, listIdentifier: draft.sourceListIdentifier,
                destinationListIdentifier: destination.id, operationIdentifier: operationIdentifier)
              {
                didMove(destination)
                dismiss()
              }
            }
          }
          .disabled(!store.canCreate || selectedDestination == nil)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.membership.move")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Moving Item") }
      }
    }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 400, minHeight: 320)
    #endif
  }
}
