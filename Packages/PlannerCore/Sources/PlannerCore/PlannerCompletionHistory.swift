import Foundation

func plannerCompletionHistoryValue(
  contributions: [PlannerPortableContextAlias], changes: [UUID: PlannerPortableCompletionChange],
  deletionMarkers: [PlannerPortableDeletionMarker]
) -> Bool {
  let winner = plannerCompletionHistoryHeads(
    contributions: contributions, changes: changes, deletionMarkers: deletionMarkers
  )
  .min { $0.id.uuidString < $1.id.uuidString }
  let permitsInitial = plannerExpandedCompletionDeletionIdentifiers(
    contributions: contributions, deletionMarkers: deletionMarkers
  ).isEmpty
  return winner?.done ?? (permitsInitial && contributions.contains(where: \.initialDone))
}

func plannerCompletionHistoryHeads(
  contributions: [PlannerPortableContextAlias], changes: [UUID: PlannerPortableCompletionChange],
  deletionMarkers: [PlannerPortableDeletionMarker]
) -> [PlannerPortableCompletionChange] {
  let closures = plannerExpandedCompletionDeletionIdentifiers(
    contributions: contributions, deletionMarkers: deletionMarkers)
  let selectedIdentifiers: Set<UUID>
  if closures.isEmpty {
    selectedIdentifiers = Set(contributions.compactMap(\.currentChangeId))
  } else {
    // A stale head cannot erase an independently retained, informed assertion on the same alias.
    let aliasIdentifiers = Set(contributions.map(\.aliasId))
    selectedIdentifiers = Set(
      changes.values.filter {
        aliasIdentifiers.contains($0.aliasId)
      }.map(\.id))
  }
  let selected = selectedIdentifiers.compactMap { changes[$0] }.filter {
    closures.isSubset(of: Set($0.observedExpandedCompletionDeletionIds))
  }
  let observed = plannerObservedCompletionChanges(selected.map(\.id), changes: changes)
  return selected.filter { !observed.contains($0.id) }
}

func plannerCompletionHistoryStates(
  aliases: [PlannerPortableContextAlias], changes: [PlannerPortableCompletionChange],
  deletionMarkers: [PlannerPortableDeletionMarker]
) throws -> [PlannerPortableCompletionContext: Bool] {
  do {
    try plannerValidateCompletionHistoryReferences(
      aliases: aliases, changes: changes, deletionMarkers: deletionMarkers)
  } catch let failure as PlannerFailure {
    throw PlannerFailure(
      "readUnavailable", "Saved completion history is unavailable: " + failure.message,
      propertyPath: failure.propertyPath)
  }
  let changesByIdentifier = Dictionary(uniqueKeysWithValues: changes.map { ($0.id, $0) })
  return Dictionary(grouping: aliases, by: \.canonicalContext).mapValues {
    plannerCompletionHistoryValue(
      contributions: $0, changes: changesByIdentifier, deletionMarkers: deletionMarkers)
  }
}

func plannerValidateCompletionHistoryReferences(
  aliases: [PlannerPortableContextAlias], changes: [PlannerPortableCompletionChange],
  deletionMarkers: [PlannerPortableDeletionMarker]
) throws {
  let aliasesByIdentifier = Dictionary(uniqueKeysWithValues: aliases.map { ($0.aliasId, $0) })
  let changesByIdentifier = Dictionary(uniqueKeysWithValues: changes.map { ($0.id, $0) })
  func failure(_ message: String, _ path: String) -> PlannerFailure {
    .init("invalidInput", message, propertyPath: path)
  }
  for (index, alias) in aliases.enumerated() {
    switch (alias.context, alias.canonicalContext) {
    case (.listMembership, .listMembership): break
    case (
      .directItineraryItem(let originalEntryIdentifier, _),
      .directItineraryItem(let canonicalEntryIdentifier, _)
    ) where originalEntryIdentifier == canonicalEntryIdentifier: break
    case (.expandedListItem(let originalContext), .expandedListItem(let canonicalContext))
    where originalContext.listEntryId == canonicalContext.listEntryId: break
    default:
      throw failure(
        "Aliases must retain the same logical context; repeated route entries stay independent.",
        "/contextAliases/\(index)/canonicalContext")
    }
    if let current = alias.currentChangeId {
      guard let change = changesByIdentifier[current], change.aliasId == alias.aliasId,
        change.context == alias.context
      else {
        throw failure(
          "The current change must resolve to this alias and context.",
          "/contextAliases/\(index)/currentChangeId")
      }
    }
  }
  for (index, change) in changes.enumerated() {
    let path = "/completionChanges/\(index)"
    guard Set(change.observedChangeIds).count == change.observedChangeIds.count else {
      throw failure(
        "Observed completion changes must be distinct.", path + "/observedChangeIds")
    }
    guard let alias = aliasesByIdentifier[change.aliasId], alias.context == change.context else {
      throw failure(
        "A completion change must resolve to its declared alias context.", path + "/aliasId")
    }
    let observationPath = path + "/observedExpandedCompletionDeletionIds"
    let observations = change.observedExpandedCompletionDeletionIds
    guard Set(observations).count == observations.count else {
      throw failure("Observed expanded completion deletions must be distinct.", observationPath)
    }
    let eligibleClosures = plannerExpandedCompletionDeletionIdentifiers(
      contributions: aliases.filter { $0.canonicalContext == alias.canonicalContext },
      deletionMarkers: deletionMarkers)
    for (observationIndex, identifier) in observations.enumerated() {
      guard case .expandedListItem = change.context, eligibleClosures.contains(identifier) else {
        throw failure(
          "An observed deletion must resolve within this proven expanded context.",
          observationPath + "/\(observationIndex)")
      }
    }
    for (predecessorIndex, predecessorId) in change.observedChangeIds.enumerated() {
      guard let predecessor = changesByIdentifier[predecessorId],
        let predecessorAlias = aliasesByIdentifier[predecessor.aliasId],
        predecessorAlias.canonicalContext == alias.canonicalContext
      else {
        throw failure(
          "An observed change must resolve within the same canonical context.",
          path + "/observedChangeIds/\(predecessorIndex)")
      }
    }
  }
  var remaining = Set(changesByIdentifier.keys)
  while !remaining.isEmpty {
    let ready = remaining.filter { identifier in
      changesByIdentifier[identifier]!.observedChangeIds.allSatisfy { !remaining.contains($0) }
    }
    guard !ready.isEmpty else {
      let index = changes.firstIndex { remaining.contains($0.id) }!
      throw failure(
        "Completion history must not contain a cycle.",
        "/completionChanges/\(index)/observedChangeIds")
    }
    remaining.subtract(ready)
  }
}

private func plannerObservedCompletionChanges(
  _ identifiers: [UUID], changes: [UUID: PlannerPortableCompletionChange]
) -> Set<UUID> {
  var pending = identifiers.flatMap { changes[$0]?.observedChangeIds ?? [] }
  var seen: Set<UUID> = []
  while let next = pending.popLast() {
    guard seen.insert(next).inserted else { continue }
    pending.append(contentsOf: changes[next]?.observedChangeIds ?? [])
  }
  return seen
}

/// Callers establish alias admission and lifetimes before sharing a closure basis.
func plannerExpandedCompletionDeletionIdentifiers(
  contributions: [PlannerPortableContextAlias],
  deletionMarkers: [PlannerPortableDeletionMarker]
) -> Set<UUID> {
  let contexts = Set(contributions.flatMap { [$0.context, $0.canonicalContext] })
  return Set(
    deletionMarkers.compactMap { marker in
      guard marker.closedFamilyId == nil,
        case .expandedCompletion(let context) = marker.target,
        contexts.contains(.expandedListItem(context))
      else { return nil }
      return marker.deletionId
    })
}

extension PortableDeletionMarker {
  var expandedCompletionMarker: PlannerPortableDeletionMarker? {
    guard case .expandedCompletion(let context) = target else { return nil }
    return .init(
      deletionId: deletionId, operationId: operationId, target: .expandedCompletion(context),
      closedFamilyId: closedFamilyId)
  }
}

struct PlannerExpandedCompletionEvidence: Codable, Equatable {
  let context: PlannerExpandedContext
  let observedExpandedCompletionDeletionIds: [UUID]

  init(context: PlannerExpandedContext, observedExpandedCompletionDeletionIds: [UUID]) {
    self.context = context
    self.observedExpandedCompletionDeletionIds = observedExpandedCompletionDeletionIds.sorted {
      $0.uuidString < $1.uuidString
    }
  }

  init(from decoder: any Decoder) throws {
    let node = PlannerImportNode(value: try PlannerImportJSON(from: decoder), path: "")
    let fields = try node.record(["context", "observedExpandedCompletionDeletionIds"])
    context = try fields.child("context").expandedContext()
    observedExpandedCompletionDeletionIds = try fields.child(
      "observedExpandedCompletionDeletionIds"
    )
    .array().map { try $0.identifier() }
    guard
      Set(observedExpandedCompletionDeletionIds).count
        == observedExpandedCompletionDeletionIds.count
    else {
      throw PlannerFailure("recoveryIntegrityFailure", "Expanded observations must be distinct.")
    }
  }

  var canonicalValue: PlannerCanonicalValue {
    .record([
      "context": context.importCanonicalValue,
      "observedExpandedCompletionDeletionIds": .identitySet(
        observedExpandedCompletionDeletionIds.map(PlannerCanonicalValue.identity)),
    ])
  }
}

func plannerSortedExpandedCompletionEvidence(
  _ evidence: [PlannerExpandedCompletionEvidence]
) -> [PlannerExpandedCompletionEvidence] {
  evidence.map {
    .init(
      context: $0.context,
      observedExpandedCompletionDeletionIds: $0.observedExpandedCompletionDeletionIds.sorted {
        $0.uuidString < $1.uuidString
      })
  }.sorted { $0.context.orderingKey < $1.context.orderingKey }
}
