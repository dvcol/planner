import PlannerCore
import PlannerPreviews
import SwiftUI

struct SavedMembershipWindowRow: Identifiable {
  let id: UUID
  let index: Int
  let identity: PlannerRowIdentity
}

struct SavedMembershipRow: View {
  let item: SavedPlannerItem
  let canChange: Bool
  let toggleCompletion: () -> Void

  var body: some View {
    HStack(alignment: .top) {
      Button(action: toggleCompletion) {
        Label(
          completionLabel,
          systemImage: item.row.effectiveDone == true ? "checkmark.circle.fill" : "circle"
        )
        #if os(iOS)
          .frame(minWidth: 44, minHeight: 44, alignment: .top)
          .contentShape(.rect)
        #endif
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.plain)
      #if os(iOS)
        .foregroundStyle(SavedRowForeground.completion(isDone: item.row.effectiveDone == true))
      #endif
      .disabled(!canChange || item.row.globalDone == true)
      .accessibilityValue(item.row.effectiveDone == true ? "Completed" : "To do")
      .accessibilityIdentifier("saved.appearance.completion.\(item.id.uuidString)")
      .help(completionLabel)
      #if os(macOS)
        SavedItemRowContent(row: item.row, rowPresentation: item.rowPresentation)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(item.row.title)
          .accessibilityValue(item.row.metadataDescription(presentation: item.rowPresentation))
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("saved.appearance.\(item.id.uuidString)")
      #else
        NavigationLink(value: item.id) {
          SavedItemRowContent(row: item.row, rowPresentation: item.rowPresentation)
        }
        .accessibilityLabel(item.row.title)
        .accessibilityValue(item.row.metadataDescription(presentation: item.rowPresentation))
        .accessibilityIdentifier("saved.appearance.\(item.id.uuidString)")
      #endif
      if item.row.archived == true {
        Image(systemName: "archivebox")
          .foregroundStyle(SavedRowForeground.secondary)
          .accessibilityLabel("Archived")
      }
    }
  }

  private var completionLabel: String {
    if item.row.globalDone == true { return "Completed globally: \(item.row.title)" }
    if item.row.effectiveDone == true { return "Mark \(item.row.title) undone in this List" }
    return "Mark \(item.row.title) done in this List"
  }
}

struct SavedAppearanceDetail: View {
  @Environment(SavedPlannerStore.self) private var store
  let item: PlannerAppearanceRead
  let listName: String
  let canChange: Bool
  let addToList: () -> Void
  let viewItem: () -> Void
  let moveToList: () -> Void
  let removeFromList: () -> Void

  var body: some View {
    Form {
      Section {
        Text(item.content.title).font(.title2).fontWeight(.semibold)
        Label(
          item.effectiveDone ? "Completed" : "To do",
          systemImage: item.effectiveDone ? "checkmark.circle.fill" : "circle")
        Text("In \(listName)").font(.subheadline).foregroundStyle(.primary)
        if item.archived {
          Label("Archived", systemImage: "archivebox").foregroundStyle(.secondary)
        }
        if let subtitle = item.content.subtitle, !subtitle.isEmpty {
          Text(subtitle).foregroundStyle(.secondary)
        }
      }
      if let notes = item.content.notes, !notes.isEmpty {
        Section {
          Text(notes).textSelection(.enabled)
        } header: {
          Text("Notes").foregroundStyle(Color.primary)
        }
      }
      SavedItemEstimateSection(estimate: item.content.estimate)
      ItemLabelsSection(labels: item.labels)
      ItemLocationSection(
        title: item.content.title, location: item.content.location, previewSource: previewSource,
        links: item.content.links)
      ItemLinksSection(
        links: item.content.links, sourceId: item.source.id,
        sourceLifetimeId: item.sourceLifetimeId)
    }
    .formStyle(.grouped)
    #if os(iOS)
      .navigationTitle(item.content.title)
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .primaryAction) { actionsMenu }
      }
    #endif
  }

  var actionsMenu: some View {
    Menu {
      Button("Add to list", action: addToList)
        .disabled(!canChange)
      Button("View item", action: viewItem)
      Button("Move to list", action: moveToList)
        .disabled(!canChange)
      Button("Remove from list", role: .destructive, action: removeFromList)
        .disabled(!canChange)
    } label: {
      Label("Item actions", systemImage: "ellipsis")
    }
    .labelStyle(.iconOnly)
    .help("Item actions")
    .accessibilityIdentifier("saved.appearance.actions")
  }

  private var previewSource: PlannerPreviewSource? {
    guard let namespace = store.devicePreferenceNamespace else { return nil }
    return .init(
      namespace: namespace, sourceId: item.source.id, sourceLifetimeId: item.sourceLifetimeId)
  }
}
