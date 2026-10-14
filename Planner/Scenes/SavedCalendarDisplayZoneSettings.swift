import SwiftUI

struct SavedCalendarDisplayZoneSettings: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var overrideTimeZoneIdentifier: String
  let deviceTimeZone: TimeZone

  private var selectedTimeZone: TimeZone {
    TimeZone(identifier: overrideTimeZoneIdentifier) ?? deviceTimeZone
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle(
            "Use device time zone",
            isOn: Binding(
              get: { overrideTimeZoneIdentifier.isEmpty },
              set: { followsDevice in
                overrideTimeZoneIdentifier = followsDevice ? "" : deviceTimeZone.identifier
              })
          )
          .accessibilityIdentifier("saved.calendar.zone.follow-device")
          if !overrideTimeZoneIdentifier.isEmpty {
            NavigationLink {
              SavedPlanningTimeZonePicker(
                selectedTimeZoneIdentifier: $overrideTimeZoneIdentifier)
            } label: {
              LabeledContent(
                "Display time zone",
                value: selectedTimeZone.localizedName(for: .generic, locale: .current)
                  ?? selectedTimeZone.identifier)
            }
            .accessibilityIdentifier("saved.calendar.zone.choose")
          }
        } footer: {
          Text("Show appointments in a chosen time zone. Saved schedules stay unchanged.")
        }
      }
      .formStyle(.grouped)
      .navigationTitle("Calendar Time Zone")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier("saved.calendar.zone.done")
        }
      }
    }
    #if os(macOS)
      .frame(minWidth: 320, minHeight: 320)
    #endif
  }
}
