import Foundation

public struct PlannerPortableMembership: Sendable, Equatable {
  public let id: UUID
  public let lifetimeId: UUID
  public let list: PlannerEntityReference
  public let listLifetimeId: UUID
  public let item: PlannerEntityReference
  public let itemLifetimeId: UUID
  public let rank: Int64
  public let localDone: Bool
}

struct PortableMembershipRecord: Codable {
  let id: UUID
  let lifetimeId: UUID
  let list: PlannerBoundIdentity
  let item: PlannerBoundIdentity
  let rank: String
  let localDone: Bool

  init(_ membership: MembershipSnapshot) {
    id = membership.id
    lifetimeId = membership.lifetimeId
    list = membership.list
    item = membership.item
    rank = String(membership.rank)
    localDone = membership.localDone
  }

  func validated(items: [PortableItemRecord], lists: [PortableListRecord]) throws
    -> PlannerPortableMembership
  {
    guard list.kind == "list", item.kind == "item",
      lists.contains(where: { $0.id == list.id && $0.lifetimeId == list.lifetimeId }),
      items.contains(where: { $0.id == item.id && $0.lifetimeId == item.lifetimeId }),
      let parsedRank = Int64(rank), String(parsedRank) == rank
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The membership has invalid bindings or rank.")
    }
    return PlannerPortableMembership(
      id: id, lifetimeId: lifetimeId, list: PlannerEntityReference(kind: .list, id: list.id),
      listLifetimeId: list.lifetimeId, item: PlannerEntityReference(kind: .item, id: item.id),
      itemLifetimeId: item.lifetimeId, rank: parsedRank, localDone: localDone)
  }
}
