import SwiftUI

struct SavedItemLabelPicker: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let kind: SavedLabelKind
  @Binding var selection: Set<UUID>
  @State private var labels: [SavedPlannerLabel]?
  @State private var loadingFailure: String?

  var body: some View {
    List {
      ForEach(labels ?? []) { label in
        Toggle(
          label.name,
          isOn: Binding(
            get: { selection.contains(label.id) },
            set: { selected in
              if selected {
                selection.insert(label.id)
              } else {
                selection.remove(label.id)
              }
            })
        )
        .accessibilityIdentifier("saved.item.label.\(kind.rawValue).\(label.id.uuidString)")
      }
    }
    .overlay {
      if let loadingFailure {
        ContentUnavailableView {
          Label("Labels unavailable", systemImage: "exclamationmark.triangle")
        } description: {
          Text(loadingFailure)
        } actions: {
          Button("Try again") { Task { await loadLabels() } }
        }
      } else if labels == nil {
        ProgressView("Loading \(kind.pluralTitle)")
      } else if labels?.isEmpty == true {
        ContentUnavailableView(
          "No \(kind.pluralTitle) yet", systemImage: kind.systemImage,
          description: Text("Create labels in Manage Labels."))
      }
    }
    .navigationTitle(kind.pluralTitle)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") { dismiss() }
          .accessibilityIdentifier("saved.item.labels.done")
      }
    }
    .task(id: store.changeRevision) { await loadLabels() }
  }

  private func loadLabels() async {
    let revision = store.changeRevision
    loadingFailure = nil
    let loaded = await store.readLabels(kind)
    guard !Task.isCancelled, revision == store.changeRevision else { return }
    labels = loaded
    if loaded == nil {
      loadingFailure = store.alertMessage ?? "Planner could not load its \(kind.pluralTitle)."
      store.alertMessage = nil
    }
  }
}
