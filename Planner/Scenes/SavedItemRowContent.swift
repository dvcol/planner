import PlannerCore
import PlannerPreviews
import SwiftUI

extension PlannerRowRead {
  var metadataDescription: String {
    var descriptions = [String]()
    if let subtitle, !subtitle.isEmpty { descriptions.append(subtitle) }
    if let locationCaption { descriptions.append(locationCaption) }
    if let address = ownedLocation?.formattedAddress, address != locationCaption {
      descriptions.append(address)
    }
    if let previewLink {
      descriptions.append(previewLink.displayTitle)
    } else if hasLinks {
      descriptions.append("Maps")
    }
    if archived == true { descriptions.append("Archived") }
    return descriptions.joined(separator: ", ")
  }

  var locationCaption: String? {
    guard let location = ownedLocation else { return nil }
    if let name = location.displayName, !name.isEmpty { return name }
    if let address = location.formattedAddress, !address.isEmpty { return address }
    if location.coordinate != nil { return "Location" }
    return nil
  }
}

struct SavedItemRowContent: View {
  let row: PlannerRowRead
  @Environment(SavedPlannerStore.self) private var store
  @Environment(PlannerPreviews.self) private var previews

  private var previewRequest: PlannerLinkPreviewRequest? {
    guard let link = row.previewLink, let namespace = store.devicePreferenceNamespace else {
      return nil
    }
    let source: PlannerEntityReference
    switch row.identity {
    case .source(let reference), .appearance(let reference, _): source = reference
    }
    return .init(
      source: .init(
        namespace: namespace, sourceId: source.id, sourceLifetimeId: row.sourceLifetimeId),
      linkId: link.linkId, originalURL: link.originalUrl)
  }

  var body: some View {
    HStack(alignment: .top) {
      textContent
      if let request = previewRequest,
        case .available(let content) = previews.linkState(for: request),
        let imageData = content.imageData
      {
        previewImage(imageData)
          .resizable()
          .scaledToFill()
          .frame(width: 44, height: 44)
          .clipShape(RoundedRectangle(cornerRadius: 6))
          .accessibilityLabel("Website preview")
          .accessibilityIdentifier("saved.item.preview.thumbnail.\(request.linkId.uuidString)")
      }
    }
    .task(id: previewRequest) {
      if let request = previewRequest { await previews.loadLink(request) }
    }
  }

  private func previewImage(_ data: Data) -> Image {
    #if os(macOS)
      guard let image = NSImage(data: data) else { return Image(systemName: "link") }
      return Image(nsImage: image)
    #else
      guard let image = UIImage(data: data) else { return Image(systemName: "link") }
      return Image(uiImage: image)
    #endif
  }

  private var textContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(row.title).lineLimit(1)
      if let subtitle = row.subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      if let link = row.previewLink {
        Label(link.displayTitle, systemImage: link.systemImage)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      } else if row.hasLinks {
        Label("Maps", systemImage: "map")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let location = row.locationCaption {
        Label(location, systemImage: "mappin.and.ellipse")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}
