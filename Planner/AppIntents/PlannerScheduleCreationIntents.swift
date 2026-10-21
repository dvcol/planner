#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  enum PlannerScheduleOccurrence: String, AppEnum {
    case earlier, later
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
      name: "Repeated time occurrence")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .earlier: "Earlier", .later: "Later",
    ]
  }

  struct CreatePlannerTimedItemScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Schedule Item at a time"
    static let description = IntentDescription(
      "Create a timed booking using local clock fields in the planning timezone. Repeated clock times need an explicit occurrence. An omitted end stays absent."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
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
      let created = try await createPlannerSchedule(
        owner: .init(kind: .item, id: item.id), form: form, store: plannerStore)
      return .result(value: created.entity, dialog: created.dialog)
    }
  }

  struct CreatePlannerTimedItineraryScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Schedule Itinerary at a time"
    static let description = IntentDescription(
      "Create a timed booking using local clock fields in the planning timezone. Repeated clock times need an explicit occurrence. An omitted end stays absent."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
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
      let created = try await createPlannerSchedule(
        owner: .init(kind: .itinerary, id: itinerary.id), form: form, store: plannerStore)
      return .result(value: created.entity, dialog: created.dialog)
    }
  }

  struct CreatePlannerAllDayItemScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Schedule Item all day"
    static let description = IntentDescription(
      "Create a booking on inclusive civil dates. An omitted end means one day; dates stay unchanged across travel."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Parameter(title: "Start day", kind: .date) var startDay: DateComponents
    @Parameter(title: "Inclusive end day", kind: .date) var endDay: DateComponents?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<
      PlannerScheduleEntity, Never, Never, IntentDialog
    >

    @MainActor func perform() async throws -> PerformResult {
      let form = PlannerScheduleForm.allDay(
        start: try plannerScheduleCivilDate(startDay),
        end: try endDay.map(plannerScheduleCivilDate))
      let created = try await createPlannerSchedule(
        owner: .init(kind: .item, id: item.id), form: form, store: plannerStore)
      return .result(value: created.entity, dialog: created.dialog)
    }
  }

  struct CreatePlannerAllDayItineraryScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Schedule Itinerary all day"
    static let description = IntentDescription(
      "Create a booking on inclusive civil dates. An omitted end means one day; dates stay unchanged across travel."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Parameter(title: "Start day", kind: .date) var startDay: DateComponents
    @Parameter(title: "Inclusive end day", kind: .date) var endDay: DateComponents?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<
      PlannerScheduleEntity, Never, Never, IntentDialog
    >

    @MainActor func perform() async throws -> PerformResult {
      let form = PlannerScheduleForm.allDay(
        start: try plannerScheduleCivilDate(startDay),
        end: try endDay.map(plannerScheduleCivilDate))
      let created = try await createPlannerSchedule(
        owner: .init(kind: .itinerary, id: itinerary.id), form: form, store: plannerStore)
      return .result(value: created.entity, dialog: created.dialog)
    }
  }

  func plannerTimedScheduleForm(
    start: DateComponents, end: DateComponents?, planningTimeZone: String,
    startOccurrence: PlannerScheduleOccurrence?, endOccurrence: PlannerScheduleOccurrence?
  ) throws -> PlannerScheduleForm {
    guard let timeZone = TimeZone(identifier: planningTimeZone) else {
      throw PlannerScheduleCreationFailure(message: "Choose a valid planning timezone.")
    }
    let startInstant = try plannerScheduleCivilInstant(
      start, timeZone: timeZone, occurrence: startOccurrence)
    let endInstant = try end.map {
      try plannerScheduleCivilInstant($0, timeZone: timeZone, occurrence: endOccurrence)
    }
    if let endInstant, endInstant <= startInstant {
      throw PlannerScheduleCreationFailure(
        message: "The supplied end must be later than the start as an instant.")
    }
    return .timed(start: startInstant, end: endInstant, planningTimeZone: planningTimeZone)
  }

  private func plannerScheduleCivilInstant(
    _ components: DateComponents, timeZone: TimeZone, occurrence: PlannerScheduleOccurrence?
  ) throws -> Date {
    let day = try plannerScheduleCivilDate(components)
    guard day.year > 0, (1...12).contains(day.month), (1...31).contains(day.day),
      let hour = components.hour, let minute = components.minute,
      (0...23).contains(hour), (0...59).contains(minute),
      components.second == nil || components.second == 0,
      components.nanosecond == nil || components.nanosecond == 0
    else {
      throw PlannerScheduleCreationFailure(
        message: "Choose a complete, valid date and time with whole-minute precision.")
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let civilFields = DateComponents(
      era: 1, year: day.year, month: day.month, day: day.day, hour: hour, minute: minute, second: 0)
    guard let civilMinute = calendar.date(from: civilFields),
      civilMinute.timeIntervalSinceReferenceDate.isFinite,
      calendar.date(civilMinute, matchesComponents: civilFields)
    else {
      throw PlannerScheduleCreationFailure(message: "Choose an exact Gregorian date and time.")
    }
    var suppliedFields = components
    suppliedFields.calendar = nil
    suppliedFields.timeZone = nil
    guard calendar.date(civilMinute, matchesComponents: suppliedFields) else {
      throw PlannerScheduleCreationFailure(
        message: "The supplied Gregorian date and time fields disagree.")
    }
    var input = SavedScheduleTimeInput(proposedInstant: civilMinute, planningTimeZone: timeZone)
    input.setPickerValue(civilMinute)
    switch input.resolution {
    case .unique(let instant): return instant
    case .repeated(let candidates):
      guard let occurrence else {
        throw PlannerScheduleCreationFailure(
          message: "This local time occurs twice. Choose Earlier or Later for this endpoint.")
      }
      let selected = occurrence == .earlier ? candidates.first : candidates.last
      guard let selected, input.selectOccurrence(selected), let instant = input.resolvedInstant
      else {
        throw PlannerScheduleCreationFailure(
          message: "Planner could not resolve this repeated local time.")
      }
      return instant
    case .nonexistent:
      throw PlannerScheduleCreationFailure(
        message: "This local time does not exist in the planning timezone. Choose another time.")
    case .unavailable:
      throw PlannerScheduleCreationFailure(
        message: "Planner could not resolve this local time in the planning timezone.")
    }
  }

  @MainActor
  private func createPlannerSchedule(
    owner: PlannerEntityReference, form: PlannerScheduleForm, store: SavedPlannerStore
  ) async throws -> (entity: PlannerScheduleEntity, dialog: IntentDialog) {
    let (planner, session) = try await store.appIntentContext()
    let title: String
    switch await planner.read(session: session, request: .source(owner)) {
    case .source(.item(let source)) where owner.kind == .item: title = source.content.title
    case .source(.itinerary(let source)) where owner.kind == .itinerary:
      title = source.content.title
    case .failed(let reason): throw PlannerScheduleCreationFailure(message: reason.message)
    default: throw PlannerScheduleCreationFailure(message: "Choose an existing Item or Itinerary.")
    }
    try Task.checkCancellation()
    let result = try await store.executeAppIntent(.createSchedule(source: owner, form: form))
    switch result.outcome {
    case .rejected(let reason): throw PlannerScheduleCreationFailure(message: reason.message)
    case .unverified:
      throw PlannerScheduleCreationFailure(
        message:
          "Planner could not verify this booking. Open Planner to review recovery before making another change."
      )
    case .applied(let applied, let recovery):
      guard let reference = applied.generated.first, reference.kind == .schedule else {
        throw PlannerScheduleCreationFailure(
          message:
            "The booking was saved on this device, but Planner could not return its identity. Open Planner before retrying."
        )
      }
      let entity = try PlannerScheduleEntity(
        schedule: reference, owner: owner, title: title, form: form)
      let dialog: IntentDialog
      switch recovery {
      case .complete: dialog = "Saved the booking. Its Item or Itinerary is unchanged."
      case .incomplete:
        dialog =
          "The booking was saved on this device, but its recovery copy is incomplete. Open Planner before making more changes."
      }
      return (entity, dialog)
    }
  }

  private struct PlannerScheduleCreationFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
