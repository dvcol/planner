import Foundation
import SwiftData

enum BulkCompletionTarget {
  case membership(PlannerSchemaV13.Membership, MembershipSnapshot)
  case direct(PlannerSchemaV13.ItineraryEntry, ItineraryEntrySnapshot)
  case expanded(
    PlannerSchemaV13.ItineraryEntry, ItineraryEntrySnapshot,
    PlannerSchemaV13.Membership, MembershipSnapshot)

  var appearance: PlannerAppearance {
    switch self {
    case .membership(_, let membership):
      return .listMembership(listId: membership.list.id, membershipId: membership.id)
    case .direct(_, let entry):
      return .directItineraryItem(itineraryId: entry.itinerary.id, entryId: entry.id)
    case .expanded(_, let entry, _, let membership):
      return .expandedListItem(
        itineraryId: entry.itinerary.id, listEntryId: entry.id, membershipId: membership.id)
    }
  }

  var reference: PlannerReferenceRead {
    switch self {
    case .membership(_, let membership): return membership.reference
    case .direct(_, let entry): return entry.reference
    case .expanded(_, let entry, _, let membership):
      return .expandedCompletion(
        itineraryId: entry.itinerary.id, listEntryId: entry.id, membershipId: membership.id)
    }
  }

  var bindings: [PlannerBoundIdentity] {
    switch self {
    case .membership(_, let membership):
      return [
        membership.list, membership.item,
        .init(kind: "membership", id: membership.id, lifetimeId: membership.lifetimeId),
      ]
    case .direct(_, let entry):
      return [
        entry.itinerary, entry.source,
        .init(kind: "itineraryEntry", id: entry.id, lifetimeId: entry.lifetimeId),
      ]
    case .expanded(_, let entry, _, let membership):
      return [
        entry.itinerary, entry.source, membership.item,
        .init(kind: "itineraryEntry", id: entry.id, lifetimeId: entry.lifetimeId),
        .init(kind: "membership", id: membership.id, lifetimeId: membership.lifetimeId),
      ]
    }
  }

  var localDone: Bool {
    switch self {
    case .membership(_, let membership): return membership.localDone
    case .direct(_, let entry): return entry.localDone == true
    case .expanded(_, let entry, _, let membership):
      return entry.expandedCompletions.first {
        $0.context == expandedContext(entry: entry, membership: membership)
      }?.localDone ?? false
    }
  }

  func apply(done: Bool, context: ModelContext) {
    switch self {
    case .membership(let record, _): record.localDone = done
    case .direct(let record, _): record.localDone = done
    case .expanded(let record, _, let membershipRecord, let membership):
      let existing = (record.expandedCompletions ?? []).first {
        $0.membershipId == membership.id && $0.membershipLifetimeId == membership.lifetimeId
      }
      if let existing {
        existing.localDone = done
      } else if done {
        context.insert(
          PlannerSchemaV13.ExpandedCompletion(
            listEntry: record, membership: membershipRecord, localDone: done))
      }
    }
  }
}

struct BulkCompletionResolution {
  let owner: PlannerBoundIdentity
  let list: PlannerSchemaV13.List?
  let itinerary: PlannerSchemaV13.Itinerary?
  let scopeBindings: [PlannerBoundIdentity]
  let targets: [BulkCompletionTarget]

  var bindings: [PlannerBoundIdentity] {
    var seen: Set<Data> = []
    return (scopeBindings + targets.flatMap(\.bindings)).filter {
      seen.insert($0.canonicalValue.encoded()).inserted
    }
  }
  var reference: PlannerEntityReference {
    .init(kind: list == nil ? .itinerary : .list, id: owner.id)
  }

  func membershipsAfter(_ memberships: [MembershipSnapshot], done: Bool) -> [MembershipSnapshot] {
    let identifiers = Set(
      targets.compactMap { target -> UUID? in
        if case .membership(_, let value) = target { return value.id }
        return nil
      })
    return memberships.map { value in
      guard identifiers.contains(value.id) else { return value }
      return .init(
        id: value.id, lifetimeId: value.lifetimeId, list: value.list, item: value.item,
        rank: value.rank, localDone: done)
    }
  }

  func itineraryAfter(_ value: ItinerarySnapshot, done: Bool, updatedAt: Date) -> ItinerarySnapshot
  {
    var directEntryIds: Set<UUID> = []
    var expandedMemberships: [UUID: [MembershipSnapshot]] = [:]
    for target in targets {
      switch target {
      case .membership: break
      case .direct(_, let entry): directEntryIds.insert(entry.id)
      case .expanded(_, let entry, _, let membership):
        expandedMemberships[entry.id, default: []].append(membership)
      }
    }
    let entries = value.entries.map { original in
      var completions = Dictionary(
        uniqueKeysWithValues: original.expandedCompletions.map { ($0.context, $0) })
      for membership in expandedMemberships[original.id] ?? [] {
        let binding = expandedContext(entry: original, membership: membership)
        guard done || completions[binding] != nil else { continue }
        completions[binding] = .init(context: binding, localDone: done, itineraryId: value.id)
      }
      return ItineraryEntrySnapshot(
        id: original.id, lifetimeId: original.lifetimeId, itinerary: original.itinerary,
        source: original.source, rank: original.rank,
        localDone: directEntryIds.contains(original.id) ? done : original.localDone,
        expandedCompletions: completions.values.sorted {
          $0.context.orderingKey < $1.context.orderingKey
        })
    }
    return .init(
      id: value.id, lifetimeId: value.lifetimeId, createdAt: value.createdAt, updatedAt: updatedAt,
      input: value.input, archived: value.archived, links: value.links,
      labelAssociations: value.labelAssociations, labels: value.labels, entries: entries)
  }
}

func resolveBulkCompletion(_ scope: PlannerBulkScope, context: ModelContext) throws
  -> BulkCompletionResolution
{
  if case .list(let listId) = scope {
    var descriptor = FetchDescriptor<PlannerSchemaV13.List>(
      predicate: #Predicate { $0.id == listId })
    descriptor.fetchLimit = 2
    let records = try context.fetch(descriptor)
    guard records.count == 1, let record = records.first else {
      throw PlannerFailure("missingReference", "The selected bulk List is missing or unresolved.")
    }
    let value = try record.value()
    let owner = PlannerBoundIdentity(kind: "list", id: value.id, lifetimeId: value.lifetimeId)
    let targets = try bulkMemberships(owner, context: context).map {
      BulkCompletionTarget.membership($0, try $0.value())
    }
    return .init(
      owner: owner, list: record, itinerary: nil, scopeBindings: [owner], targets: targets)
  }
  let itineraryId: UUID
  let listEntryId: UUID?
  switch scope {
  case .itinerary(let identifier):
    itineraryId = identifier
    listEntryId = nil
  case .itineraryListEntry(let identifier, let entryId):
    itineraryId = identifier
    listEntryId = entryId
  case .list: throw PlannerFailure("invalidInput", "Expected an itinerary scope.")
  }
  var descriptor = FetchDescriptor<PlannerSchemaV13.Itinerary>(
    predicate: #Predicate { $0.id == itineraryId })
  descriptor.fetchLimit = 2
  let records = try context.fetch(descriptor)
  guard records.count == 1, let record = records.first else {
    throw PlannerFailure(
      "missingReference", "The selected bulk Itinerary is missing or unresolved.")
  }
  let value = try record.value()
  let owner = PlannerBoundIdentity(kind: "itinerary", id: value.id, lifetimeId: value.lifetimeId)
  let lifetimeId = value.lifetimeId
  let entries = try context.fetch(
    FetchDescriptor<PlannerSchemaV13.ItineraryEntry>(
      predicate: #Predicate {
        $0.itineraryId == itineraryId && $0.itineraryLifetimeId == lifetimeId
      },
      sortBy: [SortDescriptor(\.rank), SortDescriptor(\.id)]))
  guard Set(try entries.map { try $0.value().id }).count == entries.count else {
    throw PlannerFailure("readUnavailable", "The bulk scope contains duplicate entries.")
  }
  let selected = entries.filter { listEntryId == nil || $0.id == listEntryId }
  var scopeBindings = [owner]
  if let listEntryId {
    guard selected.count == 1, let entry = selected.first, entry.sourceKind == "list" else {
      throw PlannerFailure("missingReference", "The selected itinerary List entry is unresolved.")
    }
    let binding = try entry.value()
    scopeBindings += [
      binding.source,
      .init(kind: "itineraryEntry", id: listEntryId, lifetimeId: binding.lifetimeId),
    ]
  }
  var targets: [BulkCompletionTarget] = []
  for entry in selected {
    let binding = try entry.value()
    if binding.source.kind == "item" {
      targets.append(.direct(entry, binding))
      continue
    }
    for membership in try bulkMemberships(binding.source, context: context) {
      targets.append(.expanded(entry, binding, membership, try membership.value()))
    }
    // Empty List entries still bind their identity/lifetime to the review.
    scopeBindings += [
      binding.source,
      .init(kind: "itineraryEntry", id: binding.id, lifetimeId: binding.lifetimeId),
    ]
  }
  return .init(
    owner: owner, list: nil, itinerary: record, scopeBindings: scopeBindings, targets: targets)
}

private func bulkMemberships(_ list: PlannerBoundIdentity, context: ModelContext) throws
  -> [PlannerSchemaV13.Membership]
{
  let listId = list.id
  let lifetimeId = list.lifetimeId
  let records = try context.fetch(
    FetchDescriptor<PlannerSchemaV13.Membership>(
      predicate: #Predicate { $0.listId == listId && $0.listLifetimeId == lifetimeId },
      sortBy: [SortDescriptor(\.rank), SortDescriptor(\.id)]))
  let values = try records.map { try $0.value() }
  guard Set(values.map(\.id)).count == values.count,
    Set(values.map { $0.item.id }).count == values.count
  else {
    throw PlannerFailure("readUnavailable", "The bulk scope contains duplicate memberships.")
  }
  return records
}

private func expandedContext(entry: ItineraryEntrySnapshot, membership: MembershipSnapshot)
  -> PlannerExpandedContext
{
  .init(
    listEntryId: entry.id, listEntryLifetimeId: entry.lifetimeId,
    membershipId: membership.id, membershipLifetimeId: membership.lifetimeId)
}

func bulkCompletionDigest(
  scope: PlannerBulkScope, done: Bool, identity: PlannerStoreIdentity,
  bindings: [PlannerBoundIdentity]
) -> String {
  let scopeValue: PlannerCanonicalValue
  switch scope {
  case .list(let listId):
    scopeValue = .record(["kind": .string("list"), "listId": .identity(listId)])
  case .itinerary(let itineraryId):
    scopeValue = .record(["kind": .string("itinerary"), "itineraryId": .identity(itineraryId)])
  case .itineraryListEntry(let itineraryId, let listEntryId):
    scopeValue = .record([
      "kind": .string("itineraryListEntry"), "itineraryId": .identity(itineraryId),
      "listEntryId": .identity(listEntryId),
    ])
  }
  let value = PlannerCanonicalValue.record([
    "command": .record([
      "type": .string("setBulkCompletion"), "scope": scopeValue, "done": .boolean(done),
    ]),
    "datasetId": .identity(identity.datasetId),
    "ownershipBinding": .string(identity.ownershipBinding),
    "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
  ])
  return plannerDigest(
    Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded(),
    prefix: "sha256-payload-v1:")
}
