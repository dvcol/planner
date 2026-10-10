import Foundation

struct LabelAssociationSnapshot {
  let id: UUID
  let lifetimeId: UUID
  let owner: PlannerBoundIdentity
  let label: PlannerBoundIdentity

  var ownerReference: PlannerEntityReference {
    PlannerEntityReference(kind: owner.kind == "itinerary" ? .itinerary : .item, id: owner.id)
  }
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

extension PlannerItemChanges {
  var changedLabelKinds: Set<String> {
    var kinds: Set<String> = []
    if case .set = categoryIds { kinds.insert("category") }
    if case .set = tagIds { kinds.insert("tag") }
    return kinds
  }

  func labelAssociationBindings(in item: ItemSnapshot) -> [PlannerBoundIdentity] {
    item.labelAssociations.filter { changedLabelKinds.contains($0.label.kind) }.map {
      PlannerBoundIdentity(kind: "labelAssociation", id: $0.id, lifetimeId: $0.lifetimeId)
    }
  }

  func applyingLabelAssociations(to item: ItemSnapshot, selectedLabels: [PlannerBoundIdentity])
    -> [LabelAssociationSnapshot]
  {
    let retained = item.labelAssociations.filter { !changedLabelKinds.contains($0.label.kind) }
    let selected = selectedLabels.map { label in
      if let existing = item.labelAssociations.first(where: {
        $0.label.kind == label.kind && $0.label.id == label.id
          && $0.label.lifetimeId == label.lifetimeId
      }) {
        return existing
      }
      let identifier = UUID()
      return LabelAssociationSnapshot(
        id: identifier, lifetimeId: identifier,
        owner: PlannerBoundIdentity(kind: "item", id: item.id, lifetimeId: item.lifetimeId),
        label: label)
    }
    return (retained + selected).sorted { $0.id.uuidString < $1.id.uuidString }
  }
}
