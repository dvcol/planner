import PlannerCore
import SwiftUI

struct SavedRecoverySelectionView: View {
  @Environment(\.dismiss) private var dismiss
  let selection: PlannerRecoverySelection

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
            .accessibilityIdentifier("saved.recovery.selection.done")
        }
      }
    }
    #if os(macOS)
      .frame(minWidth: 480, minHeight: 440)
    #endif
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
