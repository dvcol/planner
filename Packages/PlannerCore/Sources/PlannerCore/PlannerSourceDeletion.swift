import Foundation

func sourceDeletionDigest(
  source: PlannerEntityReference, identity: PlannerStoreIdentity,
  bindings: [PlannerBoundIdentity], removals: [PlannerReferenceRead]? = nil
) -> String {
  var fields: [String: PlannerCanonicalValue] = [
    "command": .record([
      "type": .string("deleteSource"),
      "source": .record(["kind": .string(source.kind.rawValue), "id": .identity(source.id)]),
    ]),
    "datasetId": .identity(identity.datasetId),
    "ownershipBinding": .string(identity.ownershipBinding),
    "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
  ]
  if let removals {
    fields["resolvedReferences"] = .identitySet(removals.map(\.deletionCanonicalValue))
  }
  let value = PlannerCanonicalValue.record(fields)
  return plannerDigest(
    Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded(),
    prefix: "sha256-payload-v1:")
}

extension PlannerReferenceRead {
  fileprivate var deletionCanonicalValue: PlannerCanonicalValue {
    switch self {
    case .ownedLink(let identifier, let owner):
      return .record([
        "kind": .string("ownedLink"), "id": .identity(identifier),
        "owner": owner.deletionCanonicalValue,
      ])
    case .schedule(let identifier, let source):
      return .record([
        "kind": .string("schedule"), "id": .identity(identifier),
        "source": source.deletionCanonicalValue,
      ])
    case .membership(let identifier, let list, let item):
      return .record([
        "kind": .string("membership"), "id": .identity(identifier),
        "list": list.deletionCanonicalValue, "item": item.deletionCanonicalValue,
      ])
    case .itineraryEntry(let identifier, let itinerary, let source):
      return .record([
        "kind": .string("itineraryEntry"), "id": .identity(identifier),
        "itinerary": itinerary.deletionCanonicalValue, "source": source.deletionCanonicalValue,
      ])
    case .labelAssociation(let identifier, let owner, let label):
      return .record([
        "kind": .string("labelAssociation"), "id": .identity(identifier),
        "owner": owner.deletionCanonicalValue, "label": label.deletionCanonicalValue,
      ])
    case .expandedCompletion(let itineraryId, let listEntryId, let membershipId):
      return .record([
        "kind": .string("expandedCompletion"), "itineraryId": .identity(itineraryId),
        "listEntryId": .identity(listEntryId), "membershipId": .identity(membershipId),
      ])
    }
  }
}

extension PlannerEntityReference {
  fileprivate var deletionCanonicalValue: PlannerCanonicalValue {
    .record(["kind": .string(kind.rawValue), "id": .identity(id)])
  }
}
