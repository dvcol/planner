import PlannerCore
import SwiftUI

struct SavedLabelDeletionDraft: Identifiable {
  let kind: SavedLabelKind
  let label: SavedLabelSource
  let review: PlannerReview
  var id: UUID { review.reviewId }
}

struct SavedLabelDeletionForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let draft: SavedLabelDeletionDraft
  let onDeleted: () -> Void
  @State private var review: PlannerReview
  @State private var operationIdentifier = UUID()
  @State private var reviewChanged = false

  init(store: SavedPlannerStore, draft: SavedLabelDeletionDraft, onDeleted: @escaping () -> Void) {
    self.store = store
    self.draft = draft
    self.onDeleted = onDeleted
    _review = State(initialValue: draft.review)
  }

  private var identifierPrefix: String { "saved.\(draft.kind.rawValue).delete" }

  private var usageSummary: String {
    let itemCount = associatedOwners(of: .item).count
    let itineraryCount = associatedOwners(of: .itinerary).count
    var descriptions = [String]()
    if itemCount > 0 { descriptions.append("\(itemCount) \(itemCount == 1 ? "Item" : "Items")") }
    if itineraryCount > 0 {
      descriptions.append("\(itineraryCount) \(itineraryCount == 1 ? "Itinerary" : "Itineraries")")
    }
    return descriptions.isEmpty ? "No saved uses" : descriptions.joined(separator: " · ")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(draft.label.name).font(.headline)
          Text(usageSummary).foregroundStyle(.secondary)
        }
        Section {
          Text(
            "This \(draft.kind.title.lowercased()) will be deleted and removed from all its uses.")
          Text("Your Items, Itineraries and their other data stay available.")
            .foregroundStyle(.secondary)
        }
        if reviewChanged {
          Section {
            Label(
              "The uses changed. Review the updated counts before confirming again.",
              systemImage: "arrow.trianglehead.clockwise")
          }
        }
        if let message = store.alertMessage {
          Section {
            Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
          }
        }
      }
      .formStyle(.grouped)
      .navigationTitle("Delete \(draft.kind.title)")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("\(identifierPrefix).cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Delete", role: .destructive) { Task { await confirmDeletion() } }
            .disabled(!store.canCreate)
            .accessibilityIdentifier("\(identifierPrefix).confirm")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Deleting \(draft.kind.title)") }
      }
    }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 420, minHeight: 340)
    #endif
  }

  private func associatedOwners(of kind: PlannerEntityKind) -> Set<UUID> {
    Set(
      review.impact.referenceRemovals.compactMap { reference in
        guard case .labelAssociation(_, let owner, _) = reference, owner.kind == kind else {
          return nil
        }
        return owner.id
      })
  }

  private func confirmDeletion() async {
    switch await store.applyReviewedChange(review, operationIdentifier: operationIdentifier) {
    case .applied:
      if store.alertMessage == nil {
        onDeleted()
        dismiss()
      }
    case .reviewChanged(let refreshed):
      review = refreshed
      reviewChanged = true
    case .failed: break
    }
  }
}
