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
    case agenda = "Agenda"
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"

    var component: Calendar.Component {
      switch self {
      case .agenda, .month, .quarter: .month
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
  @State private var mode: Mode = {
    #if os(iOS)
      UIDevice.current.userInterfaceIdiom == .phone ? .agenda : .month
    #else
      .month
    #endif
  }()
  @State private var showsTimeZonePreferences = false
  @State private var showsDateSelection = false
  @State private var showsScheduleCreation = false
  @State private var showsSearch = false
  @State private var searchText = ""
  @State private var showsAgenda = true
  @State private var navigatorExpanded = true
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

  private var visibleInterval: DateInterval? {
    guard let interval = displayCalendar.dateInterval(of: mode.component, for: selectedDate) else {
      return nil
    }
    if mode == .quarter {
      let month = displayCalendar.component(.month, from: selectedDate)
      guard
        let start = displayCalendar.date(
          byAdding: .month, value: -((month - 1) % 3), to: interval.start),
        let end = displayCalendar.date(byAdding: .month, value: 3, to: start)
      else { return nil }
      return .init(start: start, end: end)
    }
    return interval
  }

  /// Load the navigator and adjacent month cells with the same coherent query as the canvas.
  private var readInterval: DateInterval? {
    guard let visibleInterval,
      let month = displayCalendar.dateInterval(of: .month, for: selectedDate),
      let firstWeek = displayCalendar.dateInterval(
        of: .weekOfYear, for: min(month.start, visibleInterval.start)),
      let lastWeek = displayCalendar.dateInterval(
        of: .weekOfYear, for: max(month.end, visibleInterval.end).addingTimeInterval(-1))
    else { return nil }
    return .init(start: firstWeek.start, end: lastWeek.end)
  }

  private var visibleDays: [Date] {
    guard let visibleInterval else { return [] }
    return SavedCalendarDates.days(in: visibleInterval, calendar: displayCalendar)
  }

  private var loadIdentity: String {
    let components = displayCalendar.dateComponents(
      [.year, .month, .day], from: readInterval?.start ?? selectedDate)
    return store.changeRevision.uuidString + ":" + (store.devicePreferenceNamespace ?? "")
      + ":" + displayTimeZone.identifier + ":" + mode.rawValue
      + ":\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
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
              if geometry.size.height > 400 || mode == .agenda {
                SavedCalendarMiniMonth(
                  month: selectedDate, selectedDate: $selectedDate, calendar: displayCalendar,
                  entriesForDay: entries(on:), showsHeading: false
                )
                .padding(12)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("saved.calendar.date")
              }
              if mode != .agenda { agenda }
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
            calendarCanvas(isWide: isWide)
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

  @ViewBuilder
  private func calendarCanvas(isWide: Bool) -> some View {
    if entries == nil && !isLoading {
      ContentUnavailableView {
        Label("Calendar unavailable", systemImage: "exclamationmark.triangle")
      } actions: {
        Button("Try again") { Task { await loadEntries() } }
      }
    } else {
      switch mode {
      case .agenda:
        VStack(spacing: 0) {
          if !isWide {
            SavedCalendarMiniMonth(
              month: selectedDate, selectedDate: $selectedDate, calendar: displayCalendar,
              entriesForDay: entries(on:), showsHeading: false,
              showsOnlySelectedWeek: !navigatorExpanded
            )
            .padding(.horizontal, 16)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("saved.calendar.date")
            Button {
              navigatorExpanded.toggle()
            } label: {
              Capsule().fill(.secondary).frame(width: 36, height: 4)
                .frame(maxWidth: .infinity, minHeight: 32).contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(navigatorExpanded ? "Show week navigator" : "Show month navigator")
            .accessibilityIdentifier("saved.calendar.navigator.toggle")
            .simultaneousGesture(
              DragGesture(minimumDistance: 12).onEnded { gesture in
                navigatorExpanded = gesture.translation.height > 0
              })
          }
          agenda
        }
        .animation(reduceMotion ? nil : .snappy, value: navigatorExpanded)
      case .day, .week:
        SavedCalendarTimeGrid(
          days: visibleDays, selectedDate: $selectedDate, calendar: displayCalendar,
          selection: $selection, entriesForDay: entries(on:),
          scheduleDescription: scheduleDescription)
      case .month:
        SavedCalendarMonthGrid(
          selectedDate: $selectedDate, visibleDate: selectedDate, selection: $selection,
          calendar: displayCalendar, entriesForDay: entries(on:))
      case .quarter, .year:
        SavedCalendarOverview(
          interval: visibleInterval, selectedDate: $selectedDate, calendar: displayCalendar,
          entriesForDay: entries(on:), openMonth: { mode = .month })
      }
    }
  }

  private var agenda: some View {
    SavedCalendarAgenda(
      selectedDate: $selectedDate, calendar: displayCalendar,
      days: readInterval.map { SavedCalendarDates.days(in: $0, calendar: displayCalendar) } ?? [],
      entriesForDay: entries(on:), selection: $selection, scheduleDescription: scheduleDescription)
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
        Button(showsAgenda ? "Hide agenda" : "Show agenda", systemImage: "sidebar.left") {
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
    let component: Calendar.Component
    if mode == .quarter {
      component = .month
    } else if mode == .agenda && !navigatorExpanded {
      component = .weekOfYear
    } else {
      component = mode.component
    }
    let value = mode == .quarter ? amount * 3 : amount
    if let date = displayCalendar.date(byAdding: component, value: value, to: selectedDate) {
      if (mode == .agenda && navigatorExpanded) || mode == .month,
        let firstDay = displayCalendar.dateInterval(of: .month, for: date)?.start
      {
        selectedDate = SavedCalendarDates.selecting(
          firstDay, preserving: selectedDate, calendar: displayCalendar)
      } else {
        selectedDate = date
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
