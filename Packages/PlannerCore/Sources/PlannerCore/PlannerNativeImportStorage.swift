import Foundation
import SwiftData

struct PlannerNativeLineage {
  let contextAliases: [PlannerPortableContextAlias]
  let completionChanges: [PlannerPortableCompletionChange]
  let restorationFamilies: [PlannerPortableRestorationFamily]
  let deletionMarkers: [PortableDeletionMarker]

  private init(
    contextAliases: [PlannerPortableContextAlias],
    completionChanges: [PlannerPortableCompletionChange],
    restorationFamilies: [PlannerPortableRestorationFamily],
    deletionMarkers: [PortableDeletionMarker]
  ) {
    self.contextAliases = contextAliases.sorted { $0.aliasId.uuidString < $1.aliasId.uuidString }
    self.completionChanges = completionChanges.sorted { $0.id.uuidString < $1.id.uuidString }
    self.restorationFamilies = restorationFamilies.sorted {
      $0.familyId.uuidString < $1.familyId.uuidString
    }
    self.deletionMarkers = deletionMarkers
  }

  func reconciling(_ snapshot: PlannerDataSnapshot, context: ModelContext) throws
    -> PlannerNativeLineage
  {
    var states: [PlannerPortableCompletionContext: Bool] = [:]
    for membership in snapshot.memberships {
      states[
        .listMembership(
          membershipId: membership.id, membershipLifetimeId: membership.lifetimeId)] =
        membership.localDone
    }
    for entry in snapshot.itineraryEntries {
      if let done = entry.localDone {
        states[.directItineraryItem(entryId: entry.id, entryLifetimeId: entry.lifetimeId)] = done
      }
    }
    for expanded in snapshot.expandedCompletions {
      states[.expandedListItem(expanded.context)] = expanded.localDone
    }
    let previousChanges = Dictionary(uniqueKeysWithValues: completionChanges.map { ($0.id, $0) })
    var aliases = contextAliases
    var changes = completionChanges
    for (canonicalContext, contributions) in Dictionary(
      grouping: contextAliases, by: \.canonicalContext)
    {
      guard let done = states[canonicalContext],
        done
          != plannerCompletionHistoryValue(contributions: contributions, changes: previousChanges)
      else { continue }
      let alias = contributions.filter { $0.context == canonicalContext }.min {
        $0.aliasId.uuidString < $1.aliasId.uuidString
      }
      let aliasIdentifier = alias?.aliasId ?? UUID()
      let changeIdentifier = UUID()
      aliases.removeAll { $0.aliasId == aliasIdentifier }
      aliases.append(
        .init(
          aliasId: aliasIdentifier, context: canonicalContext, canonicalContext: canonicalContext,
          initialDone: alias?.initialDone ?? false, currentChangeId: changeIdentifier))
      changes.append(
        .init(
          id: changeIdentifier, aliasId: aliasIdentifier, context: canonicalContext, done: done,
          observedChangeIds: Array(Set(contributions.compactMap(\.currentChangeId))).sorted {
            $0.uuidString < $1.uuidString
          }))
    }
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV16.LineageRecord>())
    for alias in aliases {
      try plannerStageLineageRecord(
        alias, identifier: alias.aliasId, kind: "contextAlias", records: records, context: context)
    }
    for change in changes {
      try plannerStageLineageRecord(
        change, identifier: change.id, kind: "completionChange", records: records, context: context)
    }
    return .init(
      contextAliases: aliases, completionChanges: changes, restorationFamilies: restorationFamilies,
      deletionMarkers: deletionMarkers)
  }

  init(context: ModelContext) throws {
    var aliases: [PlannerPortableContextAlias] = []
    var changes: [PlannerPortableCompletionChange] = []
    var families: [PlannerPortableRestorationFamily] = []
    var markers: [PortableDeletionMarker] = []
    for record in try context.fetch(FetchDescriptor<PlannerSchemaV16.LineageRecord>()) {
      guard let identifier = record.recordIdentifier, let data = record.recordData else {
        throw PlannerFailure("readUnavailable", "Stored lineage has unresolved identity or data.")
      }
      switch record.recordKind {
      case "contextAlias":
        let alias = try JSONDecoder().decode(PlannerPortableContextAlias.self, from: data)
        guard alias.aliasId == identifier else { throw Self.invalidIdentity() }
        aliases.append(alias)
      case "completionChange":
        let change = try JSONDecoder().decode(PlannerPortableCompletionChange.self, from: data)
        guard change.id == identifier else { throw Self.invalidIdentity() }
        changes.append(change)
      case "restorationFamily":
        let family = try JSONDecoder().decode(PlannerPortableRestorationFamily.self, from: data)
        guard family.familyId == identifier else { throw Self.invalidIdentity() }
        families.append(family)
      case "deletionMarker":
        let marker = try JSONDecoder().decode(PortableDeletionMarker.self, from: data)
        guard marker.deletionId == identifier else { throw Self.invalidIdentity() }
        markers.append(marker)
      default: throw Self.invalidIdentity()
      }
    }
    guard Set(aliases.map(\.aliasId)).count == aliases.count,
      Set(changes.map(\.id)).count == changes.count,
      Set(families.map(\.familyId)).count == families.count,
      Set(markers.map(\.deletionId)).count == markers.count
    else { throw Self.invalidIdentity() }
    contextAliases = aliases.sorted { $0.aliasId.uuidString < $1.aliasId.uuidString }
    completionChanges = changes.sorted { $0.id.uuidString < $1.id.uuidString }
    restorationFamilies = families.sorted { $0.familyId.uuidString < $1.familyId.uuidString }
    deletionMarkers = markers.sorted { $0.deletionId.uuidString < $1.deletionId.uuidString }
  }

  private static func invalidIdentity() -> PlannerFailure {
    .init("readUnavailable", "Stored lineage has inconsistent identity or kind.")
  }
}

func plannerRemoveImportedReferences(notIn backup: PlannerPortableBackup, context: ModelContext)
  throws
{
  let expandedContexts = Set(backup.expandedCompletions.map(\.context))
  for expanded in try context.fetch(FetchDescriptor<PlannerSchemaV15.ExpandedCompletion>()) {
    if !expandedContexts.contains(try expanded.value().context) { context.delete(expanded) }
  }
  try plannerRemoveImportedRecords(
    PlannerSchemaV15.Membership.self, identity: \.id,
    retaining: Set(backup.memberships.map(\.id)), context: context)
  try plannerRemoveImportedRecords(
    PlannerSchemaV15.ItineraryEntry.self, identity: \.id,
    retaining: Set(backup.itineraryEntries.map(\.id)),
    context: context)
  try plannerRemoveImportedRecords(
    PlannerSchemaV15.LabelAssociation.self, identity: \.id,
    retaining: Set(backup.labelAssociations.map(\.id)),
    context: context)
  try plannerRemoveImportedRecords(
    PlannerSchemaV15.OwnedLink.self, identity: \.id,
    retaining: Set(backup.ownedLinks.map(\.id)), context: context)
  try plannerRemoveImportedRecords(
    PlannerSchemaV15.Schedule.self, identity: \.id,
    retaining: Set(backup.schedules.map(\.id)), context: context)
  context.processPendingChanges()
}

private func plannerRemoveImportedRecords<Record: PersistentModel>(
  _ recordType: Record.Type, identity: KeyPath<Record, UUID?>,
  retaining identifiers: Set<UUID>, context: ModelContext
) throws {
  for (identifier, record) in try plannerImportRecords(
    recordType, identity: identity, context: context)
  {
    if !identifiers.contains(identifier) { context.delete(record) }
  }
}

func plannerInsertImportedGraph(
  _ backup: PlannerPortableBackup, replacing sourceReplacements: [PlannerPortableSource],
  context: ModelContext
) throws {
  var items = try plannerImportRecords(PlannerSchemaV15.Item.self, identity: \.id, context: context)
  var lists = try plannerImportRecords(PlannerSchemaV15.List.self, identity: \.id, context: context)
  var itineraries = try plannerImportRecords(
    PlannerSchemaV15.Itinerary.self, identity: \.id, context: context)
  var categories = try plannerImportRecords(
    PlannerSchemaV15.Category.self, identity: \.id, context: context)
  var tags = try plannerImportRecords(PlannerSchemaV15.Tag.self, identity: \.id, context: context)
  for source in backup.sources + sourceReplacements {
    switch source {
    case .item(let value):
      let content = value.content
      let item =
        try items[value.id]
        ?? PlannerSchemaV15.Item(
          input: .init(
            title: content.title, subtitle: content.subtitle, notes: content.notes,
            location: content.location, estimate: content.estimate))
      item.title = content.title
      item.subtitle = content.subtitle
      item.notes = content.notes
      item.locationData = try content.location.map { try JSONEncoder().encode($0) }
      item.estimateData = try content.estimate.map { try JSONEncoder().encode($0) }
      item.id = value.id
      item.lifetimeId = value.lifetimeId
      item.createdAt = value.createdAt
      item.updatedAt = value.updatedAt
      item.globalDone = value.globalDone
      item.archived = value.archived
      if items[value.id] == nil { context.insert(item) }
      items[value.id] = item
    case .list(let value):
      let content = value.content
      let list = try lists[value.id] ?? PlannerSchemaV15.List(content: content)
      list.name = content.name
      list.notes = content.notes
      list.colorData = try content.color.map { try JSONEncoder().encode($0) }
      list.iconName = content.iconName
      list.manualEstimateData = try content.manualEstimate.map { try JSONEncoder().encode($0) }
      list.id = value.id
      list.lifetimeId = value.lifetimeId
      list.createdAt = value.createdAt
      list.updatedAt = value.updatedAt
      list.archived = value.archived
      if lists[value.id] == nil { context.insert(list) }
      lists[value.id] = list
    case .itinerary(let value):
      let content = value.content
      let itinerary =
        try itineraries[value.id]
        ?? PlannerSchemaV15.Itinerary(
          input: .init(
            title: content.title, notes: content.notes, color: content.color,
            iconName: content.iconName, location: content.location,
            manualEstimate: content.manualEstimate))
      itinerary.title = content.title
      itinerary.notes = content.notes
      itinerary.colorData = try content.color.map { try JSONEncoder().encode($0) }
      itinerary.iconName = content.iconName
      itinerary.locationData = try content.location.map { try JSONEncoder().encode($0) }
      itinerary.manualEstimateData = try content.manualEstimate.map { try JSONEncoder().encode($0) }
      itinerary.id = value.id
      itinerary.lifetimeId = value.lifetimeId
      itinerary.createdAt = value.createdAt
      itinerary.updatedAt = value.updatedAt
      itinerary.archived = value.archived
      if itineraries[value.id] == nil { context.insert(itinerary) }
      itineraries[value.id] = itinerary
    case .category(let value):
      let content = value.content
      let category = try categories[value.id] ?? PlannerSchemaV15.Category(content: content)
      category.name = content.name
      category.colorData = try content.color.map { try JSONEncoder().encode($0) }
      category.iconName = content.iconName
      category.id = value.id
      category.lifetimeId = value.lifetimeId
      category.createdAt = value.createdAt
      category.updatedAt = value.updatedAt
      if categories[value.id] == nil { context.insert(category) }
      categories[value.id] = category
    case .tag(let value):
      let content = value.content
      let tag = try tags[value.id] ?? PlannerSchemaV15.Tag(content: content)
      tag.name = content.name
      tag.colorData = try content.color.map { try JSONEncoder().encode($0) }
      tag.iconName = content.iconName
      tag.id = value.id
      tag.lifetimeId = value.lifetimeId
      tag.createdAt = value.createdAt
      tag.updatedAt = value.updatedAt
      if tags[value.id] == nil { context.insert(tag) }
      tags[value.id] = tag
    }
  }
  var memberships = try plannerImportRecords(
    PlannerSchemaV15.Membership.self, identity: \.id, context: context)
  for value in backup.memberships {
    guard let list = lists[value.list.id], let item = items[value.item.id] else {
      throw PlannerFailure("missingReference", "Imported membership bindings cannot resolve.")
    }
    if let membership = memberships[value.id] {
      membership.rank = value.rank
      membership.localDone = value.localDone
      continue
    }
    let membership = PlannerSchemaV15.Membership(
      snapshot: .init(
        id: value.id, lifetimeId: value.lifetimeId,
        list: .init(kind: "list", id: value.list.id, lifetimeId: value.listLifetimeId),
        item: .init(kind: "item", id: value.item.id, lifetimeId: value.itemLifetimeId),
        rank: value.rank, localDone: value.localDone), list: list, item: item)
    context.insert(membership)
    memberships[value.id] = membership
  }
  var entries = try plannerImportRecords(
    PlannerSchemaV15.ItineraryEntry.self, identity: \.id, context: context)
  for value in backup.itineraryEntries {
    guard let itinerary = itineraries[value.itinerary.id] else {
      throw PlannerFailure("missingReference", "Imported itinerary bindings cannot resolve.")
    }
    if let entry = entries[value.id] {
      entry.rank = value.rank
      entry.localDone = value.localDone
      continue
    }
    let entry = PlannerSchemaV15.ItineraryEntry(
      snapshot: .init(
        id: value.id, lifetimeId: value.lifetimeId,
        itinerary: .init(
          kind: "itinerary", id: value.itinerary.id, lifetimeId: value.itineraryLifetimeId),
        source: .init(
          kind: value.source.kind.rawValue, id: value.source.id,
          lifetimeId: value.sourceLifetimeId), rank: value.rank, localDone: value.localDone),
      itinerary: itinerary,
      item: value.source.kind == .item ? items[value.source.id] : nil,
      list: value.source.kind == .list ? lists[value.source.id] : nil)
    context.insert(entry)
    entries[value.id] = entry
  }
  let expandedCompletions = try Dictionary(
    uniqueKeysWithValues: context.fetch(FetchDescriptor<PlannerSchemaV15.ExpandedCompletion>()).map
    {
      (try $0.value().context, $0)
    })
  for value in backup.expandedCompletions {
    guard let entry = entries[value.context.listEntryId],
      let membership = memberships[value.context.membershipId]
    else {
      throw PlannerFailure("missingReference", "Imported expanded completion cannot resolve.")
    }
    if let expanded = expandedCompletions[value.context] {
      expanded.localDone = value.localDone
      continue
    }
    context.insert(
      PlannerSchemaV15.ExpandedCompletion(
        listEntry: entry, membership: membership, localDone: value.localDone))
  }
  let associations = try plannerImportRecords(
    PlannerSchemaV15.LabelAssociation.self, identity: \.id, context: context)
  for value in backup.labelAssociations {
    if associations[value.id] != nil { continue }
    let category = value.label.kind == .category ? categories[value.label.id] : nil
    let tag = value.label.kind == .tag ? tags[value.label.id] : nil
    let association: PlannerSchemaV15.LabelAssociation
    if value.owner.kind == .item, let item = items[value.owner.id] {
      association = PlannerSchemaV15.LabelAssociation(
        snapshot: .init(
          id: value.id, lifetimeId: value.lifetimeId,
          owner: .init(kind: "item", id: value.owner.id, lifetimeId: value.ownerLifetimeId),
          label: .init(
            kind: value.label.kind.rawValue, id: value.label.id,
            lifetimeId: value.labelLifetimeId)), item: item, category: category, tag: tag)
    } else if value.owner.kind == .itinerary, let itinerary = itineraries[value.owner.id],
      let category
    {
      association = PlannerSchemaV15.LabelAssociation(itinerary: itinerary, category: category)
    } else if value.owner.kind == .itinerary, let itinerary = itineraries[value.owner.id], let tag {
      association = PlannerSchemaV15.LabelAssociation(itinerary: itinerary, tag: tag)
    } else {
      throw PlannerFailure("missingReference", "Imported label bindings cannot resolve.")
    }
    association.id = value.id
    association.lifetimeId = value.lifetimeId
    context.insert(association)
  }
  let links = try plannerImportRecords(
    PlannerSchemaV15.OwnedLink.self, identity: \.id, context: context)
  for value in backup.ownedLinks {
    if let link = links[value.id] {
      link.rank = value.rank
      link.originalUrl = value.originalUrl
      link.label = value.label
      link.kind = value.kind.rawValue
      continue
    }
    let link: PlannerSchemaV15.OwnedLink
    if value.owner.kind == .item, let item = items[value.owner.id] {
      link = PlannerSchemaV15.OwnedLink(
        snapshot: .init(
          id: value.id, lifetimeId: value.lifetimeId, rank: value.rank,
          originalUrl: value.originalUrl, label: value.label, kind: value.kind), owner: item)
    } else if value.owner.kind == .itinerary, let itinerary = itineraries[value.owner.id] {
      link = try PlannerSchemaV15.OwnedLink(
        input: .init(originalUrl: value.originalUrl, label: value.label),
        rank: value.rank, owner: itinerary)
      link.id = value.id
      link.lifetimeId = value.lifetimeId
    } else {
      throw PlannerFailure("missingReference", "Imported bookmark owner cannot resolve.")
    }
    context.insert(link)
  }
  let schedules = try plannerImportRecords(
    PlannerSchemaV15.Schedule.self, identity: \.id, context: context)
  for value in backup.schedules {
    if let schedule = schedules[value.id] {
      try schedule.replace(with: value.form)
      continue
    }
    let snapshot = ScheduleSnapshot(id: value.id, lifetimeId: value.lifetimeId, form: value.form)
    let schedule: PlannerSchemaV15.Schedule
    if value.source.kind == .item, let item = items[value.source.id] {
      schedule = try PlannerSchemaV15.Schedule(snapshot: snapshot, owner: item)
    } else if value.source.kind == .itinerary, let itinerary = itineraries[value.source.id] {
      schedule = try PlannerSchemaV15.Schedule(snapshot: snapshot, owner: itinerary)
    } else {
      throw PlannerFailure("missingReference", "Imported Schedule owner cannot resolve.")
    }
    context.insert(schedule)
  }
  let lineageRecords = try context.fetch(FetchDescriptor<PlannerSchemaV16.LineageRecord>())
  for value in backup.deletionMarkers {
    let target: PortableDeletionTarget
    switch value.target {
    case .source(let source, let lifetimeId):
      target = .source(.init(kind: source.kind.rawValue, id: source.id, lifetimeId: lifetimeId))
    case .membership(let identifier, let lifetimeId):
      target = .membership(.init(kind: "membership", id: identifier, lifetimeId: lifetimeId))
    case .itineraryEntry(let identifier, let lifetimeId):
      target = .itineraryEntry(id: identifier, lifetimeId: lifetimeId)
    case .labelAssociation(let identifier, let lifetimeId):
      target = .labelAssociation(id: identifier, lifetimeId: lifetimeId)
    case .ownedLink(let identifier, let lifetimeId):
      target = .ownedLink(id: identifier, lifetimeId: lifetimeId)
    case .expandedCompletion(let expandedContext):
      target = .expandedCompletion(expandedContext)
    }
    let marker = PortableDeletionMarker(
      deletionId: value.deletionId, operationId: value.operationId, target: target,
      closedFamilyId: value.closedFamilyId)
    if case .expandedCompletion = target {
      try plannerStageLineageRecord(
        marker, identifier: value.deletionId, kind: "deletionMarker",
        records: lineageRecords, context: context)
    } else {
      try context.insert(PlannerSchemaV4.DeletionMarker(marker))
    }
  }
  for alias in backup.contextAliases {
    try plannerStageLineageRecord(
      alias, identifier: alias.aliasId, kind: "contextAlias", records: lineageRecords,
      context: context)
  }
  for change in backup.completionChanges {
    try plannerStageLineageRecord(
      change, identifier: change.id, kind: "completionChange", records: lineageRecords,
      context: context)
  }
  for family in backup.restorationFamilies {
    try plannerStageLineageRecord(
      family, identifier: family.familyId, kind: "restorationFamily", records: lineageRecords,
      context: context)
  }
}

private func plannerStageLineageRecord<Value: Encodable>(
  _ value: Value, identifier: UUID, kind: String,
  records: [PlannerSchemaV16.LineageRecord], context: ModelContext
) throws {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  let data = try encoder.encode(value)
  if let record = records.first(where: {
    $0.recordIdentifier == identifier && $0.recordKind == kind
  }) {
    if record.recordData != data { record.recordData = data }
    return
  }
  context.insert(PlannerSchemaV16.LineageRecord(identifier: identifier, kind: kind, data: data))
}

private func plannerImportRecords<Record: PersistentModel>(
  _ recordType: Record.Type, identity: KeyPath<Record, UUID?>, context: ModelContext
) throws -> [UUID: Record] {
  var records: [UUID: Record] = [:]
  for record in try context.fetch(FetchDescriptor<Record>()) {
    guard let identifier = record[keyPath: identity], records[identifier] == nil else {
      throw PlannerFailure(
        "readUnavailable", "Existing import bindings have unresolved or duplicate identity.")
    }
    records[identifier] = record
  }
  return records
}
