import Foundation

func plannerCompletionHistoryValue(
  contributions: [PlannerPortableContextAlias], changes: [UUID: PlannerPortableCompletionChange]
) -> Bool {
  let selected = contributions.compactMap(\.currentChangeId).compactMap { changes[$0] }
  let maximal = selected.filter { candidate in
    !selected.contains { other in
      plannerObservedCompletionChanges(other.id, changes: changes).contains(candidate.id)
    }
  }
  let winner = maximal.min { $0.id.uuidString < $1.id.uuidString }
  return winner?.done ?? contributions.contains(where: \.initialDone)
}

func plannerCompletionHistoryStates(
  aliases: [PlannerPortableContextAlias], changes: [PlannerPortableCompletionChange]
) throws -> [PlannerPortableCompletionContext: Bool] {
  do {
    try plannerValidateCompletionHistoryReferences(aliases: aliases, changes: changes)
  } catch let failure as PlannerFailure {
    throw PlannerFailure(
      "readUnavailable", "Saved completion history is unavailable: " + failure.message,
      propertyPath: failure.propertyPath)
  }
  let changesByIdentifier = Dictionary(uniqueKeysWithValues: changes.map { ($0.id, $0) })
  return Dictionary(grouping: aliases, by: \.canonicalContext).mapValues {
    plannerCompletionHistoryValue(contributions: $0, changes: changesByIdentifier)
  }
}

func plannerValidateCompletionHistoryReferences(
  aliases: [PlannerPortableContextAlias], changes: [PlannerPortableCompletionChange]
) throws {
  let aliasesByIdentifier = Dictionary(uniqueKeysWithValues: aliases.map { ($0.aliasId, $0) })
  let changesByIdentifier = Dictionary(uniqueKeysWithValues: changes.map { ($0.id, $0) })
  func failure(_ message: String, _ path: String) -> PlannerFailure {
    .init("invalidInput", message, propertyPath: path)
  }
  for (index, alias) in aliases.enumerated() {
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
  _ identifier: UUID, changes: [UUID: PlannerPortableCompletionChange]
) -> Set<UUID> {
  var pending = changes[identifier]?.observedChangeIds ?? []
  var seen: Set<UUID> = []
  while let next = pending.popLast() {
    guard seen.insert(next).inserted else { continue }
    pending.append(contentsOf: changes[next]?.observedChangeIds ?? [])
  }
  return seen
}
