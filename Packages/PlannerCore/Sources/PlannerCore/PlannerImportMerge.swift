import Foundation

struct PlannerImportMerge {
  let additions: PlannerPortableBackup
  let sourceReplacements: [PlannerPortableSource]
  let projected: PlannerPortableBackup

  init(
    incoming: PlannerPortableBackup, current: PlannerPortableBackup,
    resolution: PlannerImportReviewResolution
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
      guard let existing = currentProjection.sources[source.importBinding.reference] else {
        throw PlannerFailure("missingReference", "The replaced source cannot resolve.")
      }
      let incomingFields = incomingProjection.fields(for: source)
      let currentFields = currentProjection.fields(for: existing)
      let ownedFields = [
        "memberships", "itineraryEntries", "expandedCompletions", "labelAssociations", "ownedLinks",
        "schedules", "contextAliases", "completionChanges",
      ]
      guard
        ownedFields.allSatisfy({ incomingFields[$0]?.encoded() == currentFields[$0]?.encoded() })
      else {
        throw PlannerFailure(
          "unavailable",
          "Replacing owned references or completion history still needs reconciliation.")
      }
    }
    let aliases = incoming.contextAliases.filter {
      plannerImportCompletionOwner(
        $0.canonicalContext, memberships: incomingProjection.membershipsById,
        entries: incomingProjection.entriesById
      ).map(selectedOwners.contains) ?? false
    }
    let selectedAliasIdentifiers = Set(aliases.map(\.aliasId))
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
    additions = .init(
      sources: incoming.sources.filter { selectedOwners.contains($0.importBinding.reference) },
      labelAssociations: incoming.labelAssociations.filter { selectedOwners.contains($0.owner) },
      memberships: incoming.memberships.filter { selectedOwners.contains($0.list) },
      itineraryEntries: incoming.itineraryEntries.filter { selectedOwners.contains($0.itinerary) },
      expandedCompletions: incoming.expandedCompletions.filter {
        incomingProjection.entriesById[$0.context.listEntryId].map {
          selectedOwners.contains($0.itinerary)
        } ?? false
      },
      schedules: incoming.schedules.filter { selectedOwners.contains($0.source) },
      deletionMarkers: markers,
      ownedLinks: incoming.ownedLinks.filter { selectedOwners.contains($0.owner.reference) },
      contextAliases: aliases,
      completionChanges: incoming.completionChanges.filter {
        selectedAliasIdentifiers.contains($0.aliasId)
      },
      restorationFamilies: [])
    let retainedSources = current.sources.filter {
      !replacedOwners.contains($0.importBinding.reference)
    }
    let sources = (retainedSources + sourceReplacements + additions.sources).sorted {
      $0.id.uuidString < $1.id.uuidString
    }
    let sourceKinds: [PlannerEntityKind] = [.item, .list, .itinerary, .category, .tag]
    projected = .init(
      sources: sourceKinds.flatMap { kind in sources.filter { $0.kind == kind } },
      labelAssociations: (current.labelAssociations + additions.labelAssociations).sorted {
        $0.id.uuidString < $1.id.uuidString
      },
      memberships: (current.memberships + additions.memberships).sorted {
        $0.id.uuidString < $1.id.uuidString
      },
      itineraryEntries: (current.itineraryEntries + additions.itineraryEntries).sorted {
        $0.id.uuidString < $1.id.uuidString
      },
      expandedCompletions: (current.expandedCompletions + additions.expandedCompletions).sorted {
        $0.context.orderingKey < $1.context.orderingKey
      },
      schedules: (current.schedules + additions.schedules).sorted {
        $0.id.uuidString < $1.id.uuidString
      },
      deletionMarkers: (current.deletionMarkers + additions.deletionMarkers).sorted {
        $0.deletionId.uuidString < $1.deletionId.uuidString
      },
      ownedLinks: (current.ownedLinks + additions.ownedLinks).sorted {
        $0.id.uuidString < $1.id.uuidString
      },
      contextAliases: (current.contextAliases + additions.contextAliases).sorted {
        $0.aliasId.uuidString < $1.aliasId.uuidString
      },
      completionChanges: (current.completionChanges + additions.completionChanges).sorted {
        $0.id.uuidString < $1.id.uuidString
      },
      restorationFamilies: current.restorationFamilies)
    try PlannerImportGraph(backup: projected).validate()
  }
}
