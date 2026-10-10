import PlannerCore
import PlannerPreviews
import SwiftUI

struct ItemLinkPreviewCard: View {
  let link: PlannerOwnedLinkRead
  let request: PlannerLinkPreviewRequest
  @Environment(PlannerPreviews.self) private var previews

  var body: some View {
    Group {
      switch previews.linkState(for: request) {
      case .idle:
        Button("Load preview") { Task { await previews.loadLink(request) } }
      case .loading:
        ProgressView("Loading preview").controlSize(.small)
      case .available(let content):
        NativeLinkPreview(link: link, content: content)
      case .unavailable:
        HStack {
          Label("Preview unavailable", systemImage: "photo")
            .foregroundStyle(.secondary)
          Spacer()
          Button("Retry") { Task { await previews.retryLink(request) } }
        }
        .font(.caption)
      }
    }
    .task(id: request) { await previews.loadLink(request) }
  }
}

private struct NativeLinkPreview: View {
  let link: PlannerOwnedLinkRead
  let content: PlannerLinkPreviewContent

  private var previewImage: Image? {
    guard let data = content.imageData else { return nil }
    #if os(macOS)
      guard let image = NSImage(data: data) else { return nil }
      return Image(nsImage: image)
    #else
      guard let image = UIImage(data: data) else { return nil }
      return Image(uiImage: image)
    #endif
  }

  var body: some View {
    if let destination = URL(string: link.originalUrl) {
      let image = previewImage
      Link(destination: destination) {
        GroupBox {
          VStack(alignment: .leading, spacing: 8) {
            if let image {
              image.resizable().scaledToFit().frame(maxHeight: 200)
            }
            Text(content.title ?? link.displayTitle).font(.headline)
            if let host = destination.host() {
              Text(host).font(.caption).foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .buttonStyle(.plain)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(link.displayTitle)
      .accessibilityValue(image == nil ? "No image" : "Image available")
      .accessibilityIdentifier("saved.item.preview.card.\(link.linkId.uuidString)")
    }
  }
}
