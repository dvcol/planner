import Foundation

struct PlannerImportReferenceRemoval {
  let references: Set<PlannerReferenceRead>
  let targets: [PlannerPortableDeletionTarget]

  init(current: PlannerPortableBackup, changes: [PlannerImportReferenceChange]) {
    var references = Set(changes.filter { $0.change == .remove }.map(\.reference))
    let removedMemberships = Set(
      references.compactMap { reference -> UUID? in
        guard case .membership(let identifier, _, _) = reference else { return nil }
        return identifier
      })
    let removedEntries = Set(
      references.compactMap { reference -> UUID? in
        guard case .itineraryEntry(let identifier, _, _) = reference else { return nil }
        return identifier
      })
    let entries = Dictionary(uniqueKeysWithValues: current.itineraryEntries.map { ($0.id, $0) })
    for expanded in current.expandedCompletions {
      guard
        removedMemberships.contains(expanded.context.membershipId)
          || removedEntries.contains(expanded.context.listEntryId),
        let entry = entries[expanded.context.listEntryId]
      else { continue }
      references.insert(
        .expandedCompletion(
          itineraryId: entry.itinerary.id, listEntryId: entry.id,
          membershipId: expanded.context.membershipId))
    }
    self.references = references
    var targets: [PlannerPortableDeletionTarget] = []
    for value in current.memberships where removedMemberships.contains(value.id) {
      targets.append(.membership(id: value.id, lifetimeId: value.lifetimeId))
    }
    for value in current.itineraryEntries where removedEntries.contains(value.id) {
      targets.append(.itineraryEntry(id: value.id, lifetimeId: value.lifetimeId))
    }
    for value in current.labelAssociations
    where references.contains(
      .labelAssociation(id: value.id, owner: value.owner, label: value.label))
    {
      targets.append(.labelAssociation(id: value.id, lifetimeId: value.lifetimeId))
    }
    for value in current.ownedLinks
    where references.contains(.ownedLink(id: value.id, owner: value.owner.reference)) {
      targets.append(.ownedLink(id: value.id, lifetimeId: value.lifetimeId))
    }
    for value in current.schedules
    where references.contains(.schedule(id: value.id, source: value.source)) {
      targets.append(.source(.init(kind: .schedule, id: value.id), lifetimeId: value.lifetimeId))
    }
    let memberships = Dictionary(uniqueKeysWithValues: current.memberships.map { ($0.id, $0) })
    for reference in references {
      guard case .expandedCompletion(_, let entryIdentifier, let membershipIdentifier) = reference,
        !removedMemberships.contains(membershipIdentifier),
        !removedEntries.contains(entryIdentifier), let entry = entries[entryIdentifier],
        let membership = memberships[membershipIdentifier]
      else { continue }
      targets.append(
        .expandedCompletion(
          .init(
            listEntryId: entry.id, listEntryLifetimeId: entry.lifetimeId,
            membershipId: membership.id, membershipLifetimeId: membership.lifetimeId)))
    }
    self.targets = targets
  }

  func closes(_ context: PlannerPortableCompletionContext) -> Bool {
    targets.contains { $0.closes(context) }
  }

  func removes(
    _ value: PlannerPortableExpandedCompletion, entries: [UUID: PlannerPortableItineraryEntry]
  )
    -> Bool
  {
    guard let entry = entries[value.context.listEntryId] else { return false }
    return references.contains(
      .expandedCompletion(
        itineraryId: entry.itinerary.id, listEntryId: entry.id,
        membershipId: value.context.membershipId))
  }
}
