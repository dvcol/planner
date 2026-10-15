import MapKit
import PlannerCore
import PlannerPreviews
import SwiftUI

struct ItemMapsPreviewSection: View {
  let links: [PlannerOwnedLinkRead]
  let source: PlannerPreviewSource
  @State private var selectedLinkIdentifier: UUID?

  var body: some View {
    Section("Map preview") {
      if links.count > 1 {
        Picker("Map link", selection: $selectedLinkIdentifier) {
          ForEach(links, id: \.linkId) { link in
            Text(link.label ?? link.originalUrl).tag(Optional(link.linkId))
          }
        }
        .accessibilityIdentifier("saved.item.maps.preview.source")
      }
      if let link = links.first(where: { $0.linkId == selectedLinkIdentifier }) ?? links.first {
        let request = PlannerLinkPreviewRequest(
          source: source, linkId: link.linkId, originalURL: link.originalUrl)
        ItemMapsPreview(request: request).id(request)
      }
    }
    .onChange(of: links.map(\.linkId), initial: true) {
      guard !links.contains(where: { $0.linkId == selectedLinkIdentifier }) else { return }
      selectedLinkIdentifier = links.first?.linkId
    }
  }
}

private struct ItemMapsPreview: View {
  let request: PlannerLinkPreviewRequest
  @Environment(PlannerMapsPreviews.self) private var previews
  @State private var result: PlannerMapsPreviewResult?
  @State private var retryIdentifier: UUID?
  @State private var consumedRetryIdentifier: UUID?
  @State private var activeRequestIdentifier: UUID?

  var body: some View {
    Group {
      switch result {
      case nil:
        ProgressView("Loading map preview")
      case .unavailable:
        Label("Map preview unavailable", systemImage: "mappin.slash")
          .foregroundStyle(.secondary)
        fallbackLink
        retryButton
      case .available(let candidate):
        preview(candidate)
      }
    }
    .task(id: retryIdentifier) {
      let identifier = UUID()
      activeRequestIdentifier = identifier
      result = nil
      let shouldRetry = retryIdentifier != nil && retryIdentifier != consumedRetryIdentifier
      consumedRetryIdentifier = retryIdentifier
      let loaded: PlannerMapsPreviewResult?
      if shouldRetry {
        loaded = await previews.retry(request)
      } else {
        loaded = await previews.load(request)
      }
      guard !Task.isCancelled, activeRequestIdentifier == identifier else { return }
      result = loaded ?? .unavailable
    }
    .onDisappear { activeRequestIdentifier = nil }
  }

  @ViewBuilder
  private func preview(_ candidate: PlannerCapturePreviewCandidate) -> some View {
    let title = candidate.provider == .googleMaps ? "Search location" : candidate.displayName
    if let title { Text(title).font(.headline) }
    if let coordinate = candidate.coordinate {
      ItemLocationMap(
        title: title ?? "Map location",
        coordinate: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
        accessibilityIdentifier: "saved.item.maps.preview.map")
    } else {
      if candidate.provider == .googleMaps, let name = candidate.displayName { Text(name) }
      if let address = candidate.formattedAddress { Text(address) }
      Label("Open the saved link to choose a place", systemImage: "map")
        .foregroundStyle(.secondary)
      fallbackLink
    }
    if let attribution = candidate.attributionText {
      Text(attribution).font(.caption).foregroundStyle(.secondary)
    }
    ForEach(candidate.uncertaintyReasons, id: \.self) { reason in
      Text(reason).font(.caption).foregroundStyle(.secondary)
    }
  }

  private var retryButton: some View {
    Button("Retry", systemImage: "arrow.clockwise") { retryIdentifier = UUID() }
      .accessibilityIdentifier("saved.item.maps.preview.retry")
  }

  @ViewBuilder
  private var fallbackLink: some View {
    if let destination = URL(string: request.originalURL) {
      Link("Open saved Maps link", destination: destination)
    }
  }
}
