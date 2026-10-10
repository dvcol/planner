import Foundation

struct LabelAssociationSnapshot {
  let id: UUID
  let lifetimeId: UUID
  let owner: PlannerBoundIdentity
  let label: PlannerBoundIdentity

  var ownerReference: PlannerEntityReference { PlannerEntityReference(kind: .item, id: owner.id) }
  var labelReference: PlannerEntityReference {
    PlannerEntityReference(kind: label.kind == "category" ? .category : .tag, id: label.id)
  }
  var reference: PlannerReferenceRead {
    .labelAssociation(id: id, owner: ownerReference, label: labelReference)
  }
  var selectionValue: PlannerCanonicalValue {
    .record(["id": .identity(label.id), "lifetimeId": .identity(label.lifetimeId)])
  }
}
