import Foundation

public struct PlannerStorageConfiguration: Sendable {
  public enum ProcessRole: Sendable { case mainApplication, shareExtension }
  public enum StorageMode: Sendable { case localOnly }

  public let storeURL: URL
  public let controlURL: URL
  public let recoveryDirectoryURL: URL
  public let processRole: ProcessRole
  public let storageMode: StorageMode

  public init(
    storeURL: URL, controlURL: URL, recoveryDirectoryURL: URL,
    processRole: ProcessRole, storageMode: StorageMode
  ) {
    self.storeURL = storeURL
    self.controlURL = controlURL
    self.recoveryDirectoryURL = recoveryDirectoryURL
    self.processRole = processRole
    self.storageMode = storageMode
  }
}

public struct PlannerDatasetSession: Sendable, Equatable {
  public let datasetId: UUID
  public let sessionId: UUID
  let ownershipBinding: String
  let epochId: UUID
}

public struct PlannerFailure: Error, Sendable, Equatable {
  public let code: String
  public let propertyPath: String?
  public let message: String
  public let details: PlannerFailureDetails?

  init(
    _ code: String, _ message: String, propertyPath: String? = nil,
    details: PlannerFailureDetails? = nil
  ) {
    self.code = code
    self.propertyPath = propertyPath
    self.message = message
    self.details = details
  }
}

public enum PlannerItemFieldValue: Sendable, Equatable {
  case string(String)
  case optionalString(String?)
  case optionalLocation(PlannerOwnedLocation?)
  case links([PlannerOwnedLinkRead])
}

public enum PlannerFailureDetails: Sendable, Equatable {
  case staleSnapshot(requestedGeneration: UUID, currentGeneration: UUID?)
  case staleEdit(
    conflictingFields: [PlannerItemField], currentValues: [PlannerItemField: PlannerItemFieldValue],
    currentFieldHashes: [PlannerItemField: PlannerFieldHash]
  )
}

public enum PlannerBootstrapResult: Sendable {
  case ready(PlannerDatasetSession)
  case mainAppSetupRequired
  case mainAppMigrationRequired
  case unavailable(PlannerFailure)
}

public enum PlannerEntityKind: String, Sendable, Codable {
  case item, list, itinerary, category, tag, schedule
}

public struct PlannerEntityReference: Sendable, Codable, Equatable {
  public let kind: PlannerEntityKind
  public let id: UUID

  public init(kind: PlannerEntityKind, id: UUID) {
    self.kind = kind
    self.id = id
  }
}

public struct PlannerCoordinate: Sendable, Codable, Equatable {
  public let latitude: Double
  public let longitude: Double

  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

public struct PlannerOwnedLocation: Sendable, Codable, Equatable {
  public let displayName: String?
  public let formattedAddress: String?
  public let coordinate: PlannerCoordinate?

  public init(displayName: String?, formattedAddress: String?, coordinate: PlannerCoordinate?) {
    self.displayName = displayName
    self.formattedAddress = formattedAddress
    self.coordinate = coordinate
  }
}

public enum PlannerEstimateUnit: String, Sendable, Codable {
  case minute, hour, day, week, month, year
}

public struct PlannerEstimate: Sendable, Codable, Equatable {
  public let minutes: Int64
  public let displayUnit: PlannerEstimateUnit

  public init(minutes: Int64, displayUnit: PlannerEstimateUnit) {
    self.minutes = minutes
    self.displayUnit = displayUnit
  }
}

public struct PlannerLinkInput: Sendable, Equatable {
  public let linkId: UUID?
  public let originalUrl: String
  public let label: String?

  public init(linkId: UUID? = nil, originalUrl: String, label: String? = nil) {
    self.linkId = linkId
    self.originalUrl = originalUrl
    self.label = label
  }
}

public struct PlannerItemContentInput: Sendable, Equatable {
  public let title: String
  public let subtitle: String?
  public let notes: String?
  public let location: PlannerOwnedLocation?
  public let estimate: PlannerEstimate?
  public let links: [PlannerLinkInput]
  public let categoryIds: Set<UUID>
  public let tagIds: Set<UUID>

  public init(
    title: String, subtitle: String? = nil, notes: String? = nil,
    location: PlannerOwnedLocation? = nil, estimate: PlannerEstimate? = nil,
    links: [PlannerLinkInput] = [], categoryIds: Set<UUID> = [], tagIds: Set<UUID> = []
  ) {
    self.title = title
    self.subtitle = subtitle
    self.notes = notes
    self.location = location
    self.estimate = estimate
    self.links = links
    self.categoryIds = categoryIds
    self.tagIds = tagIds
  }
}

public enum PlannerCommand: Sendable {
  case createItem(content: PlannerItemContentInput)
  case createSchedule(source: PlannerEntityReference, form: PlannerScheduleForm)
  case setCompletion(scope: PlannerCompletionScope, done: Bool)
  case setArchive(source: PlannerEntityReference, archived: Bool)
  case editItem(
    sourceId: UUID, changes: PlannerItemChanges,
    expectedFieldHashes: [PlannerItemField: PlannerFieldHash])
}

public enum PlannerCompletionScope: Sendable {
  case globalItem(itemId: UUID)
}

public enum PlannerFieldChange<Value: Sendable>: Sendable {
  case unchanged
  case set(Value)
  case clear
}

public struct PlannerItemChanges: Sendable {
  public let title: PlannerFieldChange<String>
  public let subtitle: PlannerFieldChange<String>
  public let notes: PlannerFieldChange<String>
  public let location: PlannerFieldChange<PlannerOwnedLocation>
  public let estimate: PlannerFieldChange<PlannerEstimate>
  public let links: PlannerFieldChange<[PlannerLinkInput]>
  public let categoryIds: PlannerFieldChange<Set<UUID>>
  public let tagIds: PlannerFieldChange<Set<UUID>>

  public init(
    title: PlannerFieldChange<String> = .unchanged,
    subtitle: PlannerFieldChange<String> = .unchanged,
    notes: PlannerFieldChange<String> = .unchanged,
    location: PlannerFieldChange<PlannerOwnedLocation> = .unchanged,
    estimate: PlannerFieldChange<PlannerEstimate> = .unchanged,
    links: PlannerFieldChange<[PlannerLinkInput]> = .unchanged,
    categoryIds: PlannerFieldChange<Set<UUID>> = .unchanged,
    tagIds: PlannerFieldChange<Set<UUID>> = .unchanged
  ) {
    self.title = title
    self.subtitle = subtitle
    self.notes = notes
    self.location = location
    self.estimate = estimate
    self.links = links
    self.categoryIds = categoryIds
    self.tagIds = tagIds
  }
}

public struct PlannerReviewToken: Sendable {
  let reviewId: UUID
}

public struct PlannerOperation: Sendable {
  public let operationId: UUID
  public let session: PlannerDatasetSession
  public let command: PlannerCommand
  public let reviewToken: PlannerReviewToken?

  public init(
    operationId: UUID, session: PlannerDatasetSession, command: PlannerCommand,
    reviewToken: PlannerReviewToken? = nil
  ) {
    self.operationId = operationId
    self.session = session
    self.command = command
    self.reviewToken = reviewToken
  }
}

public struct PlannerAppliedResult: Sendable, Codable, Equatable {
  public let generated: [PlannerEntityReference]
  public let affected: [PlannerEntityReference]
}

public enum PlannerRecoveryResult: Sendable {
  case complete(checkpointGeneration: Int64)
  case incomplete(PlannerFailure)
}

public struct PlannerOperationResult: Sendable {
  public enum Outcome: Sendable {
    case rejected(PlannerFailure)
    case applied(result: PlannerAppliedResult, recovery: PlannerRecoveryResult)
    case unverified(PlannerProposalSummary)
  }

  public let operationId: UUID
  public let outcome: Outcome
}

public enum PlannerOperationStatus: Sendable {
  case knownUnapplied(PlannerFailure)
  case preparedUnverified(PlannerProposalSummary)
  case appliedRecoveryIncomplete(result: PlannerAppliedResult, reason: PlannerFailure)
  case appliedRecoveryComplete(result: PlannerAppliedResult, checkpointGeneration: Int64)
  case noReliableEvidence
  case unavailable(PlannerFailure)
}

public enum PlannerItemField: String, Sendable, CaseIterable {
  case title, subtitle, notes, location, estimate, links, categoryIds, tagIds
}

public struct PlannerFieldHash: Sendable, Equatable {
  public let value: String

  public init(value: String) {
    self.value = value
  }
}

public struct PlannerItemContent: Sendable {
  public let title: String
  public let subtitle: String?
  public let notes: String?
  public let location: PlannerOwnedLocation?
  public let estimate: PlannerEstimate?
  public let links: [PlannerOwnedLinkRead]
  public let categoryIds: Set<UUID>
  public let tagIds: Set<UUID>
}

public struct PlannerOwnedLinkRead: Sendable, Equatable {
  public let linkId: UUID
  public let originalUrl: String
  public let label: String?
  public let kind: PlannerLinkKind
  public let providerReference: PlannerProviderReference?
}

public enum PlannerLinkKind: String, Sendable, Codable {
  case appleMaps, googleMaps, tabelog, website, booking, generic
}

public struct PlannerProviderReference: Sendable, Codable, Equatable {
  public enum Kind: String, Sendable, Codable { case applePlaceId }
  public let kind: Kind
  public let value: String
}

public enum PlannerReferenceRead: Sendable, Equatable {
  case ownedLink(id: UUID, owner: PlannerEntityReference)
  case schedule(id: UUID, source: PlannerEntityReference)
}

public struct PlannerSourceRead: Sendable {
  public let source: PlannerEntityReference
  public let content: PlannerItemContent
  public let createdAt: Date
  public let updatedAt: Date
  public let fieldHashes: [PlannerItemField: PlannerFieldHash]
  public let state: PlannerSourceState
  public let labels: [PlannerEntityReference]
  public let references: [PlannerReferenceRead]
}

public struct PlannerSourceState: Sendable {
  public let globalDone: Bool?
  public let archived: Bool?
}

public enum PlannerReadRequest: Sendable {
  case source(PlannerEntityReference)
  case rows(generation: UUID, offset: Int64, limit: Int64)
}

public enum PlannerReadResult: Sendable {
  case source(PlannerSourceRead)
  case rows(PlannerRowWindow)
  case failed(PlannerFailure)
}

public struct PlannerQuery: Sendable {
  public let session: PlannerDatasetSession
  public let request: PlannerQueryRequest

  public init(session: PlannerDatasetSession, request: PlannerQueryRequest) {
    self.session = session
    self.request = request
  }
}

public enum PlannerQueryRequest: Sendable {
  case items(PlannerItemQuery)
}

public struct PlannerItemQuery: Sendable {
  public enum Scope: Sendable {
    case global, inbox
    case list(UUID)
    case itinerary(UUID)
  }
  public enum Completion: Sendable { case todo, done, all }
  public enum Archive: Sendable { case active, archived, all }
  public let scope: Scope
  public let completion: Completion
  public let archive: Archive
  public let rowPresentation: PlannerRowPresentationContext?

  public init(
    scope: Scope = .global, completion: Completion = .todo, archive: Archive = .active,
    rowPresentation: PlannerRowPresentationContext? = nil
  ) {
    self.scope = scope
    self.completion = completion
    self.archive = archive
    self.rowPresentation = rowPresentation
  }
}

public enum PlannerRowIdentity: Sendable, Equatable {
  case source(PlannerEntityReference)
}

public struct PlannerQuerySnapshot: Sendable {
  public let session: PlannerDatasetSession
  public let generation: UUID
  public let rows: [PlannerRowIdentity]
  public let matchingCount: Int64
  public let rowPresentation: PlannerRowPresentationContext?
}

public enum PlannerQueryResult: Sendable {
  case snapshot(PlannerQuerySnapshot)
  case failed(PlannerFailure)
}

public enum PlannerRecoveryRequest: Sendable {
  case namespaces
  case namespace(namespaceId: UUID)
  case acknowledgedSnapshot(namespaceId: UUID, checkpointGeneration: Int64)
  case proposal(namespaceId: UUID, proposalId: UUID)
}

public struct PlannerSnapshotSummary: Sendable {
  public let storageSchemaVersion: Int64
  public let portableFormatVersion: Int
  public let checkpointGeneration: Int64
  public let integrity: String
}

public struct PlannerProposalSummary: Sendable {
  public let proposalId: UUID
  public let originalOperationId: UUID
  public let evidence: String
  public let requiresFreshReview: Bool
}

public struct PlannerRecoveryView: Sendable {
  public enum Availability: Sendable { case available, unavailable, ownershipUnverified }
  public let namespaceId: UUID
  public let datasetId: UUID
  public let ownershipDescription: String?
  public let acknowledgedSnapshot: PlannerSnapshotSummary?
  public let preparedProposals: [PlannerProposalSummary]
  public let availability: Availability
}

public struct PlannerRecoverySelection: Sendable {
  public enum Evidence: Sendable { case acknowledgedSnapshot, preparedUnverified }
  public let selectionId: UUID
  public let namespaceId: UUID
  public let datasetId: UUID
  public let ownershipBinding: String
  public let evidence: Evidence
  public let checkpointGeneration: Int64?
  public let proposalId: UUID?
  public let originalOperationId: UUID?
  public let portableData: Data
  public let decodedBackup: PlannerDecodedBackup
}

public enum PlannerRecoveryInspection: Sendable {
  case listedNamespaces([PlannerRecoveryView])
  case listed(PlannerRecoveryView)
  case selected(PlannerRecoverySelection)
  case failed(PlannerFailure)
}

public struct PlannerDecodedBackup: Sendable {
  public let backup: PlannerPortableBackup
}

public struct PlannerPortableBackup: Sendable {
  public let sources: [PlannerPortableItem]
  public let schedules: [PlannerPortableSchedule]

  init(sources: [PlannerPortableItem], schedules: [PlannerPortableSchedule] = []) {
    self.sources = sources
    self.schedules = schedules
  }
}

public struct PlannerPortableItem: Sendable {
  public let kind: PlannerEntityKind
  public let id: UUID
  public let lifetimeId: UUID
  public let createdAt: Date
  public let updatedAt: Date
  public let content: PlannerItemContent
  public let globalDone: Bool
  public let archived: Bool
  public let contentOrigins: [String: String]
}
