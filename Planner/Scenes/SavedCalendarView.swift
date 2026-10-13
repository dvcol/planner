import PlannerCore
import SwiftUI

struct SavedCalendarSelection: Hashable {
  let scheduleIdentifier: UUID
  let source: PlannerEntityReference
}

struct SavedCalendarView: View {
  @Environment(\.timeZone) private var displayTimeZone
  @Bindable var store: SavedPlannerStore
  @Binding var selection: SavedCalendarSelection?
  @State private var selectedDate = Date()
  @State private var entries: [SavedPlannerCalendarEntry]?
  @State private var isLoading = true

  private var loadIdentity: String {
    store.changeRevision.uuidString + ":" + (store.devicePreferenceNamespace ?? "")
  }

  private var displayCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = displayTimeZone
    return calendar
  }

  private func occursOnSelectedDay(_ entry: SavedPlannerCalendarEntry) -> Bool {
    guard let interval = displayCalendar.dateInterval(of: .day, for: selectedDate) else {
      return false
    }
    switch entry.schedule.content.form {
    case .timed(let start, let end, _):
      if let end { return start < interval.end && end > interval.start }
      return start >= interval.start && start < interval.end
    case .allDay(let start, let suppliedEnd):
      let components = displayCalendar.dateComponents([.year, .month, .day], from: selectedDate)
      guard let year = components.year, let month = components.month, let day = components.day
      else {
        return false
      }
      let end = suppliedEnd ?? start
      let selected = (year, month, day)
      return (start.year, start.month, start.day) <= selected
        && selected <= (end.year, end.month, end.day)
    }
  }

  private func scheduleDescription(_ entry: SavedPlannerCalendarEntry) -> String {
    switch entry.schedule.content.form {
    case .allDay: return "All day"
    case .timed(let start, let end, _):
      var format = Date.FormatStyle(date: .abbreviated, time: .shortened)
      format.timeZone = displayTimeZone
      if let end {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = displayTimeZone
        return formatter.string(from: start, to: end)
      }
      return "Start only · " + start.formatted(format)
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
          .datePickerStyle(.graphical)
          .accessibilityIdentifier("saved.calendar.date")
        if isLoading {
          ProgressView("Loading schedules")
        } else if let entries {
          let matchingEntries = entries.filter(occursOnSelectedDay)
          if matchingEntries.isEmpty {
            ContentUnavailableView(
              "No scheduled entries", systemImage: "calendar",
              description: Text("Choose another date or schedule an Item or Itinerary."))
          } else {
            Text(selectedDate, format: .dateTime.weekday().month().day()).font(.headline)
            ForEach(matchingEntries) { entry in
              Button {
                selection = .init(
                  scheduleIdentifier: entry.id, source: entry.schedule.content.source)
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Label(entry.title, systemImage: "calendar")
                  Text(scheduleDescription(entry)).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .contentShape(.rect)
              }
              .buttonStyle(.plain)
              .accessibilityLabel(entry.title)
              .accessibilityValue(scheduleDescription(entry))
              .accessibilityIdentifier("saved.calendar.schedule.\(entry.id.uuidString)")
            }
          }
        } else {
          ContentUnavailableView {
            Label("Calendar unavailable", systemImage: "exclamationmark.triangle")
          } actions: {
            Button("Try Again") { Task { await loadEntries() } }
          }
        }
      }
      .padding()
    }
    .navigationTitle("Calendar")
    .toolbar {
      Button("Today", systemImage: "calendar") { selectedDate = Date() }
    }
    .task(id: loadIdentity) { await loadEntries() }
  }

  private func loadEntries() async {
    let identity = loadIdentity
    isLoading = true
    defer { if loadIdentity == identity { isLoading = false } }
    let loaded = await store.readCalendarEntries()
    guard !Task.isCancelled, loadIdentity == identity else { return }
    entries = loaded
    if let loaded, let selection,
      !loaded.contains(where: {
        $0.id == selection.scheduleIdentifier && $0.schedule.content.source == selection.source
      })
    {
      self.selection = nil
    }
  }
}
