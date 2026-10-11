import Foundation

func sourceDeletionDigest(
  source: PlannerEntityReference, identity: PlannerStoreIdentity,
  bindings: [PlannerBoundIdentity]
) -> String {
  let value = PlannerCanonicalValue.record([
    "command": .record([
      "type": .string("deleteSource"),
      "source": .record(["kind": .string(source.kind.rawValue), "id": .identity(source.id)]),
    ]),
    "datasetId": .identity(identity.datasetId),
    "ownershipBinding": .string(identity.ownershipBinding),
    "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
  ])
  return plannerDigest(
    Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded(),
    prefix: "sha256-payload-v1:")
}
