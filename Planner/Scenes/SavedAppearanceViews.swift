import PlannerCore
import SwiftUI

struct SavedMembershipRow: View {
  let item: SavedPlannerItem
  let canChange: Bool
  let toggleCompletion: () -> Void

  var body: some View {
    HStack {
      Button(action: toggleCompletion) {
        Label(
          completionLabel,
          systemImage: item.row.effectiveDone == true ? "checkmark.circle.fill" : "circle")
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.plain)
      .disabled(!canChange || item.row.globalDone == true)
      .accessibilityValue(item.row.effectiveDone == true ? "Completed" : "To do")
      .accessibilityIdentifier("saved.appearance.completion.\(item.id.uuidString)")
      .help(completionLabel)
      #if os(macOS)
        SavedItemRowContent(row: item.row)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(item.row.title)
          .accessibilityValue(item.row.metadataDescription)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("saved.appearance.\(item.id.uuidString)")
      #else
        NavigationLink(value: item.id) {
          SavedItemRowContent(row: item.row)
        }
        .accessibilityLabel(item.row.title)
        .accessibilityValue(item.row.metadataDescription)
        .accessibilityIdentifier("saved.appearance.\(item.id.uuidString)")
      #endif
      if item.row.archived == true {
        Image(systemName: "archivebox").accessibilityLabel("Archived")
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
        Text("In \(listName)").font(.subheadline).foregroundStyle(.secondary)
        if item.archived {
          Label("Archived", systemImage: "archivebox").foregroundStyle(.secondary)
        }
        if let subtitle = item.content.subtitle, !subtitle.isEmpty {
          Text(subtitle).foregroundStyle(.secondary)
        }
      }
      if let notes = item.content.notes, !notes.isEmpty {
        Section("Notes") { Text(notes).textSelection(.enabled) }
      }
      ItemLocationSection(title: item.content.title, location: item.content.location)
      ItemLinksSection(links: item.content.links)
    }
    .formStyle(.grouped)
    .navigationTitle(item.content.title)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Button("Add to List", action: addToList)
            .disabled(!canChange)
          Button("View Item", action: viewItem)
          Button("Move to List", action: moveToList)
            .disabled(!canChange)
          Button("Remove from List", role: .destructive, action: removeFromList)
            .disabled(!canChange)
        } label: {
          Label("Item actions", systemImage: "ellipsis")
        }
        .help("Item actions")
        .accessibilityIdentifier("saved.appearance.actions")
      }
    }
  }
}
