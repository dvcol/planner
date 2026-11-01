import PlannerCore
import SwiftUI

struct SavedCalendarSpan: Identifiable {
  let entry: PlannerCalendarEntry
  let start: Int
  let end: Int
  let lane: Int
  var id: UUID { entry.schedule.id }
}

/// Calendar arithmetic stays in the chosen display zone, including weeks across clock changes.
enum SavedCalendarDates {
  /// Allocate each all-day span once per week; shared days occupy the same horizontal lane.
  static func spans(in week: [Date], entriesForDay: (Date) -> [PlannerCalendarEntry])
    -> [SavedCalendarSpan]
  {
    var entries: [UUID: PlannerCalendarEntry] = [:]
    for day in week {
      for entry in entriesForDay(day) {
        if case .allDay = entry.form { entries[entry.schedule.id] = entry }
      }
    }
    var spans: [SavedCalendarSpan] = []
    var laneEnds: [Int] = []
    let sorted = entries.values.compactMap { entry -> SavedCalendarSpan? in
      let indices = week.indices.filter { index in
        entriesForDay(week[index]).contains { $0.schedule.id == entry.schedule.id }
      }
      guard let start = indices.first, let end = indices.last else { return nil }
      return .init(entry: entry, start: start, end: end, lane: 0)
    }.sorted { first, second in
      if first.start != second.start { return first.start < second.start }
      if first.end != second.end { return first.end > second.end }
      return first.id.uuidString < second.id.uuidString
    }
    for span in sorted {
      let lane = laneEnds.firstIndex(where: { $0 < span.start }) ?? laneEnds.count
      if lane == laneEnds.count { laneEnds.append(span.end) } else { laneEnds[lane] = span.end }
      spans.append(.init(entry: span.entry, start: span.start, end: span.end, lane: lane))
    }
    return spans
  }

  static func days(in interval: DateInterval, calendar: Calendar) -> [Date] {
    var result: [Date] = []
    var day = interval.start
    while day < interval.end {
      result.append(day)
      guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
      day = next
    }
    return result
  }

  static func monthDays(_ date: Date, calendar: Calendar) -> [Date] {
    guard let month = calendar.dateInterval(of: .month, for: date),
      let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start),
      let lastWeek = calendar.dateInterval(of: .weekOfYear, for: month.end.addingTimeInterval(-1))
    else { return [] }
    return days(in: .init(start: firstWeek.start, end: lastWeek.end), calendar: calendar)
  }

  static func selecting(_ day: Date, preserving focus: Date, calendar: Calendar) -> Date {
    let clock = calendar.dateComponents([.hour, .minute, .second], from: focus)
    return calendar.date(
      bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0,
      second: clock.second ?? 0, of: day) ?? day
  }

  static func identifier(_ date: Date, calendar: Calendar) -> String {
    let fields = calendar.dateComponents([.year, .month, .day], from: date)
    return "\(fields.year ?? 0)-\(fields.month ?? 0)-\(fields.day ?? 0)"
  }

  static func weekdayNames(calendar: Calendar) -> [String] {
    let names = calendar.veryShortStandaloneWeekdaySymbols
    let offset = calendar.firstWeekday - 1
    return Array(names.dropFirst(offset)) + Array(names.prefix(offset))
  }
}

struct SavedCalendarMiniMonth: View {
  let month: Date
  @Binding var selectedDate: Date
  let calendar: Calendar
  let entriesForDay: (Date) -> [PlannerCalendarEntry]
  var showsHeading = true
  var showsDensity = false
  var showsOnlySelectedWeek = false
  var openDay: (() -> Void)?

  private var dates: [Date] {
    if showsOnlySelectedWeek, let week = calendar.dateInterval(of: .weekOfYear, for: selectedDate) {
      return SavedCalendarDates.days(in: week, calendar: calendar)
    }
    return SavedCalendarDates.monthDays(month, calendar: calendar)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if showsHeading {
        Text(month, format: .dateTime.month(.wide))
          .font(.headline).padding(.bottom, 4)
      }
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 2)
      {
        ForEach(
          Array(SavedCalendarDates.weekdayNames(calendar: calendar).enumerated()), id: \.offset
        ) { _, name in
          Text(name).font(.caption2).foregroundStyle(.secondary)
        }
        ForEach(dates, id: \.self) { day in
          let isCurrentMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
          let count = entriesForDay(day).count
          let selected = calendar.isDate(day, inSameDayAs: selectedDate)
          Button {
            selectedDate = SavedCalendarDates.selecting(
              day, preserving: selectedDate, calendar: calendar)
            openDay?()
          } label: {
            VStack(spacing: 1) {
              Text(day, format: .dateTime.day()).font(.caption)
                .foregroundStyle(
                  selected ? Color.white : isCurrentMonth ? Color.primary : Color.secondary)
              if !showsDensity {
                HStack(spacing: 2) {
                  ForEach(0..<min(count, 3), id: \.self) { _ in
                    Circle().fill(selected ? Color.white : Color.accentColor).frame(
                      width: 3, height: 3)
                  }
                }.frame(height: 3)
              }
            }
            .frame(maxWidth: .infinity, minHeight: 27)
            .background {
              if selected {
                Circle().fill(.tint)
              } else if showsDensity && count > 0 {
                Rectangle().fill(Color.orange.opacity(min(0.6, 0.1 + Double(count) * 0.08)))
              }
            }
            .overlay {
              if !selected && calendar.isDateInToday(day) {
                Circle().strokeBorder(.tint, lineWidth: 1)
              }
            }
            .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(Text(day, format: .dateTime.weekday().month().day().year()))
          .accessibilityValue(count == 1 ? "1 scheduled entry" : "\(count) scheduled entries")
          .accessibilityAddTraits(selected ? .isSelected : [])
          .accessibilityIdentifier(
            "saved.calendar.mini-day.\(SavedCalendarDates.identifier(day, calendar: calendar))")
        }
      }
    }
  }
}

struct SavedCalendarOverview: View {
  let interval: DateInterval?
  @Binding var selectedDate: Date
  let calendar: Calendar
  let entriesForDay: (Date) -> [PlannerCalendarEntry]
  let openMonth: () -> Void
  @State private var isUserScrolling = false

  private var months: [Date] {
    guard let interval else { return [] }
    var result: [Date] = []
    var date = interval.start
    while date < interval.end {
      result.append(date)
      guard let next = calendar.date(byAdding: .month, value: 1, to: date), next > date else {
        break
      }
      date = next
    }
    return result
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 150), spacing: 24, alignment: .top)],
          alignment: .leading,
          spacing: 24
        ) {
          ForEach(months, id: \.self) { month in
            SavedCalendarMiniMonth(
              month: month, selectedDate: $selectedDate, calendar: calendar,
              entriesForDay: entriesForDay, showsDensity: true, openDay: openMonth
            )
            .id(month)
            .onGeometryChange(for: CGFloat.self) { geometry in
              geometry.frame(in: .scrollView(axis: .vertical)).minY
            } action: { top in
              if isUserScrolling && top >= 0 && top < 60 { selectedDate = month }
            }
          }
        }
        .padding(16)
      }
      .onScrollPhaseChange { _, phase in
        isUserScrolling = phase == .interacting || phase == .decelerating
      }
      .onChange(of: selectedDate, initial: true) {
        guard !isUserScrolling,
          let month = calendar.dateInterval(of: .month, for: selectedDate)?.start
        else { return }
        proxy.scrollTo(month, anchor: .top)
      }
      .accessibilityIdentifier("saved.calendar.overview")
    }
  }
}
