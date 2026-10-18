import CoreTransferable
import PlannerCore
import PlannerPreviews
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
  private struct SavedMembershipDragReference: Codable, Transferable {
    let listId: UUID
    let membershipId: UUID

    static var transferRepresentation: some TransferRepresentation {
      CodableRepresentation(
        contentType: UTType(exportedAs: "com.dvcol.planner.list-membership", conformingTo: .data))
    }
  }

  struct SavedMacMembershipTable: View {
    @Environment(PlannerPreviews.self) private var previews
    let store: SavedPlannerStore
    let list: PlannerListSourceRead
    let window: SavedItemWindow
    let rows: [SavedMembershipWindowRow]
    let selection: Binding<UUID?>
    let canReorderMemberships: Bool
    let visibilityChanged: (UUID, Bool) -> Void
    let retryMembership: (SavedMembershipWindowRow) -> Void
    let addToList: (SavedPlannerItem) -> Void
    let moveMembership: (SavedPlannerItem) -> Void
    let removeMembership: (UUID) -> Void

    var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        SavedListProgress(
          listName: list.content.name, progress: list.progress, estimates: list.estimates,
          manualEstimate: list.content.manualEstimate, matchingCount: rows.count,
          isArchived: list.state.archived == true
        ).padding()
        Table(of: SavedMembershipWindowRow.self, selection: selection) {
          TableColumn("Items") { row in
            cell(row)
              .environment(store)
              .environment(previews)
              .onScrollVisibilityChange { visible in visibilityChanged(row.id, visible) }
          }
        } rows: {
          ForEach(rows) { row in
            if canReorderMemberships, case .loaded(let item) = window.presentation(at: row.index),
              item.id == row.id
            {
              TableRow(row)
                .draggable(
                  SavedMembershipDragReference(listId: list.source.id, membershipId: item.id))
            } else {
              TableRow(row)
            }
          }
          .dropDestination(for: SavedMembershipDragReference.self) { insertionIndex, references in
            guard canReorderMemberships, references.count == 1, let reference = references.first,
              reference.listId == list.source.id, (0...rows.count).contains(insertionIndex)
            else { return }
            if insertionIndex == rows.count {
              reorder(reference.membershipId, placement: .last)
              return
            }
            let anchor = rows[insertionIndex].id
            guard anchor != reference.membershipId else { return }
            reorder(reference.membershipId, placement: .before(associationId: anchor))
          }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .accessibilityIdentifier("saved.list.contents")
      }
    }

    @ViewBuilder
    private func cell(_ row: SavedMembershipWindowRow) -> some View {
      switch window.presentation(at: row.index) {
      case .loaded(let item) where item.id == row.id:
        SavedMembershipRow(item: item, canChange: store.canCreate) {
          guard case .appearance(_, let appearance) = item.row.identity else { return }
          Task {
            _ = await store.setAppearanceCompletion(
              appearance, done: item.row.effectiveDone != true)
          }
        }
        .contextMenu {
          Button("Move to Beginning") { reorder(item.id, placement: .first) }
            .disabled(!canReorderMemberships || rows.first?.id == item.id)
          Button("Move to End") { reorder(item.id, placement: .last) }
            .disabled(!canReorderMemberships || rows.last?.id == item.id)
          Divider()
          Button("Add to List") { addToList(item) }.disabled(!store.canCreate)
          Button("Move to List") { moveMembership(item) }.disabled(!store.canCreate)
          Button("Remove from List", role: .destructive) { removeMembership(item.id) }
            .disabled(!store.canCreate)
        }
      case .loading, .loaded:
        ProgressView("Loading Item")
      case .failed(let reason):
        VStack(alignment: .leading) {
          Text(reason).foregroundStyle(.secondary)
          Button("Try Again") { retryMembership(row) }
        }
      }
    }

    private func reorder(_ membershipId: UUID, placement: PlannerPlacement) {
      guard canReorderMemberships else { return }
      Task {
        _ = await store.reorderMembership(
          membershipId, listId: list.source.id, placement: placement)
      }
    }
  }
#endif
