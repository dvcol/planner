import SwiftUI

struct SavedPlanningTimeZonePicker: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var selectedTimeZoneIdentifier: String
  @State private var searchText = ""

  private var matchingTimeZoneIdentifiers: [String] {
    let identifiers = Set(TimeZone.knownTimeZoneIdentifiers + [selectedTimeZoneIdentifier])
    return identifiers.filter { identifier in
      searchText.isEmpty || identifier.localizedStandardContains(searchText)
        || timeZoneName(identifier).localizedStandardContains(searchText)
        || locationName(identifier).localizedStandardContains(searchText)
    }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }

  var body: some View {
    List(matchingTimeZoneIdentifiers, id: \.self) { identifier in
      Button {
        selectedTimeZoneIdentifier = identifier
        dismiss()
      } label: {
        HStack {
          VStack(alignment: .leading) {
            Text(locationName(identifier))
            Text(timeZoneName(identifier)).font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          if identifier == selectedTimeZoneIdentifier {
            Image(systemName: "checkmark").accessibilityHidden(true)
          }
        }
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
      }
      .accessibilityAddTraits(identifier == selectedTimeZoneIdentifier ? .isSelected : [])
      .accessibilityIdentifier("saved.schedule.zone.option.\(identifier)")
    }
    .searchable(text: $searchText, prompt: "Search time zones")
    .navigationTitle("Time Zone")
    .overlay {
      if matchingTimeZoneIdentifiers.isEmpty {
        ContentUnavailableView.search(text: searchText)
      }
    }
  }

  private func locationName(_ identifier: String) -> String {
    let components = identifier.split(separator: "/")
    let location =
      components.count > 1 ? components.dropFirst().joined(separator: " / ") : identifier
    return location.replacingOccurrences(of: "_", with: " ")
  }

  private func timeZoneName(_ identifier: String) -> String {
    TimeZone(identifier: identifier)?.localizedName(for: .generic, locale: .current) ?? identifier
  }
}
