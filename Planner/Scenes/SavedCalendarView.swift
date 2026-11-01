import PlannerCore
import SwiftUI

#if os(iOS)
  import UIKit
#endif

struct SavedCalendarSelection: Hashable {
  let scheduleIdentifier: UUID
  let source: PlannerEntityReference
}

enum SavedCalendarCollection {
  case lists, items, inbox, itineraries
}

struct SavedCalendarView: View {
  private enum Mode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var component: Calendar.Component {
      switch self {
      case .month: .month
      case .day: .day
      case .week: .weekOfYear
      case .year: .year
      }
    }
  }

  @Environment(\.timeZone) private var deviceTimeZone
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage private var overrideTimeZoneIdentifier: String
  @Bindable var store: SavedPlannerStore
  @Binding var selection: SavedCalendarSelection?
  var openCollection: ((SavedCalendarCollection) -> Void)?
  var showDetails: (() -> Void)?
  @State private var selectedDate = Date()
  @State private var entries: [PlannerCalendarEntry]?
  @State private var isLoading = true
  @State private var mode: Mode = .month
  @State private var timelineAnchor = Date()
  @State private var bookingListAnchor = Date()
  @State private var showsTimeZonePreferences = false
  @State private var showsDateSelection = false
  @State private var showsScheduleCreation = false
  @State private var showsSearch = false
  @State private var searchText = ""
  @State private var showsAgenda = true
  #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  private var usesCompactControls: Bool {
    #if os(iOS)
      UIDevice.current.userInterfaceIdiom == .phone || horizontalSizeClass == .compact
    #else
      false
    #endif
  }

  init(
    store: SavedPlannerStore, selection: Binding<SavedCalendarSelection?>,
    openCollection: ((SavedCalendarCollection) -> Void)? = nil,
    showDetails: (() -> Void)? = nil
  ) {
    self.openCollection = openCollection
    self.showDetails = showDetails
    self.store = store
    self._selection = selection
    let namespace = store.devicePreferenceNamespace ?? "unavailable"
    self._overrideTimeZoneIdentifier = AppStorage(
      wrappedValue: "", "planner.calendar.\(namespace).display-zone")
  }

  private var displayTimeZone: TimeZone {
    TimeZone(identifier: overrideTimeZoneIdentifier) ?? deviceTimeZone
  }

  private var periodRadius: Int {
    switch mode {
    case .day: 21
    case .week, .month: 6
    case .year: 3
    }
  }

  private var periods: [Date] {
    guard let center = displayCalendar.dateInterval(of: mode.component, for: timelineAnchor)?.start
    else { return [] }
    return (-periodRadius...periodRadius).compactMap { offset in
      guard let date = displayCalendar.date(byAdding: mode.component, value: offset, to: center),
        (1...9999).contains(displayCalendar.component(.year, from: date))
      else { return nil }
      return date
    }
  }

  private var bookingDays: [Date] {
    let center = displayCalendar.startOfDay(for: bookingListAnchor)
    return (-21...21).compactMap { displayCalendar.date(byAdding: .day, value: $0, to: center) }
  }

  /// Keep adjacent dates available without materializing every Calendar row.
  private var readInterval: DateInterval? {
    guard let first = periods.first, let last = periods.last,
      let end = displayCalendar.dateInterval(of: mode.component, for: last)?.end,
      let month = displayCalendar.dateInterval(of: .month, for: selectedDate),
      let bookingEnd = displayCalendar.date(byAdding: .day, value: 1, to: bookingDays.last ?? last),
      let firstWeek = displayCalendar.dateInterval(
        of: .weekOfYear, for: min(month.start, first, bookingDays.first ?? first)),
      let lastWeek = displayCalendar.dateInterval(
        of: .weekOfYear, for: max(month.end, end, bookingEnd).addingTimeInterval(-1))
    else { return nil }
    return .init(start: firstWeek.start, end: lastWeek.end)
  }

  private func recenterTimeline() {
    let distance =
      displayCalendar.dateComponents(
        [mode.component], from: timelineAnchor, to: selectedDate
      ).value(for: mode.component) ?? 0
    if abs(distance) >= max(1, periodRadius / 2) { timelineAnchor = selectedDate }
    let dayDistance =
      displayCalendar.dateComponents(
        [.day], from: bookingListAnchor, to: selectedDate
      ).day ?? 0
    if abs(dayDistance) >= 7 { bookingListAnchor = selectedDate }
  }

  private var loadIdentity: String {
    let components = displayCalendar.dateComponents(
      [.year, .month, .day], from: readInterval?.start ?? selectedDate)
    return store.changeRevision.uuidString + ":" + (store.devicePreferenceNamespace ?? "")
      + ":" + displayTimeZone.identifier + ":" + mode.rawValue
      + ":\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
      + ":\(readInterval?.end.timeIntervalSinceReferenceDate ?? 0)"
  }

  private var displayCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = displayTimeZone
    calendar.firstWeekday = Calendar.current.firstWeekday
    calendar.minimumDaysInFirstWeek = Calendar.current.minimumDaysInFirstWeek
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
    guard let interval = readInterval,
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

  private func entries(on date: Date) -> [PlannerCalendarEntry] {
    (entries ?? []).filter { entry in
      occurs(entry, on: date)
        && (searchText.isEmpty || entry.title.localizedStandardContains(searchText))
    }.sorted(by: precedes)
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
        if let description = calendarClockChangeSpanDescription(
          start: start, end: end, calendar: displayCalendar, includesDate: true)
        {
          return description
        }
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
    GeometryReader { geometry in
      let isWide = geometry.size.width >= 700
      let compactControls = usesCompactControls || !isWide
      VStack(spacing: 0) {
        if !compactControls { wideControls }
        HStack(spacing: 0) {
          if isWide && showsAgenda {
            VStack(spacing: 0) {
              dateHeading
              if geometry.size.height > 400 {
                SavedCalendarMiniMonth(
                  month: selectedDate, selectedDate: $selectedDate, calendar: displayCalendar,
                  entriesForDay: entries(on:), showsHeading: false
                )
                .padding(12)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("saved.calendar.date")
              }
              agenda
            }
            .frame(width: min(280, geometry.size.width * 0.32))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("saved.calendar.sidebar")
            Divider()
          }
          VStack(spacing: 0) {
            if !isWide || !showsAgenda { dateHeading }
            if showsSearch {
              HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search this calendar window", text: $searchText)
                  .textFieldStyle(.plain)
                  .accessibilityIdentifier("saved.calendar.search")
                Button("Close search", systemImage: "xmark.circle.fill") {
                  searchText = ""
                  showsSearch = false
                }.labelStyle(.iconOnly)
              }
              .padding(12)
            }
            if !isWide {
              calendarCanvas(isCompact: true)
                .frame(height: showsAgenda ? calendarHeight(in: geometry.size.height) : nil)
              scaleHandle
              if showsAgenda { agenda }
            } else {
              calendarCanvas(isCompact: false)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .overlay(alignment: .bottom) {
        if compactControls {
          floatingControls(
            agendaWidth: isWide && showsAgenda
              ? min(280, geometry.size.width * 0.32) : 0
          ).padding(.horizontal, 16).padding(.vertical, 8)
        }
      }
      .overlay(alignment: .bottomTrailing) {
        if !compactControls {
          addButton.buttonStyle(.plain).glassEffect(in: .circle).padding(16)
        }
      }
      .contentMargins(.bottom, compactControls ? 68 : 0, for: .scrollContent)
      .background(.background)
      .overlay(alignment: .topTrailing) {
        if isLoading { ProgressView().controlSize(.small).padding(12) }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("saved.calendar.canvas")
    .environment(\.calendar, displayCalendar)
    .environment(\.timeZone, displayTimeZone)
    #if os(iOS)
      .toolbar(.hidden, for: .navigationBar)
      .toolbar(.hidden, for: .tabBar)
    #else
      .navigationTitle("Calendar")
      .toolbarTitleDisplayMode(.inline)
    #endif
    .sheet(isPresented: $showsDateSelection) {
      NavigationStack {
        ScrollView {
          DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .padding()
            .accessibilityIdentifier("saved.calendar.selected-date")
        }
        .navigationTitle("Choose date")
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { showsDateSelection = false }
          }
        }
      }
      .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showsScheduleCreation) {
      SavedCalendarScheduleCreation(store: store, date: selectedDate, timeZone: displayTimeZone)
    }
    .sheet(isPresented: $showsTimeZonePreferences) {
      SavedCalendarDisplayZoneSettings(
        overrideTimeZoneIdentifier: $overrideTimeZoneIdentifier, deviceTimeZone: deviceTimeZone)
    }
    .animation(reduceMotion ? nil : .snappy, value: mode)
    .onChange(of: mode) {
      timelineAnchor = selectedDate
      bookingListAnchor = selectedDate
    }
    .onChange(of: selectedDate) {
      if abs(
        displayCalendar.dateComponents([.day], from: bookingListAnchor, to: selectedDate).day ?? 0)
        > 21
      {
        bookingListAnchor = selectedDate
      }
      if let first = periods.first, let last = periods.last,
        let end = displayCalendar.dateInterval(of: mode.component, for: last)?.end,
        selectedDate < first || selectedDate >= end
      {
        timelineAnchor = selectedDate
      }
    }
    .task(id: loadIdentity) { await loadEntries() }
  }

  private var dateHeading: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      Button {
        showsDateSelection = true
      } label: {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
          if mode != .year || !usesCompactControls {
            Text(
              selectedDate,
              format: mode == .day ? .dateTime.month(.wide).day() : .dateTime.month(.wide)
            )
            .foregroundStyle(.primary)
          }
          Text(selectedDate, format: .dateTime.year()).foregroundStyle(.red)
        }
        .font(usesCompactControls ? .title.bold() : .title2.bold())
        .lineLimit(1).minimumScaleFactor(0.7)
      }
      .buttonStyle(.plain)
      .accessibilityValue(
        Text(selectedDate, format: .dateTime.weekday().month().day().hour().minute())
      )
      .accessibilityIdentifier("saved.calendar.heading")
      Spacer(minLength: 4)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 16).padding(.vertical, usesCompactControls ? 8 : 12)
    .background(.background)
  }

  private func calendarHeight(in height: CGFloat) -> CGFloat {
    min(max(160, height * 0.46), mode == .month ? 320 : 420)
  }

  private func changeScale(_ direction: Int) {
    let levels = Mode.allCases
    guard let index = levels.firstIndex(of: mode) else { return }
    mode = levels[min(levels.count - 1, max(0, index + direction))]
  }

  private var scaleHandle: some View {
    Button {
      let index = Mode.allCases.firstIndex(of: mode) ?? 0
      mode = Mode.allCases[(index + 1) % Mode.allCases.count]
    } label: {
      Capsule().fill(.secondary).frame(width: 36, height: 4)
        .frame(maxWidth: .infinity, minHeight: 32).contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Calendar scale")
    .accessibilityValue(mode.rawValue)
    .accessibilityHint("Drag up for closer dates, down for a wider range.")
    .accessibilityAdjustableAction { direction in
      changeScale(direction == .increment ? 1 : -1)
    }
    .accessibilityIdentifier("saved.calendar.navigator.toggle")
    .highPriorityGesture(
      DragGesture(minimumDistance: 12).onEnded { gesture in
        changeScale(gesture.translation.height > 0 ? 1 : -1)
      })
  }

  @ViewBuilder
  private func calendarCanvas(isCompact: Bool) -> some View {
    if entries == nil && !isLoading {
      ContentUnavailableView {
        Label("Calendar unavailable", systemImage: "exclamationmark.triangle")
      } actions: {
        Button("Try again") { Task { await loadEntries() } }
      }
    } else {
      switch mode {
      case .day, .week:
        SavedCalendarTimeGrid(
          periods: periods, isWeek: mode == .week, selectedDate: $selectedDate,
          calendar: displayCalendar, selection: $selection, entriesForDay: entries(on:),
          scheduleDescription: scheduleDescription, onScrollSettled: recenterTimeline
        )
        .id(mode)
      case .month:
        SavedCalendarMonthGrid(
          selectedDate: $selectedDate,
          days: readInterval.map { SavedCalendarDates.days(in: $0, calendar: displayCalendar) }
            ?? [],
          selection: $selection, calendar: displayCalendar, entriesForDay: entries(on:),
          isCompact: isCompact && showsAgenda, onScrollSettled: recenterTimeline)
      case .year:
        SavedCalendarOverview(
          years: periods, selectedDate: $selectedDate, calendar: displayCalendar,
          entriesForDay: entries(on:), onScrollSettled: recenterTimeline,
          openMonth: { mode = .month })
      }
    }
  }

  private var agenda: some View {
    SavedCalendarAgenda(
      selectedDate: $selectedDate, calendar: displayCalendar, days: bookingDays,
      entriesForDay: entries(on:), selection: $selection, scheduleDescription: scheduleDescription,
      isLoading: isLoading, onScrollSettled: recenterTimeline)
  }

  private var modeMenu: some View {
    Menu {
      if let openCollection {
        Menu("Collections", systemImage: "square.grid.2x2") {
          Button("Lists", systemImage: "list.bullet") { openCollection(.lists) }
          Button("Items", systemImage: "square.stack") { openCollection(.items) }
          Button("Inbox", systemImage: "tray") { openCollection(.inbox) }
          Button("Itineraries", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
            openCollection(.itineraries)
          }
        }
      }
      Picker("Calendar view", selection: $mode) {
        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }
      Menu("Options", systemImage: "ellipsis") {
        if let showDetails {
          Button("Show details", systemImage: "sidebar.right", action: showDetails)
        }
        Button("Choose date", systemImage: "calendar") { showsDateSelection = true }
          .accessibilityIdentifier("saved.calendar.choose-date")
        Button("Display time zone", systemImage: "globe") { showsTimeZonePreferences = true }
          .accessibilityIdentifier("saved.calendar.zone.open")
        Button(showsAgenda ? "Hide booking list" : "Show booking list", systemImage: "sidebar.left")
        {
          showsAgenda.toggle()
        }
      }
    } label: {
      Label(mode.rawValue, systemImage: "line.3.horizontal")
        .labelStyle(.iconOnly).frame(width: 44, height: 44)
    }
    .menuOrder(.fixed)
    .accessibilityLabel("Calendar view")
    .accessibilityValue(mode.rawValue)
    .accessibilityIdentifier("saved.calendar.mode")
  }

  private var todayButton: some View {
    Button {
      selectedDate = Date()
    } label: {
      Text("Today").frame(minWidth: 72, minHeight: 44).contentShape(.rect)
    }
    .accessibilityIdentifier("saved.calendar.today")
  }

  private var searchButton: some View {
    Button {
      showsSearch.toggle()
    } label: {
      Image(systemName: "magnifyingglass").frame(width: 44, height: 44).contentShape(.rect)
    }
    .accessibilityLabel("Search")
    .accessibilityIdentifier("saved.calendar.search.open")
  }

  private var addButton: some View {
    Button {
      showsScheduleCreation = true
    } label: {
      Image(systemName: "plus").frame(width: 44, height: 44).contentShape(.rect)
    }
    .accessibilityLabel("Schedule")
    .disabled(!store.canCreate)
    .accessibilityIdentifier("saved.calendar.add")
  }

  private var periodControls: some View {
    HStack(spacing: 0) {
      Button {
        move(-1)
      } label: {
        Image(systemName: "chevron.left").frame(width: 32, height: 44).contentShape(.rect)
      }
      .accessibilityLabel("Previous").accessibilityIdentifier("DatePicker.PreviousMonth")
      todayButton
      Button {
        move(1)
      } label: {
        Image(systemName: "chevron.right").frame(width: 32, height: 44).contentShape(.rect)
      }
      .accessibilityLabel("Next").accessibilityIdentifier("DatePicker.NextMonth")
    }
  }

  private func floatingControls(agendaWidth: CGFloat) -> some View {
    ZStack {
      HStack {
        modeMenu.buttonStyle(.plain).glassEffect(in: .circle)
        Spacer()
        HStack(spacing: 0) {
          searchButton
          addButton
        }
        .buttonStyle(.plain).glassEffect(in: .capsule)
      }
      periodControls.buttonStyle(.plain).glassEffect(in: .capsule)
        .frame(maxWidth: .infinity).padding(.leading, agendaWidth)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("saved.calendar.controls")
  }

  private var wideControls: some View {
    HStack(spacing: 12) {
      modeMenu.accessibilityIdentifier("saved.calendar.navigation")
        .accessibilityLabel("Calendar navigation")
      periodControls
      Spacer(minLength: 0)
      Picker("Calendar view", selection: $mode) {
        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
      .frame(maxWidth: 460)
      .accessibilityValue(mode.rawValue)
      .accessibilityIdentifier("saved.calendar.mode")
      Spacer(minLength: 0)
      searchButton
      if let showDetails {
        Button(action: showDetails) {
          Image(systemName: "sidebar.right").frame(width: 44, height: 44).contentShape(.rect)
        }
        .accessibilityLabel("Show details")
        .accessibilityIdentifier("saved.calendar.details.toggle")
      }
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 12)
  }

  private func move(_ amount: Int) {
    if let date = displayCalendar.date(byAdding: mode.component, value: amount, to: selectedDate) {
      selectedDate = date
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
