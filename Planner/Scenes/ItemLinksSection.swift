import PlannerCore
import PlannerPreviews
import SwiftUI

extension PlannerOwnedLinkRead {
  var editInput: PlannerLinkInput {
    PlannerLinkInput(linkId: linkId, originalUrl: originalUrl, label: label)
  }

  var displayTitle: String {
    if let label, !label.isEmpty { return label }
    return URL(string: originalUrl)?.host() ?? originalUrl
  }

  var systemImage: String {
    if kind == .appleMaps || kind == .googleMaps { return "map" }
    return "link"
  }
}

struct ItemLinksSection: View {
  let links: [PlannerOwnedLinkRead]
  let sourceId: UUID
  let sourceLifetimeId: UUID
  @Environment(SavedPlannerStore.self) private var store

  var body: some View {
    if !links.isEmpty {
      Section("Links") {
        ForEach(links, id: \.linkId) { link in
          if let destination = URL(string: link.originalUrl) {
            Link(destination: destination) {
              Label(link.displayTitle, systemImage: link.systemImage)
            }
            .help(link.originalUrl)
            .accessibilityLabel(link.displayTitle)
            .accessibilityValue(link.originalUrl)
            .accessibilityIdentifier("saved.item.link.\(link.linkId.uuidString)")
            if link.kind != .appleMaps && link.kind != .googleMaps,
              let namespace = store.devicePreferenceNamespace
            {
              ItemLinkPreviewCard(
                link: link,
                request: .init(
                  source: .init(
                    namespace: namespace, sourceId: sourceId,
                    sourceLifetimeId: sourceLifetimeId),
                  linkId: link.linkId, originalURL: link.originalUrl))
            }
          }
        }
      }
    }
  }
}
