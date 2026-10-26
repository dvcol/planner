import PlannerCore
import SwiftUI

/// Formats civil dates independently of the device's time zone.
func allDayScheduleDescription(start: PlannerCivilDate, end: PlannerCivilDate?) -> String {
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

struct SavedSchedulesSection: View {
  @Environment(SavedPlannerStore.self) private var store
  let source: PlannerEntityReference
  let references: [PlannerReferenceRead]
  let canChange: Bool
  let editSchedule: (PlannerScheduleSourceRead) -> Void
  @State private var schedules: [PlannerScheduleSourceRead] = []
  @State private var isLoading = true
  @State private var loadingFailure: String?
  @State private var scheduleToRemove: PlannerScheduleSourceRead?
  @State private var removalOperationIdentifier = UUID()

  private var scheduleIdentifiers: [UUID] {
    references.compactMap { reference in
      guard case .schedule(let identifier, let owner) = reference, owner == source else {
        return nil
      }
      return identifier
    }
  }

  private var loadRevision: String {
    source.id.uuidString + store.changeRevision.uuidString
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
            Button("Try again") { Task { await loadSchedules() } }
          } else {
            ForEach(schedules, id: \.source.id) { schedule in
              let scheduleRow = SavedScheduleRow(schedule: schedule)
              scheduleRow.contextMenu {
                Button("Edit schedule", systemImage: "pencil") {
                  editSchedule(schedule)
                }
                .disabled(!canChange)
                Button("Remove schedule", systemImage: "calendar.badge.minus", role: .destructive) {
                  removalOperationIdentifier = UUID()
                  scheduleToRemove = schedule
                }
                .disabled(!canChange)
              }
              .accessibilityValue(scheduleRow.description)
              .accessibilityAddTraits(.isStaticText)
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
        Button("Remove schedule", role: .destructive) {
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
      Text(
        "1 schedule will be removed. The \(source.kind.rawValue.capitalized) and its other schedules stay available."
      )
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

private struct SavedScheduleRow: View {
  let schedule: PlannerScheduleSourceRead

  private var title: String {
    switch schedule.content.form {
    case .allDay: return "All day"
    case .timed(_, let end, _): return end == nil ? "Start only" : "Timed"
    }
  }

  fileprivate var description: String {
    switch schedule.content.form {
    case .timed(let start, let end, let planningTimeZone):
      let timeZone = TimeZone(identifier: planningTimeZone) ?? .current
      var planningCalendar = Calendar(identifier: .gregorian)
      planningCalendar.timeZone = timeZone
      let dateDescription: String
      if let end {
        let dateIntervalFormatter = DateIntervalFormatter()
        dateIntervalFormatter.dateStyle = .medium
        dateIntervalFormatter.timeStyle = .short
        dateIntervalFormatter.timeZone = timeZone
        dateDescription =
          calendarClockChangeSpanDescription(
            start: start, end: end, calendar: planningCalendar, includesDate: true)
          ?? dateIntervalFormatter.string(from: start, to: end)
      } else {
        var dateFormatStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
        if calendarDayHasClockChange(start, calendar: planningCalendar) {
          dateFormatStyle = dateFormatStyle.timeZone(.specificName(.short))
        }
        dateFormatStyle.timeZone = timeZone
        dateDescription = start.formatted(dateFormatStyle)
      }
      return dateDescription + " · " + planningTimeZone
    case .allDay(let start, let end):
      return allDayScheduleDescription(start: start, end: end)
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
    .accessibilityIdentifier(
      "saved.\(schedule.content.source.kind.rawValue).schedule.\(schedule.source.id.uuidString)")
  }
}

struct SavedScheduleForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let source: PlannerEntityReference
  let sourceTitle: String
  let schedule: PlannerScheduleSourceRead?
  private let initialDatesAvailable: Bool
  @State private var startCivilDate: Date
  @State private var endCivilDate: Date
  @State private var startTimeInput: SavedScheduleTimeInput
  @State private var endTimeInput: SavedScheduleTimeInput
  @State private var isAllDay = false
  @State private var includesEnd = false
  @State private var planningTimeZone = TimeZone.current.identifier
  @State private var operationIdentifier = UUID()

  init(
    store: SavedPlannerStore, source: PlannerEntityReference, sourceTitle: String,
    schedule: PlannerScheduleSourceRead? = nil
  ) {
    self.store = store
    self.source = source
    self.sourceTitle = sourceTitle
    self.schedule = schedule
    let initialStart = Calendar.current.dateInterval(of: .minute, for: Date())?.start ?? Date()
    switch schedule?.content.form {
    case .timed(let start, let end, let planningTimeZone):
      let timeZone = TimeZone(identifier: planningTimeZone) ?? .current
      let startInput = SavedScheduleTimeInput(savedInstant: start, planningTimeZone: timeZone)
      let endInput: SavedScheduleTimeInput
      if let end {
        endInput = SavedScheduleTimeInput(savedInstant: end, planningTimeZone: timeZone)
      } else {
        endInput = SavedScheduleTimeInput(
          proposedInstant: start.addingTimeInterval(3600), planningTimeZone: timeZone)
      }
      _startTimeInput = State(initialValue: startInput)
      _endTimeInput = State(initialValue: endInput)
      _startCivilDate = State(initialValue: startInput.pickerValue)
      _endCivilDate = State(initialValue: endInput.pickerValue)
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
      _startCivilDate = State(initialValue: startDate ?? initialStart)
      _endCivilDate = State(initialValue: endDate ?? initialStart)
      _startTimeInput = State(
        initialValue: SavedScheduleTimeInput(
          proposedInstant: startDate ?? initialStart, planningTimeZone: .gmt))
      _endTimeInput = State(
        initialValue: SavedScheduleTimeInput(
          proposedInstant: endDate ?? initialStart, planningTimeZone: .gmt))
      _isAllDay = State(initialValue: true)
      _includesEnd = State(initialValue: end != nil)
      _planningTimeZone = State(initialValue: TimeZone.gmt.identifier)
      initialDatesAvailable = startDate != nil && endDate != nil
    case nil:
      let startInput = SavedScheduleTimeInput(
        proposedInstant: initialStart, planningTimeZone: .current)
      let endInput = SavedScheduleTimeInput(
        proposedInstant: initialStart.addingTimeInterval(3600), planningTimeZone: .current)
      _startTimeInput = State(initialValue: startInput)
      _endTimeInput = State(initialValue: endInput)
      _startCivilDate = State(initialValue: startInput.pickerValue)
      _endCivilDate = State(initialValue: endInput.pickerValue)
      initialDatesAvailable = true
    }
  }

  private var pickerCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }

  private var isValid: Bool { scheduleForm != nil }

  private var scheduleForm: PlannerScheduleForm? {
    guard initialDatesAvailable else { return nil }
    if isAllDay {
      guard
        !includesEnd
          || pickerCalendar.startOfDay(for: endCivilDate)
            >= pickerCalendar.startOfDay(for: startCivilDate)
      else { return nil }
      return .allDay(
        start: civilDate(for: startCivilDate), end: includesEnd ? civilDate(for: endCivilDate) : nil
      )
    }
    guard let start = startTimeInput.resolvedInstant else { return nil }
    guard includesEnd else {
      return .timed(start: start, end: nil, planningTimeZone: planningTimeZone)
    }
    guard let end = endTimeInput.resolvedInstant, end > start else { return nil }
    return .timed(start: start, end: end, planningTimeZone: planningTimeZone)
  }

  private func civilDate(for value: Date) -> PlannerCivilDate {
    .init(
      year: pickerCalendar.component(.year, from: value),
      month: pickerCalendar.component(.month, from: value),
      day: pickerCalendar.component(.day, from: value))
  }

  private func civilMinute(date: Date, clock: Date) -> Date? {
    var components = pickerCalendar.dateComponents([.era, .year, .month, .day], from: date)
    components.hour = pickerCalendar.component(.hour, from: clock)
    components.minute = pickerCalendar.component(.minute, from: clock)
    return pickerCalendar.date(from: components)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(sourceTitle).font(.headline)
          Toggle("All day", isOn: $isAllDay)
            .accessibilityIdentifier("saved.schedule.allDay")
          if isAllDay {
            DatePicker("Start", selection: $startCivilDate, displayedComponents: [.date])
              .accessibilityIdentifier("saved.schedule.start")
          } else {
            SavedScheduleClockPicker(
              title: "Start", input: $startTimeInput, planningTimeZone: planningTimeZone,
              identifier: "saved.schedule.start")
          }
          Toggle(isAllDay ? "Include end date" : "Include end time", isOn: $includesEnd)
            .accessibilityIdentifier("saved.schedule.hasEnd")
          if includesEnd {
            if isAllDay {
              DatePicker("End", selection: $endCivilDate, displayedComponents: [.date])
                .accessibilityIdentifier("saved.schedule.end")
            } else {
              SavedScheduleClockPicker(
                title: "End", input: $endTimeInput, planningTimeZone: planningTimeZone,
                identifier: "saved.schedule.end")
            }
          }
          if !isAllDay {
            NavigationLink {
              SavedPlanningTimeZonePicker(selectedTimeZoneIdentifier: $planningTimeZone)
            } label: {
              LabeledContent("Time zone", value: planningTimeZoneLocationName(planningTimeZone))
            }
            .accessibilityIdentifier("saved.schedule.zone")
          }
        } footer: {
          VStack(alignment: .leading, spacing: 4) {
            if !initialDatesAvailable {
              Text("This schedule's dates could not be opened.")
            } else if isAllDay && !isValid {
              Text("End date cannot precede Start.")
            } else if !isAllDay, includesEnd,
              let start = startTimeInput.resolvedInstant, let end = endTimeInput.resolvedInstant,
              end <= start
            {
              Text("End must be later than Start.")
            } else if isAllDay {
              Text(includesEnd ? "Includes both selected dates." : "Covers the selected day.")
            } else if !includesEnd {
              Text("This schedule has no end time.")
            }
            if !isAllDay {
              Text("Times use the selected planning time zone.")
              Text("Changing the time zone keeps the appointment at the same moment.")
            }
          }
        }
      }
      .formStyle(.grouped)
      .environment(\.calendar, pickerCalendar)
      .environment(\.timeZone, .gmt)
      .onChange(of: planningTimeZone) { _, identifier in
        guard let timeZone = TimeZone(identifier: identifier) else { return }
        startTimeInput.changePlanningTimeZone(timeZone)
        endTimeInput.changePlanningTimeZone(timeZone)
      }
      .onChange(of: isAllDay) { _, allDay in
        if allDay {
          startCivilDate = startTimeInput.pickerValue
          endCivilDate = startCivilDate
        } else {
          if let value = civilMinute(date: startCivilDate, clock: startTimeInput.pickerValue) {
            startTimeInput.setPickerValue(value)
          }
          if let value = civilMinute(date: endCivilDate, clock: endTimeInput.pickerValue) {
            endTimeInput.setPickerValue(value)
          }
        }
      }
      .disabled(store.isSaving)
      .navigationTitle(
        schedule == nil ? "Schedule \(source.kind.rawValue.capitalized)" : "Edit schedule"
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(store.isSaving)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("saved.schedule.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            guard let scheduleForm else { return }
            Task {
              let saved: Bool
              if let schedule {
                saved = await store.editSchedule(
                  schedule, form: scheduleForm, operationIdentifier: operationIdentifier)
              } else {
                saved = await store.createSchedule(
                  source: source, form: scheduleForm,
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

private struct SavedScheduleClockPicker: View {
  let title: String
  @Binding var input: SavedScheduleTimeInput
  let planningTimeZone: String
  let identifier: String

  var body: some View {
    DatePicker(
      title,
      selection: Binding(get: { input.pickerValue }, set: { input.setPickerValue($0) }),
      displayedComponents: [.date, .hourAndMinute]
    )
    .accessibilityIdentifier(identifier)
    switch input.resolution {
    case .unavailable:
      Text("\(title) could not be resolved. Choose another date and time.")
        .foregroundStyle(.red)
    case .nonexistent:
      Text("\(title) does not exist in this time zone. Choose another time.")
        .foregroundStyle(.red)
    case .repeated(let candidates):
      Picker(
        "\(title) occurrence",
        selection: Binding<Date?>(
          get: { input.selectedOccurrence },
          set: { if let candidate = $0 { _ = input.selectOccurrence(candidate) } })
      ) {
        Text("Choose occurrence").tag(Optional<Date>.none)
        ForEach(candidates, id: \.self) { candidate in
          Text(occurrenceLabel(candidate)).tag(Optional(candidate))
        }
      }
      .accessibilityIdentifier(identifier + ".occurrence")
      if input.resolvedInstant == nil {
        Text("\(title) occurs more than once. Choose its time-zone offset.")
          .foregroundStyle(.secondary)
      }
    case .unique:
      EmptyView()
    }
  }

  private func occurrenceLabel(_ candidate: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(identifier: planningTimeZone)
    formatter.dateFormat = "zzz '· UTC'xxx"
    return formatter.string(from: candidate)
  }
}
