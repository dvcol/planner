import PlannerCore
import SwiftUI
import UniformTypeIdentifiers

struct SavedPlannerSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  @State private var showLabels = false
  @State private var exportRequest: UUID?
  @State private var backupFile: SavedPlannerBackupFile?
  @State private var showExporter = false
  @State private var exportFailure: String?
  @State private var exportedFilename: String?
  @State private var showImporter = false
  @State private var importURL: URL?
  @State private var importDraft: SavedBackupImportDraft?
  @State private var importFailure: String?

  var body: some View {
    NavigationStack {
      Group {
        if store.isReady {
          Form {
            Section("Organization") {
              Button("Manage Labels", systemImage: "square.grid.2x2") { showLabels = true }
                .disabled(store.isSaving)
                .accessibilityIdentifier("saved.settings.labels")
            }
            Section {
              Button("Export Backup", systemImage: "square.and.arrow.up") {
                exportFailure = nil
                exportedFilename = nil
                exportRequest = UUID()
              }
              .disabled(store.isSaving || exportRequest != nil || showExporter)
              .accessibilityIdentifier("saved.settings.export")
              if exportRequest != nil {
                ProgressView("Preparing backup")
              }
              if let exportedFilename {
                LabeledContent("Backup exported", value: exportedFilename)
                  .accessibilityIdentifier("saved.settings.exported")
              }
              Button("Import Backup", systemImage: "square.and.arrow.down") {
                importFailure = nil
                showImporter = true
              }
              .disabled(
                !store.canCreate || exportRequest != nil || showExporter || importURL != nil
              )
              .accessibilityIdentifier("saved.settings.import")
              if importURL != nil { ProgressView("Reading backup") }
            } header: {
              Text("Data")
            } footer: {
              Text(
                "Save or import a JSON copy of your Planner data, including archived content. Import changes are reviewed before applying."
              )
            }
          }
          .formStyle(.grouped)
        } else if let reason = store.openingFailure {
          ContentUnavailableView {
            Label("Planner unavailable", systemImage: "exclamationmark.triangle")
          } description: {
            Text(reason)
          } actions: {
            Button("Try Again") { Task { await store.open() } }
          }
        } else {
          ProgressView("Opening Planner")
        }
      }
      .navigationTitle("Planner Settings")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
            .disabled(store.isSaving || importURL != nil)
            .accessibilityIdentifier("saved.settings.done")
          }
        }
      #endif
    }
    .task { await store.open() }
    .task(id: exportRequest) { await prepareBackup() }
    .task(id: importURL) { await prepareImport() }
    .sheet(isPresented: $showLabels) { SavedLabelsView(store: store) }
    .sheet(item: $importDraft) { draft in SavedBackupImportForm(store: store, draft: draft) }
    .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
      switch result {
      case .success(let selectedURL): importURL = selectedURL
      case .failure(let error): importFailure = error.localizedDescription
      }
    }
    .fileExporter(
      isPresented: $showExporter, item: backupFile, contentTypes: [.json],
      defaultFilename: backupFile?.filename, onCompletion: finishExport,
      onCancellation: { backupFile = nil }
    )
    .alert("Backup export failed", isPresented: exportFailurePresented) {
      Button("OK", role: .cancel) { exportFailure = nil }
    } message: {
      Text(exportFailure ?? "")
    }
    .alert("Backup import failed", isPresented: importFailurePresented) {
      Button("OK", role: .cancel) { importFailure = nil }
    } message: {
      Text(importFailure ?? "")
    }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 440, minHeight: 320)
    #endif
  }

  private var exportFailurePresented: Binding<Bool> {
    Binding(
      get: { exportFailure != nil },
      set: { if !$0 { exportFailure = nil } })
  }

  private var importFailurePresented: Binding<Bool> {
    Binding(get: { importFailure != nil }, set: { if !$0 { importFailure = nil } })
  }

  private func prepareImport() async {
    guard let selectedURL = importURL else { return }
    defer { if importURL == selectedURL { importURL = nil } }
    do {
      let data = try await Task.detached {
        try SavedPlannerBackupFile.readSelectedFile(selectedURL)
      }.value
      let backup = try await store.decodeBackup(data)
      guard !Task.isCancelled, importURL == selectedURL else { return }
      importDraft = .init(filename: selectedURL.lastPathComponent, backup: backup)
    } catch {
      guard !Task.isCancelled, importURL == selectedURL else { return }
      importFailure = (error as? PlannerFailure)?.message ?? error.localizedDescription
    }
  }

  private func prepareBackup() async {
    guard let request = exportRequest else { return }
    defer { if exportRequest == request { exportRequest = nil } }
    do {
      let data = try await store.exportBackup()
      guard !Task.isCancelled, exportRequest == request else { return }
      backupFile = SavedPlannerBackupFile(data: data)
      showExporter = true
    } catch {
      guard !Task.isCancelled, exportRequest == request else { return }
      exportFailure = (error as? PlannerFailure)?.message ?? error.localizedDescription
    }
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
}
