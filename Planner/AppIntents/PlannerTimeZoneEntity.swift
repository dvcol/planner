#if !PLANNER_FIXTURES
  import AppIntents
  import Foundation

  struct PlannerTimeZoneEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Timezone")
    static var defaultQuery: PlannerTimeZoneEntityQuery { PlannerTimeZoneEntityQuery() }
    let id: String
    @Property(title: "Identifier") var identifier: String
    @Property(title: "Name") var name: String
    var displayRepresentation: DisplayRepresentation {
      DisplayRepresentation(title: "\(name)", subtitle: "\(identifier)")
    }

    init?(identifier: String) {
      guard let timeZone = TimeZone(identifier: identifier) else { return nil }
      self.id = identifier
      self.identifier = identifier
      self.name = timeZone.localizedName(for: .generic, locale: .current) ?? identifier
    }
  }

  struct PlannerTimeZoneEntityQuery: EntityStringQuery {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    func entities(for identifiers: [String]) async throws -> [PlannerTimeZoneEntity] {
      try Task.checkCancellation()
      var seenIdentifiers: Set<String> = []
      var entities: [PlannerTimeZoneEntity] = []
      for identifier in identifiers where seenIdentifiers.insert(identifier).inserted {
        try Task.checkCancellation()
        if let entity = PlannerTimeZoneEntity(identifier: identifier) { entities.append(entity) }
      }
      return entities
    }

    func entities(matching string: String) async throws -> [PlannerTimeZoneEntity] {
      var entities = try await suggestedEntities()
      if let exact = PlannerTimeZoneEntity(identifier: string),
        !entities.contains(where: { $0.id == exact.id })
      {
        entities.append(exact)
      }
      return entities.filter {
        string.isEmpty || $0.identifier.localizedStandardContains(string)
          || $0.name.localizedStandardContains(string)
      }
    }

    func suggestedEntities() async throws -> [PlannerTimeZoneEntity] {
      try Task.checkCancellation()
      let identifiers = Set(
        TimeZone.knownTimeZoneIdentifiers + ["UTC", "Etc/UTC", "GMT", TimeZone.current.identifier])
      return identifiers.sorted().compactMap(PlannerTimeZoneEntity.init(identifier:))
    }
  }
#endif
