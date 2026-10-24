import Foundation

extension PlannerBoundSource {
  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "kind": .string(kind.rawValue), "id": .identity(id), "lifetimeId": .identity(lifetimeId),
    ])
  }
}

extension PlannerPortableSource {
  var importBinding: PlannerBoundSource {
    let lifetime: UUID
    switch self {
    case .item(let source): lifetime = source.lifetimeId
    case .list(let source): lifetime = source.lifetimeId
    case .itinerary(let source): lifetime = source.lifetimeId
    case .category(let source): lifetime = source.lifetimeId
    case .tag(let source): lifetime = source.lifetimeId
    }
    return .init(kind: kind, id: id, lifetimeId: lifetime)
  }

  var importTitle: String {
    switch self {
    case .item(let source): source.content.title
    case .list(let source): source.content.name
    case .itinerary(let source): source.content.title
    case .category(let source): source.content.name
    case .tag(let source): source.content.name
    }
  }

  var importFields: [String: PlannerCanonicalValue] {
    let createdAt: Date
    let updatedAt: Date
    let origins: [String: String]
    var fields: [String: PlannerCanonicalValue]
    switch self {
    case .item(let source):
      createdAt = source.createdAt
      updatedAt = source.updatedAt
      origins = source.contentOrigins
      fields = [
        "title": .string(source.content.title),
        "subtitle": .optional(source.content.subtitle.map(PlannerCanonicalValue.string)),
        "notes": .optional(source.content.notes.map(PlannerCanonicalValue.string)),
        "location": .optional(source.content.location.map(\.canonicalValue)),
        "estimate": .optional(source.content.estimate.map(\.canonicalValue)),
        "globalDone": .boolean(source.globalDone), "archived": .boolean(source.archived),
      ]
    case .list(let source):
      createdAt = source.createdAt
      updatedAt = source.updatedAt
      origins = source.contentOrigins
      fields = [
        "name": .string(source.content.name),
        "notes": .optional(source.content.notes.map(PlannerCanonicalValue.string)),
        "color": .optional(source.content.color.map(\.canonicalValue)),
        "iconName": .optional(source.content.iconName.map(PlannerCanonicalValue.string)),
        "manualEstimate": .optional(source.content.manualEstimate.map(\.canonicalValue)),
        "globalDone": .optional(nil), "archived": .boolean(source.archived),
      ]
    case .itinerary(let source):
      createdAt = source.createdAt
      updatedAt = source.updatedAt
      origins = source.contentOrigins
      fields = [
        "title": .string(source.content.title),
        "notes": .optional(source.content.notes.map(PlannerCanonicalValue.string)),
        "color": .optional(source.content.color.map(\.canonicalValue)),
        "iconName": .optional(source.content.iconName.map(PlannerCanonicalValue.string)),
        "location": .optional(source.content.location.map(\.canonicalValue)),
        "manualEstimate": .optional(source.content.manualEstimate.map(\.canonicalValue)),
        "globalDone": .optional(nil), "archived": .boolean(source.archived),
      ]
    case .category(let source):
      createdAt = source.createdAt
      updatedAt = source.updatedAt
      origins = source.contentOrigins
      fields = [
        "name": .string(source.content.name),
        "color": .optional(source.content.color.map(\.canonicalValue)),
        "iconName": .optional(source.content.iconName.map(PlannerCanonicalValue.string)),
        "globalDone": .optional(nil), "archived": .optional(nil),
      ]
    case .tag(let source):
      createdAt = source.createdAt
      updatedAt = source.updatedAt
      origins = source.contentOrigins
      fields = [
        "name": .string(source.content.name),
        "color": .optional(source.content.color.map(\.canonicalValue)),
        "iconName": .optional(source.content.iconName.map(PlannerCanonicalValue.string)),
        "globalDone": .optional(nil), "archived": .optional(nil),
      ]
    }
    fields["createdAt"] = .date(createdAt)
    fields["updatedAt"] = .date(updatedAt)
    fields["contentOrigins"] = .record(origins.mapValues(PlannerCanonicalValue.string))
    return fields
  }

  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "identity": importBinding.importCanonicalValue, "fields": .record(importFields),
    ])
  }
}

extension PlannerPortableMembership {
  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "id": .identity(id), "lifetimeId": .identity(lifetimeId),
      "list": PlannerBoundSource(kind: list.kind, id: list.id, lifetimeId: listLifetimeId)
        .importCanonicalValue,
      "item": PlannerBoundSource(kind: item.kind, id: item.id, lifetimeId: itemLifetimeId)
        .importCanonicalValue,
      "rank": .integer(rank), "localDone": .boolean(localDone),
    ])
  }
}

extension PlannerPortableItineraryEntry {
  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "id": .identity(id), "lifetimeId": .identity(lifetimeId),
      "itinerary": PlannerBoundSource(
        kind: itinerary.kind, id: itinerary.id, lifetimeId: itineraryLifetimeId
      ).importCanonicalValue,
      "source": PlannerBoundSource(
        kind: source.kind, id: source.id, lifetimeId: sourceLifetimeId
      ).importCanonicalValue,
      "rank": .integer(rank), "localDone": .optional(localDone.map(PlannerCanonicalValue.boolean)),
    ])
  }
}

extension PlannerExpandedContext {
  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "listEntryId": .identity(listEntryId), "listEntryLifetimeId": .identity(listEntryLifetimeId),
      "membershipId": .identity(membershipId),
      "membershipLifetimeId": .identity(membershipLifetimeId),
    ])
  }
}

extension PlannerPortableExpandedCompletion {
  var importCanonicalValue: PlannerCanonicalValue {
    .record(["context": context.importCanonicalValue, "localDone": .boolean(localDone)])
  }
}

extension PlannerPortableLabelAssociation {
  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "id": .identity(id), "lifetimeId": .identity(lifetimeId),
      "owner": PlannerBoundSource(kind: owner.kind, id: owner.id, lifetimeId: ownerLifetimeId)
        .importCanonicalValue,
      "label": PlannerBoundSource(kind: label.kind, id: label.id, lifetimeId: labelLifetimeId)
        .importCanonicalValue,
    ])
  }
}

extension PlannerPortableOwnedLink {
  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "id": .identity(id), "lifetimeId": .identity(lifetimeId), "owner": owner.importCanonicalValue,
      "rank": .integer(rank), "originalUrl": .string(originalUrl),
      "label": .optional(label.map(PlannerCanonicalValue.string)), "kind": .string(kind.rawValue),
      "providerReference": .optional(
        providerReference.map {
          .record(["kind": .string($0.kind.rawValue), "value": .string($0.value)])
        }),
    ])
  }
}

extension PlannerPortableSchedule {
  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "id": .identity(id), "lifetimeId": .identity(lifetimeId),
      "source": PlannerBoundSource(kind: source.kind, id: source.id, lifetimeId: sourceLifetimeId)
        .importCanonicalValue,
      "form": form.canonicalValue,
    ])
  }
}

extension PlannerPortableBoundIdentity {
  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "kind": .string(kind.rawValue), "id": .identity(id), "lifetimeId": .identity(lifetimeId),
    ])
  }
}

extension PlannerPortableCompletionContext {
  var importCanonicalValue: PlannerCanonicalValue {
    switch self {
    case .listMembership(let identifier, let lifetime):
      return .record([
        "kind": .string("listMembership"), "membershipId": .identity(identifier),
        "membershipLifetimeId": .identity(lifetime),
      ])
    case .directItineraryItem(let identifier, let lifetime):
      return .record([
        "kind": .string("directItineraryItem"), "entryId": .identity(identifier),
        "entryLifetimeId": .identity(lifetime),
      ])
    case .expandedListItem(let context):
      return .record(["kind": .string("expandedListItem"), "context": context.importCanonicalValue])
    }
  }
}

extension PlannerPortableDeletionTarget {
  var importCanonicalValue: PlannerCanonicalValue {
    switch self {
    case .source(let source, let lifetime):
      return .record([
        "kind": .string("source"),
        "source": PlannerBoundSource(kind: source.kind, id: source.id, lifetimeId: lifetime)
          .importCanonicalValue,
      ])
    case .expandedCompletion(let context):
      return .record([
        "kind": .string("expandedCompletion"), "context": context.importCanonicalValue,
      ])
    case .membership(let identifier, let lifetime):
      return association("membership", identifier: identifier, lifetime: lifetime)
    case .itineraryEntry(let identifier, let lifetime):
      return association("itineraryEntry", identifier: identifier, lifetime: lifetime)
    case .labelAssociation(let identifier, let lifetime):
      return association("labelAssociation", identifier: identifier, lifetime: lifetime)
    case .ownedLink(let identifier, let lifetime):
      return association("ownedLink", identifier: identifier, lifetime: lifetime)
    }
  }

  private func association(_ kind: String, identifier: UUID, lifetime: UUID)
    -> PlannerCanonicalValue
  {
    .record(["kind": .string(kind), "id": .identity(identifier), "lifetimeId": .identity(lifetime)])
  }
}

extension PlannerPortableCompletionContext {
  var importContextIdentities: [PlannerPortableBoundIdentity] {
    switch self {
    case .listMembership(let identifier, let lifetime):
      [.init(kind: .membership, id: identifier, lifetimeId: lifetime)]
    case .directItineraryItem(let identifier, let lifetime):
      [.init(kind: .itineraryEntry, id: identifier, lifetimeId: lifetime)]
    case .expandedListItem(let context):
      [
        .init(
          kind: .itineraryEntry, id: context.listEntryId, lifetimeId: context.listEntryLifetimeId),
        .init(
          kind: .membership, id: context.membershipId, lifetimeId: context.membershipLifetimeId),
      ]
    }
  }
}

extension PlannerPortableDeletionTarget {
  func closes(_ context: PlannerPortableCompletionContext) -> Bool {
    if case .expandedCompletion(let expanded) = self, context == .expandedListItem(expanded) {
      return true
    }
    return importIdentity.map(context.importContextIdentities.contains) ?? false
  }
}

extension PlannerPortableContextAlias {
  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "aliasId": .identity(aliasId), "context": context.importCanonicalValue,
      "canonicalContext": canonicalContext.importCanonicalValue,
      "initialDone": .boolean(initialDone),
      "currentChangeId": .optional(currentChangeId.map(PlannerCanonicalValue.identity)),
    ])
  }
}

extension PlannerPortableCompletionChange {
  var importCanonicalValue: PlannerCanonicalValue {
    .record([
      "id": .identity(id), "aliasId": .identity(aliasId),
      "context": context.importCanonicalValue, "done": .boolean(done),
      "observedChangeIds": .identitySet(observedChangeIds.map(PlannerCanonicalValue.identity)),
    ])
  }
}

extension PlannerPortableBackup {
  func closedHistoryPaths(for target: PlannerPortableDeletionTarget) -> [String] {
    let aliases = contextAliases.enumerated().filter { target.closes($0.element.canonicalContext) }
    let aliasIdentifiers = Set(aliases.map { $0.element.aliasId })
    return aliases.map { "/contextAliases/\($0.offset)" }
      + completionChanges.enumerated().filter { aliasIdentifiers.contains($0.element.aliasId) }.map
    {
      "/completionChanges/\($0.offset)"
    }
  }

  var importCanonicalValue: PlannerCanonicalValue {
    var fields: [String: PlannerCanonicalValue] = [
      "format": .string("planner-data"), "formatVersion": .integer(2),
      "sources": .ordered(sources.map(\.importCanonicalValue)),
      "memberships": .ordered(memberships.map(\.importCanonicalValue)),
      "itineraryEntries": .ordered(itineraryEntries.map(\.importCanonicalValue)),
      "expandedCompletions": .ordered(expandedCompletions.map(\.importCanonicalValue)),
      "labelAssociations": .ordered(labelAssociations.map(\.importCanonicalValue)),
      "ownedLinks": .ordered(ownedLinks.map(\.importCanonicalValue)),
      "schedules": .ordered(schedules.map(\.importCanonicalValue)),
      "deletionMarkers": .ordered(
        deletionMarkers.map {
          .record([
            "deletionId": .identity($0.deletionId), "operationId": .identity($0.operationId),
            "target": $0.target.importCanonicalValue,
            "closedFamilyId": .optional($0.closedFamilyId.map(PlannerCanonicalValue.identity)),
          ])
        }),
      "contextAliases": .ordered(contextAliases.map(\.importCanonicalValue)),
      "completionChanges": .ordered(completionChanges.map(\.importCanonicalValue)),
      "restorationFamilies": .ordered(
        restorationFamilies.map {
          .record([
            "familyId": .identity($0.familyId), "predecessor": $0.predecessor.importCanonicalValue,
            "candidates": .ordered(
              $0.candidates.map {
                .record([
                  "lifetimeId": .identity($0.lifetimeId), "operationId": .identity($0.operationId),
                ])
              }),
          ])
        }),
    ]
    if usesMembershipProvenanceFormat {
      fields["formatVersion"] = .integer(3)
      fields["membershipProvenance"] = .ordered(
        membershipProvenance.map(\.normalized).map(\.importCanonicalValue))
      fields["membershipRemovals"] = .ordered(
        membershipRemovals.map { .record(["deletionId": .identity($0.deletionId)]) })
    }
    return .record(fields)
  }
}

func plannerImportDigest(
  incoming: PlannerDecodedBackup, current: PlannerDecodedBackup, mode: PlannerImportMode,
  identity: PlannerStoreIdentity, restoreDeletedData: Bool = false,
  recoverySelection: PlannerRecoverySelection? = nil
) -> String {
  let bindings = incoming.backup.sources.map(\.importBinding) + incoming.externalBindings
  var command: [String: PlannerCanonicalValue] = [
    "type": .string("applyImport"), "backup": incoming.backup.importCanonicalValue,
    "mode": .string(mode.rawValue),
  ]
  if restoreDeletedData { command["restoreDeletedData"] = .boolean(true) }
  if let selection = recoverySelection {
    command["type"] = .string("restoreRecovery")
    /// Read-specific selection IDs are transient; retained evidence binds restoration and replay.
    command["selection"] = .record([
      "namespaceId": .identity(selection.namespaceId),
      "datasetId": .identity(selection.datasetId),
      "ownershipBinding": .string(selection.ownershipBinding),
      "evidence": .string(
        selection.evidence == .acknowledgedSnapshot ? "acknowledgedSnapshot" : "preparedUnverified"),
      "checkpointGeneration": .optional(
        selection.checkpointGeneration.map(PlannerCanonicalValue.integer)),
      "proposalId": .optional(selection.proposalId.map(PlannerCanonicalValue.identity)),
      "originalOperationId": .optional(
        selection.originalOperationId.map(PlannerCanonicalValue.identity)),
    ])
  }
  var fields: [String: PlannerCanonicalValue] = [
    "command": .record(command),
    "datasetId": .identity(identity.datasetId),
    "ownershipBinding": .string(identity.ownershipBinding),
    "resolvedBindings": .identitySet(Set(bindings).map(\.importCanonicalValue)),
    "reviewedCurrentData": current.backup.importCanonicalValue,
  ]
  if incoming.backup.usesMembershipProvenanceFormat {
    fields["resolvedMembershipEvidence"] = .ordered(
      incoming.backup.resolvedMembershipProvenance.map(\.operationCanonicalValue))
    return plannerDigest(
      Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 3])
        + PlannerCanonicalValue.record(fields).encoded(), prefix: "sha256-payload-v3:")
  }
  let value = PlannerCanonicalValue.record(fields)
  if restoreDeletedData {
    return plannerDigest(
      Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 2]) + value.encoded(),
      prefix: "sha256-payload-v2:")
  }
  return plannerDigest(
    Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded(),
    prefix: "sha256-payload-v1:")
}
