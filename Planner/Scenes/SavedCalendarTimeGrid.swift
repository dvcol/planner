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
  @Environment(\.scenePhase) private var scenePhase
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

  let periods: [Date]
  let isWeek: Bool
  @Binding var selectedDate: Date
  let calendar: Calendar
  @Binding var selection: SavedCalendarSelection?
  let entriesForDay: (Date) -> [PlannerCalendarEntry]
  let scheduleDescription: (PlannerCalendarEntry) -> String
  let onScrollSettled: () -> Void

  @State private var allDayPresentation: AllDayPresentation?
  @State private var scrollOffset = CGPoint.zero
  @State private var scrollPosition = ScrollPosition()
  @State private var isUserScrolling = false
  @State private var lastScrollFocus: Date?
  @ScaledMetric(relativeTo: .subheadline) private var allDayCardHeight = 64
  @ScaledMetric(relativeTo: .subheadline) private var timedCardMinimumHeight = 64
  @ScaledMetric(relativeTo: .caption2) private var timeRulerWidth: CGFloat = 48
  @ScaledMetric(relativeTo: .caption) private var weekColumnMinimumWidth: CGFloat = 48
  @ScaledMetric(relativeTo: .caption) private var weekCardMinimumHeight: CGFloat = 44
  @ScaledMetric(relativeTo: .subheadline) private var appointmentLaneMinimumWidth: CGFloat = 100
  @ScaledMetric(relativeTo: .caption) private var pointsPerMinute: CGFloat = 1

  private func days(in period: Date) -> [Date] {
    guard let interval = calendar.dateInterval(of: isWeek ? .weekOfYear : .day, for: period)
    else { return [] }
    return SavedCalendarDates.days(in: interval, calendar: calendar)
  }

  private var focusMinute: CGFloat {
    CGFloat(
      calendar.component(.hour, from: selectedDate) * 60
        + calendar.component(.minute, from: selectedDate))
  }
  private var cardMinimumHeight: CGFloat {
    max(44, isWeek ? weekCardMinimumHeight : timedCardMinimumHeight)
  }

  private func dateIdentifier(_ date: Date) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
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

  private func headerHeight(for period: Date) -> CGFloat {
    let spans = SavedCalendarDates.spans(in: days(in: period), entriesForDay: entriesForDay)
    let rows = min(2, (spans.map(\.lane).max() ?? -1) + 1)
    return 52 + CGFloat(rows) * 26 + (spans.contains { $0.lane >= 2 } ? 32 : 0)
  }

  private var bodyHeight: CGFloat { 24 * 60 * pointsPerMinute + cardMinimumHeight }

  private var visibleDays: [Date] { periods.flatMap { days(in: $0) } }

  /// One header extent keeps every date aligned to the same local clock grid.
  private var headingHeight: CGFloat { periods.map { headerHeight(for: $0) }.max() ?? 52 }

  private func header(for period: Date, columnWidth: CGFloat) -> some View {
    let days = days(in: period)
    return VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 0) {
        ForEach(days, id: \.self) { day in dayHeader(day, width: columnWidth) }
      }
      allDayBand(days: days, widths: Array(repeating: columnWidth, count: days.count))
    }
    .padding(.vertical, 4)
    .frame(height: headingHeight, alignment: .top)
    .background(.background)
    .overlay(alignment: .bottom) { Rectangle().fill(.separator).frame(height: 0.5) }
  }

  var body: some View {
    GeometryReader { geometry in
      let count = isWeek ? 7 : 1
      let minimumWidth =
        if isWeek {
          weekColumnMinimumWidth
        } else {
          visibleDays.map { minimumColumnWidth(on: $0) }.max() ?? 120
        }
      let columnWidth = max(minimumWidth, (geometry.size.width - timeRulerWidth) / CGFloat(count))
      TimelineView(.everyMinute) { context in
        let now = scenePhase == .active ? Date() : context.date
        let todayVisible = visibleDays.enumerated().contains { index, day in
          let leading = CGFloat(index) * columnWidth
          return calendar.isDate(day, inSameDayAs: now)
            && leading + columnWidth > scrollOffset.x
            && leading < scrollOffset.x + geometry.size.width - timeRulerWidth
        }
        ScrollView([.horizontal, .vertical]) {
          HStack(alignment: .top, spacing: 0) {
            Color.clear.frame(width: timeRulerWidth)
            LazyHStack(alignment: .top, spacing: 0) {
              ForEach(periods, id: \.self) { period in
                HStack(alignment: .top, spacing: 0) {
                  ForEach(days(in: period), id: \.self) { day in
                    dayColumn(day, width: columnWidth, visibleOffset: scrollOffset.y)
                  }
                }
                .frame(width: CGFloat(count) * columnWidth)
                .padding(.top, headingHeight)
              }
            }
          }
          .frame(height: headingHeight + bodyHeight, alignment: .top)
          .overlay(alignment: .topLeading) {
            if todayVisible {
              currentTimeLine(now: now, columnWidth: columnWidth)
                .offset(y: headingHeight)
            }
          }
          .overlay(alignment: .topLeading) {
            timeRuler(now: todayVisible ? now : nil)
              .background(.background)
              .offset(x: scrollOffset.x, y: headingHeight)
          }
          .overlay(alignment: .topLeading) {
            HStack(spacing: 0) {
              Color.clear.frame(width: timeRulerWidth)
              LazyHStack(spacing: 0) {
                ForEach(periods, id: \.self) { period in
                  header(for: period, columnWidth: columnWidth)
                    .frame(width: CGFloat(count) * columnWidth)
                }
              }
            }
            .frame(height: headingHeight)
            .offset(y: scrollOffset.y)
            .overlay(alignment: .topLeading) {
              Group {
                if headingHeight > 52 {
                  Text("All day").font(.system(size: 10)).foregroundStyle(.secondary)
                } else {
                  Color.clear
                }
              }
              .frame(width: timeRulerWidth, height: headingHeight, alignment: .bottom)
              .padding(.bottom, 4)
              .background(.background)
              .offset(x: scrollOffset.x, y: scrollOffset.y)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("saved.calendar.time-heading")
          }
        }
        .scrollPosition($scrollPosition)
        .onScrollPhaseChange { _, phase in
          let wasScrolling = isUserScrolling
          isUserScrolling = phase == .interacting || phase == .decelerating
          if phase == .idle && wasScrolling { onScrollSettled() }
        }
        .onScrollGeometryChange(for: CGPoint.self) { geometry in
          CGPoint(
            x: max(0, geometry.contentOffset.x + geometry.contentInsets.leading),
            y: max(0, geometry.contentOffset.y + geometry.contentInsets.top))
        } action: { previous, offset in
          scrollOffset = offset
          guard isUserScrolling else { return }
          let days = visibleDays
          guard
            let selectedIndex = days.firstIndex(where: {
              calendar.isDate($0, inSameDayAs: selectedDate)
            })
          else { return }
          let dayDelta =
            Int((offset.x / columnWidth).rounded()) - Int((previous.x / columnWidth).rounded())
          var index = selectedIndex + dayDelta
          if offset.x != previous.x {
            let first = Int(ceil(offset.x / columnWidth - 0.5))
            let last = Int(
              floor((offset.x + geometry.size.width - timeRulerWidth) / columnWidth - 0.5))
            index = min(max(index, first), last)
          }
          let day = days[min(max(0, index), days.count - 1)]
          let minute = min(1439, max(0, Int((offset.y + 16) / pointsPerMinute)))
          if let date = calendar.date(
            bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
          {
            lastScrollFocus = date
            selectedDate = date
          }
        }
        .task(id: selectedDate) {
          await Task.yield()
          guard !Task.isCancelled, selectedDate != lastScrollFocus else { return }
          scrollToFocus(size: geometry.size, columnWidth: columnWidth)
        }
        .onChange(of: periods) { previous, current in
          guard let oldStart = previous.first, let newStart = current.first else { return }
          let shift = calendar.dateComponents([.day], from: oldStart, to: newStart).day ?? 0
          let adjusted = scrollOffset.x - CGFloat(shift) * columnWidth
          let index = visibleDays.firstIndex { calendar.isDate($0, inSameDayAs: selectedDate) }
          if let index, adjusted >= 0,
            (CGFloat(index) + 0.5) * columnWidth >= adjusted - 1,
            (CGFloat(index) + 0.5) * columnWidth < adjusted + geometry.size.width - timeRulerWidth
          {
            scrollPosition.scrollTo(x: adjusted, y: scrollOffset.y)
          } else {
            scrollToFocus(size: geometry.size, columnWidth: columnWidth)
          }
        }
        .onChange(of: geometry.size) { _, size in
          scrollToFocus(size: size, columnWidth: columnWidth)
        }
        .onChange(of: bodyHeight) {
          scrollToFocus(size: geometry.size, columnWidth: columnWidth)
        }
      }
    }
    .clipped()
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("saved.calendar.time-grid")
    .sheet(item: $allDayPresentation) { presentation in allDaySchedules(on: presentation.date) }
  }

  private func scrollToFocus(size: CGSize, columnWidth: CGFloat) {
    guard !isUserScrolling,
      let index = visibleDays.firstIndex(where: { calendar.isDate($0, inSameDayAs: selectedDate) })
    else { return }
    var horizontal = scrollOffset.x
    let leading = CGFloat(index) * columnWidth
    if leading < horizontal
      || leading + columnWidth + timeRulerWidth > horizontal + size.width + 1
    {
      if isWeek {
        horizontal = CGFloat(index / 7 * 7) * columnWidth
      } else {
        horizontal = leading
      }
    }
    scrollPosition.scrollTo(x: horizontal, y: max(0, focusMinute * pointsPerMinute - 16))
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
            Text(day, format: .dateTime.weekday(.wide).month(.abbreviated).day()).font(
              .caption.weight(.semibold))
          }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: isWeek ? .center : .leading)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text(day, format: .dateTime.weekday().month().day()))
      .accessibilityAddTraits(calendar.isDate(day, inSameDayAs: selectedDate) ? .isSelected : [])
      .accessibilityIdentifier("saved.calendar.day-heading.\(dateIdentifier(day))")
    }
    .frame(width: width, alignment: .topLeading)
    .background { SavedCalendarWeekendBackground(day: day, calendar: calendar) }
  }

  private func allDayBand(days: [Date], widths: [CGFloat]) -> some View {
    let spans = SavedCalendarDates.spans(in: days, entriesForDay: entriesForDay)
    let rows = min(2, (spans.map(\.lane).max() ?? -1) + 1)
    let hasOverflow = spans.contains { $0.lane >= 2 }
    return VStack(spacing: 0) {
      if rows > 0 {
        ZStack(alignment: .topLeading) {
          ForEach(spans.filter { $0.lane < 2 }) { span in
            entryButton(span.entry, day: days[span.start], isTimed: false, isCompact: true)
              .frame(width: widths[span.start...span.end].reduce(0, +) - 4, height: 24)
              .background(
                Color.teal.opacity(colorScheme == .dark ? 0.28 : 0.14), in: .rect(cornerRadius: 3)
              )
              .offset(
                x: widths.prefix(span.start).reduce(0, +) + 2,
                y: CGFloat(span.lane) * 26)
          }
        }
        .frame(
          width: widths.reduce(0, +), height: CGFloat(rows) * 26,
          alignment: .topLeading)
      }
      if hasOverflow {
        HStack(spacing: 0) {
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

  private func dayColumn(_ day: Date, width: CGFloat, visibleOffset: CGFloat) -> some View {
    let entries = entriesForDay(day)
    return VStack(spacing: 0) {
      if let interval = calendar.dateInterval(of: .day, for: day) {
        ZStack(alignment: .topLeading) {
          SavedCalendarWeekendBackground(day: day, calendar: calendar)
          if calendar.isDate(day, inSameDayAs: selectedDate) {
            Color.accentColor.opacity(colorScheme == .dark ? 0.08 : 0.035)
          }
          hourLines
          ForEach(timedPlacements(entries, interval: interval), id: \.entry.schedule.id) {
            placement in
            let laneWidth = (width - 4) / CGFloat(placement.laneCount)
            entryButton(
              placement.entry, day: day, isTimed: true, isCompact: isWeek,
              titleTopInset: max(
                0, min(placement.height - 24, visibleOffset - placement.top))
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

  private func currentTimeLine(now: Date, columnWidth: CGFloat) -> some View {
    let days = visibleDays
    return ZStack(alignment: .topLeading) {
      if let index = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: now) }),
        let interval = calendar.dateInterval(of: .day, for: now)
      {
        let top = clockMinute(now, interval: interval) * pointsPerMinute
        Rectangle().fill(.red).frame(width: CGFloat(days.count) * columnWidth, height: 1)
          .offset(x: timeRulerWidth, y: top)
        Circle().fill(.red).frame(width: 7, height: 7)
          .offset(x: timeRulerWidth + CGFloat(index) * columnWidth - 3, y: top - 3)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private var hourLines: some View {
    VStack(spacing: 0) {
      ForEach(0..<24, id: \.self) { _ in
        Rectangle().fill(.separator).opacity(0.5).frame(height: 0.5)
          .frame(height: 60 * pointsPerMinute, alignment: .top)
      }
    }
  }

  private func timeRuler(now: Date?) -> some View {
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
      if let now, let interval = calendar.dateInterval(of: .day, for: now) {
        Text(timeDescription(now)).font(.system(size: 9)).foregroundStyle(.red)
          .padding(.trailing, 4).background(.background)
          .offset(y: clockMinute(now, interval: interval) * pointsPerMinute - 6)
          .accessibilityLabel("Current time " + timeDescription(now))
          .accessibilityIdentifier("saved.calendar.current-time")
          .allowsHitTesting(false)
      }
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
      switch entry.form {
      case .timed(let start, _, _): selectedDate = max(start, calendar.startOfDay(for: day))
      case .allDay:
        selectedDate = SavedCalendarDates.selecting(
          day, preserving: selectedDate, calendar: calendar)
      }
      selection = selected
    } label: {
      ViewThatFits(in: .vertical) {
        VStack(alignment: .leading, spacing: 2) {
          Text(entry.title).font(
            isCompact ? .caption.weight(.medium) : .subheadline.weight(.medium)
          )
          .lineLimit(isCompact ? 1 : 2).fixedSize(horizontal: false, vertical: true)
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
