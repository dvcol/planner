import PlannerCore
import SwiftUI
import UniformTypeIdentifiers

struct SavedRecoverySelectionView: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let selection: PlannerRecoverySelection
  @State private var backupFile: SavedPlannerBackupFile?
  @State private var showExporter = false
  @State private var exportFailure: String?
  @State private var exportedFilename: String?
  @State private var restoreDraft: SavedBackupImportDraft?

  private var backup: PlannerPortableBackup { selection.decodedBackup.backup }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          if selection.evidence == .acknowledgedSnapshot {
            Label("Saved snapshot", systemImage: "checkmark.shield")
              .accessibilityIdentifier("saved.recovery.evidence")
            Text("Planner acknowledged this saved recovery copy.")
              .foregroundStyle(.secondary)
          } else {
            Label("Unverified proposal", systemImage: "exclamationmark.triangle")
              .accessibilityIdentifier("saved.recovery.evidence")
            Text("These proposed changes have not been verified as saved data.")
              .foregroundStyle(.secondary)
          }
          if let exportedFilename {
            LabeledContent("Recovery copy exported", value: exportedFilename)
              .accessibilityIdentifier("saved.recovery.exported")
          }
          DisclosureGroup("Copy details") {
            LabeledContent("Dataset", value: selection.datasetId.uuidString)
            LabeledContent("Recovery copy", value: selection.namespaceId.uuidString)
            if let generation = selection.checkpointGeneration {
              LabeledContent("Saved generation", value: String(generation))
            }
            if let proposalIdentifier = selection.proposalId {
              LabeledContent("Proposal", value: proposalIdentifier.uuidString)
            }
            if let operationIdentifier = selection.originalOperationId {
              LabeledContent("Original operation", value: operationIdentifier.uuidString)
            }
          }
          Button("Review Restore", systemImage: "arrow.uturn.backward") {
            restoreDraft = .init(recoverySelection: selection)
          }
          .disabled(!store.canCreate || showExporter)
          .accessibilityIdentifier("saved.recovery.restore.review")
        }
        Section("Planner data") {
          if backup.sources.isEmpty {
            Text("No Items, Lists, Itineraries or labels")
              .foregroundStyle(.secondary)
          }
          ForEach(backup.sources, id: \.recoveryIdentity) { source in
            LabeledContent(sourceName(source), value: source.kind.rawValue.capitalized)
              .accessibilityIdentifier("saved.recovery.source.\(source.kind.rawValue).\(source.id)")
          }
        }
        Section("References") {
          LabeledContent("List memberships", value: String(backup.memberships.count))
          LabeledContent("Itinerary entries", value: String(backup.itineraryEntries.count))
          LabeledContent("Schedules", value: String(backup.schedules.count))
          LabeledContent("Label associations", value: String(backup.labelAssociations.count))
          LabeledContent("Bookmarks", value: String(backup.ownedLinks.count))
        }
      }
      .formStyle(.grouped)
      .navigationTitle("Recovery Copy")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
            .disabled(showExporter || store.isSaving)
            .accessibilityIdentifier("saved.recovery.selection.done")
        }
        ToolbarItem(placement: .primaryAction) {
          Button("Export", systemImage: "square.and.arrow.up") {
            exportFailure = nil
            exportedFilename = nil
            backupFile = .init(data: selection.portableData, filename: exportFilename)
            showExporter = true
          }
          .disabled(showExporter || store.isSaving)
          .accessibilityIdentifier("saved.recovery.export")
        }
      }
    }
    .sheet(item: $restoreDraft) { draft in
      SavedBackupImportForm(store: store, draft: draft)
    }
    .fileExporter(
      isPresented: $showExporter, item: backupFile, contentTypes: [.json],
      defaultFilename: backupFile?.filename, onCompletion: finishExport,
      onCancellation: { backupFile = nil }
    )
    .alert("Recovery export failed", isPresented: exportFailurePresented) {
      Button("OK", role: .cancel) { exportFailure = nil }
    } message: {
      Text(exportFailure ?? "")
    }
    .interactiveDismissDisabled(showExporter || store.isSaving)
    #if os(macOS)
      .frame(minWidth: 480, minHeight: 440)
    #endif
  }

  private var exportFailurePresented: Binding<Bool> {
    Binding(get: { exportFailure != nil }, set: { if !$0 { exportFailure = nil } })
  }

  private var exportFilename: String {
    let evidenceName: String
    switch selection.evidence {
    case .acknowledgedSnapshot: evidenceName = "Saved"
    case .preparedUnverified: evidenceName = "Unverified"
    }
    var components = ["Planner \(evidenceName) Recovery", selection.namespaceId.uuidString]
    if let generation = selection.checkpointGeneration {
      components.append("Generation \(generation)")
    }
    if let proposalIdentifier = selection.proposalId {
      components.append("Proposal \(proposalIdentifier)")
    }
    return components.joined(separator: " ")
  }

  private func finishExport(_ result: Result<URL, any Error>) {
    backupFile = nil
    switch result {
    case .success(let destination): exportedFilename = destination.lastPathComponent
    case .failure(let error):
      let reason = error as NSError
      guard reason.domain != NSCocoaErrorDomain || reason.code != CocoaError.userCancelled.rawValue
      else { return }
      exportFailure = error.localizedDescription
    }
  }

  private func sourceName(_ source: PlannerPortableSource) -> String {
    switch source {
    case .item(let item): item.content.title
    case .list(let list): list.content.name
    case .itinerary(let itinerary): itinerary.content.title
    case .category(let category): category.content.name
    case .tag(let tag): tag.content.name
    }
  }
}

extension PlannerPortableSource {
  fileprivate var recoveryIdentity: PlannerEntityReference { .init(kind: kind, id: id) }
}
