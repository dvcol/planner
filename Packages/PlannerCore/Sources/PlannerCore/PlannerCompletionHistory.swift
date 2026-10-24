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
) -> [PlannerPortableCompletionContext: Bool] {
  let changesByIdentifier = Dictionary(uniqueKeysWithValues: changes.map { ($0.id, $0) })
  return Dictionary(grouping: aliases, by: \.canonicalContext).mapValues {
    plannerCompletionHistoryValue(contributions: $0, changes: changesByIdentifier)
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
