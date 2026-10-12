import Foundation

struct PlannerImportMerge {
  let recordsToWrite: PlannerPortableBackup
  let sourceReplacements: [PlannerPortableSource]
  let projected: PlannerPortableBackup

  init(
    incoming: PlannerPortableBackup, current: PlannerPortableBackup,
    resolution: PlannerImportReviewResolution, mode: PlannerImportMode
  ) throws {
    guard resolution.details.restorations.isEmpty,
      resolution.details.incomingDeletions.allSatisfy({ $0.before == nil })
    else {
      throw PlannerFailure(
        "unavailable",
        "Deleting or restoring current import owners still needs native reconciliation.")
    }
    let selectedOwners = Set(resolution.details.imports.map { $0.owner.reference })
    let incomingProjection = try PlannerImportProjection(backup: incoming)
    let currentProjection = try PlannerImportProjection(backup: current)
    let replacedOwners = Set(resolution.details.replacements.map { $0.owner.reference })
    sourceReplacements = incoming.sources.filter {
      replacedOwners.contains($0.importBinding.reference)
    }
    for source in sourceReplacements {
      let owner = source.importBinding.reference
      guard currentProjection.sources[owner] != nil else {
        throw PlannerFailure("missingReference", "The replaced source cannot resolve.")
      }
      let incomingReferences = incomingProjection.ownedReferences[owner] ?? []
      let currentReferences = currentProjection.ownedReferences[owner] ?? []
      let incomingHistory = try (incomingProjection.histories[owner] ?? []).map(
        plannerImportHistoryBinding)
      let currentHistory = try (currentProjection.histories[owner] ?? []).map(
        plannerImportHistoryBinding)
      guard
        incomingReferences.count == currentReferences.count,
        incomingReferences.allSatisfy({ incoming in
          currentReferences.contains {
            $0.identity == incoming.identity && $0.reference == incoming.reference
          }
        }),
        PlannerCanonicalValue.identitySet(incomingHistory).encoded()
          == PlannerCanonicalValue.identitySet(currentHistory).encoded()
      else {
        throw PlannerFailure(
          "unavailable",
          "Changing reference or history identities still needs closure reconciliation.")
      }
    }
    let selectedRecordOwners = selectedOwners.union(replacedOwners)
    let incomingGraph = PlannerImportGraph(backup: incoming)
    let currentGraph = PlannerImportGraph(backup: current)
    let liveAliases = incoming.contextAliases.filter {
      guard !incomingGraph.isClosed($0.canonicalContext) else { return false }
      return
        plannerImportCompletionOwner(
          $0.canonicalContext, memberships: incomingProjection.membershipsById,
          entries: incomingProjection.entriesById
        ).map(selectedRecordOwners.contains) ?? false
    }
    let knownMarkers = Dictionary(
      uniqueKeysWithValues: current.deletionMarkers.map { ($0.deletionId, $0) })
    var markers: [PlannerPortableDeletionMarker] = []
    for marker in incoming.deletionMarkers {
      if let known = knownMarkers[marker.deletionId] {
        guard known.operationId == marker.operationId,
          known.closedFamilyId == marker.closedFamilyId,
          known.target.importCanonicalValue.encoded()
            == marker.target.importCanonicalValue.encoded()
        else {
          throw PlannerFailure(
            "invalidInput", "A deletion identity describes different retained history.")
        }
        continue
      }
      if currentProjection.liveOwner(for: marker.target) == nil { markers.append(marker) }
    }
    let currentAliases = Dictionary(
      uniqueKeysWithValues: current.contextAliases.map { ($0.aliasId, $0) })
    let currentChanges = Dictionary(
      uniqueKeysWithValues: current.completionChanges.map { ($0.id, $0) })
    let closedAliases = incoming.contextAliases.filter { alias in
      guard incomingGraph.isClosed(alias.canonicalContext) else { return false }
      return currentGraph.isClosed(alias.canonicalContext)
        || markers.contains(where: { $0.target.closes(alias.canonicalContext) })
    }
    let selectedAliases = liveAliases + closedAliases
    let selectedClosedAliasIdentifiers = Set(closedAliases.map(\.aliasId))
    for alias in selectedAliases {
      guard let existing = currentAliases[alias.aliasId] else { continue }
      guard existing.context == alias.context, existing.canonicalContext == alias.canonicalContext
      else {
        throw PlannerFailure(
          "unavailable", "Rebinding completion history needs restoration review.")
      }
    }
    let aliases = selectedAliases.filter {
      mode != .skip || !selectedClosedAliasIdentifiers.contains($0.aliasId)
        || currentAliases[$0.aliasId] == nil
    }
    let selectedAliasIdentifiers = Set(selectedAliases.map(\.aliasId))
    let selectedChanges = incoming.completionChanges.filter {
      selectedAliasIdentifiers.contains($0.aliasId)
    }
    for change in selectedChanges {
      guard let existing = currentChanges[change.id] else { continue }
      guard existing.aliasId == change.aliasId, existing.context == change.context else {
        throw PlannerFailure(
          "unavailable", "Rebinding a completion change needs restoration review.")
      }
    }
    let changes = selectedChanges.filter {
      mode != .skip || !selectedClosedAliasIdentifiers.contains($0.aliasId)
        || currentChanges[$0.id] == nil
    }
    recordsToWrite = .init(
      sources: incoming.sources.filter { selectedOwners.contains($0.importBinding.reference) },
      labelAssociations: incoming.labelAssociations.filter {
        selectedRecordOwners.contains($0.owner)
      },
      memberships: incoming.memberships.filter { selectedRecordOwners.contains($0.list) },
      itineraryEntries: incoming.itineraryEntries.filter {
        selectedRecordOwners.contains($0.itinerary)
      },
      expandedCompletions: incoming.expandedCompletions.filter {
        incomingProjection.entriesById[$0.context.listEntryId].map {
          selectedRecordOwners.contains($0.itinerary)
        } ?? false
      },
      schedules: incoming.schedules.filter { selectedRecordOwners.contains($0.source) },
      deletionMarkers: markers,
      ownedLinks: incoming.ownedLinks.filter { selectedRecordOwners.contains($0.owner.reference) },
      contextAliases: aliases,
      completionChanges: changes,
      restorationFamilies: [])
    let retainedSources = current.sources.filter {
      !replacedOwners.contains($0.importBinding.reference)
    }
    let sources = (retainedSources + sourceReplacements + recordsToWrite.sources).sorted {
      $0.id.uuidString < $1.id.uuidString
    }
    let sourceKinds: [PlannerEntityKind] = [.item, .list, .itinerary, .category, .tag]
    let replacedAliasIdentifiers = Set(
      current.contextAliases.filter {
        guard !currentGraph.isClosed($0.canonicalContext) else { return false }
        return plannerImportCompletionOwner(
          $0.canonicalContext, memberships: currentProjection.membershipsById,
          entries: currentProjection.entriesById
        ).map(replacedOwners.contains) ?? false
      }.map(\.aliasId))
    let writtenAliasIdentifiers = Set(aliases.map(\.aliasId))
    let writtenChangeIdentifiers = Set(changes.map(\.id))
    projected = .init(
      sources: sourceKinds.flatMap { kind in sources.filter { $0.kind == kind } },
      labelAssociations: (current.labelAssociations.filter { !replacedOwners.contains($0.owner) }
        + recordsToWrite.labelAssociations).sorted {
          $0.id.uuidString < $1.id.uuidString
        },
      memberships: (current.memberships.filter { !replacedOwners.contains($0.list) }
        + recordsToWrite.memberships).sorted {
          $0.id.uuidString < $1.id.uuidString
        },
      itineraryEntries: (current.itineraryEntries.filter { !replacedOwners.contains($0.itinerary) }
        + recordsToWrite.itineraryEntries).sorted {
          $0.id.uuidString < $1.id.uuidString
        },
      expandedCompletions: (current.expandedCompletions.filter {
        currentProjection.entriesById[$0.context.listEntryId].map {
          !replacedOwners.contains($0.itinerary)
        } ?? true
      } + recordsToWrite.expandedCompletions).sorted {
        $0.context.orderingKey < $1.context.orderingKey
      },
      schedules: (current.schedules.filter { !replacedOwners.contains($0.source) }
        + recordsToWrite.schedules).sorted {
          $0.id.uuidString < $1.id.uuidString
        },
      deletionMarkers: (current.deletionMarkers + recordsToWrite.deletionMarkers).sorted {
        $0.deletionId.uuidString < $1.deletionId.uuidString
      },
      ownedLinks: (current.ownedLinks.filter { !replacedOwners.contains($0.owner.reference) }
        + recordsToWrite.ownedLinks).sorted {
          $0.id.uuidString < $1.id.uuidString
        },
      contextAliases: (current.contextAliases.filter {
        !replacedAliasIdentifiers.contains($0.aliasId)
          && !writtenAliasIdentifiers.contains($0.aliasId)
      }
        + recordsToWrite.contextAliases).sorted {
          $0.aliasId.uuidString < $1.aliasId.uuidString
        },
      completionChanges: (current.completionChanges.filter {
        !replacedAliasIdentifiers.contains($0.aliasId) && !writtenChangeIdentifiers.contains($0.id)
      } + recordsToWrite.completionChanges).sorted {
        $0.id.uuidString < $1.id.uuidString
      },
      restorationFamilies: current.restorationFamilies)
    try PlannerImportGraph(backup: projected).validate()
  }
}

private func plannerImportHistoryBinding(_ history: PlannerImportOwnerHistory) throws
  -> PlannerCanonicalValue
{
  guard case .record(let fields) = history.value else {
    throw PlannerFailure("readUnavailable", "Completion history has no record binding.")
  }
  var binding = fields.filter { ["id", "aliasId", "context", "canonicalContext"].contains($0.key) }
  binding["group"] = .string(history.group)
  return .record(binding)
}
