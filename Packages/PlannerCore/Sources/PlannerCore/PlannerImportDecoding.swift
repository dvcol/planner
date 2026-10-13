import Foundation

extension Planner {
  public nonisolated func decodeImport(_ data: Data) -> PlannerImportDecodingResult {
    do {
      let value = try JSONDecoder().decode(PlannerImportJSON.self, from: data)
      var decoder = PlannerPortableImportDecoder(root: .init(value: value, path: ""))
      return .decoded(try decoder.decode())
    } catch let failure as PlannerFailure {
      return .invalid(failure)
    } catch let error as DecodingError {
      let codingPath: [any CodingKey]
      switch error {
      case .dataCorrupted(let context), .typeMismatch(_, let context),
        .valueNotFound(_, let context):
        codingPath = context.codingPath
      case .keyNotFound(let key, let context): codingPath = context.codingPath + [key]
      @unknown default: codingPath = []
      }
      let path = codingPath.map { key in
        "/"
          + key.stringValue.replacingOccurrences(of: "~", with: "~0")
          .replacingOccurrences(of: "/", with: "~1")
      }.joined()
      return .invalid(
        PlannerFailure(
          "invalidInput", "The backup contains an invalid JSON value.", propertyPath: path))
    } catch {
      return .invalid(
        PlannerFailure("invalidInput", "The backup must contain valid JSON.", propertyPath: ""))
    }
  }
}

/// Foundation resolves repeated properties once; every later check reads this immutable value.
indirect enum PlannerImportJSON: Decodable {
  case null
  case boolean(Bool)
  case number(Double)
  case string(String)
  case array([PlannerImportJSON])
  case object([String: PlannerImportJSON])

  init(from decoder: any Decoder) throws {
    if let fields = try? decoder.container(keyedBy: PlannerImportCodingKey.self) {
      var values: [String: PlannerImportJSON] = [:]
      for key in fields.allKeys {
        values[key.stringValue] = try fields.decode(Self.self, forKey: key)
      }
      self = .object(values)
      return
    }
    if var elements = try? decoder.unkeyedContainer() {
      var values: [PlannerImportJSON] = []
      while !elements.isAtEnd { values.append(try elements.decode(Self.self)) }
      self = .array(values)
      return
    }
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
      return
    }
    if let value = try? container.decode(Bool.self) {
      self = .boolean(value)
      return
    }
    if let value = try? container.decode(String.self) {
      self = .string(value)
      return
    }
    self = .number(try container.decode(Double.self))
  }
}

private struct PlannerImportCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }
  init(intValue: Int) {
    stringValue = String(intValue)
    self.intValue = intValue
  }
}

struct PlannerImportNode {
  let value: PlannerImportJSON
  let path: String

  var isNull: Bool {
    if case .null = value { return true }
    return false
  }

  func failure(_ message: String) -> PlannerFailure {
    .init("invalidInput", message, propertyPath: path)
  }

  func child(_ name: String) throws -> Self {
    let escaped = name.replacingOccurrences(of: "~", with: "~0")
      .replacingOccurrences(of: "/", with: "~1")
    let propertyPath = path + "/" + escaped
    guard case .object(let fields) = value, let child = fields[name] else {
      throw PlannerFailure(
        "invalidInput", "A declared backup property is missing.",
        propertyPath: propertyPath)
    }
    return .init(value: child, path: propertyPath)
  }

  func record(_ names: [String]) throws -> Self {
    guard case .object(let fields) = value else { throw failure("Expected a backup object.") }
    if let unknown = Set(fields.keys).subtracting(names).sorted().first {
      throw try child(unknown).failure("This backup property is not supported.")
    }
    for name in names { _ = try child(name) }
    return self
  }

  func array() throws -> [Self] {
    guard case .array(let values) = value else { throw failure("Expected a backup array.") }
    return values.enumerated().map { .init(value: $0.element, path: path + "/\($0.offset)") }
  }

  func string(requiredText: Bool = false) throws -> String {
    guard case .string(let text) = value else { throw failure("Expected a String.") }
    if requiredText && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw failure("Required text must contain a non-whitespace character.")
    }
    return text
  }

  func optionalString() throws -> String? { isNull ? nil : try string() }

  func identifier() throws -> UUID {
    guard let identifier = UUID(uuidString: try string()) else {
      throw failure("Expected a UUID.")
    }
    return identifier
  }

  func optionalIdentifier() throws -> UUID? { isNull ? nil : try identifier() }

  func boolean() throws -> Bool {
    guard case .boolean(let flag) = value else { throw failure("Expected a Bool.") }
    return flag
  }

  func optionalBoolean() throws -> Bool? { isNull ? nil : try boolean() }

  func number() throws -> Double {
    guard case .number(let number) = value, number.isFinite else {
      throw failure("Expected a finite native number.")
    }
    return number
  }

  func integer() throws -> Int {
    guard let integer = Int(exactly: try number()) else {
      throw failure("Expected a native integer.")
    }
    return integer
  }

  func integerString() throws -> Int64 {
    let text = try string()
    guard let integer = Int64(text), String(integer) == text else {
      throw failure("Expected a canonical signed Int64 String.")
    }
    return integer
  }

  func requireNull() throws {
    guard isNull else { throw failure("This property must be null for its record kind.") }
  }

  func expandedContext() throws -> PlannerExpandedContext {
    let fields = try record([
      "listEntryId", "listEntryLifetimeId", "membershipId", "membershipLifetimeId",
    ])
    return try .init(
      listEntryId: fields.child("listEntryId").identifier(),
      listEntryLifetimeId: fields.child("listEntryLifetimeId").identifier(),
      membershipId: fields.child("membershipId").identifier(),
      membershipLifetimeId: fields.child("membershipLifetimeId").identifier())
  }

  func completionContext() throws -> PlannerPortableCompletionContext {
    switch try child("kind").string() {
    case "listMembership":
      let fields = try record(["kind", "membershipId", "membershipLifetimeId"])
      return try .listMembership(
        membershipId: fields.child("membershipId").identifier(),
        membershipLifetimeId: fields.child("membershipLifetimeId").identifier())
    case "directItineraryItem":
      let fields = try record(["kind", "entryId", "entryLifetimeId"])
      return try .directItineraryItem(
        entryId: fields.child("entryId").identifier(),
        entryLifetimeId: fields.child("entryLifetimeId").identifier())
    case "expandedListItem":
      let fields = try record([
        "kind", "listEntryId", "listEntryLifetimeId", "membershipId", "membershipLifetimeId",
      ])
      return try .expandedListItem(
        .init(
          listEntryId: fields.child("listEntryId").identifier(),
          listEntryLifetimeId: fields.child("listEntryLifetimeId").identifier(),
          membershipId: fields.child("membershipId").identifier(),
          membershipLifetimeId: fields.child("membershipLifetimeId").identifier()))
    default: throw try child("kind").failure("Unsupported completion context kind.")
    }
  }

  func location() throws -> PlannerOwnedLocation? {
    if isNull { return nil }
    let fields = try record(["displayName", "formattedAddress", "coordinate"])
    let coordinateNode = try fields.child("coordinate")
    var coordinate: PlannerCoordinate?
    if !coordinateNode.isNull {
      let components = try coordinateNode.record(["latitude", "longitude"])
      let latitude = try components.child("latitude").number()
      let longitude = try components.child("longitude").number()
      guard (-90...90).contains(latitude) else {
        throw try components.child("latitude").failure("Latitude must be in -90...90.")
      }
      guard (-180...180).contains(longitude) else {
        throw try components.child("longitude").failure("Longitude must be in -180...180.")
      }
      coordinate = .init(latitude: latitude, longitude: longitude)
    }
    return try .init(
      displayName: fields.child("displayName").optionalString(),
      formattedAddress: fields.child("formattedAddress").optionalString(), coordinate: coordinate)
  }

  func color() throws -> PlannerColor? {
    if isNull { return nil }
    let fields = try record(["red", "green", "blue", "alpha"])
    let color = try PlannerColor(
      red: fields.child("red").number(), green: fields.child("green").number(),
      blue: fields.child("blue").number(), alpha: fields.child("alpha").number())
    try color.validate(propertyPath: path)
    return color
  }

  func estimate() throws -> PlannerEstimate? {
    if isNull { return nil }
    let fields = try record(["minutes", "displayUnit"])
    let minutes = try fields.child("minutes").integerString()
    guard minutes > 0 else {
      throw try fields.child("minutes").failure("An estimate must be positive.")
    }
    guard let unit = PlannerEstimateUnit(rawValue: try fields.child("displayUnit").string()) else {
      throw try fields.child("displayUnit").failure("Unsupported estimate unit.")
    }
    return .init(minutes: minutes, displayUnit: unit)
  }

  func civilDate() throws -> PlannerCivilDate {
    let fields = try record(["year", "month", "day"])
    let date = try PlannerCivilDate(
      year: fields.child("year").integer(), month: fields.child("month").integer(),
      day: fields.child("day").integer())
    try date.validate(propertyPath: path)
    return date
  }

  func scheduleForm() throws -> PlannerScheduleForm {
    let form: PlannerScheduleForm
    switch try child("kind").string() {
    case "timed":
      let fields = try record(["kind", "start", "end", "planningTimeZone"])
      let endNode = try fields.child("end")
      let end = endNode.isNull ? nil : Date(timeIntervalSinceReferenceDate: try endNode.number())
      form = try .timed(
        start: Date(timeIntervalSinceReferenceDate: fields.child("start").number()), end: end,
        planningTimeZone: fields.child("planningTimeZone").string())
    case "allDay":
      let fields = try record(["kind", "start", "end"])
      let endNode = try fields.child("end")
      form = try .allDay(
        start: fields.child("start").civilDate(), end: endNode.isNull ? nil : endNode.civilDate())
    default: throw try child("kind").failure("Unsupported Schedule form kind.")
    }
    try form.validate(propertyPath: path)
    return form
  }
}

struct PlannerPortableImportDecoder {
  let root: PlannerImportNode
  private var formatVersion: Int = 1
  private var bindingPaths: [PlannerBindingPath] = []

  init(root: PlannerImportNode) { self.root = root }

  mutating func decode() throws -> PlannerDecodedBackup {
    let fields = try root.record([
      "format", "formatVersion", "sources", "memberships", "itineraryEntries",
      "expandedCompletions", "schedules", "labelAssociations", "ownedLinks", "deletionMarkers",
      "contextAliases", "completionChanges", "restorationFamilies",
    ])
    guard try fields.child("format").string() == "planner-data" else {
      throw try fields.child("format").failure("Expected a Planner data backup.")
    }
    formatVersion = try fields.child("formatVersion").integer()
    guard (1...2).contains(formatVersion) else {
      throw PlannerFailure(
        "unsupportedVersion", "Unsupported portable backup version.",
        propertyPath: "/formatVersion")
    }
    let sources = try fields.child("sources").array().map { try source($0) }
    let memberships = try fields.child("memberships").array().map { try membership($0) }
    let entries = try fields.child("itineraryEntries").array().map { try itineraryEntry($0) }
    let expanded = try fields.child("expandedCompletions").array().map { node in
      let fields = try node.record(["context", "localDone"])
      return try PlannerPortableExpandedCompletion(
        context: fields.child("context").expandedContext(),
        localDone: fields.child("localDone").boolean())
    }
    let schedules = try fields.child("schedules").array().map { try schedule($0) }
    let labels = try fields.child("labelAssociations").array().map { try labelAssociation($0) }
    let links = try fields.child("ownedLinks").array().map { try ownedLink($0) }
    let markers = try fields.child("deletionMarkers").array().map { try deletionMarker($0) }
    let aliases = try fields.child("contextAliases").array().map { try contextAlias($0) }
    let changes = try fields.child("completionChanges").array().map { try completionChange($0) }
    let families = try fields.child("restorationFamilies").array().map { try restorationFamily($0) }
    let backup = PlannerPortableBackup(
      sources: sources, labelAssociations: labels, memberships: memberships,
      itineraryEntries: entries, expandedCompletions: expanded, schedules: schedules,
      deletionMarkers: markers, ownedLinks: links, contextAliases: aliases,
      completionChanges: changes, restorationFamilies: families)
    try PlannerImportGraph(backup: backup).validate()
    let external = try externalPaths(backup: backup)
    let unique = Set(external.map(\.binding)).sorted {
      if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
      if $0.id != $1.id { return $0.id.uuidString < $1.id.uuidString }
      return $0.lifetimeId.uuidString < $1.lifetimeId.uuidString
    }
    return .init(backup: projectingContent(backup), externalBindings: unique, originPaths: external)
  }

  private mutating func boundSource(
    _ node: PlannerImportNode, kinds: [PlannerEntityKind], recordPath: Bool = true
  ) throws -> PlannerBoundSource {
    let fields = try node.record(["kind", "id", "lifetimeId"])
    guard let kind = PlannerEntityKind(rawValue: try fields.child("kind").string()),
      kinds.contains(kind)
    else { throw try fields.child("kind").failure("Unsupported source kind for this reference.") }
    let binding = try PlannerBoundSource(
      kind: kind, id: fields.child("id").identifier(),
      lifetimeId: fields.child("lifetimeId").identifier())
    if recordPath { bindingPaths.append(.init(binding: binding, propertyPath: node.path)) }
    return binding
  }

  private func source(_ node: PlannerImportNode) throws -> PlannerPortableSource {
    let fields = try node.record([
      "kind", "id", "lifetimeId", "createdAt", "updatedAt", "content", "globalDone", "archived",
      "contentOrigins",
    ])
    let identifier = try fields.child("id").identifier()
    let lifetime = try fields.child("lifetimeId").identifier()
    let created = try Date(timeIntervalSinceReferenceDate: fields.child("createdAt").number())
    let updated = try Date(timeIntervalSinceReferenceDate: fields.child("updatedAt").number())
    let content = try fields.child("content")
    let kind = try fields.child("kind").string()
    switch kind {
    case "item":
      let content = try content.record(["title", "subtitle", "notes", "location", "estimate"])
      let origins = try origins(
        fields.child("contentOrigins"), content: content,
        textFields: ["title", "subtitle", "notes", "location"])
      return try .item(
        .init(
          kind: .item, id: identifier, lifetimeId: lifetime, createdAt: created, updatedAt: updated,
          content: .init(
            title: content.child("title").string(requiredText: true),
            subtitle: content.child("subtitle").optionalString(),
            notes: content.child("notes").optionalString(),
            location: content.child("location").location(),
            estimate: content.child("estimate").estimate(), links: [], categoryIds: [], tagIds: []),
          globalDone: fields.child("globalDone").boolean(),
          archived: fields.child("archived").boolean(),
          contentOrigins: origins))
    case "list":
      try fields.child("globalDone").requireNull()
      var names = ["name", "notes", "color", "iconName"]
      if formatVersion == 2 { names.append("manualEstimate") }
      let content = try content.record(names)
      let manualEstimate = try containerManualEstimate(content)
      return try .list(
        .init(
          id: identifier, lifetimeId: lifetime, createdAt: created, updatedAt: updated,
          content: .init(
            name: content.child("name").string(requiredText: true),
            notes: content.child("notes").optionalString(),
            color: content.child("color").color(),
            iconName: content.child("iconName").optionalString(), manualEstimate: manualEstimate),
          archived: fields.child("archived").boolean(),
          contentOrigins: origins(
            fields.child("contentOrigins"), content: content, textFields: ["name", "notes"])))
    case "itinerary":
      try fields.child("globalDone").requireNull()
      var names = ["title", "notes", "color", "iconName", "location"]
      if formatVersion == 2 { names.append("manualEstimate") }
      let content = try content.record(names)
      let manualEstimate = try containerManualEstimate(content)
      return try .itinerary(
        .init(
          id: identifier, lifetimeId: lifetime, createdAt: created, updatedAt: updated,
          content: .init(
            title: content.child("title").string(requiredText: true),
            notes: content.child("notes").optionalString(),
            color: content.child("color").color(),
            iconName: content.child("iconName").optionalString(),
            location: content.child("location").location(), links: [], categoryIds: [], tagIds: [],
            manualEstimate: manualEstimate),
          archived: fields.child("archived").boolean(),
          contentOrigins: origins(
            fields.child("contentOrigins"), content: content,
            textFields: ["title", "notes", "location"])))
    case "category", "tag":
      try fields.child("globalDone").requireNull()
      try fields.child("archived").requireNull()
      let content = try content.record(["name", "color", "iconName"])
      let name = try content.child("name").string(requiredText: true)
      let color = try content.child("color").color()
      let icon = try content.child("iconName").optionalString()
      let origins = try origins(
        fields.child("contentOrigins"), content: content, textFields: ["name"])
      if kind == "category" {
        return .category(
          .init(
            id: identifier, lifetimeId: lifetime, createdAt: created, updatedAt: updated,
            content: .init(name: name, color: color, iconName: icon), contentOrigins: origins))
      }
      return .tag(
        .init(
          id: identifier, lifetimeId: lifetime, createdAt: created, updatedAt: updated,
          content: .init(name: name, color: color, iconName: icon), contentOrigins: origins))
    default: throw try fields.child("kind").failure("Unsupported portable source kind.")
    }
  }

  private func origins(_ node: PlannerImportNode, content: PlannerImportNode, textFields: [String])
    throws -> [String: String]
  {
    let names = try textFields.filter { try !content.child($0).isNull }
    let fields = try node.record(names)
    var result: [String: String] = [:]
    for name in names {
      let origin = try fields.child(name).string()
      guard origin == "independent" || origin == "appFallback" else {
        throw try fields.child(name).failure("Unsupported persisted content origin.")
      }
      result[name] = origin
    }
    return result
  }

  private mutating func membership(_ node: PlannerImportNode) throws -> PlannerPortableMembership {
    let fields = try node.record(["id", "lifetimeId", "list", "item", "rank", "localDone"])
    let list = try boundSource(fields.child("list"), kinds: [.list])
    let item = try boundSource(fields.child("item"), kinds: [.item])
    return try .init(
      id: fields.child("id").identifier(), lifetimeId: fields.child("lifetimeId").identifier(),
      list: list.reference, listLifetimeId: list.lifetimeId, item: item.reference,
      itemLifetimeId: item.lifetimeId,
      rank: fields.child("rank").integerString(), localDone: fields.child("localDone").boolean())
  }

  private mutating func itineraryEntry(_ node: PlannerImportNode) throws
    -> PlannerPortableItineraryEntry
  {
    let fields = try node.record(["id", "lifetimeId", "itinerary", "source", "rank", "localDone"])
    let itinerary = try boundSource(fields.child("itinerary"), kinds: [.itinerary])
    let source = try boundSource(fields.child("source"), kinds: [.item, .list])
    let done = try fields.child("localDone").optionalBoolean()
    guard (source.kind == .item) == (done != nil) else {
      throw try fields.child("localDone").failure(
        "Item entries require Bool completion; List entries require null.")
    }
    return try .init(
      id: fields.child("id").identifier(), lifetimeId: fields.child("lifetimeId").identifier(),
      itinerary: itinerary.reference, itineraryLifetimeId: itinerary.lifetimeId,
      source: source.reference, sourceLifetimeId: source.lifetimeId,
      rank: fields.child("rank").integerString(), localDone: done)
  }

  private mutating func schedule(_ node: PlannerImportNode) throws -> PlannerPortableSchedule {
    let fields = try node.record(["id", "lifetimeId", "source", "form"])
    let source = try boundSource(fields.child("source"), kinds: [.item, .itinerary])
    return try .init(
      id: fields.child("id").identifier(), lifetimeId: fields.child("lifetimeId").identifier(),
      source: source.reference, sourceLifetimeId: source.lifetimeId,
      form: fields.child("form").scheduleForm())
  }

  private mutating func labelAssociation(_ node: PlannerImportNode) throws
    -> PlannerPortableLabelAssociation
  {
    let fields = try node.record(["id", "lifetimeId", "owner", "label"])
    let owner = try boundSource(fields.child("owner"), kinds: [.item, .itinerary])
    let label = try boundSource(fields.child("label"), kinds: [.category, .tag])
    return try .init(
      id: fields.child("id").identifier(), lifetimeId: fields.child("lifetimeId").identifier(),
      owner: owner.reference, ownerLifetimeId: owner.lifetimeId, label: label.reference,
      labelLifetimeId: label.lifetimeId)
  }

  private mutating func ownedLink(_ node: PlannerImportNode) throws -> PlannerPortableOwnedLink {
    let fields = try node.record([
      "id", "lifetimeId", "owner", "rank", "originalUrl", "label", "kind", "providerReference",
    ])
    let owner = try boundSource(fields.child("owner"), kinds: [.item, .itinerary])
    let original = try fields.child("originalUrl").string()
    let detected = try PlannerLinkInput(originalUrl: original).validatedKind(
      propertyPath: node.path)
    guard let kind = PlannerLinkKind(rawValue: try fields.child("kind").string()),
      kind == detected || kind == .generic
    else {
      throw try fields.child("kind").failure("The saved link classification is inconsistent.")
    }
    let referenceNode = try fields.child("providerReference")
    var reference: PlannerProviderReference?
    if !referenceNode.isNull {
      let referenceFields = try referenceNode.record(["kind", "value"])
      guard kind == .appleMaps, try referenceFields.child("kind").string() == "applePlaceId" else {
        throw try referenceFields.child("kind").failure(
          "Only an Apple Maps place can retain an Apple Place ID.")
      }
      let value = try referenceFields.child("value").string(requiredText: true)
      let providerReference = PlannerProviderReference(kind: .applePlaceId, value: value)
      guard providerReference.isValid(for: kind) else {
        throw try referenceFields.child("value").failure(
          "A contextual location command is not a stable place identity.")
      }
      reference = providerReference
    }
    return try .init(
      id: fields.child("id").identifier(), lifetimeId: fields.child("lifetimeId").identifier(),
      owner: owner, rank: fields.child("rank").integerString(), originalUrl: original,
      label: fields.child("label").optionalString(), kind: kind, providerReference: reference)
  }

  private mutating func deletionMarker(_ node: PlannerImportNode) throws
    -> PlannerPortableDeletionMarker
  {
    let fields = try node.record(["deletionId", "operationId", "target", "closedFamilyId"])
    let targetNode = try fields.child("target")
    let target: PlannerPortableDeletionTarget
    switch try targetNode.child("kind").string() {
    case "source":
      let targetFields = try targetNode.record(["kind", "source"])
      let binding = try boundSource(
        targetFields.child("source"),
        kinds: [.item, .list, .itinerary, .category, .tag, .schedule], recordPath: false)
      target = .source(binding.reference, lifetimeId: binding.lifetimeId)
    case "membership", "itineraryEntry", "labelAssociation", "ownedLink":
      let targetFields = try targetNode.record(["kind", "id", "lifetimeId"])
      let identifier = try targetFields.child("id").identifier()
      let lifetime = try targetFields.child("lifetimeId").identifier()
      switch try targetFields.child("kind").string() {
      case "membership": target = .membership(id: identifier, lifetimeId: lifetime)
      case "itineraryEntry": target = .itineraryEntry(id: identifier, lifetimeId: lifetime)
      case "labelAssociation": target = .labelAssociation(id: identifier, lifetimeId: lifetime)
      default: target = .ownedLink(id: identifier, lifetimeId: lifetime)
      }
    case "expandedCompletion":
      let targetFields = try targetNode.record(["kind", "context"])
      target = try .expandedCompletion(targetFields.child("context").expandedContext())
    default: throw try targetNode.child("kind").failure("Unsupported deletion target kind.")
    }
    return try .init(
      deletionId: fields.child("deletionId").identifier(),
      operationId: fields.child("operationId").identifier(),
      target: target, closedFamilyId: fields.child("closedFamilyId").optionalIdentifier())
  }

  private func contextAlias(_ node: PlannerImportNode) throws -> PlannerPortableContextAlias {
    let fields = try node.record([
      "aliasId", "context", "canonicalContext", "initialDone", "currentChangeId",
    ])
    return try .init(
      aliasId: fields.child("aliasId").identifier(),
      context: fields.child("context").completionContext(),
      canonicalContext: fields.child("canonicalContext").completionContext(),
      initialDone: fields.child("initialDone").boolean(),
      currentChangeId: fields.child("currentChangeId").optionalIdentifier())
  }

  private func completionChange(_ node: PlannerImportNode) throws -> PlannerPortableCompletionChange
  {
    let fields = try node.record(["id", "aliasId", "context", "done", "observedChangeIds"])
    let predecessors = try fields.child("observedChangeIds").array().map { try $0.identifier() }
    guard Set(predecessors).count == predecessors.count else {
      throw try fields.child("observedChangeIds").failure(
        "Observed completion changes must be distinct.")
    }
    return try .init(
      id: fields.child("id").identifier(), aliasId: fields.child("aliasId").identifier(),
      context: fields.child("context").completionContext(), done: fields.child("done").boolean(),
      observedChangeIds: predecessors)
  }

  private func restorationFamily(_ node: PlannerImportNode) throws
    -> PlannerPortableRestorationFamily
  {
    let fields = try node.record(["familyId", "predecessor", "candidates"])
    let predecessor = try fields.child("predecessor").record(["kind", "id", "lifetimeId"])
    guard let kind = PlannerPortableIdentityKind(rawValue: try predecessor.child("kind").string())
    else {
      throw try predecessor.child("kind").failure("Unsupported restoration predecessor kind.")
    }
    let candidates = try fields.child("candidates").array().map { node in
      let fields = try node.record(["lifetimeId", "operationId"])
      return try PlannerPortableRestorationCandidate(
        lifetimeId: fields.child("lifetimeId").identifier(),
        operationId: fields.child("operationId").identifier())
    }
    guard !candidates.isEmpty else {
      throw try fields.child("candidates").failure(
        "A restoration family needs at least one candidate.")
    }
    return try .init(
      familyId: fields.child("familyId").identifier(),
      predecessor: .init(
        kind: kind, id: predecessor.child("id").identifier(),
        lifetimeId: predecessor.child("lifetimeId").identifier()),
      candidates: candidates)
  }

  private func externalPaths(backup: PlannerPortableBackup) throws -> [PlannerBindingPath] {
    let graph = PlannerImportGraph(backup: backup)
    var external: [PlannerBindingPath] = []
    for origin in bindingPaths {
      let identity = PlannerPortableBoundIdentity(
        kind: .init(rawValue: origin.binding.kind.rawValue)!, id: origin.binding.id,
        lifetimeId: origin.binding.lifetimeId)
      if graph.isClosed(identity) {
        throw PlannerFailure(
          "invalidInput", "A reference still targets a closed lifetime.",
          propertyPath: origin.propertyPath + "/lifetimeId")
      }
      guard let live = graph.liveIdentity(for: identity) else {
        external.append(origin)
        continue
      }
      guard graph.resolves(identity, to: live) else {
        throw PlannerFailure(
          "invalidInput", "The reference lifetime differs from its declared source.",
          propertyPath: origin.propertyPath + "/lifetimeId")
      }
    }
    return external
  }

  private func containerManualEstimate(_ content: PlannerImportNode) throws -> PlannerEstimate? {
    guard formatVersion == 2 else { return nil }
    return try content.child("manualEstimate").estimate()
  }

  private func projectingContent(_ backup: PlannerPortableBackup) -> PlannerPortableBackup {
    let sources = backup.sources.map { source -> PlannerPortableSource in
      let links = backup.ownedLinks.filter {
        $0.owner.kind == source.kind && $0.owner.id == source.id
      }
      .sorted {
        if $0.rank != $1.rank { return $0.rank < $1.rank }
        return $0.id.uuidString < $1.id.uuidString
      }.map(\.read)
      let labels = backup.labelAssociations.filter {
        $0.owner.kind == source.kind && $0.owner.id == source.id
      }
      let categories = Set(labels.filter { $0.label.kind == .category }.map(\.label.id))
      let tags = Set(labels.filter { $0.label.kind == .tag }.map(\.label.id))
      switch source {
      case .item(let item):
        let content = item.content
        return .item(
          .init(
            kind: item.kind, id: item.id, lifetimeId: item.lifetimeId, createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            content: .init(
              title: content.title, subtitle: content.subtitle, notes: content.notes,
              location: content.location,
              estimate: content.estimate, links: links, categoryIds: categories, tagIds: tags),
            globalDone: item.globalDone,
            archived: item.archived, contentOrigins: item.contentOrigins))
      case .itinerary(let itinerary):
        let content = itinerary.content
        return .itinerary(
          .init(
            id: itinerary.id, lifetimeId: itinerary.lifetimeId, createdAt: itinerary.createdAt,
            updatedAt: itinerary.updatedAt,
            content: .init(
              title: content.title, notes: content.notes, color: content.color,
              iconName: content.iconName, location: content.location,
              links: links, categoryIds: categories, tagIds: tags,
              manualEstimate: content.manualEstimate), archived: itinerary.archived,
            contentOrigins: itinerary.contentOrigins))
      default: return source
      }
    }
    return .init(
      sources: sources, labelAssociations: backup.labelAssociations,
      memberships: backup.memberships,
      itineraryEntries: backup.itineraryEntries, expandedCompletions: backup.expandedCompletions,
      schedules: backup.schedules,
      deletionMarkers: backup.deletionMarkers, ownedLinks: backup.ownedLinks,
      contextAliases: backup.contextAliases,
      completionChanges: backup.completionChanges, restorationFamilies: backup.restorationFamilies)
  }
}
