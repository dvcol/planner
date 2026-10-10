import PlannerCore
import SwiftUI

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
    }
  }
}
