import CoreTransferable
import PlannerCore
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
    let store: SavedPlannerStore
    let list: PlannerListSourceRead
    let items: [SavedPlannerItem]
    let selection: Binding<UUID?>

    var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        SavedListProgress(progress: list.progress, matchingCount: items.count).padding()
        Table(of: SavedPlannerItem.self, selection: selection) {
          TableColumn("Items") { item in
            SavedMembershipRow(item: item, canChange: store.canCreate) {
              guard case .appearance(_, let appearance) = item.row.identity else { return }
              Task {
                _ = await store.setAppearanceCompletion(
                  appearance, done: item.row.effectiveDone != true)
              }
            }
            .contextMenu {
              Button("Move to Beginning") { reorder(item.id, placement: .first) }
                .disabled(!store.canCreate || items.first?.id == item.id)
              Button("Move to End") { reorder(item.id, placement: .last) }
                .disabled(!store.canCreate || items.last?.id == item.id)
            }
          }
        } rows: {
          ForEach(items) { item in
            TableRow(item)
              .draggable(
                SavedMembershipDragReference(listId: list.source.id, membershipId: item.id))
          }
          .dropDestination(for: SavedMembershipDragReference.self) { insertionIndex, references in
            guard store.canCreate, references.count == 1, let reference = references.first,
              reference.listId == list.source.id, (0...items.count).contains(insertionIndex)
            else { return }
            if insertionIndex == items.count {
              reorder(reference.membershipId, placement: .last)
              return
            }
            let anchor = items[insertionIndex].id
            guard anchor != reference.membershipId else { return }
            reorder(reference.membershipId, placement: .before(associationId: anchor))
          }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
      }
    }

    private func reorder(_ membershipId: UUID, placement: PlannerPlacement) {
      Task {
        _ = await store.reorderMembership(
          membershipId, listId: list.source.id, placement: placement)
      }
    }
  }
#endif
