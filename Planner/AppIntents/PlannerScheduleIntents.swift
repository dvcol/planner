#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation
  import PlannerCore

  struct PlannerScheduleEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Schedule")
    static var defaultQuery: PlannerScheduleEntityQuery { PlannerScheduleEntityQuery() }
    let id: UUID
    @Property(title: "Title") var title: String
    @Property(title: "Source type") var sourceType: String
    @Property(title: "All day") var allDay: Bool
    @Property(title: "Start time") var start: Date?
    @Property(title: "End time") var end: Date?
    @Property(title: "Start day") var startDay: DateComponents?
    @Property(title: "End day") var endDay: DateComponents?
    @Property(title: "Planning timezone") var planningTimeZone: PlannerTimeZoneEntity?
    @Property(title: "When") var when: String
    var displayRepresentation: DisplayRepresentation {
      DisplayRepresentation(title: "\(title)", subtitle: "\(sourceType) · \(when)")
    }

    init(
      schedule: PlannerEntityReference, owner: PlannerEntityReference, title: String,
      form: PlannerScheduleForm
    ) throws {
      guard schedule.kind == .schedule else {
        throw PlannerScheduleIntentFailure(message: "Planner could not identify this Schedule.")
      }
      self.id = schedule.id
      self.title = title
      switch owner.kind {
      case .item: self.sourceType = "Item"
      case .itinerary: self.sourceType = "Itinerary"
      default:
        throw PlannerScheduleIntentFailure(
          message: "Planner could not identify this Schedule's owner.")
      }
      switch form {
      case .timed(let start, let end, let identifier):
        guard let zone = PlannerTimeZoneEntity(identifier: identifier),
          let timeZone = TimeZone(identifier: identifier)
        else {
          throw PlannerScheduleIntentFailure(
            message: "Planner could not read this Schedule's planning timezone.")
        }
        self.allDay = false
        self.start = start
        self.end = end
        self.startDay = nil
        self.endDay = nil
        self.planningTimeZone = zone
        var style = Date.FormatStyle.dateTime.year().month(.abbreviated).day().hour().minute()
          .timeZone(.specificName(.short))
        style.calendar = Calendar(identifier: .gregorian)
        style.timeZone = timeZone
        var description = style.format(start)
        if let end { description += " – " + style.format(end) }
        self.when = description + " · " + identifier
      case .allDay(let start, let end):
        self.allDay = true
        self.start = nil
        self.end = nil
        self.startDay = DateComponents(year: start.year, month: start.month, day: start.day)
        self.endDay = end.map { DateComponents(year: $0.year, month: $0.month, day: $0.day) }
        self.planningTimeZone = nil
        var description = try plannerScheduleDayDescription(start)
        if let end, end != start { description += " – " + (try plannerScheduleDayDescription(end)) }
        self.when = description
      }
    }
  }

  struct PlannerScheduleEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Dependency var plannerStore: SavedPlannerStore

    @MainActor func entities(for identifiers: [UUID]) async throws -> [PlannerScheduleEntity] {
      let entities = try await loadPlannerScheduleEntities(
        store: plannerStore, selection: .identifiers(Set(identifiers)))
      var resolved: [UUID: PlannerScheduleEntity] = [:]
      for entity in entities { resolved[entity.id] = entity }
      var seenIdentifiers: Set<UUID> = []
      return identifiers.filter { seenIdentifiers.insert($0).inserted }.compactMap { resolved[$0] }
    }

    @MainActor func suggestedEntities() async throws -> [PlannerScheduleEntity] {
      try await loadPlannerScheduleEntities(store: plannerStore, selection: .all)
    }

    @MainActor func entities(matching string: String) async throws -> [PlannerScheduleEntity] {
      let entities = try await loadPlannerScheduleEntities(store: plannerStore, selection: .all)
      return entities.filter { string.isEmpty || $0.title.localizedStandardContains(string) }
    }
  }

  struct SetPlannerScheduleTimeZoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Timed Schedule Timezone"
    static let description = IntentDescription(
      "Change the planning timezone while preserving the saved start and optional end instants.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Schedule", query: PlannerScheduleEntityQuery())
    var schedule: PlannerScheduleEntity
    @Parameter(title: "Planning timezone", query: PlannerTimeZoneEntityQuery())
    var planningTimeZone: PlannerTimeZoneEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let (planner, session) = try await plannerStore.appIntentContext()
      try Task.checkCancellation()
      let source: PlannerScheduleSourceRead
      switch await planner.read(
        session: session, request: .source(.init(kind: .schedule, id: schedule.id)))
      {
      case .source(.schedule(let current)): source = current
      case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
      default: throw PlannerScheduleIntentFailure(message: "Planner could not read this Schedule.")
      }
      guard case .timed = source.content.form else {
        throw PlannerScheduleIntentFailure(
          message: "Choose a timed Schedule to change its timezone.")
      }
      let result = try await plannerStore.executeAppIntent(
        .changeScheduleZone(
          scheduleId: source.source.id, planningTimeZone: planningTimeZone.id,
          expectedFieldHashes: source.fieldHashes))
      switch result.outcome {
      case .rejected(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerScheduleIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "Updated the planning timezone. The saved instants are preserved."
        case .incomplete:
          dialog =
            "The planning timezone changed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  struct RemovePlannerScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Planner Schedule"
    static let description = IntentDescription(
      "Remove this saved booking. Keep its Item or Itinerary and all other bookings.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Schedule", query: PlannerScheduleEntityQuery())
    var schedule: PlannerScheduleEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<Never, Never, Never, IntentDialog>

    @MainActor func perform() async throws -> PerformResult {
      let result = try await plannerStore.executeAppIntent(.removeSchedule(scheduleId: schedule.id))
      switch result.outcome {
      case .rejected(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
      case .unverified:
        throw PlannerScheduleIntentFailure(
          message:
            "Planner could not verify this change. Open Planner to review recovery before making another change."
        )
      case .applied(_, let recovery):
        let dialog: IntentDialog
        switch recovery {
        case .complete: dialog = "Removed the Schedule. Its Item or Itinerary is preserved."
        case .incomplete:
          dialog =
            "The Schedule was removed on this device, but its recovery copy is incomplete. Open Planner before making more changes."
        }
        return .result(dialog: dialog)
      }
    }
  }

  struct GetPlannerItemSchedulesIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Item Direct Schedules"
    static let description = IntentDescription(
      "Read this Item's own Schedule records. Dates inherited from an Itinerary remain on that Itinerary's Schedules."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Item") var item: PlannerItemEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerScheduleEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let entities = try await loadPlannerScheduleEntities(
        store: plannerStore, selection: .owner(.init(kind: .item, id: item.id)))
      return .result(value: entities)
    }
  }

  struct GetPlannerItinerarySchedulesIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Itinerary Schedules"
    static let description = IntentDescription(
      "Read this Itinerary's own Schedule records, without including its children's direct bookings."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Itinerary") var itinerary: PlannerItineraryEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerScheduleEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let entities = try await loadPlannerScheduleEntities(
        store: plannerStore, selection: .owner(.init(kind: .itinerary, id: itinerary.id)))
      return .result(value: entities)
    }
  }

  struct GetPlannerScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Planner Schedule"
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Schedule", query: PlannerScheduleEntityQuery())
    var schedule: PlannerScheduleEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerScheduleEntity, Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let query = PlannerScheduleEntityQuery()
      query.plannerStore = plannerStore
      let entities = try await query.entities(for: [schedule.id])
      guard let current = entities.first else {
        throw PlannerScheduleIntentFailure(
          message: "This Schedule is no longer available in Planner's current data.")
      }
      return .result(value: current)
    }
  }

  struct GetPlannerScheduleItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Schedule Item"
    static let description = IntentDescription(
      "Read this Schedule's current Item owner. An Itinerary Schedule has no Item owner.")
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Schedule", query: PlannerScheduleEntityQuery())
    var schedule: PlannerScheduleEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerItemEntity?, Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let owner = try await loadPlannerScheduleOwner(store: plannerStore, identifier: schedule.id)
      guard case .item(let source) = owner else {
        return .result(value: Optional<PlannerItemEntity>.none)
      }
      return .result(value: try PlannerItemEntity(source: source))
    }
  }

  struct GetPlannerScheduleItineraryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Schedule Itinerary"
    static let description = IntentDescription(
      "Read this Schedule's current Itinerary owner. A direct Item Schedule has no Itinerary owner."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Schedule", query: PlannerScheduleEntityQuery())
    var schedule: PlannerScheduleEntity
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<PlannerItineraryEntity?, Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let owner = try await loadPlannerScheduleOwner(store: plannerStore, identifier: schedule.id)
      guard case .itinerary(let source) = owner else {
        return .result(value: Optional<PlannerItineraryEntity>.none)
      }
      guard let archived = source.state.archived else {
        throw PlannerScheduleIntentFailure(
          message: "Planner could not read this Itinerary's state.")
      }
      return .result(
        value: PlannerItineraryEntity(
          id: source.source.id, title: source.content.title, archived: archived))
    }
  }

  struct FindPlannerSchedulesIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Planner Schedules"
    static let description = IntentDescription(
      "Read saved Schedules overlapping these inclusive dates. The display timezone groups timed entries; it never changes their saved instants or all-day dates."
    )
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "From", kind: .date) var startDay: DateComponents
    @Parameter(title: "Through", kind: .date) var endDay: DateComponents
    @Parameter(title: "Display timezone", query: PlannerTimeZoneEntityQuery())
    var displayTimeZone: PlannerTimeZoneEntity?
    @Dependency private var plannerStore: SavedPlannerStore
    typealias PerformResult = IntentResultContainer<[PlannerScheduleEntity], Never, Never, Never>

    @MainActor func perform() async throws -> PerformResult {
      let (planner, session) = try await plannerStore.appIntentContext()
      try Task.checkCancellation()
      let query = PlannerCalendarQuery(
        startDay: try plannerScheduleCivilDate(startDay),
        endDay: try plannerScheduleCivilDate(endDay),
        displayTimeZone: displayTimeZone?.id ?? TimeZone.current.identifier)
      let snapshot: PlannerQuerySnapshot
      switch await planner.query(.init(session: session, request: .calendar(query))) {
      case .snapshot(let current): snapshot = current
      case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
      }
      var entities: [PlannerScheduleEntity] = []
      var offset: Int64 = 0
      while offset < snapshot.matchingCount {
        try Task.checkCancellation()
        switch await planner.read(
          session: session,
          request: .calendarRows(generation: snapshot.generation, offset: offset, limit: 64))
        {
        case .calendarRows(let window):
          guard !window.rows.isEmpty else {
            throw PlannerScheduleIntentFailure(
              message: "Planner could not read all matching Schedules.")
          }
          for entry in window.rows {
            entities.append(
              try .init(
                schedule: entry.schedule, owner: entry.source, title: entry.title, form: entry.form)
            )
          }
          offset += Int64(window.rows.count)
        case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
        default: throw PlannerScheduleIntentFailure(message: "Planner could not read its Calendar.")
        }
      }
      try Task.checkCancellation()
      switch await planner.read(
        session: session,
        request: .calendarRows(
          generation: snapshot.generation, offset: snapshot.matchingCount, limit: 1))
      {
      case .calendarRows(let final) where final.rows.isEmpty: return .result(value: entities)
      case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
      default:
        throw PlannerScheduleIntentFailure(message: "Planner changed while reading its Calendar.")
      }
    }
  }

  private enum PlannerScheduleSelection {
    case all
    case identifiers(Set<UUID>)
    case owner(PlannerEntityReference)
  }

  @MainActor
  private func loadPlannerScheduleEntities(
    store: SavedPlannerStore, selection: PlannerScheduleSelection
  ) async throws -> [PlannerScheduleEntity] {
    let (planner, session) = try await store.appIntentContext()
    try Task.checkCancellation()
    let snapshot: PlannerQuerySnapshot
    switch await planner.query(
      .init(session: session, request: .catalog(.init(sourceKind: .schedule, archive: .all))))
    {
    case .snapshot(let current): snapshot = current
    case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
    }
    let identifiers: Set<UUID>?
    switch selection {
    case .all: identifiers = nil
    case .identifiers(let selected): identifiers = selected
    case .owner(let owner):
      let references: [PlannerReferenceRead]
      switch await planner.read(session: session, request: .source(owner)) {
      case .source(.item(let source)) where owner.kind == .item: references = source.references
      case .source(.itinerary(let source)) where owner.kind == .itinerary:
        references = source.references
      case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
      default:
        throw PlannerScheduleIntentFailure(message: "Planner could not read this Schedule owner.")
      }
      identifiers = Set(
        references.compactMap { reference in
          guard case .schedule(let identifier, let source) = reference, source == owner else {
            return nil
          }
          return identifier
        })
    }
    var pageOffsets: Set<Int64> = []
    for (index, identity) in snapshot.rows.enumerated() {
      guard case .source(let source) = identity, source.kind == .schedule else {
        throw PlannerScheduleIntentFailure(message: "Planner could not identify a saved Schedule.")
      }
      if identifiers == nil || identifiers?.contains(source.id) == true {
        pageOffsets.insert(Int64(index / 64 * 64))
      }
    }
    var entities: [PlannerScheduleEntity] = []
    for offset in pageOffsets.sorted() {
      try Task.checkCancellation()
      let rows: [PlannerRowRead]
      switch await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: offset, limit: 64)
      )
      {
      case .rows(let window):
        guard !window.rows.isEmpty else {
          throw PlannerScheduleIntentFailure(message: "Planner could not read all saved Schedules.")
        }
        rows = window.rows
      case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
      default: throw PlannerScheduleIntentFailure(message: "Planner could not read its Schedules.")
      }
      for row in rows {
        guard case .source(let reference) = row.identity, reference.kind == .schedule else {
          throw PlannerScheduleIntentFailure(
            message: "Planner could not identify a saved Schedule.")
        }
        if let identifiers, !identifiers.contains(reference.id) { continue }
        try Task.checkCancellation()
        switch await planner.read(session: session, request: .source(reference)) {
        case .source(.schedule(let source)):
          entities.append(
            try .init(
              schedule: source.source, owner: source.content.source, title: row.title,
              form: source.content.form))
        case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
        default:
          throw PlannerScheduleIntentFailure(message: "Planner could not read this Schedule.")
        }
      }
    }
    try Task.checkCancellation()
    switch await planner.read(
      session: session,
      request: .rows(generation: snapshot.generation, offset: snapshot.matchingCount, limit: 1))
    {
    case .rows(let final) where final.rows.isEmpty: return entities
    case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
    default:
      throw PlannerScheduleIntentFailure(message: "Planner changed while reading its Schedules.")
    }
  }

  @MainActor
  private func loadPlannerScheduleOwner(
    store: SavedPlannerStore, identifier: UUID
  ) async throws -> PlannerSourceRead {
    let (planner, session) = try await store.appIntentContext()
    try Task.checkCancellation()
    let snapshot: PlannerQuerySnapshot
    switch await planner.query(
      .init(session: session, request: .catalog(.init(sourceKind: .schedule, archive: .all))))
    {
    case .snapshot(let current): snapshot = current
    case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
    }
    let owner: PlannerEntityReference
    switch await planner.read(
      session: session, request: .source(.init(kind: .schedule, id: identifier)))
    {
    case .source(.schedule(let source)): owner = source.content.source
    case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
    default: throw PlannerScheduleIntentFailure(message: "Planner could not read this Schedule.")
    }
    try Task.checkCancellation()
    let source: PlannerSourceRead
    switch await planner.read(session: session, request: .source(owner)) {
    case .source(.item(let current)) where owner.kind == .item: source = .item(current)
    case .source(.itinerary(let current)) where owner.kind == .itinerary:
      source = .itinerary(current)
    case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
    default:
      throw PlannerScheduleIntentFailure(message: "Planner could not read this Schedule owner.")
    }
    try Task.checkCancellation()
    switch await planner.read(
      session: session,
      request: .rows(generation: snapshot.generation, offset: snapshot.matchingCount, limit: 1))
    {
    case .rows(let final) where final.rows.isEmpty: return source
    case .failed(let reason): throw PlannerScheduleIntentFailure(message: reason.message)
    default:
      throw PlannerScheduleIntentFailure(
        message: "Planner changed while reading this Schedule owner.")
    }
  }

  private func plannerScheduleCivilDate(_ components: DateComponents) throws -> PlannerCivilDate {
    if let calendar = components.calendar,
      calendar.identifier != .gregorian && calendar.identifier != .iso8601
    {
      throw PlannerScheduleIntentFailure(message: "Select a Gregorian Calendar date.")
    }
    guard components.isLeapMonth != true,
      components.era == nil || components.era == 1,
      let year = components.year, let month = components.month, let day = components.day
    else {
      throw PlannerScheduleIntentFailure(message: "Select a complete Gregorian Calendar date.")
    }
    return .init(year: year, month: month, day: day)
  }

  private func plannerScheduleDayDescription(_ day: PlannerCivilDate) throws -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    guard
      let date = calendar.date(
        from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))
    else {
      throw PlannerScheduleIntentFailure(message: "Planner could not display this Schedule date.")
    }
    var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
    style.calendar = calendar
    style.timeZone = calendar.timeZone
    return style.format(date)
  }

  private struct PlannerScheduleIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }
#endif
