import PlannerCore
import SwiftUI

struct SavedBackupImportDraft: Identifiable {
  let id = UUID()
  let filename: String
  let backup: PlannerDecodedBackup
}

struct SavedBackupImportForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let draft: SavedBackupImportDraft
  @State private var mode = PlannerImportMode.skip
  @State private var restoreDeletedData = false
  @State private var review: PlannerReview?
  @State private var preparedSelection: String?
  @State private var isReviewing = false
  @State private var reviewFailure: String?
  @State private var reviewChanged = false
  @State private var operationIdentifier = UUID()
  @State private var appliedResult: PlannerAppliedResult?
  @State private var reviewRequest = UUID()

  private var selection: String { "\(mode.rawValue):\(restoreDeletedData)" }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(draft.filename).font(.headline)
          if appliedResult != nil {
            Label("Import applied", systemImage: "checkmark.circle")
              .accessibilityIdentifier("saved.import.applied")
          } else {
            Picker("Matching records", selection: $mode) {
              Text("Skip").tag(PlannerImportMode.skip)
              Text("Overwrite").tag(PlannerImportMode.overwrite)
            }
            .accessibilityIdentifier("saved.import.mode")
            .disabled(store.isSaving)
            Text(modeExplanation)
              .foregroundStyle(.secondary)
            if mode == .overwrite {
              Toggle("Restore previously deleted data", isOn: $restoreDeletedData)
                .disabled(store.isSaving)
                .accessibilityIdentifier("saved.import.restore")
              Text(
                "Restoration is a separate choice. Review the listed restored records and deletions before importing."
              )
              .foregroundStyle(.secondary)
            }
          }
        }
        if let details = appliedResult?.importSummary ?? currentReview?.impact.importDetails {
          SavedBackupImportSummary(details: details)
        } else if appliedResult != nil {
          Section {
            Label(
              "The import was applied, but its summary is unavailable.",
              systemImage: "exclamationmark.triangle")
          }
        } else if isReviewing {
          Section { ProgressView("Reviewing backup") }
        }
        if reviewChanged {
          Section {
            Label(
              "Current data changed. Review the refreshed impact before confirming again.",
              systemImage: "arrow.trianglehead.clockwise")
          }
        }
        if let message = reviewFailure ?? store.alertMessage {
          Section {
            Label(message, systemImage: "exclamationmark.triangle")
              .foregroundStyle(.red)
          }
        }
        if reviewFailure != nil {
          Section {
            Button("Try Again") { Task { await prepareReview() } }
              .disabled(isReviewing || store.isSaving)
          }
        }
      }
      .id(appliedResult != nil)
      .formStyle(.grouped)
      .accessibilityIdentifier("saved.import.form")
      .navigationTitle(appliedResult == nil ? "Review Backup" : "Import Result")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(appliedResult == nil ? "Cancel" : "Done") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.import.close")
        }
        if appliedResult == nil {
          ToolbarItem(placement: .confirmationAction) {
            Button("Import") { Task { await confirmImport() } }
              .disabled(currentReview == nil || isReviewing || !store.canCreate)
              .accessibilityIdentifier("saved.import.confirm")
          }
        }
      }
      .overlay { if store.isSaving { ProgressView("Importing backup") } }
    }
    .task(id: selection) { await prepareReview() }
    .onChange(of: mode) { if mode == .skip { restoreDeletedData = false } }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 480, minHeight: 480)
    #endif
  }

  private var currentReview: PlannerReview? {
    guard preparedSelection == selection else { return nil }
    return review
  }

  private var modeExplanation: String {
    if mode == .skip {
      return "Keep current matching records and their contents. Add independent new records."
    }
    return
      "Replace represented matching records and their contents with the backup. Omitted records stay available."
  }

  private func prepareReview() async {
    guard appliedResult == nil else { return }
    let requestedSelection = selection
    let request = UUID()
    reviewRequest = request
    review = nil
    preparedSelection = nil
    reviewFailure = nil
    reviewChanged = false
    isReviewing = true
    defer { if reviewRequest == request { isReviewing = false } }
    do {
      let prepared = try await store.prepareBackupImport(
        draft.backup, mode: mode, restoreDeletedData: mode == .overwrite && restoreDeletedData)
      guard !Task.isCancelled, reviewRequest == request, selection == requestedSelection else {
        return
      }
      review = prepared
      preparedSelection = requestedSelection
      operationIdentifier = UUID()
    } catch {
      guard !Task.isCancelled, reviewRequest == request, selection == requestedSelection else {
        return
      }
      reviewFailure = (error as? PlannerFailure)?.message ?? error.localizedDescription
    }
  }

  private func confirmImport() async {
    guard let currentReview, !isReviewing else { return }
    switch await store.applyReviewedChange(currentReview, operationIdentifier: operationIdentifier)
    {
    case .applied(let result):
      appliedResult = result
      await store.refreshLists()
      await store.refreshItems()
    case .reviewChanged(let refreshed):
      review = refreshed
      operationIdentifier = UUID()
      reviewChanged = true
    case .failed: break
    }
  }
}
