import Foundation

struct PlannerImportOwnerReference {
  let owner: PlannerEntityReference
  let identity: PlannerPortableBoundIdentity?
  let group: String
  let propertyPath: String
  let dependencies: [PlannerBoundSource]
  let reference: PlannerReferenceRead
  let value: PlannerCanonicalValue
  var identifier: UUID? { identity?.id }
}

struct PlannerImportClosedIdentity: Hashable {
  let kind: PlannerPortableIdentityKind
  let id: UUID

  init(_ identity: PlannerPortableBoundIdentity) {
    kind = identity.kind
    id = identity.id
  }
}

struct PlannerImportOwnerHistory {
  let owner: PlannerEntityReference
  let group: String
  let propertyPath: String
  let value: PlannerCanonicalValue
}

func plannerImportCompletionOwner(
  _ context: PlannerPortableCompletionContext,
  memberships: [UUID: PlannerPortableMembership], entries: [UUID: PlannerPortableItineraryEntry]
) -> PlannerEntityReference? {
  switch context {
  case .listMembership(let membershipIdentifier, _): return memberships[membershipIdentifier]?.list
  case .directItineraryItem(let entryIdentifier, _): return entries[entryIdentifier]?.itinerary
  case .expandedListItem(let expanded): return entries[expanded.listEntryId]?.itinerary
  }
}

struct PlannerImportProjection {
  let backup: PlannerPortableBackup
  let sources: [PlannerEntityReference: PlannerPortableSource]
  let ownedReferences: [PlannerEntityReference: [PlannerImportOwnerReference]]
  let references: [PlannerImportOwnerReference]
  let referenceOwners: [PlannerPortableBoundIdentity: PlannerEntityReference]
  let entriesById: [UUID: PlannerPortableItineraryEntry]
  let membershipsById: [UUID: PlannerPortableMembership]
  let histories: [PlannerEntityReference: [PlannerImportOwnerHistory]]

  init(backup: PlannerPortableBackup) throws {
    self.backup = backup
    sources = Dictionary(
      uniqueKeysWithValues: backup.sources.map { ($0.importBinding.reference, $0) })
    var references: [PlannerImportOwnerReference] = []
    for (index, membership) in backup.memberships.enumerated() {
      references.append(
        .init(
          owner: membership.list,
          identity: .init(kind: .membership, id: membership.id, lifetimeId: membership.lifetimeId),
          group: "memberships",
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
          owner: entry.itinerary,
          identity: .init(kind: .itineraryEntry, id: entry.id, lifetimeId: entry.lifetimeId),
          group: "itineraryEntries",
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
    entriesById = entries
    membershipsById = memberships
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
          owner: entry.itinerary, identity: nil, group: "expandedCompletions",
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
          owner: association.owner,
          identity: .init(
            kind: .labelAssociation, id: association.id, lifetimeId: association.lifetimeId),
          group: "labelAssociations",
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
          owner: link.owner.reference,
          identity: .init(kind: .ownedLink, id: link.id, lifetimeId: link.lifetimeId),
          group: "ownedLinks",
          propertyPath: "/ownedLinks/\(index)", dependencies: [],
          reference: .ownedLink(id: link.id, owner: link.owner.reference),
          value: link.importCanonicalValue))
    }
    for (index, schedule) in backup.schedules.enumerated() {
      references.append(
        .init(
          owner: schedule.source,
          identity: .init(kind: .schedule, id: schedule.id, lifetimeId: schedule.lifetimeId),
          group: "schedules",
          propertyPath: "/schedules/\(index)", dependencies: [],
          reference: .schedule(id: schedule.id, source: schedule.source),
          value: schedule.importCanonicalValue))
    }
    self.references = references
    ownedReferences = Dictionary(grouping: references, by: \.owner)
    referenceOwners = Dictionary(
      uniqueKeysWithValues: references.compactMap { reference in
        guard let identity = reference.identity else { return nil }
        return (identity, reference.owner)
      })
    var histories: [PlannerImportOwnerHistory] = []
    let graph = PlannerImportGraph(backup: backup)
    let suppressedMemberships = try graph.suppressedMembershipIdentities()
    let aliases = Dictionary(uniqueKeysWithValues: backup.contextAliases.map { ($0.aliasId, $0) })
    for (index, alias) in backup.contextAliases.enumerated() {
      if graph.isClosed(alias.canonicalContext)
        || alias.canonicalContext.importContextIdentities.contains(
          where: suppressedMemberships.contains)
      {
        continue
      }
      guard
        let owner = plannerImportCompletionOwner(
          alias.canonicalContext, memberships: memberships, entries: entries)
      else {
        throw PlannerFailure(
          "missingReference", "Completion history needs its current context owner.",
          propertyPath: "/contextAliases/\(index)/canonicalContext")
      }
      histories.append(
        .init(
          owner: owner, group: "contextAliases", propertyPath: "/contextAliases/\(index)",
          value: alias.importCanonicalValue))
    }
    for (index, change) in backup.completionChanges.enumerated() {
      if let alias = aliases[change.aliasId],
        graph.isClosed(alias.canonicalContext)
          || alias.canonicalContext.importContextIdentities.contains(
            where: suppressedMemberships.contains)
      {
        continue
      }
      guard let alias = aliases[change.aliasId],
        let owner = plannerImportCompletionOwner(
          alias.canonicalContext, memberships: memberships, entries: entries)
      else {
        throw PlannerFailure(
          "missingReference", "A completion change needs its context owner.",
          propertyPath: "/completionChanges/\(index)/aliasId")
      }
      histories.append(
        .init(
          owner: owner, group: "completionChanges", propertyPath: "/completionChanges/\(index)",
          value: change.importCanonicalValue))
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

  func liveOwner(for target: PlannerPortableDeletionTarget) -> PlannerPortableSource? {
    if case .expandedCompletion(let context) = target,
      let entry = entriesById[context.listEntryId], entry.lifetimeId == context.listEntryLifetimeId,
      let membership = membershipsById[context.membershipId],
      membership.lifetimeId == context.membershipLifetimeId,
      entry.source == membership.list, entry.sourceLifetimeId == membership.listLifetimeId
    {
      return sources[entry.itinerary]
    }
    if case .source(let reference, let lifetimeId) = target, let source = sources[reference],
      source.importBinding.lifetimeId == lifetimeId
    {
      return source
    }
    guard let identity = target.importIdentity, let owner = referenceOwners[identity] else {
      return nil
    }
    return sources[owner]
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
  let incoming: PlannerPortableBackup
  let predecessorValueOwners: Set<PlannerEntityReference>
  let details: PlannerImportReview
  let targets: [PlannerReviewTarget]
  let sourceDeletes: [PlannerEntityReference]
  let globalFlagsChanged: Bool
}

struct PlannerImportDeletionImpact {
  let markerIndex: Int
  let sourceDeletes: [PlannerEntityReference]
  let referenceRemovals: [PlannerReferenceRead]
}

func plannerResolveImportReview(
  incoming: PlannerDecodedBackup, current: PlannerDecodedBackup, mode: PlannerImportMode,
  deletionImpacts: [PlannerImportDeletionImpact]
) throws -> PlannerImportReviewResolution {
  let currentSources = Dictionary(
    uniqueKeysWithValues: current.backup.sources.map {
      ($0.importBinding.reference, $0.importBinding)
    })
  let closedSourceBindings = Set(
    current.backup.deletionMarkers.compactMap { marker -> PlannerBoundSource? in
      guard case .source(let source, let lifetimeId) = marker.target else { return nil }
      return .init(kind: source.kind, id: source.id, lifetimeId: lifetimeId)
    })
  let currentGraph = PlannerImportGraph(backup: current.backup)
  var resolvedSourceLifetimes: [PlannerBoundSource: UUID] = [:]
  for path in incoming.originPaths {
    if let actual = currentSources[path.binding.reference] {
      guard
        let kind = PlannerPortableIdentityKind(rawValue: actual.kind.rawValue),
        currentGraph.resolves(
          .init(kind: kind, id: path.binding.id, lifetimeId: path.binding.lifetimeId),
          to: .init(kind: kind, id: actual.id, lifetimeId: actual.lifetimeId))
      else {
        throw PlannerFailure(
          "missingReference", "The imported reference names another source lifetime.",
          propertyPath: path.propertyPath + "/lifetimeId")
      }
      if path.binding.lifetimeId != actual.lifetimeId {
        resolvedSourceLifetimes[path.binding] = actual.lifetimeId
      }
      continue
    }
    if let kind = PlannerPortableIdentityKind(rawValue: path.binding.kind.rawValue),
      currentGraph.isClosed(
        .init(kind: kind, id: path.binding.id, lifetimeId: path.binding.lifetimeId))
    {
      continue
    }
    let knownIdentity = closedSourceBindings.contains { $0.reference == path.binding.reference }
    throw PlannerFailure(
      "missingReference", "The imported reference cannot resolve in this dataset.",
      propertyPath: path.propertyPath + (knownIdentity ? "/lifetimeId" : "/id"))
  }
  let incomingGraph = PlannerImportGraph(backup: incoming.backup)
  let incomingSources = Dictionary(
    uniqueKeysWithValues: incoming.backup.sources.map {
      ($0.importBinding.reference, $0.importBinding)
    })
  for family in current.backup.restorationFamilies + incoming.backup.restorationFamilies {
    guard let kind = PlannerEntityKind(rawValue: family.predecessor.kind.rawValue) else { continue }
    let reference = PlannerEntityReference(kind: kind, id: family.predecessor.id)
    guard let actual = currentSources[reference] ?? incomingSources[reference] else { continue }
    let graph = currentSources[reference] == nil ? incomingGraph : currentGraph
    for candidate in family.candidates where candidate.lifetimeId != actual.lifetimeId {
      guard
        graph.resolves(
          .init(
            kind: family.predecessor.kind, id: actual.id, lifetimeId: candidate.lifetimeId),
          to: .init(
            kind: family.predecessor.kind, id: actual.id, lifetimeId: actual.lifetimeId))
      else { continue }
      resolvedSourceLifetimes[
        .init(kind: kind, id: actual.id, lifetimeId: candidate.lifetimeId)] = actual.lifetimeId
    }
  }
  var replacementSourceLifetimes: [PlannerBoundSource: UUID] = [:]
  var excludedSourceBindings: Set<PlannerBoundSource> = []
  var selectedIncomingFamilies = incoming.backup.restorationFamilies
  if mode == .skip {
    selectedIncomingFamilies = try selectedIncomingFamilies.filter { family in
      if let known = current.backup.restorationFamilies.first(where: {
        $0.familyId == family.familyId
      }), known.predecessor != family.predecessor {
        throw PlannerFailure(
          "unavailable", "A known restoration family names another predecessor.")
      }
      guard let kind = PlannerEntityKind(rawValue: family.predecessor.kind.rawValue),
        let actual = currentSources[.init(kind: kind, id: family.predecessor.id)],
        let known = current.backup.restorationFamilies.first(where: { currentFamily in
          currentFamily.predecessor == family.predecessor
            && currentFamily.candidates.contains { $0.lifetimeId == actual.lifetimeId }
            && !current.backup.deletionMarkers.contains {
              $0.closedFamilyId == currentFamily.familyId
            }
        })
      else { return true }
      for candidate in family.candidates {
        if let knownCandidate = known.candidates.first(where: {
          $0.lifetimeId == candidate.lifetimeId
        }) {
          guard knownCandidate.operationId == candidate.operationId else {
            throw PlannerFailure(
              "unavailable", "A known restoration candidate has conflicting provenance.")
          }
        } else {
          excludedSourceBindings.insert(
            .init(kind: kind, id: actual.id, lifetimeId: candidate.lifetimeId))
        }
      }
      return false
    }
  }
  if mode == .overwrite {
    for source in incoming.backup.sources {
      guard let actual = currentSources[source.importBinding.reference],
        actual.lifetimeId != source.importBinding.lifetimeId,
        currentGraph.authorizesPredecessorValues(
          source.importIdentity,
          for: .init(
            kind: source.importIdentity.kind, id: actual.id, lifetimeId: actual.lifetimeId))
      else { continue }
      replacementSourceLifetimes[source.importBinding] = actual.lifetimeId
      resolvedSourceLifetimes[source.importBinding] = actual.lifetimeId
    }
    for source in incoming.backup.sources {
      let actual = currentSources[source.importBinding.reference]
      let live = actual.map {
        PlannerPortableBoundIdentity(
          kind: source.importIdentity.kind, id: $0.id, lifetimeId: $0.lifetimeId)
      }
      guard
        let family = try currentGraph.restoredValueFamily(
          for: source.importIdentity, to: live, in: incoming.backup)
      else { continue }
      let targetLifetime = actual?.lifetimeId ?? family.predecessor.lifetimeId
      replacementSourceLifetimes[source.importBinding] = targetLifetime
      for candidate in family.candidates {
        resolvedSourceLifetimes[
          .init(kind: source.importBinding.kind, id: source.id, lifetimeId: candidate.lifetimeId)] =
          targetLifetime
      }
      selectedIncomingFamilies.removeAll {
        $0.predecessor.kind == source.importIdentity.kind && $0.predecessor.id == source.id
      }
    }
  }
  let resolvedIncoming = incoming.backup.resolvingImportSourceLifetimes(
    resolvedSourceLifetimes, replacingSources: replacementSourceLifetimes,
    selectingFamilies: selectedIncomingFamilies)
  let projection = try PlannerImportProjection(backup: resolvedIncoming)
  let currentProjection = try PlannerImportProjection(backup: current.backup)
  let deletedSources = Set(
    current.backup.deletionMarkers.compactMap { marker -> PlannerEntityReference? in
      guard case .source(let source, _) = marker.target, currentProjection.sources[source] == nil
      else { return nil }
      return source
    })
  let closedIdentities = Set(
    current.backup.deletionMarkers.compactMap(\.target.importIdentity).map(
      PlannerImportClosedIdentity.init))
  let closedContexts = Set(
    current.backup.deletionMarkers.compactMap { marker -> PlannerExpandedContext? in
      guard case .expandedCompletion(let completionContext) = marker.target else { return nil }
      return completionContext
    })
  let closedContextOwners = Set(
    incoming.backup.expandedCompletions.filter { closedContexts.contains($0.context) }.compactMap {
      expanded in
      incoming.backup.itineraryEntries.first(where: { $0.id == expanded.context.listEntryId })?
        .itinerary
    })
  var unavailableSources = deletedSources
  if mode == .overwrite {
    unavailableSources.subtract(projection.sources.keys)
  }
  var didDiscoverUnavailableSource = true
  while didDiscoverUnavailableSource {
    didDiscoverUnavailableSource = false
    for source in incoming.backup.sources {
      let sourceReference = source.importBinding.reference
      guard currentProjection.sources[sourceReference] == nil,
        !unavailableSources.contains(sourceReference)
      else { continue }
      let references = projection.ownedReferences[sourceReference] ?? []
      let dependencies = references.flatMap(\.dependencies)
      let ownsClosedRecord = references.contains { reference in
        guard let identity = reference.identity else { return false }
        return closedIdentities.contains(PlannerImportClosedIdentity(identity))
      }
      let dependsOnClosedSource = dependencies.contains { dependency in
        guard let kind = PlannerPortableIdentityKind(rawValue: dependency.kind.rawValue) else {
          return false
        }
        return currentGraph.isClosed(
          .init(kind: kind, id: dependency.id, lifetimeId: dependency.lifetimeId))
      }
      guard
        (mode == .skip
          && (ownsClosedRecord || dependsOnClosedSource
            || dependencies.contains { excludedSourceBindings.contains($0) }
            || closedContextOwners.contains(sourceReference)))
          || dependencies.contains(where: { unavailableSources.contains($0.reference) })
      else {
        continue
      }
      unavailableSources.insert(sourceReference)
      didDiscoverUnavailableSource = true
    }
  }
  var imports: [PlannerImportEntry] = []
  var unchanged: [PlannerImportEntry] = []
  var skippedConflicts: [PlannerImportEntry] = []
  var skippedDependents: [PlannerImportEntry] = []
  var replacements: [PlannerImportEntry] = []
  var restorations: [PlannerImportEntry] = []
  var changes: [PlannerImportReferenceChange] = []
  var globalFlagsChanged = false
  for (index, source) in resolvedIncoming.sources.enumerated() {
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
    if deletedSources.contains(source.importBinding.reference) {
      if mode == .overwrite {
        restorations.append(
          .init(
            owner: source.importBinding, reasonCode: "deletedSource",
            dependencies: dependencies, propertyPaths: propertyPaths, before: nil, after: after))
        changes += references.map { .init(change: .restore, reference: $0.reference) }
        if case .item(let item) = source, item.globalDone { globalFlagsChanged = true }
        continue
      }
      skippedConflicts.append(
        .init(
          owner: source.importBinding, reasonCode: "deletedSource",
          dependencies: dependencies, propertyPaths: propertyPaths, before: nil, after: nil))
      continue
    }
    if unavailableSources.contains(source.importBinding.reference) {
      skippedDependents.append(
        .init(
          owner: source.importBinding, reasonCode: "deletedDependency",
          dependencies: dependencies, propertyPaths: propertyPaths, before: nil, after: nil))
      continue
    }
    guard let existing = currentProjection.sources[source.importBinding.reference] else {
      imports.append(
        PlannerImportEntry(
          owner: source.importBinding, reasonCode: nil, dependencies: dependencies,
          propertyPaths: propertyPaths, before: nil,
          after: after))
      changes += references.map {
        let isClosed =
          $0.identity.map {
            closedIdentities.contains(PlannerImportClosedIdentity($0))
          } ?? false
        return .init(change: isClosed ? .restore : .add, reference: $0.reference)
      }
      if case .item(let item) = source, item.globalDone { globalFlagsChanged = true }
      continue
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
          owner: existing.importBinding, reasonCode: "matchingRecordConflict",
          dependencies: dependencies,
          propertyPaths: propertyPaths,
          before: before, after: before))
      changes += existingReferences.map { .init(change: .retain, reference: $0.reference) }
      continue
    }
    guard source.importBinding.lifetimeId == existing.importBinding.lifetimeId else {
      throw PlannerFailure(
        "unavailable", "Source-lifetime import reconciliation is not implemented yet.",
        propertyPath: "/sources/\(index)/lifetimeId")
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
      let isClosed =
        incoming.identity.map {
          closedIdentities.contains(PlannerImportClosedIdentity($0))
        } ?? false
      if isClosed { return .init(change: .restore, reference: incoming.reference) }
      return .init(
        change: existingReferences.contains { $0.reference == incoming.reference } ? .retain : .add,
        reference: incoming.reference)
    }
  }
  let omittedOwners = projection.ownedReferences.keys.filter { projection.sources[$0] == nil }
    .sorted {
      if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
      return $0.id.uuidString < $1.id.uuidString
    }
  for owner in omittedOwners {
    let references = projection.ownedReferences[owner] ?? []
    let existing = currentProjection.sources[owner]
    guard
      let binding = existing?.importBinding
        ?? incoming.externalBindings.first(where: { $0.reference == owner })
    else {
      throw PlannerFailure(
        "missingReference", "The omitted source owner cannot resolve in this dataset.",
        propertyPath: references.first?.propertyPath)
    }
    let summary = existing.map { currentProjection.summary($0, changedFields: []) }
    let dependencies = Set(references.flatMap(\.dependencies)).sorted {
      if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
      if $0.id != $1.id { return $0.id.uuidString < $1.id.uuidString }
      return $0.lifetimeId.uuidString < $1.lifetimeId.uuidString
    }
    skippedConflicts.append(
      .init(
        owner: binding, reasonCode: "omittedOwner", dependencies: dependencies,
        propertyPaths: references.map(\.propertyPath)
          + (projection.histories[owner] ?? []).map(\.propertyPath),
        before: summary, after: summary))
    changes += (currentProjection.ownedReferences[owner] ?? []).map {
      .init(change: .retain, reference: $0.reference)
    }
  }
  var deletions: [PlannerDeletionImportEntry] = []
  var sourceDeletes: [PlannerEntityReference] = []
  var selectedSourceDeletes: Set<PlannerEntityReference> = []
  var deletionPositions: [Data: Int] = [:]
  let impactsByIndex = Dictionary(
    uniqueKeysWithValues: deletionImpacts.map { ($0.markerIndex, $0) })
  let allSourceDeletes = Set(deletionImpacts.flatMap(\.sourceDeletes))
  let allReferenceRemovals = Set(deletionImpacts.flatMap(\.referenceRemovals))
  var skippedConflictPositions = Dictionary(
    uniqueKeysWithValues: skippedConflicts.enumerated().map {
      ($0.element.owner, $0.offset)
    })
  var retainedOwners = Set((unchanged + skippedConflicts).map { $0.owner.reference })
  for (index, marker) in incoming.backup.deletionMarkers.enumerated() {
    let propertyPaths =
      ["/deletionMarkers/\(index)"]
      + incoming.backup.closedHistoryPaths(for: marker.target)
    if let existing = currentProjection.liveOwner(for: marker.target) {
      let path = "/deletionMarkers/\(index)"
      if mode == .overwrite {
        guard let impact = impactsByIndex[index] else {
          throw PlannerFailure(
            "unavailable", "Incoming deletion of live data needs its reviewed impact.",
            propertyPath: path)
        }
        let ownedReferences =
          currentProjection.ownedReferences[existing.importBinding.reference] ?? []
        let removedReferences = ownedReferences.filter {
          allReferenceRemovals.contains($0.reference)
        }
        let replacementFields =
          replacements.first {
            $0.owner == existing.importBinding
          }?.after?.changedFieldNames ?? []
        let changedFields = Set(removedReferences.map(\.group) + replacementFields).sorted()
        let after: PlannerImportOwnerSummary?
        if allSourceDeletes.contains(existing.importBinding.reference) {
          after = nil
        } else {
          let proposedSource = projection.sources[existing.importBinding.reference] ?? existing
          let proposedReferences: [PlannerImportOwnerReference]
          if projection.sources[existing.importBinding.reference] != nil {
            proposedReferences = projection.ownedReferences[existing.importBinding.reference] ?? []
          } else {
            proposedReferences = ownedReferences
          }
          after = .init(
            identity: existing.importBinding, title: proposedSource.importTitle,
            associationIds: proposedReferences.filter {
              !allReferenceRemovals.contains($0.reference)
            }.compactMap(\.identifier).sorted { $0.uuidString < $1.uuidString },
            changedFieldNames: changedFields)
        }
        let targetKey = marker.target.importCanonicalValue.encoded()
        if let position = deletionPositions[targetKey] {
          let previous = deletions[position]
          deletions[position] = .init(
            target: previous.target, owner: previous.owner,
            propertyPaths: previous.propertyPaths + propertyPaths, before: previous.before,
            after: after)
        } else {
          deletionPositions[targetKey] = deletions.count
          deletions.append(
            .init(
              target: marker.target, owner: existing.importBinding, propertyPaths: propertyPaths,
              before: currentProjection.summary(existing, changedFields: changedFields),
              after: after)
          )
        }
        sourceDeletes += impact.sourceDeletes.filter { selectedSourceDeletes.insert($0).inserted }
        changes += impact.referenceRemovals.map { .init(change: .remove, reference: $0) }
        continue
      }
      if let position = skippedConflictPositions[existing.importBinding] {
        let conflict = skippedConflicts[position]
        skippedConflicts[position] = .init(
          owner: conflict.owner, reasonCode: conflict.reasonCode,
          dependencies: conflict.dependencies,
          propertyPaths: conflict.propertyPaths + propertyPaths,
          before: conflict.before, after: conflict.after)
      } else {
        let summary = currentProjection.summary(existing, changedFields: [])
        skippedConflictPositions[existing.importBinding] = skippedConflicts.count
        skippedConflicts.append(
          .init(
            owner: existing.importBinding, reasonCode: "matchingRecordConflict",
            dependencies: [], propertyPaths: propertyPaths, before: summary, after: summary))
      }
      if retainedOwners.insert(existing.importBinding.reference).inserted {
        changes += (currentProjection.ownedReferences[existing.importBinding.reference] ?? []).map {
          .init(change: .retain, reference: $0.reference)
        }
      }
      continue
    }
    let owner: PlannerBoundSource?
    if case .source(let source, let lifetime) = marker.target {
      owner = .init(kind: source.kind, id: source.id, lifetimeId: lifetime)
    } else {
      owner = nil
    }
    deletions.append(
      PlannerDeletionImportEntry(
        target: marker.target, owner: owner, propertyPaths: propertyPaths,
        before: nil, after: nil))
  }
  var uniqueChanges: [PlannerImportReferenceChange] = []
  let removalClosure = PlannerImportReferenceRemoval(current: current.backup, changes: changes)
  changes += currentProjection.references.filter {
    removalClosure.references.contains($0.reference)
  }.map { .init(change: .remove, reference: $0.reference) }
  for schedule in current.backup.schedules
  where removalClosure.references.contains(.schedule(id: schedule.id, source: schedule.source)) {
    let source = PlannerEntityReference(kind: .schedule, id: schedule.id)
    if selectedSourceDeletes.insert(source).inserted { sourceDeletes.append(source) }
  }
  var changePositions: [PlannerReferenceRead: Int] = [:]
  for change in changes {
    if let position = changePositions[change.reference] {
      if change.change == .remove { uniqueChanges[position] = change }
      continue
    }
    changePositions[change.reference] = uniqueChanges.count
    uniqueChanges.append(change)
  }
  let targetSources = Set(
    incoming.backup.sources.map { $0.importBinding.reference }
      + skippedConflicts.map { $0.owner.reference }
      + deletions.compactMap { $0.before?.identity.reference }
      + currentProjection.references.filter {
        removalClosure.references.contains($0.reference)
      }.map(\.owner)
      + sourceDeletes
  ).sorted {
    if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
    return $0.id.uuidString < $1.id.uuidString
  }
  return .init(
    incoming: resolvedIncoming,
    predecessorValueOwners: Set(replacementSourceLifetimes.keys.map(\.reference)),
    details: .init(
      imports: imports, unchanged: unchanged, skippedConflicts: skippedConflicts,
      skippedDependents: skippedDependents,
      replacements: replacements, restorations: restorations, incomingDeletions: deletions,
      referenceChanges: uniqueChanges),
    targets: targetSources.map { .source($0) }
      + uniqueChanges.map { .reference($0.reference) }, sourceDeletes: sourceDeletes,
    globalFlagsChanged: globalFlagsChanged)
}

extension PlannerPortableBackup {
  fileprivate func resolvingImportSourceLifetimes(
    _ lifetimes: [PlannerBoundSource: UUID], replacingSources: [PlannerBoundSource: UUID],
    selectingFamilies: [PlannerPortableRestorationFamily]
  ) -> PlannerPortableBackup {
    guard !lifetimes.isEmpty || selectingFamilies.count != restorationFamilies.count else {
      return self
    }
    func lifetime(_ source: PlannerEntityReference, _ original: UUID) -> UUID {
      lifetimes[.init(kind: source.kind, id: source.id, lifetimeId: original)] ?? original
    }
    return .init(
      sources: sources.map { source in
        guard let lifetimeIdentifier = replacingSources[source.importBinding] else { return source }
        return source.replacingImportLifetime(lifetimeIdentifier)
      },
      labelAssociations: labelAssociations.map {
        .init(
          id: $0.id, lifetimeId: $0.lifetimeId, owner: $0.owner,
          ownerLifetimeId: lifetime($0.owner, $0.ownerLifetimeId), label: $0.label,
          labelLifetimeId: lifetime($0.label, $0.labelLifetimeId))
      },
      memberships: memberships.map {
        .init(
          id: $0.id, lifetimeId: $0.lifetimeId, list: $0.list,
          listLifetimeId: lifetime($0.list, $0.listLifetimeId), item: $0.item,
          itemLifetimeId: lifetime($0.item, $0.itemLifetimeId), rank: $0.rank,
          localDone: $0.localDone)
      },
      itineraryEntries: itineraryEntries.map {
        .init(
          id: $0.id, lifetimeId: $0.lifetimeId, itinerary: $0.itinerary,
          itineraryLifetimeId: lifetime($0.itinerary, $0.itineraryLifetimeId), source: $0.source,
          sourceLifetimeId: lifetime($0.source, $0.sourceLifetimeId), rank: $0.rank,
          localDone: $0.localDone)
      },
      expandedCompletions: expandedCompletions,
      schedules: schedules.map {
        .init(
          id: $0.id, lifetimeId: $0.lifetimeId, source: $0.source,
          sourceLifetimeId: lifetime($0.source, $0.sourceLifetimeId), form: $0.form)
      },
      deletionMarkers: deletionMarkers,
      ownedLinks: ownedLinks.map {
        .init(
          id: $0.id, lifetimeId: $0.lifetimeId,
          owner: .init(
            kind: $0.owner.kind, id: $0.owner.id,
            lifetimeId: lifetime($0.owner.reference, $0.owner.lifetimeId)),
          rank: $0.rank, originalUrl: $0.originalUrl, label: $0.label, kind: $0.kind,
          providerReference: $0.providerReference)
      },
      contextAliases: contextAliases, completionChanges: completionChanges,
      restorationFamilies: selectingFamilies, formatVersion: formatVersion,
      membershipProvenance: membershipProvenance, membershipRemovals: membershipRemovals)
  }
}
