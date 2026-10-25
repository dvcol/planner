import Foundation

struct PlannerImportRequest {
  let backup: PlannerDecodedBackup
  let mode: PlannerImportMode
  let restoreDeletedData: Bool
  let recoverySelection: PlannerRecoverySelection?

  init(command: PlannerCommand) throws {
    switch command {
    case .applyImport(let backup, let mode, let restoreDeletedData):
      self.backup = backup
      self.mode = mode
      self.restoreDeletedData = restoreDeletedData
      recoverySelection = nil
    case .restoreRecovery(let selection, let mode):
      backup = selection.decodedBackup
      self.mode = mode
      restoreDeletedData = mode == .overwrite
      recoverySelection = selection
    default:
      throw PlannerFailure("invalidInput", "This command does not import Planner data.")
    }
  }
}

public enum PlannerImportDecodingResult: Sendable {
  case decoded(PlannerDecodedBackup)
  case invalid(PlannerFailure)
}

public enum PlannerImportMode: String, Sendable {
  case skip, overwrite
}

public struct PlannerImportOwnerSummary: Sendable, Equatable, Codable {
  public let identity: PlannerBoundSource
  public let title: String?
  public let associationIds: [UUID]
  public let changedFieldNames: [String]
}

public struct PlannerImportEntry: Sendable, Equatable, Codable {
  public let owner: PlannerBoundSource
  public let reasonCode: String?
  public let dependencies: [PlannerBoundSource]
  public let propertyPaths: [String]
  public let before: PlannerImportOwnerSummary?
  public let after: PlannerImportOwnerSummary?
}

public struct PlannerDeletionImportEntry: Sendable, Equatable, Codable {
  public let target: PlannerPortableDeletionTarget
  public let owner: PlannerBoundSource?
  public let propertyPaths: [String]
  public let before: PlannerImportOwnerSummary?
  public let after: PlannerImportOwnerSummary?
}

public struct PlannerImportReferenceChange: Sendable, Equatable, Codable {
  public enum Change: String, Sendable, Codable { case add, remove, retain, restore }
  public let change: Change
  public let reference: PlannerReferenceRead
}

public struct PlannerImportReview: Sendable, Equatable, Codable {
  public let imports: [PlannerImportEntry]
  public let unchanged: [PlannerImportEntry]
  public let skippedConflicts: [PlannerImportEntry]
  public let skippedDependents: [PlannerImportEntry]
  public let replacements: [PlannerImportEntry]
  public let restorations: [PlannerImportEntry]
  public let incomingDeletions: [PlannerDeletionImportEntry]
  public let referenceChanges: [PlannerImportReferenceChange]
}

public struct PlannerBoundSource: Sendable, Hashable, Codable {
  public let kind: PlannerEntityKind
  public let id: UUID
  public let lifetimeId: UUID

  var reference: PlannerEntityReference { .init(kind: kind, id: id) }
}

public struct PlannerBindingPath: Sendable, Equatable {
  public let binding: PlannerBoundSource
  public let propertyPath: String
}

public enum PlannerPortableIdentityKind: String, Sendable, Codable {
  case item, list, itinerary, category, tag, schedule
  case membership, itineraryEntry, labelAssociation, ownedLink
}

public struct PlannerPortableBoundIdentity: Sendable, Hashable, Codable {
  public let kind: PlannerPortableIdentityKind
  public let id: UUID
  public let lifetimeId: UUID
}

public enum PlannerPortableCompletionContext: Sendable, Hashable {
  case listMembership(membershipId: UUID, membershipLifetimeId: UUID)
  case directItineraryItem(entryId: UUID, entryLifetimeId: UUID)
  case expandedListItem(PlannerExpandedContext)
}

public struct PlannerPortableContextAlias: Sendable, Codable {
  public let aliasId: UUID
  public let context: PlannerPortableCompletionContext
  public let canonicalContext: PlannerPortableCompletionContext
  public let initialDone: Bool
  public let currentChangeId: UUID?
}

public struct PlannerPortableCompletionChange: Sendable, Codable {
  public let id: UUID
  public let aliasId: UUID
  public let context: PlannerPortableCompletionContext
  public let done: Bool
  public let observedChangeIds: [UUID]
  public let observedExpandedCompletionDeletionIds: [UUID]

  init(
    id: UUID, aliasId: UUID, context: PlannerPortableCompletionContext, done: Bool,
    observedChangeIds: [UUID], observedExpandedCompletionDeletionIds: [UUID] = []
  ) {
    self.id = id
    self.aliasId = aliasId
    self.context = context
    self.done = done
    self.observedChangeIds = observedChangeIds
    self.observedExpandedCompletionDeletionIds = observedExpandedCompletionDeletionIds
  }

  private enum CodingKeys: String, CodingKey {
    case id, aliasId, context, done, observedChangeIds, observedExpandedCompletionDeletionIds
  }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(id, forKey: .id)
    try fields.encode(aliasId, forKey: .aliasId)
    try fields.encode(context, forKey: .context)
    try fields.encode(done, forKey: .done)
    try fields.encode(observedChangeIds, forKey: .observedChangeIds)
    try fields.encode(
      observedExpandedCompletionDeletionIds.sorted {
        $0.uuidString < $1.uuidString
      }, forKey: .observedExpandedCompletionDeletionIds)
  }

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    id = try fields.decode(UUID.self, forKey: .id)
    aliasId = try fields.decode(UUID.self, forKey: .aliasId)
    context = try fields.decode(PlannerPortableCompletionContext.self, forKey: .context)
    done = try fields.decode(Bool.self, forKey: .done)
    observedChangeIds = try fields.decode([UUID].self, forKey: .observedChangeIds)
    observedExpandedCompletionDeletionIds =
      try fields.decodeIfPresent(
        [UUID].self, forKey: .observedExpandedCompletionDeletionIds) ?? []
  }
}

public struct PlannerPortableRestorationCandidate: Sendable, Codable {
  public let lifetimeId: UUID
  public let operationId: UUID
}

public struct PlannerPortableRestorationFamily: Sendable, Codable {
  public let familyId: UUID
  public let predecessor: PlannerPortableBoundIdentity
  public let candidates: [PlannerPortableRestorationCandidate]
}

public struct PlannerPortableOwnedLink: Sendable {
  public let id: UUID
  public let lifetimeId: UUID
  public let owner: PlannerBoundSource
  public let rank: Int64
  public let originalUrl: String
  public let label: String?
  public let kind: PlannerLinkKind
  public let providerReference: PlannerProviderReference?

  var read: PlannerOwnedLinkRead {
    .init(
      linkId: id, originalUrl: originalUrl, label: label, kind: kind,
      providerReference: providerReference)
  }
}

extension PlannerImportOwnerSummary {
  private enum CodingKeys: String, CodingKey {
    case identity, title, associationIds, changedFieldNames
  }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(identity, forKey: .identity)
    try fields.encode(title, forKey: .title)
    try fields.encode(associationIds, forKey: .associationIds)
    try fields.encode(changedFieldNames, forKey: .changedFieldNames)
  }
}

extension PlannerImportEntry {
  private enum CodingKeys: String, CodingKey {
    case owner, reasonCode, dependencies, propertyPaths, before, after
  }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(owner, forKey: .owner)
    try fields.encode(reasonCode, forKey: .reasonCode)
    try fields.encode(dependencies, forKey: .dependencies)
    try fields.encode(propertyPaths, forKey: .propertyPaths)
    try fields.encode(before, forKey: .before)
    try fields.encode(after, forKey: .after)
  }
}

extension PlannerDeletionImportEntry {
  private enum CodingKeys: String, CodingKey { case target, owner, propertyPaths, before, after }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(target, forKey: .target)
    try fields.encode(owner, forKey: .owner)
    try fields.encode(propertyPaths, forKey: .propertyPaths)
    try fields.encode(before, forKey: .before)
    try fields.encode(after, forKey: .after)
  }
}

struct PlannerLegacyPortableCompletionChange: Encodable {
  let id: UUID
  let aliasId: UUID
  let context: PlannerPortableCompletionContext
  let done: Bool
  let observedChangeIds: [UUID]

  init(_ change: PlannerPortableCompletionChange) {
    id = change.id
    aliasId = change.aliasId
    context = change.context
    done = change.done
    observedChangeIds = change.observedChangeIds
  }
}

extension PlannerPortableBackup {
  /// Legacy absence is not an instruction to erase evidence on an immutable change identity.
  func preservingKnownCompletionObservations(from current: PlannerPortableBackup) throws
    -> PlannerPortableBackup
  {
    let known = Dictionary(uniqueKeysWithValues: current.completionChanges.map { ($0.id, $0) })
    let changes = try completionChanges.enumerated().map { index, change in
      guard let retained = known[change.id] else { return change }
      if formatVersion >= 4 {
        guard
          Set(retained.observedExpandedCompletionDeletionIds)
            == Set(change.observedExpandedCompletionDeletionIds)
        else {
          throw PlannerFailure(
            "invalidInput", "A known completion change has conflicting deletion observations.",
            propertyPath: "/completionChanges/\(index)/observedExpandedCompletionDeletionIds")
        }
        return change
      }
      // Existing selection and restoration rules still decide context rebinding at apply.
      guard retained.context == change.context, retained.aliasId == change.aliasId else {
        return change
      }
      return PlannerPortableCompletionChange(
        id: change.id, aliasId: change.aliasId, context: change.context, done: change.done,
        observedChangeIds: change.observedChangeIds,
        observedExpandedCompletionDeletionIds: retained.observedExpandedCompletionDeletionIds)
    }
    return .init(
      sources: sources, labelAssociations: labelAssociations, memberships: memberships,
      itineraryEntries: itineraryEntries, expandedCompletions: expandedCompletions,
      schedules: schedules, deletionMarkers: deletionMarkers, ownedLinks: ownedLinks,
      contextAliases: contextAliases, completionChanges: changes,
      restorationFamilies: restorationFamilies, formatVersion: formatVersion,
      membershipProvenance: membershipProvenance, membershipRemovals: membershipRemovals)
  }
}
