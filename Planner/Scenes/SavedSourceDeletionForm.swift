import PlannerCore
import SwiftUI

struct SavedSourceDeletionDraft: Identifiable {
  let source: PlannerEntityReference
  let name: String
  let review: PlannerReview
  var id: UUID { review.reviewId }
}

struct SavedSourceDeletionForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let draft: SavedSourceDeletionDraft
  let onDeleted: (PlannerReview) -> Void
  @State private var review: PlannerReview
  @State private var operationIdentifier = UUID()
  @State private var reviewChanged = false

  init(
    store: SavedPlannerStore, draft: SavedSourceDeletionDraft,
    onDeleted: @escaping (PlannerReview) -> Void
  ) {
    self.store = store
    self.draft = draft
    self.onDeleted = onDeleted
    _review = State(initialValue: draft.review)
  }

  private var identifierPrefix: String { "saved.\(draft.source.kind.rawValue).delete" }
  private var sourceKindTitle: String { draft.source.kind.rawValue.capitalized }

  private var usageSummary: String {
    if [.item, .list, .itinerary].contains(draft.source.kind) {
      let count = review.impact.referenceRemovals.count
      if count == 0 { return "No saved references" }
      return "\(count) saved \(count == 1 ? "reference" : "references")"
    }
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
          Text(draft.name).font(.headline)
          Text(usageSummary).foregroundStyle(.secondary)
        }
        Section {
          if draft.source.kind == .item {
            Text(
              "This Item, its links and appointments will be deleted, and it will be removed from all Lists and Itineraries."
            )
            Text("Your other Items, Lists, Itineraries and shared labels stay available.")
              .foregroundStyle(.secondary)
          } else if draft.source.kind == .list {
            Text("This List, its memberships and its references in Itineraries will be deleted.")
            Text("Your Items, other Lists, Itineraries and appointments stay available.")
              .foregroundStyle(.secondary)
          } else if draft.source.kind == .itinerary {
            Text("This Itinerary, its links, appointments and route entries will be deleted.")
            Text("Your Items, Lists, other Itineraries and their appointments stay available.")
              .foregroundStyle(.secondary)
          } else {
            Text(
              "This \(sourceKindTitle.lowercased()) will be deleted and removed from all its uses.")
            Text("Your Items, Itineraries and their other data stay available.")
              .foregroundStyle(.secondary)
          }
        }
        if reviewChanged {
          Section {
            Label(
              "The references changed. Review the updated impact before confirming again.",
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
      .navigationTitle("Delete \(sourceKindTitle)")
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
        if store.isSaving { ProgressView("Deleting \(sourceKindTitle)") }
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
      onDeleted(review)
      if store.alertMessage == nil {
        dismiss()
      }
    case .reviewChanged(let refreshed):
      review = refreshed
      reviewChanged = true
    case .failed: break
    }
  }
}
