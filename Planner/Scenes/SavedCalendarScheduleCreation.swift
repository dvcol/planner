import PlannerCore
import SwiftUI

/// Reuse the normal booking form after choosing a live Item or Itinerary.
struct SavedCalendarScheduleCreation: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let date: Date
  let timeZone: TimeZone
  @State private var kind = PlannerEntityKind.item
  @State private var searchText = ""
  @State private var window: SavedItemWindow?
  @State private var owner: PlannerEntityReference?
  @State private var ownerTitle = ""
  @State private var loadingFailure: String?

  private var loadIdentity: String {
    (store.devicePreferenceNamespace ?? "") + store.changeRevision.uuidString + kind.rawValue
      + searchText
  }

  var body: some View {
    Group {
      if let owner {
        SavedScheduleForm(
          store: store, source: owner, sourceTitle: ownerTitle,
          proposedStart: date, proposedTimeZone: timeZone)
      } else {
        NavigationStack {
          List {
            Picker("Schedule", selection: $kind) {
              Text("Item").tag(PlannerEntityKind.item)
              Text("Itinerary").tag(PlannerEntityKind.itinerary)
            }.pickerStyle(.segmented)
            if let window {
              SavedContainerWindowRows(window: window, sourceKind: kind, selectionTag: { $0 }) {
                row in
                if case .source(let source) = row.identity {
                  Button {
                    ownerTitle = row.title
                    owner = source
                  } label: {
                    Label(
                      row.title,
                      systemImage: kind == .item
                        ? "square.stack" : "point.topleft.down.to.point.bottomright.curvepath")
                  }
                  .accessibilityIdentifier("saved.calendar.owner.\(source.id.uuidString)")
                }
              }
              if case .failed(let reason) = window.state {
                Text(reason).foregroundStyle(.secondary)
                Button("Try again") { Task { await loadOwners() } }
              } else if window.state == .loading {
                ProgressView("Loading")
              } else if window.state == .ready && window.matchingCount == 0 {
                Text("Create an Item or Itinerary first, then schedule it here.")
                  .foregroundStyle(.secondary)
              }
            } else if let loadingFailure {
              Text(loadingFailure).foregroundStyle(.secondary)
              Button("Try again") { Task { await loadOwners() } }
            } else {
              ProgressView("Loading")
            }
          }
          .searchable(text: $searchText, prompt: "Find a plan to schedule")
          .navigationTitle("Schedule a plan")
          .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          }
          .task(id: loadIdentity) { await loadOwners() }
          .onDisappear { window?.cancel() }
        }
      }
    }
    #if os(macOS)
      .frame(minWidth: 420, minHeight: 440)
    #endif
  }

  private func loadOwners() async {
    window?.cancel()
    window = nil
    loadingFailure = nil
    guard let namespace = store.devicePreferenceNamespace, let window = store.makeItemWindow()
    else {
      loadingFailure = "Planner is not ready to load plans."
      return
    }
    self.window = window
    let identity = SavedItemWindowIdentity(
      namespace: namespace, savedRevision: store.changeRevision)
    if kind == .item {
      await window.reload(
        query: .init(text: searchText, completion: .all, archive: .active), identity: identity)
    } else {
      await window.reload(
        catalogQuery: .init(sourceKind: .itinerary, text: searchText), identity: identity)
    }
  }
}
