import PlannerCore
import SwiftUI

struct SavedOwnedLinkDraft: Identifiable {
  let id: UUID
  let retainedLinkIdentifier: UUID?
  let originalLabel: String?
  var originalURL: String
  var label: String

  init(link: PlannerOwnedLinkRead) {
    id = link.linkId
    retainedLinkIdentifier = link.linkId
    originalLabel = link.label
    originalURL = link.originalUrl
    label = link.label ?? ""
  }

  init(link: PlannerCaptureDraftLink) {
    id = link.linkId
    retainedLinkIdentifier = link.linkId
    originalLabel = link.label
    originalURL = link.originalUrl
    label = link.label ?? ""
  }

  init() {
    id = UUID()
    retainedLinkIdentifier = nil
    originalLabel = nil
    originalURL = ""
    label = ""
  }

  var input: PlannerLinkInput {
    let savedLabel: String?
    if label == (originalLabel ?? "") {
      savedLabel = originalLabel
    } else {
      savedLabel = label.isEmpty ? nil : label
    }
    return PlannerLinkInput(
      linkId: retainedLinkIdentifier, originalUrl: originalURL, label: savedLabel)
  }
}

struct SavedOwnedLinksEditor: View {
  @Binding var links: [SavedOwnedLinkDraft]
  let accessibilityIdentifierPrefix: String
  @FocusState private var focusedLinkIdentifier: UUID?

  var body: some View {
    Section("Links") {
      ForEach($links) { $link in
        VStack(alignment: .leading) {
          HStack {
            TextField("URL", text: $link.originalURL)
              .autocorrectionDisabled()
              .focused($focusedLinkIdentifier, equals: link.id)
              .accessibilityIdentifier("\(accessibilityIdentifierPrefix).url.\(link.id.uuidString)")
              #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
              #endif
            Menu {
              Button("Move Up", systemImage: "arrow.up") { moveLink(link.id, offset: -1) }
                .disabled(links.first?.id == link.id)
              Button("Move Down", systemImage: "arrow.down") { moveLink(link.id, offset: 1) }
                .disabled(links.last?.id == link.id)
              Divider()
              Button("Remove Link", systemImage: "minus.circle", role: .destructive) {
                if focusedLinkIdentifier == link.id { focusedLinkIdentifier = nil }
                links.removeAll { $0.id == link.id }
              }
            } label: {
              Label("Link actions", systemImage: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
            .help("Link actions")
            .accessibilityIdentifier(
              "\(accessibilityIdentifierPrefix).actions.\(link.id.uuidString)")
          }
          TextField("Label", text: $link.label)
            .accessibilityIdentifier("\(accessibilityIdentifierPrefix).label.\(link.id.uuidString)")
        }
      }
      Button("Add Link", systemImage: "plus") {
        let draft = SavedOwnedLinkDraft()
        links.append(draft)
        focusedLinkIdentifier = draft.id
      }
      .accessibilityIdentifier("\(accessibilityIdentifierPrefix).add")
    }
  }

  private func moveLink(_ identifier: UUID, offset: Int) {
    guard let index = links.firstIndex(where: { $0.id == identifier }),
      links.indices.contains(index + offset)
    else { return }
    links.swapAt(index, index + offset)
  }
}
