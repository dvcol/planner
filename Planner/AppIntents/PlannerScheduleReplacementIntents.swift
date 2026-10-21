#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct SetPlannerScheduleTimedFormIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Schedule to timed"
    static let description = IntentDescription(
      "Replace the whole booking with local clock fields in the planning timezone. Keep its identity and owner. Omitting End clears it. Repeated times need an explicit occurrence."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Schedule", query: PlannerScheduleEntityQuery())
    var schedule: PlannerScheduleEntity
    @Parameter(title: "Start", kind: .dateTime) var start: DateComponents
    @Parameter(title: "Planning timezone", query: PlannerTimeZoneEntityQuery())
    var planningTimeZone: PlannerTimeZoneEntity
    @Parameter(title: "End", kind: .dateTime) var end: DateComponents?
    @Parameter(title: "Start occurrence") var startOccurrence: PlannerScheduleOccurrence?
    @Parameter(title: "End occurrence") var endOccurrence: PlannerScheduleOccurrence?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<
      PlannerScheduleEntity, Never, Never, IntentDialog
    >

    @MainActor func perform() async throws -> PerformResult {
      let form = try plannerTimedScheduleForm(
        start: start, end: end, planningTimeZone: planningTimeZone.id,
        startOccurrence: startOccurrence, endOccurrence: endOccurrence)
      let replacement = try await replacePlannerSchedule(
        scheduleIdentifier: schedule.id, form: form, store: plannerStore)
      return .result(value: replacement.entity, dialog: replacement.dialog)
    }
  }

  struct SetPlannerScheduleAllDayFormIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Schedule to all day"
    static let description = IntentDescription(
      "Replace the whole booking with inclusive civil dates, keeping its identity and owner. Omitting End clears it and means one day."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Schedule", query: PlannerScheduleEntityQuery())
    var schedule: PlannerScheduleEntity
    @Parameter(title: "Start day", kind: .date) var startDay: DateComponents
    @Parameter(title: "Inclusive end day", kind: .date) var endDay: DateComponents?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<
      PlannerScheduleEntity, Never, Never, IntentDialog
    >

    @MainActor func perform() async throws -> PerformResult {
      let form = PlannerScheduleForm.allDay(
        start: try plannerScheduleCivilDate(startDay), end: try endDay.map(plannerScheduleCivilDate)
      )
      let replacement = try await replacePlannerSchedule(
        scheduleIdentifier: schedule.id, form: form, store: plannerStore)
      return .result(value: replacement.entity, dialog: replacement.dialog)
    }
  }

  @MainActor
  private func replacePlannerSchedule(
    scheduleIdentifier: UUID, form: PlannerScheduleForm, store: SavedPlannerStore
  ) async throws -> (entity: PlannerScheduleEntity, dialog: IntentDialog) {
    let (planner, session) = try await store.appIntentContext()
    let schedule: PlannerScheduleSourceRead
    switch await planner.read(
      session: session, request: .source(.init(kind: .schedule, id: scheduleIdentifier)))
    {
    case .source(.schedule(let source)): schedule = source
    case .failed(let reason): throw PlannerScheduleReplacementFailure(message: reason.message)
    default: throw PlannerScheduleReplacementFailure(message: "Choose an existing Schedule.")
    }
    let owner = schedule.content.source
    let title: String
    switch await planner.read(session: session, request: .source(owner)) {
    case .source(.item(let source)) where owner.kind == .item: title = source.content.title
    case .source(.itinerary(let source)) where owner.kind == .itinerary:
      title = source.content.title
    case .failed(let reason): throw PlannerScheduleReplacementFailure(message: reason.message)
    default:
      throw PlannerScheduleReplacementFailure(
        message: "Planner could not read this Schedule's owner.")
    }
    try Task.checkCancellation()
    let result = try await store.executeAppIntent(
      .editSchedule(
        scheduleId: schedule.source.id, changes: .init(form: form),
        expectedFieldHashes: schedule.fieldHashes))
    switch result.outcome {
    case .rejected(let reason): throw PlannerScheduleReplacementFailure(message: reason.message)
    case .unverified:
      throw PlannerScheduleReplacementFailure(
        message:
          "Planner could not verify this replacement. Open Planner to review recovery before making another change."
      )
    case .applied(_, let recovery):
      let entity = try PlannerScheduleEntity(
        schedule: schedule.source, owner: owner, title: title, form: form)
      let dialog: IntentDialog
      switch recovery {
      case .complete: dialog = "Updated the booking. Its identity and owner are preserved."
      case .incomplete:
        dialog =
          "The booking changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
      }
      return (entity, dialog)
    }
  }

  private struct PlannerScheduleReplacementFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
