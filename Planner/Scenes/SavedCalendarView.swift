import PlannerCore
import SwiftUI

struct SavedCalendarSelection: Hashable {
  let scheduleIdentifier: UUID
  let source: PlannerEntityReference
}

struct SavedCalendarView: View {
  private enum Mode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var component: Calendar.Component {
      switch self {
      case .day: .day
      case .week: .weekOfYear
      case .month: .month
      }
    }
  }

  @Environment(\.timeZone) private var deviceTimeZone
  @AppStorage private var overrideTimeZoneIdentifier: String
  @Bindable var store: SavedPlannerStore
  @Binding var selection: SavedCalendarSelection?
  @State private var selectedDate = Date()
  @State private var visibleDate = Date()
  @State private var entries: [PlannerCalendarEntry]?
  @State private var isLoading = true
  @State private var mode = Mode.month
  @State private var showsTimeZonePreferences = false

  init(store: SavedPlannerStore, selection: Binding<SavedCalendarSelection?>) {
    self.store = store
    self._selection = selection
    let namespace = store.devicePreferenceNamespace ?? "unavailable"
    self._overrideTimeZoneIdentifier = AppStorage(
      wrappedValue: "", "planner.calendar.\(namespace).display-zone")
  }

  private var displayTimeZone: TimeZone {
    TimeZone(identifier: overrideTimeZoneIdentifier) ?? deviceTimeZone
  }

  private var visibleInterval: DateInterval? {
    displayCalendar.dateInterval(
      of: mode.component, for: mode == .month ? visibleDate : selectedDate)
  }

  private var visibleDays: [Date] {
    guard let interval = visibleInterval else { return [] }
    var days: [Date] = []
    var date = interval.start
    while date < interval.end {
      days.append(date)
      guard let nextDate = displayCalendar.date(byAdding: .day, value: 1, to: date), nextDate > date
      else { break }
      date = nextDate
    }
    return days
  }

  private var loadIdentity: String {
    let components = displayCalendar.dateComponents(
      [.year, .month, .day], from: visibleInterval?.start ?? selectedDate)
    return store.changeRevision.uuidString + ":" + (store.devicePreferenceNamespace ?? "")
      + ":" + displayTimeZone.identifier + ":" + mode.rawValue
      + ":\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
  }

  private var displayCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = displayTimeZone
    return calendar
  }

  private func occurs(_ entry: PlannerCalendarEntry, on date: Date) -> Bool {
    guard let interval = displayCalendar.dateInterval(of: .day, for: date) else {
      return false
    }
    switch entry.form {
    case .timed(let start, let end, _):
      if let end { return start < interval.end && end > interval.start }
      return start >= interval.start && start < interval.end
    case .allDay(let start, let suppliedEnd):
      let components = displayCalendar.dateComponents([.year, .month, .day], from: date)
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

  private var windowQuery: PlannerCalendarQuery? {
    guard let interval = visibleInterval,
      let lastDate = displayCalendar.date(byAdding: .day, value: -1, to: interval.end)
    else { return nil }
    let start = displayCalendar.dateComponents([.year, .month, .day], from: interval.start)
    let end = displayCalendar.dateComponents([.year, .month, .day], from: lastDate)
    guard let startYear = start.year, let startMonth = start.month, let startDay = start.day,
      let endYear = end.year, let endMonth = end.month, let endDay = end.day
    else { return nil }
    return .init(
      startDay: .init(year: startYear, month: startMonth, day: startDay),
      endDay: .init(year: endYear, month: endMonth, day: endDay),
      displayTimeZone: displayTimeZone.identifier)
  }

  private var scheduleCounts: [DateComponents: Int] {
    guard !isLoading, let entries,
      let interval = displayCalendar.dateInterval(of: .month, for: visibleDate)
    else { return [:] }
    var counts: [DateComponents: Int] = [:]
    var date = interval.start
    while date < interval.end {
      let count = entries.filter { occurs($0, on: date) }.count
      if count > 0 {
        let components = displayCalendar.dateComponents([.year, .month, .day], from: date)
        counts[
          DateComponents(year: components.year, month: components.month, day: components.day)] =
          count
      }
      guard let nextDate = displayCalendar.date(byAdding: .day, value: 1, to: date), nextDate > date
      else { break }
      date = nextDate
    }
    return counts
  }

  private func scheduleDescription(_ entry: PlannerCalendarEntry) -> String {
    switch entry.form {
    case .allDay(let start, let end):
      return "All day · " + allDayScheduleDescription(start: start, end: end)
    case .timed(let start, let end, _):
      var format = Date.FormatStyle(date: .abbreviated, time: .shortened)
      if calendarDayHasClockChange(start, calendar: displayCalendar) {
        format = format.timeZone(.specificName(.short))
      }
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

  private func precedes(
    _ first: PlannerCalendarEntry, _ second: PlannerCalendarEntry
  ) -> Bool {
    switch (first.form, second.form) {
    case (.timed(let firstStart, _, _), .timed(let secondStart, _, _)):
      if firstStart != secondStart { return firstStart < secondStart }
    case (.allDay(let firstStart, _), .allDay(let secondStart, _)):
      let firstDate = (firstStart.year, firstStart.month, firstStart.day)
      let secondDate = (secondStart.year, secondStart.month, secondStart.day)
      if firstDate != secondDate { return firstDate < secondDate }
    case (.allDay, .timed): return true
    case (.timed, .allDay): return false
    }
    return first.schedule.id.uuidString < second.schedule.id.uuidString
  }

  var body: some View {
    VStack(spacing: 12) {
      Picker("Calendar view", selection: $mode) {
        ForEach(Mode.allCases, id: \.self) { mode in
          Text(mode.rawValue).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .frame(maxWidth: 400)
      .padding(.horizontal)
      .accessibilityIdentifier("saved.calendar.mode")
      if mode == .month {
        monthContent
      } else {
        DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
          .datePickerStyle(.compact)
          .padding(.horizontal)
        if isLoading {
          ProgressView("Loading schedules").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if entries != nil {
          SavedCalendarTimeGrid(
            days: visibleDays, selectedDate: selectedDate, calendar: displayCalendar,
            selection: $selection,
            entriesForDay: { date in
              (entries ?? []).filter { occurs($0, on: date) }.sorted(by: precedes)
            },
            scheduleDescription: scheduleDescription)
        } else {
          ContentUnavailableView {
            Label("Calendar unavailable", systemImage: "exclamationmark.triangle")
          } actions: {
            Button("Try Again") { Task { await loadEntries() } }
          }
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("saved.calendar.canvas")
    .environment(\.timeZone, displayTimeZone)
    .navigationTitle("Calendar")
    .toolbar {
      Button("Display Time Zone", systemImage: "globe") {
        showsTimeZonePreferences = true
      }
      .disabled(!store.isReady)
      .accessibilityIdentifier("saved.calendar.zone.open")
      Button("Today", systemImage: "calendar") {
        selectedDate = Date()
        visibleDate = selectedDate
      }
    }
    .sheet(isPresented: $showsTimeZonePreferences) {
      SavedCalendarDisplayZoneSettings(
        overrideTimeZoneIdentifier: $overrideTimeZoneIdentifier, deviceTimeZone: deviceTimeZone)
    }
    .onChange(of: selectedDate) {
      let selectedMonth = displayCalendar.dateComponents([.year, .month], from: selectedDate)
      let visibleMonth = displayCalendar.dateComponents([.year, .month], from: visibleDate)
      if selectedMonth != visibleMonth { visibleDate = selectedDate }
    }
    .task(id: loadIdentity) { await loadEntries() }
  }

  private var monthContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        #if os(iOS)
          ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
              monthPicker.frame(width: 400)
              agenda.frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 20) {
              monthPicker.frame(maxWidth: 400)
              agenda
            }
          }
        #else
          SavedCalendarMonthGrid(
            selectedDate: $selectedDate, visibleDate: $visibleDate, selection: $selection,
            calendar: displayCalendar,
            entriesForDay: { date in
              (entries ?? []).filter { occurs($0, on: date) }.sorted(by: precedes)
            })
          agenda
        #endif
      }
      .padding()
    }
  }

  #if os(iOS)
    private var monthPicker: some View {
      SavedCalendarMonthPicker(
        selectedDate: $selectedDate, visibleDate: $visibleDate,
        calendar: displayCalendar, scheduleCounts: scheduleCounts
      )
      .accessibilityIdentifier("saved.calendar.date")
    }
  #endif

  private var agenda: some View {
    VStack(alignment: .leading, spacing: 12) {
      if isLoading {
        ProgressView("Loading schedules")
      } else if let entries {
        let matchingEntries = entries.filter { occurs($0, on: selectedDate) }.sorted(by: precedes)
        if matchingEntries.isEmpty {
          ContentUnavailableView(
            "No scheduled entries", systemImage: "calendar",
            description: Text("Choose another date or schedule an Item or Itinerary."))
        } else {
          Text(selectedDate, format: .dateTime.weekday().month().day()).font(.headline)
          ForEach(matchingEntries, id: \.schedule.id) { entry in
            Button {
              selection = .init(
                scheduleIdentifier: entry.schedule.id, source: entry.source)
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
            .accessibilityIdentifier("saved.calendar.schedule.\(entry.schedule.id.uuidString)")
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
  }

  private func loadEntries() async {
    let identity = loadIdentity
    isLoading = true
    defer { if loadIdentity == identity { isLoading = false } }
    guard let query = windowQuery else {
      entries = nil
      return
    }
    let loaded = await store.readCalendarEntries(query: query)
    guard !Task.isCancelled, loadIdentity == identity else { return }
    entries = loaded
    if let loaded, let selection,
      !loaded.contains(where: {
        $0.schedule.id == selection.scheduleIdentifier && $0.source == selection.source
      })
    {
      let read = await store.readSchedule(selection.scheduleIdentifier)
      guard !Task.isCancelled, loadIdentity == identity, self.selection == selection else { return }
      switch read {
      case .source(.schedule(let schedule)):
        if schedule.content.source != selection.source { self.selection = nil }
      case .failed(let failure) where failure.code == "missingReference":
        self.selection = nil
      default: break
      }
    }
  }
}
