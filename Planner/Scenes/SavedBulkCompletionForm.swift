import PlannerCore
import SwiftUI

struct SavedBulkCompletionDraft: Identifiable {
  let containerName: String
  let review: PlannerReview
  var id: UUID { review.reviewId }
}

struct SavedBulkCompletionForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let draft: SavedBulkCompletionDraft
  @State private var review: PlannerReview
  @State private var operationIdentifier = UUID()
  @State private var reviewChanged = false

  init(store: SavedPlannerStore, draft: SavedBulkCompletionDraft) {
    self.store = store
    self.draft = draft
    _review = State(initialValue: draft.review)
  }

  private var marksDone: Bool {
    guard case .setBulkCompletion(_, let done) = review.command else { return false }
    return done
  }

  private var actionTitle: String { marksDone ? "Mark all done" : "Mark all undone" }

  private var contextDescription: String {
    guard case .setBulkCompletion(let scope, _) = review.command else { return "this plan" }
    switch scope {
    case .list: return "this List"
    case .itinerary: return "this Itinerary"
    case .itineraryListEntry: return "this List entry in the Itinerary"
    }
  }

  private var identifierPrefix: String {
    guard case .setBulkCompletion(let scope, _) = review.command else { return "saved.bulk" }
    switch scope {
    case .list: return "saved.list.bulk"
    case .itinerary: return "saved.itinerary.bulk"
    case .itineraryListEntry: return "saved.itinerary.list.bulk"
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          let unit = review.targetCount == 1 ? "item" : "items"
          Text("\(review.targetCount) \(unit) in \(draft.containerName)").font(.headline)
          Text("Includes archived items and items hidden by filters.")
            .foregroundStyle(.secondary)
        }
        Section {
          Text("Only completion in \(contextDescription) changes.")
          if !marksDone { Text("Items completed globally will still appear done.") }
        }
        if reviewChanged {
          Section {
            Label(
              "The items changed. Review the updated count before confirming again.",
              systemImage: "arrow.trianglehead.clockwise")
          }
        }
        if let message = store.alertMessage {
          Section {
            Label(message, systemImage: "exclamationmark.triangle")
              .foregroundStyle(.red)
          }
        }
      }
      .formStyle(.grouped)
      .navigationTitle(actionTitle)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("\(identifierPrefix).cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Confirm") {
            Task {
              switch await store.applyReviewedChange(
                review, operationIdentifier: operationIdentifier)
              {
              case .applied:
                if store.alertMessage == nil { dismiss() }
              case .reviewChanged(let refreshed):
                review = refreshed
                reviewChanged = true
              case .failed: break
              }
            }
          }
          .disabled(!store.canCreate)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("\(identifierPrefix).confirm")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Saving completion") }
      }
    }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 420, minHeight: 320)
    #endif
  }
}
