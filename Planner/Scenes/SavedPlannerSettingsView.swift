import SwiftUI

struct SavedPlannerSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  @State private var showLabels = false

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
            .disabled(store.isSaving)
            .accessibilityIdentifier("saved.settings.done")
          }
        }
      #endif
    }
    .task { await store.open() }
    .sheet(isPresented: $showLabels) { SavedLabelsView(store: store) }
    .interactiveDismissDisabled(store.isSaving)
    #if os(macOS)
      .frame(minWidth: 440, minHeight: 320)
    #endif
  }
}
