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
