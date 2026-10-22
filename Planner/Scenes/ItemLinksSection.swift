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
  let source: PlannerEntityReference
  let sourceLifetimeId: UUID
  var appearance: PlannerAppearance?
  @Environment(SavedPlannerStore.self) private var store
  @Environment(\.openURL) private var openURL
  @Environment(\.savedWebsiteOpening) private var openWebsite

  var body: some View {
    if !links.isEmpty {
      Section("Links") {
        ForEach(links, id: \.linkId) { link in
          linkContent(link)
            .environment(
              \.openURL,
              OpenURLAction { destination in
                open(destination, link: link)
              })
        }
      }
    }
  }

  @ViewBuilder
  private func linkContent(_ link: PlannerOwnedLinkRead) -> some View {
    if let destination = URL(string: link.originalUrl) {
      Link(destination: destination) {
        Label(link.displayTitle, systemImage: link.systemImage)
      }
      .contextMenu {
        if link.kind != .appleMaps && link.kind != .googleMaps {
          Button("Open in default browser", systemImage: "arrow.up.right.square") {
            openURL(destination)
          }
        }
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
              namespace: namespace, sourceId: source.id,
              sourceLifetimeId: sourceLifetimeId),
            linkId: link.linkId, originalURL: link.originalUrl))
      }
    }
  }

  private func open(_ destination: URL, link: PlannerOwnedLinkRead) -> OpenURLAction.Result {
    guard let openWebsite, let namespace = store.devicePreferenceNamespace,
      link.kind != .appleMaps, link.kind != .googleMaps,
      ["http", "https"].contains(destination.scheme?.lowercased() ?? "")
    else { return .systemAction }
    openWebsite(
      .init(
        destination: destination, linkIdentifier: link.linkId, source: source,
        sourceLifetimeIdentifier: sourceLifetimeId, appearance: appearance, namespace: namespace))
    return .handled
  }
}
