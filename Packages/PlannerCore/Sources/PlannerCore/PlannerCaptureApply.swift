import Foundation

func plannerCaptureReviewDigest(operationDigest: String, source: ItemSnapshot?) -> String {
  let value = PlannerCanonicalValue.record([
    "operationDigest": .string(operationDigest),
    "sourceArchived": .optional(source.map { .boolean($0.archived) }),
    "sourceLinks": .optional(source.map { .ordered($0.links.map { $0.read.canonicalValue }) }),
  ])
  return plannerDigest(value.encoded(), prefix: "sha256-capture-review-v1:")
}

func plannerCaptureOperationDigest(
  draftId: UUID, draftGeneration: UUID, choice: PlannerCaptureChoice, listIds: Set<UUID>,
  identity: PlannerStoreIdentity, bindings: [PlannerBoundIdentity]
) -> String {
  let choiceValue: PlannerCanonicalValue
  switch choice {
  case .createNew: choiceValue = .record(["kind": .string("createNew")])
  case .reuse(let itemId):
    choiceValue = .record(["kind": .string("reuse"), "itemId": .identity(itemId)])
  }
  let value = PlannerCanonicalValue.record([
    "command": .record([
      "type": .string("applyCapture"), "draftId": .identity(draftId),
      "draftGeneration": .identity(draftGeneration), "choice": choiceValue,
      "listIds": .identitySet(listIds.map { .identity($0) }),
    ]),
    "datasetId": .identity(identity.datasetId),
    "ownershipBinding": .string(identity.ownershipBinding),
    "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
  ])
  let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
  return plannerDigest(bytes, prefix: "sha256-payload-v1:")
}
