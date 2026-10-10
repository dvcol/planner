import Foundation

public struct PlannerExpandedContext: Sendable, Hashable, Codable {
  public let listEntryId: UUID
  public let listEntryLifetimeId: UUID
  public let membershipId: UUID
  public let membershipLifetimeId: UUID

  var orderingKey: String {
    [listEntryId, listEntryLifetimeId, membershipId, membershipLifetimeId].map(\.uuidString).joined(
      separator: ":")
  }
}

struct ExpandedCompletionSnapshot {
  let context: PlannerExpandedContext
  let localDone: Bool
  let itineraryId: UUID

  var reference: PlannerReferenceRead {
    .expandedCompletion(
      itineraryId: itineraryId, listEntryId: context.listEntryId,
      membershipId: context.membershipId)
  }
}

public struct PlannerPortableExpandedCompletion: Sendable, Equatable {
  public let context: PlannerExpandedContext
  public let localDone: Bool
}

struct PortableExpandedCompletionRecord: Codable {
  let context: PlannerExpandedContext
  let localDone: Bool

  init(_ snapshot: ExpandedCompletionSnapshot) {
    context = snapshot.context
    localDone = snapshot.localDone
  }

  func validated(entries: [PortableItineraryEntryRecord], memberships: [PortableMembershipRecord])
    throws -> PlannerPortableExpandedCompletion
  {
    guard
      let entry = entries.first(where: {
        $0.id == context.listEntryId && $0.lifetimeId == context.listEntryLifetimeId
      }),
      entry.source.kind == "list",
      let membership = memberships.first(where: {
        $0.id == context.membershipId && $0.lifetimeId == context.membershipLifetimeId
      }),
      membership.list.id == entry.source.id, membership.list.lifetimeId == entry.source.lifetimeId
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure",
        "The expanded completion has unresolved entry or membership bindings.")
    }
    return .init(context: context, localDone: localDone)
  }
}

func removingExpandedContexts(
  for membership: MembershipSnapshot, from itineraries: [ItinerarySnapshot]
) -> [ItinerarySnapshot] {
  itineraries.map { original in
    var itinerary = original
    itinerary.entries = original.entries.map { originalEntry in
      var entry = originalEntry
      entry.expandedCompletions.removeAll {
        $0.context.membershipId == membership.id
          && $0.context.membershipLifetimeId == membership.lifetimeId
      }
      return entry
    }
    return itinerary
  }
}
