import CryptoKit
import Foundation

struct PlannerImportRestoration {
  let incoming: PlannerPortableBackup

  init(
    incoming: PlannerPortableBackup, current: PlannerPortableBackup,
    resolution: PlannerImportReviewResolution, operationId: UUID
  ) throws {
    let selectedOwners = Set(
      (resolution.details.imports + resolution.details.replacements
        + resolution.details.restorations)
        .map { $0.owner.reference })
    let projection = try PlannerImportProjection(backup: incoming)
    let graph = PlannerImportGraph(backup: current)
    for restored in resolution.details.restorations {
      guard let source = projection.sources[restored.owner.reference],
        graph.isClosed(source.importIdentity)
      else {
        throw PlannerFailure(
          "unavailable", "Incoming restored lifetimes need family reconciliation.")
      }
    }
    for family in incoming.restorationFamilies {
      guard let known = current.restorationFamilies.first(where: { $0.familyId == family.familyId })
      else { continue }
      let knownCandidates = Set(
        known.candidates.map {
          $0.lifetimeId.uuidString + ":" + $0.operationId.uuidString
        })
      let incomingCandidates = Set(
        family.candidates.map {
          $0.lifetimeId.uuidString + ":" + $0.operationId.uuidString
        })
      guard known.predecessor == family.predecessor, knownCandidates == incomingCandidates else {
        throw PlannerFailure(
          "unavailable", "Restoration-family reconciliation needs separate review.")
      }
    }
    let identities =
      incoming.sources.filter {
        selectedOwners.contains($0.importBinding.reference)
      }.map(\.importIdentity)
      + projection.references.filter { selectedOwners.contains($0.owner) }.compactMap(\.identity)
    let closedIdentities = Set(
      current.deletionMarkers.compactMap(\.target.importIdentity).map(
        PlannerImportClosedIdentity.init))
    for identity in identities
    where closedIdentities.contains(PlannerImportClosedIdentity(identity))
      && graph.liveIdentity(for: identity) == nil && !graph.isClosed(identity)
    {
      throw PlannerFailure("unavailable", "Incoming restored lifetimes need family reconciliation.")
    }
    var lifetimes: [PlannerPortableBoundIdentity: UUID] = [:]
    let selectedIdentities = Set(identities.map(PlannerImportClosedIdentity.init))
    let incomingGraph = PlannerImportGraph(backup: incoming)
    var families = incoming.restorationFamilies.filter { family in
      current.restorationFamilies.contains { $0.familyId == family.familyId }
        || selectedIdentities.contains(PlannerImportClosedIdentity(family.predecessor))
        || incomingGraph.liveIdentity(for: family.predecessor) == nil
    }
    let closedFamilies = Set(current.deletionMarkers.compactMap(\.closedFamilyId))
    for identity in identities where graph.isClosed(identity) {
      guard lifetimes[identity] == nil else { continue }
      var predecessor = identity
      var seen: Set<PlannerPortableBoundIdentity> = [identity]
      while let family = current.restorationFamilies.first(where: {
        $0.predecessor == predecessor && closedFamilies.contains($0.familyId)
      }),
        let candidate = family.candidates.min(by: {
          $0.lifetimeId.uuidString < $1.lifetimeId.uuidString
        })
      {
        predecessor = .init(
          kind: predecessor.kind, id: predecessor.id, lifetimeId: candidate.lifetimeId)
        guard seen.insert(predecessor).inserted else {
          throw PlannerFailure("readUnavailable", "Stored restoration history contains a cycle.")
        }
      }
      let lifetimeIdentifier = UUID()
      lifetimes[identity] = lifetimeIdentifier
      families.append(
        .init(
          familyId: plannerRestorationFamilyIdentifier(predecessor), predecessor: predecessor,
          candidates: [.init(lifetimeId: lifetimeIdentifier, operationId: operationId)]))
    }
    func lifetime(_ kind: PlannerPortableIdentityKind, _ identifier: UUID, _ original: UUID) -> UUID
    {
      lifetimes[.init(kind: kind, id: identifier, lifetimeId: original)] ?? original
    }
    func sourceLifetime(_ source: PlannerEntityReference, _ original: UUID) throws -> UUID {
      guard let kind = PlannerPortableIdentityKind(rawValue: source.kind.rawValue) else {
        throw PlannerFailure("invalidInput", "A restored reference has an unsupported source kind.")
      }
      return lifetime(kind, source.id, original)
    }
    self.incoming = try .init(
      sources: incoming.sources.map {
        $0.replacingImportLifetime(lifetimes[$0.importIdentity] ?? $0.importBinding.lifetimeId)
      },
      labelAssociations: incoming.labelAssociations.map {
        .init(
          id: $0.id, lifetimeId: lifetime(.labelAssociation, $0.id, $0.lifetimeId),
          owner: $0.owner, ownerLifetimeId: try sourceLifetime($0.owner, $0.ownerLifetimeId),
          label: $0.label, labelLifetimeId: try sourceLifetime($0.label, $0.labelLifetimeId))
      },
      memberships: incoming.memberships.map {
        .init(
          id: $0.id, lifetimeId: lifetime(.membership, $0.id, $0.lifetimeId), list: $0.list,
          listLifetimeId: lifetime(.list, $0.list.id, $0.listLifetimeId), item: $0.item,
          itemLifetimeId: lifetime(.item, $0.item.id, $0.itemLifetimeId), rank: $0.rank,
          localDone: $0.localDone)
      },
      itineraryEntries: incoming.itineraryEntries.map {
        .init(
          id: $0.id, lifetimeId: lifetime(.itineraryEntry, $0.id, $0.lifetimeId),
          itinerary: $0.itinerary,
          itineraryLifetimeId: lifetime(.itinerary, $0.itinerary.id, $0.itineraryLifetimeId),
          source: $0.source, sourceLifetimeId: try sourceLifetime($0.source, $0.sourceLifetimeId),
          rank: $0.rank, localDone: $0.localDone)
      },
      expandedCompletions: incoming.expandedCompletions.map {
        .init(
          context: .init(
            listEntryId: $0.context.listEntryId,
            listEntryLifetimeId: lifetime(
              .itineraryEntry, $0.context.listEntryId, $0.context.listEntryLifetimeId),
            membershipId: $0.context.membershipId,
            membershipLifetimeId: lifetime(
              .membership, $0.context.membershipId, $0.context.membershipLifetimeId)),
          localDone: $0.localDone)
      },
      schedules: incoming.schedules.map {
        .init(
          id: $0.id, lifetimeId: lifetime(.schedule, $0.id, $0.lifetimeId), source: $0.source,
          sourceLifetimeId: try sourceLifetime($0.source, $0.sourceLifetimeId), form: $0.form)
      },
      deletionMarkers: incoming.deletionMarkers
        + current.deletionMarkers.filter { marker in
          !incoming.deletionMarkers.contains { $0.deletionId == marker.deletionId }
        },
      ownedLinks: incoming.ownedLinks.map {
        .init(
          id: $0.id, lifetimeId: lifetime(.ownedLink, $0.id, $0.lifetimeId),
          owner: .init(
            kind: $0.owner.kind, id: $0.owner.id,
            lifetimeId: try sourceLifetime($0.owner.reference, $0.owner.lifetimeId)),
          rank: $0.rank, originalUrl: $0.originalUrl, label: $0.label, kind: $0.kind,
          providerReference: $0.providerReference)
      },
      contextAliases: incoming.contextAliases, completionChanges: incoming.completionChanges,
      restorationFamilies: families)
  }
}

private func plannerRestorationFamilyIdentifier(_ predecessor: PlannerPortableBoundIdentity) -> UUID
{
  let bytes = Data("PlannerRestorationFamily-v1".utf8) + predecessor.importCanonicalValue.encoded()
  var digest = Array(SHA256.hash(data: bytes))
  digest[6] = (digest[6] & 0x0f) | 0x80
  digest[8] = (digest[8] & 0x3f) | 0x80
  return UUID(
    uuid: (
      digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
      digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]
    ))
}

extension PlannerPortableDeletionMarker {
  func closingRestorationFamily(_ families: [PlannerPortableRestorationFamily])
    -> PlannerPortableDeletionMarker
  {
    guard closedFamilyId == nil, let identity = target.importIdentity,
      let family = families.first(where: {
        $0.predecessor.kind == identity.kind && $0.predecessor.id == identity.id
          && $0.candidates.contains { $0.lifetimeId == identity.lifetimeId }
      })
    else { return self }
    return .init(
      deletionId: deletionId, operationId: operationId, target: target,
      closedFamilyId: family.familyId)
  }
}

extension PlannerPortableSource {
  fileprivate func replacingImportLifetime(_ lifetimeIdentifier: UUID) -> PlannerPortableSource {
    switch self {
    case .item(let value):
      return .item(
        .init(
          kind: value.kind, id: value.id, lifetimeId: lifetimeIdentifier,
          createdAt: value.createdAt,
          updatedAt: value.updatedAt, content: value.content, globalDone: value.globalDone,
          archived: value.archived, contentOrigins: value.contentOrigins))
    case .list(let value):
      return .list(
        .init(
          id: value.id, lifetimeId: lifetimeIdentifier, createdAt: value.createdAt,
          updatedAt: value.updatedAt, content: value.content, archived: value.archived,
          contentOrigins: value.contentOrigins))
    case .itinerary(let value):
      return .itinerary(
        .init(
          id: value.id, lifetimeId: lifetimeIdentifier, createdAt: value.createdAt,
          updatedAt: value.updatedAt, content: value.content, archived: value.archived,
          contentOrigins: value.contentOrigins))
    case .category(let value):
      return .category(
        .init(
          id: value.id, lifetimeId: lifetimeIdentifier, createdAt: value.createdAt,
          updatedAt: value.updatedAt, content: value.content, contentOrigins: value.contentOrigins))
    case .tag(let value):
      return .tag(
        .init(
          id: value.id, lifetimeId: lifetimeIdentifier, createdAt: value.createdAt,
          updatedAt: value.updatedAt, content: value.content, contentOrigins: value.contentOrigins))
    }
  }
}
