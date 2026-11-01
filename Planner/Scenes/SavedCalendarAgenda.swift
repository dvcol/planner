import PlannerCore
import SwiftUI

struct SavedCalendarAgenda: View {
  @Binding var selectedDate: Date
  let calendar: Calendar
  let days: [Date]
  let entriesForDay: (Date) -> [PlannerCalendarEntry]
  @Binding var selection: SavedCalendarSelection?
  let scheduleDescription: (PlannerCalendarEntry) -> String
  var isLoading = false
  var onScrollSettled: () -> Void = {}
  @State private var renderedDays: Set<Date> = []
  @State private var pendingFocusDay: Date?
  @State private var visibleRow: String?
  @State private var isUserScrolling = false
  @State private var viewportHeight: CGFloat = 1
  @State private var headerHeight: CGFloat = 34

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
          ForEach(days, id: \.self) { day in
            Section {
              VStack(alignment: .leading, spacing: 0) {
                let entries = entriesForDay(day)
                if entries.isEmpty {
                  Text(isLoading ? "Loading calendar" : "No scheduled entries")
                    .id("empty." + SavedCalendarDates.identifier(day, calendar: calendar))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.vertical, 20)
                }
                ForEach(entries.map { (id: rowIdentifier($0, day: day), entry: $0) }, id: \.id) {
                  row in
                  entryRow(row.entry, day: day)
                    .id(row.id)
                    .onGeometryChange(for: CGRect.self) { geometry in
                      geometry.frame(in: .scrollView(axis: .vertical))
                    } action: { frame in
                      guard isUserScrolling, frame.minY <= headerHeight + 4,
                        frame.maxY > headerHeight + 4
                      else { return }
                      selectedDate = focusDate(row.entry, day: day)
                    }
                }
                Color.clear.frame(height: 12)
              }
              .onAppear {
                renderedDays.insert(day)
                if pendingFocusDay == day { scrollToFocus(proxy) }
              }
              .onDisappear { renderedDays.remove(day) }
              .scrollTargetLayout()
              .accessibilityElement(children: .contain)
              .accessibilityIdentifier(
                "saved.calendar.agenda-day.\(SavedCalendarDates.identifier(day, calendar: calendar))"
              )
            } header: {
              HStack {
                Text(day, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(
                    calendar.isDateInToday(day) ? Color.accentColor : Color.secondary)
                Spacer(minLength: 0)
              }
              .padding(.horizontal, 16).padding(.vertical, 10)
              .background(.background)
              .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: .scrollView(axis: .vertical))
              } action: { frame in
                headerHeight = frame.height
                if isUserScrolling && frame.minY >= 0 && frame.minY < 8 {
                  selectedDate = SavedCalendarDates.selecting(
                    day, preserving: selectedDate, calendar: calendar)
                }
              }
              .overlay(alignment: .top) { Divider().opacity(0.5) }
              .id(calendar.startOfDay(for: day))
              .accessibilityIdentifier(
                "saved.calendar.agenda-heading.\(SavedCalendarDates.identifier(day, calendar: calendar))"
              )
              .accessibilityAddTraits(.isHeader)
            }
          }
        }
        // Let the last day's focused entry reach the pinned heading in a short agenda.
        .padding(.bottom, max(0, viewportHeight - headerHeight - 52))
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        viewportHeight = $0
      }
      .scrollPosition(id: $visibleRow)
      .onScrollPhaseChange { _, phase in
        let wasScrolling = isUserScrolling
        isUserScrolling = phase == .interacting || phase == .decelerating
        if phase == .idle && wasScrolling { onScrollSettled() }
      }
      .task(id: selectedDate) {
        await Task.yield()
        guard !Task.isCancelled else { return }
        scrollToFocus(proxy)
      }
      .task(id: days) {
        await Task.yield()
        guard !Task.isCancelled else { return }
        scrollToFocus(proxy)
      }
      .onChange(of: entriesForDay(selectedDate).map(\.schedule.id)) { scrollToFocus(proxy) }
    }
    .accessibilityIdentifier("saved.calendar.agenda")
  }

  private func scrollToFocus(_ proxy: ScrollViewProxy) {
    guard !isUserScrolling else { return }
    let day = calendar.startOfDay(for: selectedDate)
    guard renderedDays.contains(day) else {
      pendingFocusDay = day
      proxy.scrollTo(day, anchor: .top)
      return
    }
    pendingFocusDay = nil
    let entries = entriesForDay(selectedDate)
    let minute =
      calendar.component(.hour, from: selectedDate) * 60
      + calendar.component(.minute, from: selectedDate)
    let ongoing = entries.first { entry in
      guard case .timed(let start, let end, _) = entry.form, let end else { return false }
      return start <= selectedDate && selectedDate < end
    }
    let closest =
      ongoing
      ?? entries.min { first, second in
        abs(focusMinute(first) - minute) < abs(focusMinute(second) - minute)
      }
    if let closest {
      // Leave the focused row below the pinned day heading.
      let anchor = UnitPoint(x: 0, y: min(1, (headerHeight + 4) / max(1, viewportHeight - 52)))
      proxy.scrollTo(rowIdentifier(closest, day: selectedDate), anchor: anchor)
    } else {
      proxy.scrollTo(calendar.startOfDay(for: selectedDate), anchor: .top)
    }
  }

  private func rowIdentifier(_ entry: PlannerCalendarEntry, day: Date) -> String {
    SavedCalendarDates.identifier(day, calendar: calendar) + entry.schedule.id.uuidString
  }

  private func focusDate(_ entry: PlannerCalendarEntry, day: Date) -> Date {
    if case .timed(let start, _, _) = entry.form {
      return max(start, calendar.startOfDay(for: day))
    }
    return SavedCalendarDates.selecting(day, preserving: selectedDate, calendar: calendar)
  }

  private func focusMinute(_ entry: PlannerCalendarEntry) -> Int {
    guard case .timed(let start, _, _) = entry.form else { return 0 }
    return calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
  }

  private func entryRow(_ entry: PlannerCalendarEntry, day: Date) -> some View {
    Button {
      selectedDate = focusDate(entry, day: day)
      selection = .init(scheduleIdentifier: entry.schedule.id, source: entry.source)
    } label: {
      HStack(alignment: .top, spacing: 10) {
        Circle().fill(.teal).frame(width: 8, height: 8).padding(.top, 5)
        VStack(alignment: .leading, spacing: 3) {
          if case .timed = entry.form {
            Text(rowTimeDescription(entry, day: day)).font(.caption).foregroundStyle(.secondary)
          }
          Text(entry.title).font(.subheadline).foregroundStyle(.primary)
            .lineLimit(3)
            .padding(.horizontal, isAllDay(entry) ? 6 : 0)
            .padding(.vertical, isAllDay(entry) ? 3 : 0)
            .background {
              if isAllDay(entry) { RoundedRectangle(cornerRadius: 3).fill(.teal.opacity(0.22)) }
            }
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16).padding(.vertical, 7)
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(entry.title)
    .accessibilityValue(scheduleDescription(entry))
    .accessibilityIdentifier("saved.calendar.schedule.\(entry.schedule.id.uuidString)")
  }

  private func rowTimeDescription(_ entry: PlannerCalendarEntry, day: Date) -> String {
    guard case .timed(let start, let end, _) = entry.form else { return "All day" }
    var format = Date.FormatStyle(date: .omitted, time: .shortened)
    format.timeZone = calendar.timeZone
    if calendarDayHasClockChange(day, calendar: calendar) {
      format = format.timeZone(.specificName(.short))
    }
    guard let interval = calendar.dateInterval(of: .day, for: day) else {
      return scheduleDescription(entry)
    }
    if start < interval.start {
      if let end, end < interval.end { return "Until " + end.formatted(format) }
      return "Continues all day"
    }
    guard let end else { return start.formatted(format) + " · Start only" }
    if end > interval.end { return "From " + start.formatted(format) }
    return start.formatted(format) + " – " + end.formatted(format)
  }

  private func isAllDay(_ entry: PlannerCalendarEntry) -> Bool {
    if case .allDay = entry.form { return true }
    return false
  }
}
