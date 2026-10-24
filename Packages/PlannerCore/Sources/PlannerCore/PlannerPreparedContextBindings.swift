import Foundation

struct PlannerPreparedContextBindings {
  private let graph: PlannerImportGraph

  init(_ snapshot: PlannerDataSnapshot) throws {
    graph = PlannerImportGraph(backup: try snapshot.validated().backup)
  }

  func bindings(for command: PlannerCommand) throws -> [PlannerBoundIdentity] {
    do {
      switch command {
      case .setCompletion(.appearance(let selected), _): return try appearance(selected)
      case .reorderMembership(let listIdentifier, let membershipIdentifier, let placement):
        return try reordering(
          listIdentifier: listIdentifier, membershipIdentifier: membershipIdentifier,
          placement: placement)
      case .setBulkCompletion(let scope, _): return try bulk(scope)
      default: throw missing()
      }
    } catch let failure as PlannerFailure where failure.code == "missingReference" {
      throw PlannerFailure(
        "operationPayloadMismatch", "The saved preparation describes another contextual action.")
    }
  }

  private func appearance(_ selected: PlannerAppearance) throws -> [PlannerBoundIdentity] {
    switch selected {
    case .listMembership(let listIdentifier, let membershipIdentifier):
      return membershipBindings(
        try graph.resolvedMembershipForAction(
          listIdentifier: listIdentifier, membershipIdentifier: membershipIdentifier
        ).nativeSnapshot)
    case .directItineraryItem(let itineraryIdentifier, let entryIdentifier):
      return directBindings(
        try entry(entryIdentifier, itineraryIdentifier: itineraryIdentifier, sourceKind: .item))
    case .expandedListItem(let itineraryIdentifier, let entryIdentifier, let membershipIdentifier):
      let selectedEntry = try entry(
        entryIdentifier, itineraryIdentifier: itineraryIdentifier, sourceKind: .list)
      let member = try graph.resolvedMembershipForAction(
        listIdentifier: selectedEntry.source.id, membershipIdentifier: membershipIdentifier
      ).nativeSnapshot
      guard member.list.lifetimeId == selectedEntry.sourceLifetimeId else { throw missing() }
      return expandedBindings(selectedEntry, membership: member)
    }
  }

  private func reordering(
    listIdentifier: UUID, membershipIdentifier: UUID, placement: PlannerPlacement
  ) throws
    -> [PlannerBoundIdentity]
  {
    let member = try graph.resolvedMembershipForAction(
      listIdentifier: listIdentifier, membershipIdentifier: membershipIdentifier
    )
    .nativeSnapshot
    var bindings = membershipBindings(member)
    switch placement {
    case .before(let identifier), .after(let identifier):
      let anchor = try graph.resolvedMembershipForAction(
        listIdentifier: listIdentifier, membershipIdentifier: identifier)
      bindings.append(.init(kind: "membership", id: anchor.id, lifetimeId: anchor.lifetimeId))
    case .first, .last: break
    }
    return bindings
  }

  private func bulk(_ scope: PlannerBulkScope) throws -> [PlannerBoundIdentity] {
    if case .list(let listIdentifier) = scope {
      let owner = try source(.init(kind: .list, id: listIdentifier))
      return unique([owner] + memberships(in: owner).flatMap(membershipBindings))
    }
    let itineraryIdentifier: UUID
    let entryIdentifier: UUID?
    switch scope {
    case .itinerary(let identifier):
      itineraryIdentifier = identifier
      entryIdentifier = nil
    case .itineraryListEntry(let identifier, let selected):
      itineraryIdentifier = identifier
      entryIdentifier = selected
    case .list: throw missing()
    }
    let owner = try source(.init(kind: .itinerary, id: itineraryIdentifier))
    let selected = graph.backup.itineraryEntries.filter {
      $0.itinerary.id == itineraryIdentifier && $0.itineraryLifetimeId == owner.lifetimeId
        && (entryIdentifier == nil || $0.id == entryIdentifier)
    }
    if entryIdentifier != nil {
      guard selected.count == 1, selected.first?.source.kind == .list else { throw missing() }
    }
    var bindings = [owner]
    for selectedEntry in selected {
      if selectedEntry.source.kind == .item {
        bindings += directBindings(selectedEntry)
        continue
      }
      let list = PlannerBoundIdentity(
        kind: "list", id: selectedEntry.source.id, lifetimeId: selectedEntry.sourceLifetimeId)
      bindings += [list, entryBinding(selectedEntry)]
      for member in memberships(in: list) {
        bindings += expandedBindings(selectedEntry, membership: member)
      }
    }
    return unique(bindings)
  }

  private func memberships(in list: PlannerBoundIdentity) -> [MembershipSnapshot] {
    graph.backup.memberships.filter {
      $0.list.id == list.id && $0.listLifetimeId == list.lifetimeId
    }.map(\.nativeSnapshot)
  }

  private func membershipBindings(_ member: MembershipSnapshot) -> [PlannerBoundIdentity] {
    [
      .init(kind: "membership", id: member.id, lifetimeId: member.lifetimeId), member.list,
      member.item,
    ]
  }

  private func directBindings(_ entry: PlannerPortableItineraryEntry) -> [PlannerBoundIdentity] {
    [
      entryBinding(entry),
      .init(kind: "itinerary", id: entry.itinerary.id, lifetimeId: entry.itineraryLifetimeId),
      .init(kind: "item", id: entry.source.id, lifetimeId: entry.sourceLifetimeId),
    ]
  }

  private func expandedBindings(
    _ entry: PlannerPortableItineraryEntry, membership: MembershipSnapshot
  )
    -> [PlannerBoundIdentity]
  {
    [
      .init(kind: "itinerary", id: entry.itinerary.id, lifetimeId: entry.itineraryLifetimeId),
      membership.list, membership.item, entryBinding(entry),
      .init(kind: "membership", id: membership.id, lifetimeId: membership.lifetimeId),
    ]
  }

  private func entryBinding(_ entry: PlannerPortableItineraryEntry) -> PlannerBoundIdentity {
    .init(kind: "itineraryEntry", id: entry.id, lifetimeId: entry.lifetimeId)
  }

  private func entry(_ identifier: UUID, itineraryIdentifier: UUID, sourceKind: PlannerEntityKind)
    throws
    -> PlannerPortableItineraryEntry
  {
    let entries = graph.backup.itineraryEntries.filter {
      $0.id == identifier && $0.itinerary.id == itineraryIdentifier && $0.source.kind == sourceKind
    }
    guard entries.count == 1, let entry = entries.first else { throw missing() }
    return entry
  }

  private func source(_ reference: PlannerEntityReference) throws -> PlannerBoundIdentity {
    guard
      let source = graph.backup.sources.first(where: { $0.importBinding.reference == reference })
    else {
      throw missing()
    }
    let bound = source.importBinding
    return .init(kind: bound.kind.rawValue, id: bound.id, lifetimeId: bound.lifetimeId)
  }

  private func unique(_ bindings: [PlannerBoundIdentity]) -> [PlannerBoundIdentity] {
    var seen: Set<Data> = []
    return bindings.filter { seen.insert($0.canonicalValue.encoded()).inserted }
  }

  private func missing() -> PlannerFailure {
    .init("missingReference", "The original context does not resolve in the saved preparation.")
  }
}

extension RecoveryPreparedProposal {
  /// Saved proposal bindings are review data, never proof that an operation applied.
  func contextualBindings(for command: PlannerCommand) throws -> [PlannerBoundIdentity] {
    if let resolvedBindings { return resolvedBindings }
    return try PlannerPreparedContextBindings(proposedBackup).bindings(for: command)
  }
}
