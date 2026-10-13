import Foundation

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
