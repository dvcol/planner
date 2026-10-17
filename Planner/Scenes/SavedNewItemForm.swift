import Observation
import PlannerCore
import SwiftUI

@MainActor @Observable
final class SavedNewItemDraft: Identifiable {
  let id = UUID()
  var destination: PlannerListSourceRead?
  var proposedDestination: PlannerListSourceRead?

  let listIdentifier: UUID?
  let namespace: String
  var title = ""
  var subtitle = ""
  var notes = ""
  var estimate: PlannerEstimate?
  var location = SavedOwnedLocationDraft(nil)
  var links: [SavedOwnedLinkDraft] = []
  var categoryIdentifiers: Set<UUID> = []
  var tagIdentifiers: Set<UUID> = []

  init(destination: PlannerListSourceRead?, namespace: String) {
    self.destination = destination
    listIdentifier = destination?.source.id
    self.namespace = namespace
  }

  var hasChanges: Bool {
    !title.isEmpty || !subtitle.isEmpty || !notes.isEmpty || estimate != nil
      || location.value != nil || !links.isEmpty
      || !categoryIdentifiers.isEmpty || !tagIdentifiers.isEmpty
  }

  var content: PlannerItemContentInput {
    .init(
      title: title, subtitle: subtitle.isEmpty ? nil : subtitle,
      notes: notes.isEmpty ? nil : notes, location: location.value,
      estimate: estimate, links: links.map(\.input),
      categoryIds: categoryIdentifiers, tagIds: tagIdentifiers)
  }
}

struct SavedNewItemForm: View {
  #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif
  let store: SavedPlannerStore
  @Bindable var draft: SavedNewItemDraft
  let isSaving: Bool
  let cancel: () -> Void
  let save: () -> Void
  @State private var presentedLabelKind: SavedLabelKind?

  var body: some View {
    NavigationStack {
      Form {
        if let destination = draft.destination {
          Section {
            LabeledContent("List", value: destination.content.name)
              .accessibilityIdentifier("saved.item.destination")
          }
        }
        Section {
          TextField("Title", text: $draft.title)
            .accessibilityIdentifier("saved.item.title")
          TextField("Subtitle", text: $draft.subtitle)
            .accessibilityIdentifier("saved.item.subtitle")
          TextField("Notes", text: $draft.notes, axis: .vertical)
            .lineLimit(3...8)
            .accessibilityIdentifier("saved.item.notes")
        }
        SavedActivityEstimateEditor(
          estimate: $draft.estimate, accessibilityIdentifierPrefix: "saved.item.estimate")
        Section("Labels") {
          Button {
            presentedLabelKind = .category
          } label: {
            LabeledContent("Categories", value: labelSummary(draft.categoryIdentifiers))
          }
          .accessibilityIdentifier("saved.item.categories")
          Button {
            presentedLabelKind = .tag
          } label: {
            LabeledContent("Tags", value: labelSummary(draft.tagIdentifiers))
          }
          .accessibilityIdentifier("saved.item.tags")
        }
        SavedOwnedLocationEditor(
          draft: $draft.location, title: draft.title,
          accessibilityIdentifierPrefix: "saved.item.location")
        SavedOwnedLinksEditor(links: $draft.links, accessibilityIdentifierPrefix: "saved.item.link")
      }
      .disabled(isSaving)
      .formStyle(.grouped)
      .navigationTitle("New Item")
      .toolbarTitleDisplayMode(.inline)
      #if os(iOS)
        .navigationBarBackButtonHidden(horizontalSizeClass == .compact)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          cancelButton
            .disabled(isSaving)
            .keyboardShortcut(.cancelAction)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save)
            .disabled(
              isSaving || !store.canCreate
                || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("saved.item.save")
        }
      }
      .overlay {
        if isSaving { ProgressView("Saving Item") }
      }
    }
    .popover(item: $presentedLabelKind) { kind in
      let selection = kind == .category ? $draft.categoryIdentifiers : $draft.tagIdentifiers
      NavigationStack {
        SavedItemLabelPicker(store: store, kind: kind, selection: selection)
      }
      .frame(minWidth: 320, idealWidth: 360, minHeight: 420)
      #if os(iOS)
        .presentationCompactAdaptation(.sheet)
        .presentationDetents([.large])
      #endif
    }
    .confirmationDialog(
      "Review Item destination",
      isPresented: Binding(
        get: { draft.proposedDestination != nil },
        set: { if !$0 { draft.proposedDestination = nil } }),
      titleVisibility: .visible
    ) {
      if let destination = draft.proposedDestination {
        Button("Use This List") {
          draft.destination = destination
          draft.proposedDestination = nil
        }
      }
      Button("Keep Editing", role: .cancel) { draft.proposedDestination = nil }
    } message: {
      Text(
        "The original List changed. Save to \(draft.proposedDestination?.content.name ?? "this List") instead? Your draft is preserved."
      )
    }
    .alert(
      "Planner",
      isPresented: Binding(
        get: { store.alertMessage != nil },
        set: { if !$0 { store.alertMessage = nil } })
    ) {
      Button("OK") { store.alertMessage = nil }
    } message: {
      Text(store.alertMessage ?? "")
    }
  }

  @ViewBuilder
  private var cancelButton: some View {
    #if os(iOS)
      if horizontalSizeClass == .compact {
        Button("Back", systemImage: "chevron.backward", action: cancel)
          .labelStyle(.iconOnly)
          .accessibilityIdentifier("saved.item.back")
      } else {
        Button("Cancel", action: cancel).accessibilityIdentifier("saved.item.cancel")
      }
    #else
      Button("Cancel", action: cancel).accessibilityIdentifier("saved.item.cancel")
    #endif
  }

  private func labelSummary(_ identifiers: Set<UUID>) -> String {
    identifiers.isEmpty ? "None" : "\(identifiers.count) selected"
  }
}
