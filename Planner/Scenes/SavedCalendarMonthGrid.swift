#if os(macOS)
  import PlannerCore
  import SwiftUI

  struct SavedCalendarMonthGrid: View {
    @Binding var selectedDate: Date
    @Binding var visibleDate: Date
    @Binding var selection: SavedCalendarSelection?
    let calendar: Calendar
    let entriesForDay: (Date) -> [PlannerCalendarEntry]

    private var monthDays: [Date?] {
      guard let interval = calendar.dateInterval(of: .month, for: visibleDate) else { return [] }
      let weekday = calendar.component(.weekday, from: interval.start)
      let leadingCount = (weekday - calendar.firstWeekday + 7) % 7
      var days = [Date?](repeating: nil, count: leadingCount)
      var date = interval.start
      while date < interval.end {
        days.append(date)
        guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date), nextDate > date
        else { break }
        date = nextDate
      }
      while !days.count.isMultiple(of: 7) { days.append(nil) }
      return days
    }

    private var weekdays: [String] {
      let names = calendar.shortStandaloneWeekdaySymbols
      let offset = calendar.firstWeekday - 1
      return Array(names.dropFirst(offset)) + Array(names.prefix(offset))
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
            .datePickerStyle(.compact)
          Spacer()
          Button("Previous Month", systemImage: "chevron.left") { moveMonth(-1) }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("DatePicker.PreviousMonth")
          Button("Next Month", systemImage: "chevron.right") { moveMonth(1) }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("DatePicker.NextMonth")
        }
        Text(visibleDate, format: .dateTime.month(.wide).year())
          .font(.title2.weight(.semibold))
        LazyVGrid(
          columns: Array(
            repeating: GridItem(.flexible(minimum: 70), alignment: .leading), count: 7),
          alignment: .leading, spacing: 8
        ) {
          ForEach(Array(weekdays.enumerated()), id: \.offset) { _, name in
            Text(name).font(.caption).foregroundStyle(.secondary)
          }
          ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
            if let date {
              dayCell(date)
            } else {
              Color.clear.frame(minHeight: 108)
            }
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("saved.calendar.date")
    }

    private func moveMonth(_ amount: Int) {
      guard let interval = calendar.dateInterval(of: .month, for: visibleDate),
        let date = calendar.date(byAdding: .month, value: amount, to: interval.start)
      else { return }
      visibleDate = date
      selectedDate = date
    }

    private func dateDescription(_ date: Date) -> String {
      var format = Date.FormatStyle().weekday(.wide).month(.wide).day()
      format.calendar = calendar
      format.timeZone = calendar.timeZone
      return date.formatted(format)
    }

    private func dayCell(_ date: Date) -> some View {
      let entries = entriesForDay(date)
      let components = calendar.dateComponents([.year, .month, .day], from: date)
      let dateIdentifier = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
      let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
      return VStack(alignment: .leading, spacing: 6) {
        Button {
          selectedDate = date
        } label: {
          Text(String(components.day ?? 0)).font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dateDescription(date))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        if !entries.isEmpty {
          Text(entries.count == 1 ? "1 scheduled entry" : "\(entries.count) scheduled entries")
            .font(.caption2).foregroundStyle(.secondary)
            .accessibilityIdentifier("saved.calendar.day.\(dateIdentifier).schedule-count")
          ForEach(entries.prefix(2), id: \.schedule.id) { entry in
            Button {
              selectedDate = date
              selection = .init(scheduleIdentifier: entry.schedule.id, source: entry.source)
            } label: {
              Text(entry.title).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .help(entry.title)
            .accessibilityIdentifier(
              "saved.calendar.day.\(dateIdentifier).schedule.\(entry.schedule.id.uuidString)")
          }
          if entries.count > 2 {
            Button("+\(entries.count - 2) more") { selectedDate = date }
              .buttonStyle(.borderless)
              .accessibilityLabel("Show all \(entries.count) scheduled entries for this day")
          }
        }
        Spacer(minLength: 0)
      }
      .padding(8)
      .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
      .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
    }
  }
#endif
