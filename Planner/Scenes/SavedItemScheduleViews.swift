import PlannerCore
import SwiftUI

struct SavedItemSchedulesSection: View {
  @Environment(SavedPlannerStore.self) private var store
  let item: PlannerItemSourceRead
  let canChange: Bool
  let editSchedule: (PlannerScheduleSourceRead) -> Void
  @State private var schedules: [PlannerScheduleSourceRead] = []
  @State private var isLoading = true
  @State private var loadingFailure: String?
  @State private var scheduleToRemove: PlannerScheduleSourceRead?
  @State private var removalOperationIdentifier = UUID()

  private var scheduleIdentifiers: [UUID] {
    item.references.compactMap { reference in
      guard case .schedule(let identifier, let source) = reference, source == item.source else {
        return nil
      }
      return identifier
    }
  }

  private var loadRevision: String {
    item.source.id.uuidString + store.changeRevision.uuidString
      + scheduleIdentifiers.map(\.uuidString).joined(separator: ":")
  }

  var body: some View {
    Group {
      if !scheduleIdentifiers.isEmpty {
        Section("Schedule") {
          if isLoading {
            ProgressView("Loading schedules")
          } else if let loadingFailure {
            Text(loadingFailure).foregroundStyle(.secondary)
            Button("Try Again") { Task { await loadSchedules() } }
          } else {
            ForEach(schedules, id: \.source.id) { schedule in
              SavedItemScheduleRow(schedule: schedule)
                .contextMenu {
                  Button("Edit Schedule", systemImage: "pencil") {
                    editSchedule(schedule)
                  }
                  .disabled(!canChange)
                  Button("Remove Schedule", systemImage: "calendar.badge.minus", role: .destructive)
                  {
                    removalOperationIdentifier = UUID()
                    scheduleToRemove = schedule
                  }
                  .disabled(!canChange)
                }
            }
          }
        }
      }
    }
    .task(id: loadRevision) { await loadSchedules() }
    .confirmationDialog(
      "Remove this schedule?",
      isPresented: Binding(
        get: { scheduleToRemove != nil }, set: { if !$0 { scheduleToRemove = nil } }),
      titleVisibility: .visible
    ) {
      if let schedule = scheduleToRemove {
        Button("Remove Schedule", role: .destructive) {
          let operationIdentifier = removalOperationIdentifier
          Task {
            await store.removeSchedule(schedule.source.id, operationIdentifier: operationIdentifier)
          }
        }
        .disabled(!canChange)
        .accessibilityIdentifier("saved.schedule.remove.confirm")
      }
      Button("Cancel", role: .cancel) { scheduleToRemove = nil }
    } message: {
      Text("1 schedule will be removed. The Item and its other schedules stay available.")
    }
  }

  private func loadSchedules() async {
    let revision = loadRevision
    let identifiers = scheduleIdentifiers
    isLoading = true
    defer { if revision == loadRevision { isLoading = false } }
    var loadedSchedules: [PlannerScheduleSourceRead] = []
    var failure: String?
    for identifier in identifiers {
      switch await store.readSchedule(identifier) {
      case .source(.schedule(let schedule))?: loadedSchedules.append(schedule)
      case .failed(let reason)?: failure = reason.message
      default: failure = "Planner could not open this Schedule."
      }
      if failure != nil { break }
    }
    guard !Task.isCancelled, revision == loadRevision else { return }
    schedules = failure == nil ? loadedSchedules : []
    loadingFailure = failure
  }
}

private struct SavedItemScheduleRow: View {
  let schedule: PlannerScheduleSourceRead

  private var title: String {
    switch schedule.content.form {
    case .allDay: return "All day"
    case .timed(_, let end, _): return end == nil ? "Start only" : "Timed"
    }
  }

  private var description: String {
    switch schedule.content.form {
    case .timed(let start, let end, let planningTimeZone):
      let timeZone = TimeZone(identifier: planningTimeZone) ?? .current
      let dateDescription: String
      if let end {
        let dateIntervalFormatter = DateIntervalFormatter()
        dateIntervalFormatter.dateStyle = .medium
        dateIntervalFormatter.timeStyle = .short
        dateIntervalFormatter.timeZone = timeZone
        dateDescription = dateIntervalFormatter.string(from: start, to: end)
      } else {
        var dateFormatStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
        dateFormatStyle.timeZone = timeZone
        dateDescription = start.formatted(dateFormatStyle)
      }
      return dateDescription + " · " + planningTimeZone
    case .allDay(let start, let end):
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      guard
        let startDate = calendar.date(
          from: DateComponents(year: start.year, month: start.month, day: start.day, hour: 12))
      else { return "Date unavailable" }
      let finalDate = end ?? start
      guard
        let endDate = calendar.date(
          from: DateComponents(
            year: finalDate.year, month: finalDate.month, day: finalDate.day, hour: 12))
      else { return "Date unavailable" }
      let dateIntervalFormatter = DateIntervalFormatter()
      dateIntervalFormatter.calendar = calendar
      dateIntervalFormatter.timeZone = .gmt
      dateIntervalFormatter.dateStyle = .medium
      dateIntervalFormatter.timeStyle = .none
      return dateIntervalFormatter.string(from: startDate, to: endDate)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label(title, systemImage: "calendar")
      Text(description).foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue(description)
    .accessibilityIdentifier("saved.item.schedule.\(schedule.source.id.uuidString)")
  }
}

struct SavedItemScheduleForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let item: PlannerItemSourceRead
  let schedule: PlannerScheduleSourceRead?
  private let initialDatesAvailable: Bool
  @State private var startInstant: Date
  @State private var endInstant: Date
  @State private var isAllDay = false
  @State private var includesEnd = false
  @State private var planningTimeZone = TimeZone.current.identifier
  @State private var operationIdentifier = UUID()

  init(
    store: SavedPlannerStore, item: PlannerItemSourceRead,
    schedule: PlannerScheduleSourceRead? = nil
  ) {
    self.store = store
    self.item = item
    self.schedule = schedule
    let initialStart = Calendar.current.dateInterval(of: .minute, for: Date())?.start ?? Date()
    switch schedule?.content.form {
    case .timed(let start, let end, let planningTimeZone):
      _startInstant = State(initialValue: start)
      _endInstant = State(initialValue: end ?? start.addingTimeInterval(3600))
      _includesEnd = State(initialValue: end != nil)
      _planningTimeZone = State(initialValue: planningTimeZone)
      initialDatesAvailable = true
    case .allDay(let start, let end):
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      let startDate = calendar.date(
        from: DateComponents(year: start.year, month: start.month, day: start.day, hour: 12))
      let finalDate = end ?? start
      let endDate = calendar.date(
        from: DateComponents(
          year: finalDate.year, month: finalDate.month, day: finalDate.day, hour: 12))
      _startInstant = State(initialValue: startDate ?? initialStart)
      _endInstant = State(initialValue: endDate ?? initialStart)
      _isAllDay = State(initialValue: true)
      _includesEnd = State(initialValue: end != nil)
      _planningTimeZone = State(initialValue: TimeZone.gmt.identifier)
      initialDatesAvailable = startDate != nil && endDate != nil
    case nil:
      _startInstant = State(initialValue: initialStart)
      _endInstant = State(initialValue: initialStart.addingTimeInterval(3600))
      initialDatesAvailable = true
    }
  }

  private var planningCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: planningTimeZone) ?? .current
    return calendar
  }

  private var isValid: Bool {
    guard initialDatesAvailable else { return false }
    guard includesEnd else { return true }
    guard isAllDay else { return endInstant > startInstant }
    return planningCalendar.startOfDay(for: endInstant)
      >= planningCalendar.startOfDay(for: startInstant)
  }

  private var scheduleForm: PlannerScheduleForm {
    if isAllDay {
      return .allDay(
        start: civilDate(for: startInstant), end: includesEnd ? civilDate(for: endInstant) : nil)
    }
    return .timed(
      start: startInstant, end: includesEnd ? endInstant : nil, planningTimeZone: planningTimeZone)
  }

  private func civilDate(for instant: Date) -> PlannerCivilDate {
    .init(
      year: planningCalendar.component(.year, from: instant),
      month: planningCalendar.component(.month, from: instant),
      day: planningCalendar.component(.day, from: instant))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(item.content.title).font(.headline)
          Toggle("All day", isOn: $isAllDay)
            .accessibilityIdentifier("saved.schedule.allDay")
          DatePicker(
            "Start", selection: $startInstant,
            displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
          )
          .accessibilityIdentifier("saved.schedule.start")
          Toggle(isAllDay ? "Include end date" : "Include end time", isOn: $includesEnd)
            .accessibilityIdentifier("saved.schedule.hasEnd")
          if includesEnd {
            DatePicker(
              "End", selection: $endInstant,
              displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .accessibilityIdentifier("saved.schedule.end")
          }
          if !isAllDay { LabeledContent("Time zone", value: planningTimeZone) }
        } footer: {
          if !initialDatesAvailable {
            Text("This schedule's dates could not be opened.")
          } else if !isValid {
            Text(isAllDay ? "End date cannot precede Start." : "End must be later than Start.")
          } else if isAllDay {
            Text(includesEnd ? "Includes both selected dates." : "Covers the selected day.")
          } else if !includesEnd {
            Text("This schedule has no end time.")
          }
        }
      }
      .formStyle(.grouped)
      .environment(\.calendar, planningCalendar)
      .environment(\.timeZone, TimeZone(identifier: planningTimeZone) ?? .current)
      .onChange(of: isAllDay) { _, allDay in
        if allDay { endInstant = startInstant }
      }
      .disabled(store.isSaving)
      .navigationTitle(schedule == nil ? "Schedule Item" : "Edit Schedule")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.schedule.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              let saved: Bool
              if let schedule {
                saved = await store.editSchedule(
                  schedule, form: scheduleForm, operationIdentifier: operationIdentifier)
              } else {
                saved = await store.createItemSchedule(
                  itemIdentifier: item.source.id, form: scheduleForm,
                  operationIdentifier: operationIdentifier)
              }
              if saved && store.alertMessage == nil { dismiss() }
            }
          }
          .disabled(!store.canCreate || !isValid)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("saved.schedule.save")
        }
      }
      .overlay {
        if store.isSaving { ProgressView("Saving schedule") }
      }
    }
    .interactiveDismissDisabled(store.isSaving)
    .alert(
      "Planner",
      isPresented: Binding(
        get: { store.alertMessage != nil }, set: { if !$0 { store.alertMessage = nil } })
    ) {
      Button("OK") { store.alertMessage = nil }
    } message: {
      Text(store.alertMessage ?? "")
    }
    #if os(macOS)
      .frame(minWidth: 440, minHeight: 300)
    #endif
  }
}
