import Foundation

struct PlannerImportOwnerReference {
  let owner: PlannerEntityReference
  let identifier: UUID?
  let group: String
  let propertyPath: String
  let dependencies: [PlannerBoundSource]
  let reference: PlannerReferenceRead
  let value: PlannerCanonicalValue
}

struct PlannerImportOwnerHistory {
  let owner: PlannerEntityReference
  let group: String
  let propertyPath: String
  let value: PlannerCanonicalValue
}

struct PlannerImportProjection {
  let backup: PlannerPortableBackup
  let sources: [PlannerEntityReference: PlannerPortableSource]
  let ownedReferences: [PlannerEntityReference: [PlannerImportOwnerReference]]
  let references: [PlannerImportOwnerReference]
  let histories: [PlannerEntityReference: [PlannerImportOwnerHistory]]

  init(backup: PlannerPortableBackup) throws {
    self.backup = backup
    sources = Dictionary(
      uniqueKeysWithValues: backup.sources.map { ($0.importBinding.reference, $0) })
    var references: [PlannerImportOwnerReference] = []
    for (index, membership) in backup.memberships.enumerated() {
      references.append(
        .init(
          owner: membership.list, identifier: membership.id, group: "memberships",
          propertyPath: "/memberships/\(index)",
          dependencies: [
            .init(kind: .item, id: membership.item.id, lifetimeId: membership.itemLifetimeId)
          ],
          reference: .membership(id: membership.id, list: membership.list, item: membership.item),
          value: membership.importCanonicalValue))
    }
    for (index, entry) in backup.itineraryEntries.enumerated() {
      references.append(
        .init(
          owner: entry.itinerary, identifier: entry.id, group: "itineraryEntries",
          propertyPath: "/itineraryEntries/\(index)",
          dependencies: [
            .init(kind: entry.source.kind, id: entry.source.id, lifetimeId: entry.sourceLifetimeId)
          ],
          reference: .itineraryEntry(
            id: entry.id, itinerary: entry.itinerary, source: entry.source),
          value: entry.importCanonicalValue))
    }
    let entries = Dictionary(uniqueKeysWithValues: backup.itineraryEntries.map { ($0.id, $0) })
    let memberships = Dictionary(uniqueKeysWithValues: backup.memberships.map { ($0.id, $0) })
    for (index, expanded) in backup.expandedCompletions.enumerated() {
      guard let entry = entries[expanded.context.listEntryId],
        let membership = memberships[expanded.context.membershipId]
      else {
        throw PlannerFailure(
          "missingReference", "An expanded state needs its referenced List entry and membership.",
          propertyPath: "/expandedCompletions/\(index)/context")
      }
      references.append(
        .init(
          owner: entry.itinerary, identifier: nil, group: "expandedCompletions",
          propertyPath: "/expandedCompletions/\(index)",
          dependencies: [
            .init(kind: .item, id: membership.item.id, lifetimeId: membership.itemLifetimeId)
          ],
          reference: .expandedCompletion(
            itineraryId: entry.itinerary.id, listEntryId: entry.id, membershipId: membership.id),
          value: expanded.importCanonicalValue))
    }
    for (index, association) in backup.labelAssociations.enumerated() {
      references.append(
        .init(
          owner: association.owner, identifier: association.id, group: "labelAssociations",
          propertyPath: "/labelAssociations/\(index)",
          dependencies: [
            .init(
              kind: association.label.kind, id: association.label.id,
              lifetimeId: association.labelLifetimeId)
          ],
          reference: .labelAssociation(
            id: association.id, owner: association.owner, label: association.label),
          value: association.importCanonicalValue))
    }
    for (index, link) in backup.ownedLinks.enumerated() {
      references.append(
        .init(
          owner: link.owner.reference, identifier: link.id, group: "ownedLinks",
          propertyPath: "/ownedLinks/\(index)", dependencies: [],
          reference: .ownedLink(id: link.id, owner: link.owner.reference),
          value: link.importCanonicalValue))
    }
    for (index, schedule) in backup.schedules.enumerated() {
      references.append(
        .init(
          owner: schedule.source, identifier: schedule.id, group: "schedules",
          propertyPath: "/schedules/\(index)", dependencies: [],
          reference: .schedule(id: schedule.id, source: schedule.source),
          value: schedule.importCanonicalValue))
    }
    self.references = references
    ownedReferences = Dictionary(grouping: references, by: \.owner)
    func owner(for completionContext: PlannerPortableCompletionContext) -> PlannerEntityReference? {
      switch completionContext {
      case .listMembership(let membershipId, _): return memberships[membershipId]?.list
      case .directItineraryItem(let entryId, _): return entries[entryId]?.itinerary
      case .expandedListItem(let expanded): return entries[expanded.listEntryId]?.itinerary
      }
    }
    var histories: [PlannerImportOwnerHistory] = []
    let aliases = Dictionary(uniqueKeysWithValues: backup.contextAliases.map { ($0.aliasId, $0) })
    for (index, alias) in backup.contextAliases.enumerated() {
      guard let owner = owner(for: alias.canonicalContext) else {
        throw PlannerFailure(
          "missingReference", "Completion history needs its current context owner.",
          propertyPath: "/contextAliases/\(index)/canonicalContext")
      }
      histories.append(
        .init(
          owner: owner, group: "contextAliases", propertyPath: "/contextAliases/\(index)",
          value: .record([
            "aliasId": .identity(alias.aliasId), "context": alias.context.importCanonicalValue,
            "canonicalContext": alias.canonicalContext.importCanonicalValue,
            "initialDone": .boolean(alias.initialDone),
            "currentChangeId": .optional(alias.currentChangeId.map(PlannerCanonicalValue.identity)),
          ])))
    }
    for (index, change) in backup.completionChanges.enumerated() {
      guard let alias = aliases[change.aliasId], let owner = owner(for: alias.canonicalContext)
      else {
        throw PlannerFailure(
          "missingReference", "A completion change needs its context owner.",
          propertyPath: "/completionChanges/\(index)/aliasId")
      }
      histories.append(
        .init(
          owner: owner, group: "completionChanges", propertyPath: "/completionChanges/\(index)",
          value: .record([
            "id": .identity(change.id), "aliasId": .identity(change.aliasId),
            "context": change.context.importCanonicalValue, "done": .boolean(change.done),
            "observedChangeIds": .identitySet(
              change.observedChangeIds.map(PlannerCanonicalValue.identity)),
          ])))
    }
    self.histories = Dictionary(grouping: histories, by: \.owner)
  }

  func fields(for source: PlannerPortableSource) -> [String: PlannerCanonicalValue] {
    var fields = source.importFields
    fields["lifetimeId"] = .identity(source.importBinding.lifetimeId)
    let groups = Dictionary(
      grouping: ownedReferences[source.importBinding.reference] ?? [], by: \.group)
    for group in [
      "memberships", "itineraryEntries", "expandedCompletions", "labelAssociations", "ownedLinks",
      "schedules",
    ] {
      fields[group] = .identitySet((groups[group] ?? []).map(\.value))
    }
    let historyGroups = Dictionary(
      grouping: histories[source.importBinding.reference] ?? [], by: \.group)
    for group in ["contextAliases", "completionChanges"] {
      fields[group] = .identitySet((historyGroups[group] ?? []).map(\.value))
    }
    return fields
  }

  func summary(_ source: PlannerPortableSource, changedFields: [String])
    -> PlannerImportOwnerSummary
  {
    .init(
      identity: source.importBinding, title: source.importTitle,
      associationIds: (ownedReferences[source.importBinding.reference] ?? []).compactMap(
        \.identifier
      )
      .sorted { $0.uuidString < $1.uuidString },
      changedFieldNames: changedFields)
  }
}

struct PlannerImportReviewResolution {
  let details: PlannerImportReview
  let targets: [PlannerReviewTarget]
  let globalFlagsChanged: Bool
}

func plannerResolveImportReview(
  incoming: PlannerDecodedBackup, current: PlannerDecodedBackup, mode: PlannerImportMode
) throws -> PlannerImportReviewResolution {
  let currentSources = Dictionary(
    uniqueKeysWithValues: current.backup.sources.map {
      ($0.importBinding.reference, $0.importBinding)
    })
  for path in incoming.originPaths {
    guard let actual = currentSources[path.binding.reference] else {
      throw PlannerFailure(
        "missingReference", "The imported reference is absent from this dataset.",
        propertyPath: path.propertyPath + "/id")
    }
    guard actual.lifetimeId == path.binding.lifetimeId else {
      throw PlannerFailure(
        "missingReference", "The imported reference names another source lifetime.",
        propertyPath: path.propertyPath + "/lifetimeId")
    }
  }
  guard current.backup.deletionMarkers.isEmpty else {
    throw PlannerFailure(
      "unavailable", "Deleted identity import review is not implemented yet.",
      propertyPath: "/command/type"
    )
  }
  guard incoming.backup.restorationFamilies.isEmpty else {
    throw PlannerFailure(
      "unavailable", "Restoration-family import review is not implemented yet.",
      propertyPath: "/restorationFamilies")
  }
  for (index, marker) in incoming.backup.deletionMarkers.enumerated() {
    guard case .source(let source, let lifetime) = marker.target,
      currentSources[source]?.lifetimeId == lifetime
    else { continue }
    throw PlannerFailure(
      "unavailable", "Incoming deletion of live data needs its reviewed impact.",
      propertyPath: "/deletionMarkers/\(index)")
  }
  let projection = try PlannerImportProjection(backup: incoming.backup)
  if let externalOwner = projection.references.first(where: { projection.sources[$0.owner] == nil })
  {
    throw PlannerFailure(
      "unavailable", "Import policy for owned records with an omitted source is pending.",
      propertyPath: externalOwner.propertyPath)
  }
  let currentProjection = try PlannerImportProjection(backup: current.backup)
  var imports: [PlannerImportEntry] = []
  var unchanged: [PlannerImportEntry] = []
  var skippedConflicts: [PlannerImportEntry] = []
  var replacements: [PlannerImportEntry] = []
  var changes: [PlannerImportReferenceChange] = []
  var globalFlagsChanged = false
  for (index, source) in incoming.backup.sources.enumerated() {
    let references = projection.ownedReferences[source.importBinding.reference] ?? []
    let propertyPaths =
      ["/sources/\(index)"] + references.map(\.propertyPath)
      + (projection.histories[source.importBinding.reference] ?? []).map(\.propertyPath)
    let dependencies = Set(references.flatMap(\.dependencies)).sorted {
      if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
      if $0.id != $1.id { return $0.id.uuidString < $1.id.uuidString }
      return $0.lifetimeId.uuidString < $1.lifetimeId.uuidString
    }
    let after = projection.summary(
      source, changedFields: projection.fields(for: source).keys.sorted())
    guard let existing = currentProjection.sources[source.importBinding.reference] else {
      imports.append(
        PlannerImportEntry(
          owner: source.importBinding, reasonCode: nil, dependencies: dependencies,
          propertyPaths: propertyPaths, before: nil,
          after: after))
      changes += references.map { .init(change: .add, reference: $0.reference) }
      if case .item(let item) = source, item.globalDone { globalFlagsChanged = true }
      continue
    }
    guard source.importBinding.lifetimeId == existing.importBinding.lifetimeId else {
      throw PlannerFailure(
        "unavailable", "Source-lifetime import reconciliation is not implemented yet.",
        propertyPath: "/sources/\(index)/lifetimeId")
    }
    let incomingFields = projection.fields(for: source)
    let currentFields = currentProjection.fields(for: existing)
    let changedFields = incomingFields.keys.filter { name in
      incomingFields[name]?.encoded() != currentFields[name]?.encoded()
    }.sorted()
    let existingReferences = currentProjection.ownedReferences[source.importBinding.reference] ?? []
    if changedFields.isEmpty {
      unchanged.append(
        PlannerImportEntry(
          owner: source.importBinding, reasonCode: "unchanged", dependencies: dependencies,
          propertyPaths: propertyPaths,
          before: currentProjection.summary(existing, changedFields: []),
          after: projection.summary(source, changedFields: [])))
      changes += existingReferences.map { .init(change: .retain, reference: $0.reference) }
      continue
    }
    let before = currentProjection.summary(existing, changedFields: changedFields)
    if mode == .skip {
      skippedConflicts.append(
        .init(
          owner: source.importBinding, reasonCode: "matchingRecordConflict",
          dependencies: dependencies,
          propertyPaths: propertyPaths,
          before: before, after: before))
      changes += existingReferences.map { .init(change: .retain, reference: $0.reference) }
      continue
    }
    replacements.append(
      .init(
        owner: source.importBinding, reasonCode: nil, dependencies: dependencies,
        propertyPaths: propertyPaths,
        before: before, after: projection.summary(source, changedFields: changedFields)))
    if source.kind == .item, changedFields.contains("globalDone") { globalFlagsChanged = true }
    changes += existingReferences.filter { existing in
      !references.contains { $0.reference == existing.reference }
    }.map { .init(change: .remove, reference: $0.reference) }
    changes += references.map { incoming in
      .init(
        change: existingReferences.contains { $0.reference == incoming.reference } ? .retain : .add,
        reference: incoming.reference)
    }
  }
  let deletions = incoming.backup.deletionMarkers.enumerated().map { index, marker in
    let owner: PlannerBoundSource?
    if case .source(let source, let lifetime) = marker.target {
      owner = .init(kind: source.kind, id: source.id, lifetimeId: lifetime)
    } else {
      owner = nil
    }
    return PlannerDeletionImportEntry(
      target: marker.target, owner: owner, propertyPaths: ["/deletionMarkers/\(index)"],
      before: nil, after: nil)
  }
  return .init(
    details: .init(
      imports: imports, unchanged: unchanged, skippedConflicts: skippedConflicts,
      skippedDependents: [],
      replacements: replacements, restorations: [], incomingDeletions: deletions,
      referenceChanges: changes),
    targets: incoming.backup.sources.map { .source($0.importBinding.reference) }
      + changes.map { .reference($0.reference) }, globalFlagsChanged: globalFlagsChanged)
}
