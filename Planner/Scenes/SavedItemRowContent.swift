import PlannerCore
import SwiftUI

extension PlannerRowRead {
  var metadataDescription: String {
    var descriptions = [String]()
    if let subtitle, !subtitle.isEmpty { descriptions.append(subtitle) }
    if let previewLink {
      descriptions.append(previewLink.displayTitle)
    } else if hasLinks {
      descriptions.append("Maps")
    }
    if archived == true { descriptions.append("Archived") }
    return descriptions.joined(separator: ", ")
  }
}

struct SavedItemRowContent: View {
  let row: PlannerRowRead

  var body: some View {
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
    }
  }
}
