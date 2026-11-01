import PlannerCore
import SwiftUI

func calendarDayHasClockChange(_ date: Date, calendar: Calendar) -> Bool {
  guard let interval = calendar.dateInterval(of: .day, for: date) else { return false }
  return calendar.timeZone.secondsFromGMT(for: interval.start)
    != calendar.timeZone.secondsFromGMT(for: interval.end.addingTimeInterval(-1))
}

func calendarClockChangeSpanDescription(
  start: Date, end: Date, calendar: Calendar, includesDate: Bool
) -> String? {
  guard
    calendarDayHasClockChange(start, calendar: calendar)
      || calendarDayHasClockChange(end, calendar: calendar)
      || calendar.timeZone.secondsFromGMT(for: start) != calendar.timeZone.secondsFromGMT(for: end)
  else { return nil }
  var format = Date.FormatStyle(
    date: includesDate ? .abbreviated : .omitted, time: .shortened
  ).timeZone(.specificName(.short))
  format.calendar = calendar
  format.timeZone = calendar.timeZone
  return start.formatted(format) + " – " + end.formatted(format)
}

struct SavedCalendarTimeGrid: View {
  @Environment(\.colorScheme) private var colorScheme
  private struct AllDayPresentation: Identifiable {
    let date: Date
    var id: Date { date }
  }

  private struct TimedPlacement {
    let entry: PlannerCalendarEntry
    let top: CGFloat
    let height: CGFloat
    var lane: Int
    var laneCount = 1
  }

  let days: [Date]
  @Binding var selectedDate: Date
  let calendar: Calendar
  @Binding var selection: SavedCalendarSelection?
  let entriesForDay: (Date) -> [PlannerCalendarEntry]
  let scheduleDescription: (PlannerCalendarEntry) -> String

  @State private var allDayPresentation: AllDayPresentation?
  @State private var selectedEntryTarget: (identifier: String, selection: SavedCalendarSelection)?
  @State private var horizontalScrollOffset: CGFloat = 0
  @State private var verticalScrollOffset: CGFloat = 0
  @State private var isUserScrolling = false
  @State private var scrollPosition = ScrollPosition()
  @ScaledMetric(relativeTo: .subheadline) private var allDayCardHeight = 64
  @ScaledMetric(relativeTo: .subheadline) private var timedCardMinimumHeight = 64
  @ScaledMetric(relativeTo: .caption2) private var timeRulerWidth: CGFloat = 48
  @ScaledMetric(relativeTo: .caption) private var weekColumnMinimumWidth: CGFloat = 48
  @ScaledMetric(relativeTo: .caption) private var weekCardMinimumHeight: CGFloat = 44
  @ScaledMetric(relativeTo: .subheadline) private var appointmentLaneMinimumWidth: CGFloat = 100
  @ScaledMetric(relativeTo: .caption) private var pointsPerMinute: CGFloat = 1

  private var isWeek: Bool { days.count > 1 }
  private var cardMinimumHeight: CGFloat {
    max(44, isWeek ? weekCardMinimumHeight : timedCardMinimumHeight)
  }

  private func dateIdentifier(_ date: Date) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
  }

  private func hourIdentifier(_ date: Date, hour: Int) -> String {
    dateIdentifier(date) + ":\(hour)"
  }

  private func timeDescription(_ date: Date) -> String {
    var format = Date.FormatStyle(date: .omitted, time: .shortened)
    if calendarDayHasClockChange(date, calendar: calendar) {
      format = format.timeZone(.specificName(.short))
    }
    format.calendar = calendar
    format.timeZone = calendar.timeZone
    return date.formatted(format)
  }

  private func timedPlacements(
    _ entries: [PlannerCalendarEntry], interval: DateInterval
  ) -> [TimedPlacement] {
    var placements = entries.compactMap { entry -> TimedPlacement? in
      guard case .timed(let start, let end, _) = entry.form else { return nil }
      let visibleStart = max(start, interval.start)
      let bounds = clockBounds(
        start: visibleStart, end: min(end ?? start, interval.end), interval: interval)
      let top = bounds.lowerBound * pointsPerMinute
      let height = max(
        cardMinimumHeight,
        (bounds.upperBound - bounds.lowerBound) * pointsPerMinute)
      return .init(entry: entry, top: top, height: height, lane: 0)
    }
    placements.sort { $0.top < $1.top }
    var laneEnds: [CGFloat] = []
    var groupStart = 0
    var groupEnd: CGFloat = 0
    for index in placements.indices {
      let top = placements[index].top
      let height = placements[index].height
      if top >= groupEnd {
        for groupIndex in groupStart..<index { placements[groupIndex].laneCount = laneEnds.count }
        groupStart = index
        laneEnds = []
      }
      let lane = laneEnds.firstIndex(where: { $0 <= top }) ?? laneEnds.count
      if lane == laneEnds.count {
        laneEnds.append(top + height)
      } else {
        laneEnds[lane] = top + height
      }
      groupEnd = max(groupEnd, top + height)
      placements[index].lane = lane
    }
    for index in groupStart..<placements.count { placements[index].laneCount = laneEnds.count }
    return placements
  }

  private func clockMinute(_ date: Date, interval: DateInterval) -> CGFloat {
    if date == interval.end { return 24 * 60 }
    let components = calendar.dateComponents([.hour, .minute, .second], from: date)
    return CGFloat((components.hour ?? 0) * 60 + (components.minute ?? 0))
      + CGFloat(components.second ?? 0) / 60
  }

  /// A backward change can put the end above the start; include both transition boundaries.
  private func clockBounds(start: Date, end: Date, interval: DateInterval)
    -> ClosedRange<CGFloat>
  {
    var minutes = [clockMinute(start, interval: interval), clockMinute(end, interval: interval)]
    var cursor = start
    while let transition = calendar.timeZone.nextDaylightSavingTimeTransition(after: cursor),
      transition > cursor, transition <= end
    {
      let previousMinute =
        clockMinute(transition.addingTimeInterval(-1), interval: interval)
        + 1 / 60
      if transition == end {
        minutes[1] = max(minutes[1], previousMinute)
      } else {
        minutes.append(previousMinute)
        minutes.append(clockMinute(transition, interval: interval))
      }
      cursor = transition
    }
    return (minutes.min() ?? 0)...(minutes.max() ?? 0)
  }

  private func minimumColumnWidth(on day: Date) -> CGFloat {
    guard let interval = calendar.dateInterval(of: .day, for: day) else { return 0 }
    let placements = timedPlacements(entriesForDay(day), interval: interval)
    let lanes = placements.map(\.laneCount).max() ?? 1
    let laneWidth = isWeek ? max(46, weekColumnMinimumWidth - 4) : appointmentLaneMinimumWidth
    return max(isWeek ? weekColumnMinimumWidth : 120, 4 + CGFloat(lanes) * laneWidth)
  }

  var body: some View {
    GeometryReader { geometry in
      let minimumWidths = days.map { minimumColumnWidth(on: $0) }
      let minimumWidth = minimumWidths.reduce(0, +)
      let extraWidth =
        max(0, geometry.size.width - timeRulerWidth - minimumWidth)
        / CGFloat(max(1, days.count))
      let horizontalAnchor = min(1, timeRulerWidth / max(1, geometry.size.width - 1))
      ScrollViewReader { proxy in
        ScrollView([.horizontal, .vertical]) {
          LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
              HStack(alignment: .top, spacing: 0) {
                timeRuler
                  .background(.background)
                  .offset(x: horizontalScrollOffset)
                  .zIndex(1)
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                  dayColumn(day, width: minimumWidths[index] + extraWidth)
                }
              }
              .overlay(alignment: .topLeading) {
                currentTimeLine(widths: minimumWidths.map { $0 + extraWidth })
              }
            } header: {
              VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                  Color.clear.frame(width: timeRulerWidth)
                  ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    dayHeader(day, width: minimumWidths[index] + extraWidth)
                  }
                }
                allDayBand(widths: minimumWidths.map { $0 + extraWidth })
              }
              .padding(.vertical, 4)
              .background(.background)
              .overlay(alignment: .bottom) { Divider() }
            }
          }
          .frame(width: timeRulerWidth + minimumWidth + extraWidth * CGFloat(days.count))
        }
        .scrollPosition($scrollPosition)
        .onScrollPhaseChange { _, phase in
          isUserScrolling = phase == .interacting || phase == .decelerating
        }
        .onScrollGeometryChange(for: CGPoint.self) { geometry in
          CGPoint(
            x: max(0, geometry.contentOffset.x + geometry.contentInsets.leading),
            y: max(0, geometry.contentOffset.y + geometry.contentInsets.top))
        } action: { previous, offset in
          horizontalScrollOffset = offset.x
          verticalScrollOffset = offset.y
          guard isUserScrolling else { return }
          let minute = min(1439, max(0, Int(offset.y / pointsPerMinute)))
          var focusDay = selectedDate
          if abs(offset.x - previous.x) > abs(offset.y - previous.y) {
            let widths = minimumWidths.map { $0 + extraWidth }
            var end: CGFloat = 0
            for (index, width) in widths.enumerated() {
              end += width
              if end > offset.x {
                focusDay = days[index]
                break
              }
            }
          }
          if let date = calendar.date(
            bySettingHour: minute / 60, minute: minute % 60, second: 0, of: focusDay)
          {
            selectedDate = date
          }
        }
        .onChange(of: selectedDate) {
          scrollToFocus(
            availableWidth: geometry.size.width, widths: minimumWidths.map { $0 + extraWidth })
        }
        .onChange(of: minimumWidths) {
          scrollToFocus(
            availableWidth: geometry.size.width, widths: minimumWidths.map { $0 + extraWidth })
        }
        .onAppear {
          scrollToFocus(
            availableWidth: geometry.size.width, widths: minimumWidths.map { $0 + extraWidth })
        }
        .onChange(of: geometry.size) { previousSize, size in
          if size.width < previousSize.width || size.height < previousSize.height,
            let selectedEntryTarget,
            selection == selectedEntryTarget.selection
          {
            proxy.scrollTo(
              selectedEntryTarget.identifier, anchor: .init(x: horizontalAnchor, y: 0.5))
          } else {
            scrollToFocus(
              availableWidth: size.width, widths: minimumWidths.map { $0 + extraWidth })
          }
        }
      }
    }
    .clipped()
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("saved.calendar.time-grid")
    .sheet(item: $allDayPresentation) { presentation in
      allDaySchedules(on: presentation.date)
    }
  }

  private func scrollToFocus(availableWidth: CGFloat, widths: [CGFloat]) {
    guard !isUserScrolling else { return }
    let minute =
      calendar.component(.hour, from: selectedDate) * 60
      + calendar.component(.minute, from: selectedDate)
    var horizontal = horizontalScrollOffset
    if let index = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) {
      let leading = widths.prefix(index).reduce(0, +)
      if leading < horizontal
        || leading + widths[index] + timeRulerWidth > horizontal + availableWidth
      {
        horizontal = leading
      }
    }
    // Leave a little clock context so the current-time label clears the sticky heading.
    scrollPosition.scrollTo(x: horizontal, y: max(0, CGFloat(minute) * pointsPerMinute - 16))
  }

  private func allDaySchedules(on day: Date) -> some View {
    NavigationStack {
      List(allDayEntries(on: day), id: \.schedule.id) { entry in
        entryButton(entry, day: day, isTimed: false, isCompact: false)
          .frame(height: allDayCardHeight)
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("saved.calendar.all-day-overflow")
      .navigationTitle("All-day schedules")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { allDayPresentation = nil }
        }
      }
    }
    #if os(macOS)
      .frame(minWidth: 320, idealWidth: 360, minHeight: 420)
    #endif
    .presentationDetents([.medium, .large])
  }

  private func allDayEntries(on day: Date) -> [PlannerCalendarEntry] {
    entriesForDay(day).filter {
      if case .allDay = $0.form { return true }
      return false
    }
  }

  private func dayHeader(_ day: Date, width: CGFloat) -> some View {
    return VStack(alignment: .leading, spacing: 4) {
      Button {
        selectedDate = SavedCalendarDates.selecting(
          day, preserving: selectedDate, calendar: calendar)
      } label: {
        Group {
          if isWeek {
            VStack(spacing: 2) {
              Text(day, format: .dateTime.weekday(.abbreviated))
                .font(.caption2).foregroundStyle(.secondary)
              Text(day, format: .dateTime.day())
                .foregroundStyle(calendar.isDateInToday(day) ? Color.white : Color.primary)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 28, minHeight: 28)
                .background {
                  if calendar.isDateInToday(day) {
                    Circle().fill(.tint)
                  } else if calendar.isDate(day, inSameDayAs: selectedDate) {
                    Circle().fill(.tint.opacity(colorScheme == .dark ? 0.32 : 0.16))
                  }
                }
            }
          } else {
            Text(day, format: .dateTime.weekday(.wide)).font(.caption.weight(.semibold))
          }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text(day, format: .dateTime.weekday().month().day()))
      .accessibilityAddTraits(calendar.isDate(day, inSameDayAs: selectedDate) ? .isSelected : [])
      .accessibilityIdentifier("saved.calendar.day-heading.\(dateIdentifier(day))")
    }
    .frame(width: width, alignment: .topLeading)
  }

  private func allDayBand(widths: [CGFloat]) -> some View {
    let spans = SavedCalendarDates.spans(in: days, entriesForDay: entriesForDay)
    let rows = min(2, (spans.map(\.lane).max() ?? -1) + 1)
    let hasOverflow = spans.contains { $0.lane >= 2 }
    return VStack(spacing: 0) {
      if rows > 0 {
        ZStack(alignment: .topLeading) {
          Text("All day").font(.system(size: 10)).foregroundStyle(.secondary)
            .frame(width: timeRulerWidth, height: 24)
            .offset(x: horizontalScrollOffset)
          ForEach(spans.filter { $0.lane < 2 }) { span in
            entryButton(span.entry, day: days[span.start], isTimed: false, isCompact: true)
              .frame(width: widths[span.start...span.end].reduce(0, +) - 4, height: 24)
              .background(
                Color.teal.opacity(colorScheme == .dark ? 0.28 : 0.14), in: .rect(cornerRadius: 3)
              )
              .offset(
                x: timeRulerWidth + widths.prefix(span.start).reduce(0, +) + 2,
                y: CGFloat(span.lane) * 26)
          }
        }
        .frame(
          width: timeRulerWidth + widths.reduce(0, +), height: CGFloat(rows) * 26,
          alignment: .topLeading)
      }
      if hasOverflow {
        HStack(spacing: 0) {
          Color.clear.frame(width: timeRulerWidth)
          ForEach(Array(days.enumerated()), id: \.element) { index, day in
            let count = spans.filter { span in
              span.lane >= 2 && span.start <= index && index <= span.end
            }.count
            Group {
              if count > 0 {
                Button("+\(count) more") { allDayPresentation = .init(date: day) }
                  .font(.caption2)
                  .accessibilityLabel("\(count) more all-day schedules")
                  .accessibilityIdentifier("saved.calendar.all-day.more.\(dateIdentifier(day))")
              } else {
                Color.clear
              }
            }.frame(width: widths[index], height: 32)
          }
        }
      }
    }
  }

  private func dayColumn(_ day: Date, width: CGFloat) -> some View {
    let entries = entriesForDay(day)
    return VStack(spacing: 0) {
      if let interval = calendar.dateInterval(of: .day, for: day) {
        ZStack(alignment: .topLeading) {
          if calendar.isDate(day, inSameDayAs: selectedDate) {
            Color.accentColor.opacity(colorScheme == .dark ? 0.08 : 0.035)
          }
          hourLines(day: day)
          ForEach(timedPlacements(entries, interval: interval), id: \.entry.schedule.id) {
            placement in
            let laneWidth = (width - 4) / CGFloat(placement.laneCount)
            entryButton(
              placement.entry, day: day, isTimed: true, isCompact: isWeek,
              titleTopInset: max(
                0, min(placement.height - 24, verticalScrollOffset - placement.top))
            )
            .frame(width: laneWidth - 2, height: placement.height, alignment: .topLeading)
            .background(
              Color.teal.opacity(colorScheme == .dark ? 0.28 : 0.12), in: .rect(cornerRadius: 4)
            )
            .background(.background, in: .rect(cornerRadius: 4))
            .overlay(alignment: .leading) {
              RoundedRectangle(cornerRadius: 2).fill(.teal).frame(width: 2)
                .accessibilityHidden(true)
            }
            .offset(x: 2 + CGFloat(placement.lane) * laneWidth, y: placement.top)
          }
        }
        .frame(
          width: width,
          height: 24 * 60 * pointsPerMinute
            + cardMinimumHeight,
          alignment: .topLeading
        )
        .overlay(alignment: .leading) { Divider().opacity(0.4) }
      }
    }
    .frame(width: width, alignment: .topLeading)
  }

  private func currentTimeLine(widths: [CGFloat]) -> some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      if let index = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: context.date) }),
        let interval = calendar.dateInterval(of: .day, for: context.date)
      {
        let top = clockMinute(context.date, interval: interval) * pointsPerMinute
        ZStack(alignment: .topLeading) {
          Rectangle().fill(.red).frame(width: widths.reduce(0, +), height: 1)
            .offset(x: timeRulerWidth, y: top)
          Circle().fill(.red).frame(width: 7, height: 7)
            .offset(x: timeRulerWidth + widths.prefix(index).reduce(0, +) - 3, y: top - 3)
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func hourLines(day: Date) -> some View {
    VStack(spacing: 0) {
      ForEach(0..<24, id: \.self) { hour in
        Rectangle().fill(.separator).opacity(0.5).frame(height: 0.5)
          .overlay(alignment: .topLeading) {
            Color.clear.frame(width: 1, height: 1).id(hourIdentifier(day, hour: hour))
          }
          .frame(height: 60 * pointsPerMinute, alignment: .top)
      }
    }
  }

  private var timeRuler: some View {
    let hourFormat = DateFormatter()
    hourFormat.timeZone = .gmt
    hourFormat.setLocalizedDateFormatFromTemplate("j")
    return VStack(alignment: .trailing, spacing: 0) {
      ForEach(0..<24, id: \.self) { hour in
        let date = Date(timeIntervalSinceReferenceDate: Double(hour) * 3600)
        Text(hourFormat.string(from: date)).font(.caption2).foregroundStyle(.secondary)
          .lineLimit(1)
          .padding(.trailing, 8)
          .frame(width: timeRulerWidth, height: 60 * pointsPerMinute, alignment: .topTrailing)
      }
    }
    .frame(
      height: 24 * 60 * pointsPerMinute + cardMinimumHeight, alignment: .top
    )
    .overlay(alignment: .topTrailing) {
      TimelineView(.periodic(from: .now, by: 60)) { context in
        if days.contains(where: { calendar.isDate($0, inSameDayAs: context.date) }),
          let interval = calendar.dateInterval(of: .day, for: context.date)
        {
          Text(timeDescription(context.date)).font(.system(size: 9)).foregroundStyle(.red)
            .padding(.trailing, 4).background(.background)
            .offset(y: clockMinute(context.date, interval: interval) * pointsPerMinute - 6)
            .accessibilityLabel("Current time " + timeDescription(context.date))
        }
      }
      .allowsHitTesting(false)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("saved.calendar.time-ruler")
  }

  private func entryButton(
    _ entry: PlannerCalendarEntry, day: Date, isTimed: Bool, isCompact: Bool,
    titleTopInset: CGFloat = 0
  ) -> some View {
    let identifier =
      "saved.calendar.\(isTimed ? "timed" : "all-day").\(dateIdentifier(day)).\(entry.schedule.id.uuidString)"
    return Button {
      allDayPresentation = nil
      let selected = SavedCalendarSelection(
        scheduleIdentifier: entry.schedule.id, source: entry.source)
      selectedEntryTarget = (identifier, selected)
      selection = selected
    } label: {
      ViewThatFits(in: .vertical) {
        VStack(alignment: .leading, spacing: 2) {
          Text(entry.title).font(
            isCompact ? .caption.weight(.medium) : .subheadline.weight(.medium)
          )
          .lineLimit(isTimed ? 2 : 1).fixedSize(horizontal: false, vertical: true)
          if isTimed || !isCompact {
            Text(previewDescription(entry, isTimed: isTimed, isCompact: isCompact)).font(.caption2)
              .foregroundStyle(.secondary).lineLimit(isCompact ? 1 : 2)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Text(entry.title).font(isCompact ? .caption.weight(.medium) : .subheadline.weight(.medium))
          .lineLimit(2)
      }
      .padding(isCompact ? 4 : 6)
      // Keep a long event's title visible when its start is above the pinned date headings.
      .padding(.top, titleTopInset)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .overlay(alignment: .topLeading) {
      Color.clear.frame(width: 1, height: 1).id(identifier)
    }
    .accessibilityLabel(entry.title)
    .accessibilityValue(scheduleDescription(entry))
    .accessibilityIdentifier(identifier)
  }

  private func previewDescription(
    _ entry: PlannerCalendarEntry, isTimed: Bool, isCompact: Bool
  ) -> String {
    guard isTimed, case .timed(let start, let end, _) = entry.form else {
      return isCompact ? "All day" : scheduleDescription(entry)
    }
    if let end {
      if let description = calendarClockChangeSpanDescription(
        start: start, end: end, calendar: calendar, includesDate: false)
      {
        return description
      }
      if isCompact { return timeDescription(start) + " – " + timeDescription(end) }
      return scheduleDescription(entry)
    }
    if isCompact, !calendarDayHasClockChange(start, calendar: calendar) {
      return timeDescription(start)
    }
    return "Start only · " + timeDescription(start)
  }
}
