import SwiftUI

struct SavedPlanningTimeZonePicker: View {
  @Binding var selectedTimeZoneIdentifier: String
  @State private var searchText = ""

  private var matchingTimeZoneIdentifiers: [String] {
    let identifiers = Set(TimeZone.knownTimeZoneIdentifiers + [selectedTimeZoneIdentifier])
    return identifiers.filter { identifier in
      searchText.isEmpty || identifier.localizedStandardContains(searchText)
        || planningTimeZoneName(identifier).localizedStandardContains(searchText)
        || planningTimeZoneLocationName(identifier).localizedStandardContains(searchText)
    }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }

  var body: some View {
    SavedPlanningTimeZoneResults(
      selectedTimeZoneIdentifier: $selectedTimeZoneIdentifier,
      identifiers: matchingTimeZoneIdentifiers
    )
    .searchable(text: $searchText, prompt: "Search time zones")
    .navigationTitle("Time Zone")
    .overlay {
      if matchingTimeZoneIdentifiers.isEmpty {
        ContentUnavailableView.search(text: searchText)
      }
    }
  }
}

private struct SavedPlanningTimeZoneResults: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dismissSearch) private var dismissSearch
  @Binding var selectedTimeZoneIdentifier: String
  let identifiers: [String]

  var body: some View {
    List(identifiers, id: \.self) { identifier in
      Button {
        selectedTimeZoneIdentifier = identifier
        dismissSearch()
        dismiss()
      } label: {
        HStack {
          VStack(alignment: .leading) {
            Text(planningTimeZoneLocationName(identifier))
            Text(planningTimeZoneName(identifier)).font(.caption).foregroundStyle(.secondary)
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
  }
}

private func planningTimeZoneLocationName(_ identifier: String) -> String {
  let components = identifier.split(separator: "/")
  let location =
    components.count > 1 ? components.dropFirst().joined(separator: " / ") : identifier
  return location.replacingOccurrences(of: "_", with: " ")
}

private func planningTimeZoneName(_ identifier: String) -> String {
  TimeZone(identifier: identifier)?.localizedName(for: .generic, locale: .current) ?? identifier
}
