import PlannerCore
import SwiftUI

struct SavedBackupImportDraft: Identifiable {
  enum Source {
    case file(filename: String, backup: PlannerDecodedBackup)
    case recovery(PlannerRecoverySelection)
  }

  let id = UUID()
  let source: Source

  init(filename: String, backup: PlannerDecodedBackup) {
    source = .file(filename: filename, backup: backup)
  }

  init(recoverySelection: PlannerRecoverySelection) {
    source = .recovery(recoverySelection)
  }

  var recoverySelection: PlannerRecoverySelection? {
    guard case .recovery(let selection) = source else { return nil }
    return selection
  }

  var isRecovery: Bool { recoverySelection != nil }

  var name: String {
    switch source {
    case .file(let filename, _): filename
    case .recovery(let selection):
      selection.evidence == .acknowledgedSnapshot ? "Saved snapshot" : "Unverified proposal"
    }
  }
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
          Text(draft.name).font(.headline)
          if let recoverySelection = draft.recoverySelection {
            LabeledContent("Destination", value: "Current Planner")
              .accessibilityIdentifier("saved.recovery.restore.target")
            if recoverySelection.evidence == .preparedUnverified {
              Text("This proposal contains intended changes that were not verified as saved data.")
                .foregroundStyle(.secondary)
            }
            DisclosureGroup("Recovery details") {
              LabeledContent("Copy dataset", value: recoverySelection.datasetId.uuidString)
              if let targetIdentifier = store.currentDatasetIdentifier {
                LabeledContent("Destination dataset", value: targetIdentifier.uuidString)
              }
            }
          }
          if appliedResult != nil {
            Label(
              draft.isRecovery ? "Restore applied" : "Import applied",
              systemImage: "checkmark.circle"
            )
            .accessibilityIdentifier(
              draft.isRecovery ? "saved.recovery.restore.applied" : "saved.import.applied")
          } else {
            Picker("Matching records", selection: $mode) {
              Text("Skip").tag(PlannerImportMode.skip)
              Text("Overwrite").tag(PlannerImportMode.overwrite)
            }
            .accessibilityIdentifier("saved.import.mode")
            .disabled(store.isSaving)
            Text(modeExplanation)
              .foregroundStyle(.secondary)
            if mode == .overwrite && !draft.isRecovery {
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
              "The changes were applied, but their summary is unavailable.",
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
      .navigationTitle(navigationTitle)
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
            Button(draft.isRecovery ? "Restore" : "Import") { Task { await confirmImport() } }
              .disabled(currentReview == nil || isReviewing || !store.canCreate)
              .accessibilityIdentifier("saved.import.confirm")
          }
        }
      }
      .overlay {
        if store.isSaving {
          ProgressView(draft.isRecovery ? "Restoring recovery copy" : "Importing backup")
        }
      }
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

  private var navigationTitle: String {
    if appliedResult != nil { return draft.isRecovery ? "Restore Result" : "Import Result" }
    return draft.isRecovery ? "Review Recovery" : "Review Backup"
  }

  private var modeExplanation: String {
    if mode == .skip {
      return "Keep current matching records and their contents. Add independent new records."
    }
    if draft.isRecovery {
      return
        "Replace matching records with this copy and restore the listed deleted records. Omitted records stay available."
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
      let prepared: PlannerReview
      switch draft.source {
      case .file(_, let backup):
        prepared = try await store.prepareBackupImport(
          backup, mode: mode, restoreDeletedData: mode == .overwrite && restoreDeletedData)
      case .recovery(let recoverySelection):
        prepared = try await store.prepareRecoveryRestoration(recoverySelection, mode: mode)
      }
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
