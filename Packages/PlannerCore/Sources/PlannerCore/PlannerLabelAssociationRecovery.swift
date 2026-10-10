import Foundation

public struct PlannerPortableLabelAssociation: Sendable {
  public let id: UUID
  public let lifetimeId: UUID
  public let owner: PlannerEntityReference
  public let ownerLifetimeId: UUID
  public let label: PlannerEntityReference
  public let labelLifetimeId: UUID
}

struct PortableLabelAssociationRecord: Codable {
  let id: UUID
  let lifetimeId: UUID
  let owner: PlannerBoundIdentity
  let label: PlannerBoundIdentity

  init(_ snapshot: LabelAssociationSnapshot) {
    id = snapshot.id
    lifetimeId = snapshot.lifetimeId
    owner = snapshot.owner
    label = snapshot.label
  }

  func validated(
    items: [PortableItemRecord], categories: [PlannerPortableCategory],
    tags: [PlannerPortableTag]
  ) throws -> PlannerPortableLabelAssociation {
    guard owner.kind == "item",
      items.contains(where: {
        $0.id == owner.id && $0.lifetimeId == owner.lifetimeId
      })
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The label association has an unresolved Item owner.")
    }
    let labelKind: PlannerEntityKind
    switch label.kind {
    case "category":
      guard categories.contains(where: { $0.id == label.id && $0.lifetimeId == label.lifetimeId })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The label association has an unresolved Category.")
      }
      labelKind = .category
    case "tag":
      guard tags.contains(where: { $0.id == label.id && $0.lifetimeId == label.lifetimeId }) else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The label association has an unresolved Tag.")
      }
      labelKind = .tag
    default:
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The association has an unsupported label kind.")
    }
    return PlannerPortableLabelAssociation(
      id: id, lifetimeId: lifetimeId,
      owner: PlannerEntityReference(kind: .item, id: owner.id), ownerLifetimeId: owner.lifetimeId,
      label: PlannerEntityReference(kind: labelKind, id: label.id),
      labelLifetimeId: label.lifetimeId)
  }
}
