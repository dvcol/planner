import PlannerCore
import SwiftUI

struct SavedCalendarMonthGrid: View {
  @Binding var selectedDate: Date
  let visibleDate: Date
  @Binding var selection: SavedCalendarSelection?
  let calendar: Calendar
  let entriesForDay: (Date) -> [PlannerCalendarEntry]
  @State private var agendaDay: Date?
  @State private var isUserScrolling = false

  private var weeks: [[Date]] {
    let days = SavedCalendarDates.monthDays(visibleDate, calendar: calendar)
    return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
  }

  var body: some View {
    GeometryReader { geometry in
      let rowHeight = max(100, (geometry.size.height - 24) / CGFloat(max(1, weeks.count)))
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 0) {
            HStack(spacing: 0) {
              ForEach(
                Array(SavedCalendarDates.weekdayNames(calendar: calendar).enumerated()),
                id: \.offset
              ) { _, name in
                Text(name).font(.caption2).foregroundStyle(.secondary)
                  .frame(maxWidth: .infinity, minHeight: 24)
              }
            }
            ForEach(weeks, id: \.first) { week in
              weekRow(week, height: rowHeight)
                .id(week.first)
                .onGeometryChange(for: CGFloat.self) { geometry in
                  geometry.frame(in: .scrollView(axis: .vertical)).minY
                } action: { top in
                  guard isUserScrolling, top >= 0, top < rowHeight / 2,
                    let day = week.first(where: {
                      calendar.isDate($0, equalTo: visibleDate, toGranularity: .month)
                    })
                  else { return }
                  selectedDate = SavedCalendarDates.selecting(
                    day, preserving: selectedDate, calendar: calendar)
                }
            }
          }
        }
        .onScrollPhaseChange { _, phase in
          isUserScrolling = phase == .interacting || phase == .decelerating
        }
        .onChange(of: selectedDate) {
          guard !isUserScrolling,
            let week = weeks.first(where: { week in
              week.contains { calendar.isDate($0, inSameDayAs: selectedDate) }
            })
          else { return }
          proxy.scrollTo(week.first, anchor: .top)
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("saved.calendar.date")
    .sheet(isPresented: Binding(get: { agendaDay != nil }, set: { if !$0 { agendaDay = nil } })) {
      if let agendaDay {
        NavigationStack {
          SavedCalendarAgenda(
            selectedDate: .constant(agendaDay), calendar: calendar, days: [agendaDay],
            entriesForDay: { calendar.isDate($0, inSameDayAs: agendaDay) ? entriesForDay($0) : [] },
            selection: Binding(
              get: { selection },
              set: {
                selection = $0
                self.agendaDay = nil
              }),
            scheduleDescription: compactDescription
          )
          .navigationTitle(agendaDay.formatted(.dateTime.month().day()))
          .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { self.agendaDay = nil } }
          }
        }
        .presentationDetents([.medium, .large])
      }
    }
  }

  private func weekRow(_ week: [Date], height: CGFloat) -> some View {
    let spans = SavedCalendarDates.spans(in: week, entriesForDay: entriesForDay)
    let visibleSpans = spans.filter { $0.lane < 2 }
    let spanRows = min(2, (spans.map(\.lane).max() ?? -1) + 1)
    return GeometryReader { geometry in
      let width = geometry.size.width / 7
      HStack(spacing: 0) {
        ForEach(week, id: \.self) { day in
          dayCell(day, height: height, spanRows: spanRows, spans: spans)
            .frame(width: width, height: height, alignment: .topLeading)
        }
      }
      ForEach(visibleSpans) { span in
        Button {
          selectedDate = SavedCalendarDates.selecting(
            week[span.start], preserving: selectedDate, calendar: calendar)
          selection = .init(scheduleIdentifier: span.entry.schedule.id, source: span.entry.source)
        } label: {
          Text(span.entry.title).font(.caption2).lineLimit(1)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
            .background(.teal.opacity(0.25))
        }
        .buttonStyle(.plain)
        .frame(width: width * CGFloat(span.end - span.start + 1) - 2, height: 18)
        .offset(x: CGFloat(span.start) * width + 1, y: 32 + CGFloat(span.lane) * 20)
        .accessibilityLabel(span.entry.title)
        .accessibilityValue(compactDescription(span.entry))
        .accessibilityIdentifier(
          "saved.calendar.span.\(SavedCalendarDates.identifier(week[0], calendar: calendar)).\(span.id.uuidString)"
        )
      }
    }
    .frame(height: height)
    .overlay(alignment: .top) { Divider().opacity(0.6) }
  }

  private func dayCell(_ day: Date, height: CGFloat, spanRows: Int, spans: [SavedCalendarSpan])
    -> some View
  {
    let entries = entriesForDay(day)
    let timed = entries.filter {
      if case .timed = $0.form { return true }
      return false
    }
    let reserved = CGFloat(spanRows) * 20
    let capacity = max(0, Int((height - 58 - reserved) / 17))
    let hiddenSpans = spans.filter { span in
      span.lane >= 2 && entries.contains { $0.schedule.id == span.id }
    }.count
    let overflow = max(0, timed.count - capacity) + hiddenSpans
    let selected = calendar.isDate(day, inSameDayAs: selectedDate)
    let identifier = SavedCalendarDates.identifier(day, calendar: calendar)
    return VStack(alignment: .leading, spacing: 0) {
      Button {
        selectedDate = SavedCalendarDates.selecting(
          day, preserving: selectedDate, calendar: calendar)
        agendaDay = day
      } label: {
        Text(day, format: .dateTime.day()).font(.caption.weight(.semibold))
          .foregroundStyle(calendar.isDateInToday(day) ? Color.white : Color.primary)
          .frame(width: 26, height: 26)
          .background {
            if calendar.isDateInToday(day) { Circle().fill(.tint) }
          }
          .frame(maxWidth: .infinity, minHeight: 32, alignment: .trailing)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text(day, format: .dateTime.weekday().month(.wide).day()))
      .accessibilityValue(
        entries.count == 1 ? "1 scheduled entry" : "\(entries.count) scheduled entries"
      )
      .accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityIdentifier("saved.calendar.day.\(identifier)")
      Color.clear.frame(height: reserved)
      ForEach(timed.prefix(capacity), id: \.schedule.id) { entry in
        Button {
          selectedDate = SavedCalendarDates.selecting(
            day, preserving: selectedDate, calendar: calendar)
          selection = .init(scheduleIdentifier: entry.schedule.id, source: entry.source)
        } label: {
          HStack(spacing: 2) {
            Circle().fill(.teal).frame(width: 3, height: 3)
            Text(entry.title).font(.caption2).lineLimit(1)
          }.frame(maxWidth: .infinity, minHeight: 17, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.title)
        .accessibilityValue(compactDescription(entry))
        .accessibilityIdentifier(
          "saved.calendar.day.\(identifier).schedule.\(entry.schedule.id.uuidString)")
      }
      if overflow > 0 {
        Button("+\(overflow) more") {
          selectedDate = SavedCalendarDates.selecting(
            day, preserving: selectedDate, calendar: calendar)
          agendaDay = day
        }
        .font(.caption2).foregroundStyle(.secondary)
        .accessibilityLabel("Show all \(entries.count) scheduled entries for this day")
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 3)
    .background(selected ? Color.accentColor.opacity(0.1) : Color.clear)
    .opacity(calendar.isDate(day, equalTo: visibleDate, toGranularity: .month) ? 1 : 0.5)
    .overlay(alignment: .leading) { Divider().opacity(0.35) }
  }

  private func compactDescription(_ entry: PlannerCalendarEntry) -> String {
    switch entry.form {
    case .allDay(let start, let end):
      return "All day · " + allDayScheduleDescription(start: start, end: end)
    case .timed(let start, let end, _):
      var format = Date.FormatStyle(date: .abbreviated, time: .shortened).timeZone(
        .specificName(.short))
      format.timeZone = calendar.timeZone
      return start.formatted(format) + (end.map { " – " + $0.formatted(format) } ?? " · Start only")
    }
  }
}
