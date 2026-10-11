import PlannerCore
import SwiftUI

struct SavedItemSchedulesSection: View {
  @Environment(SavedPlannerStore.self) private var store
  let item: PlannerItemSourceRead
  @State private var schedules: [PlannerScheduleSourceRead] = []
  @State private var isLoading = true
  @State private var loadingFailure: String?

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
            }
          }
        }
      }
    }
    .task(id: loadRevision) { await loadSchedules() }
  }

  private func loadSchedules() async {
    let revision = loadRevision
    let identifiers = scheduleIdentifiers
    isLoading = true
    defer { if revision == loadRevision { isLoading = false } }
    var loadedSchedules: [PlannerScheduleSourceRead] = []
    var failure: String?
    for identifier in identifiers {
      guard let schedule = await store.readSchedule(identifier) else {
        failure = store.alertMessage ?? "Planner could not read this Item's schedules."
        break
      }
      loadedSchedules.append(schedule)
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

struct SavedNewItemScheduleForm: View {
  @Environment(\.dismiss) private var dismiss
  let store: SavedPlannerStore
  let item: PlannerItemSourceRead
  @State private var startInstant =
    Calendar.current.dateInterval(of: .minute, for: Date())?.start ?? Date()
  @State private var planningTimeZone = TimeZone.current.identifier
  @State private var operationIdentifier = UUID()

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(item.content.title).font(.headline)
          DatePicker(
            "Start", selection: $startInstant, displayedComponents: [.date, .hourAndMinute]
          )
          .accessibilityIdentifier("saved.schedule.start")
          LabeledContent("Time zone", value: planningTimeZone)
        } footer: {
          Text("This schedule has no end time.")
        }
      }
      .formStyle(.grouped)
      .environment(\.timeZone, TimeZone(identifier: planningTimeZone) ?? .current)
      .disabled(store.isSaving)
      .navigationTitle("Schedule Item")
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
              let saved = await store.createStartOnlyItemSchedule(
                itemIdentifier: item.source.id, startInstant: startInstant,
                planningTimeZone: planningTimeZone, operationIdentifier: operationIdentifier)
              if saved && store.alertMessage == nil { dismiss() }
            }
          }
          .disabled(!store.canCreate)
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
