import Foundation

struct PortableItemContent: Codable {
  let title: String
  let subtitle: String?
  let notes: String?
  let location: PlannerOwnedLocation?
  let estimate: PlannerEstimate?

  enum CodingKeys: String, CodingKey { case title, subtitle, notes, location, estimate }

  init(_ input: PlannerItemContentInput) {
    title = input.title
    subtitle = input.subtitle
    notes = input.notes
    location = input.location
    estimate = input.estimate
  }

  var input: PlannerItemContentInput {
    PlannerItemContentInput(
      title: title, subtitle: subtitle, notes: notes, location: location, estimate: estimate)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(title, forKey: .title)
    try container.encode(subtitle, forKey: .subtitle)
    try container.encode(notes, forKey: .notes)
    try container.encode(location, forKey: .location)
    try container.encode(estimate, forKey: .estimate)
  }
}

struct PortableItemRecord: Codable {
  let kind: PlannerEntityKind
  let id: UUID
  let lifetimeId: UUID
  let createdAt: Date
  let updatedAt: Date
  let content: PortableItemContent
  let globalDone: Bool
  let archived: Bool
  let contentOrigins: [String: String]

  init(_ item: ItemSnapshot) {
    kind = .item
    id = item.id
    lifetimeId = item.lifetimeId
    createdAt = item.createdAt
    updatedAt = item.updatedAt
    content = PortableItemContent(item.input)
    globalDone = item.globalDone
    archived = item.archived
    var origins = ["title": "independent"]
    if item.input.subtitle != nil { origins["subtitle"] = "independent" }
    if item.input.notes != nil { origins["notes"] = "independent" }
    if item.input.location != nil { origins["location"] = "independent" }
    contentOrigins = origins
  }

  func validated() throws -> PlannerPortableItem {
    guard kind == .item, createdAt.timeIntervalSinceReferenceDate.isFinite,
      updatedAt.timeIntervalSinceReferenceDate.isFinite
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot has invalid Item identity or dates.")
    }
    try content.input.validate()
    let expected = PortableItemRecord(
      ItemSnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
        input: content.input, globalDone: globalDone, archived: archived
      )
    ).contentOrigins
    guard contentOrigins == expected else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot has inconsistent content origins.")
    }
    return PlannerPortableItem(
      kind: kind, id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
      content: content.input.readContent(), globalDone: globalDone, archived: archived,
      contentOrigins: contentOrigins
    )
  }
}

/// This slice supports Items, Lists, Categories, memberships, owned links, direct timed/all-day Schedules and minimal deletion metadata. Other graph groups must be empty.
struct PlannerDataSnapshot: Codable {
  let format: String
  let formatVersion: Int
  let sources: [PortableSourceRecord]
  let memberships: [PortableMembershipRecord]
  let ownedLinks: [PortableOwnedLink]
  let schedules: [PortableScheduleRecord]
  let deletionMarkers: [PortableDeletionMarker]

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, formatVersion, sources, memberships, itineraryEntries, expandedCompletions
    case schedules, labelAssociations, ownedLinks, deletionMarkers, contextAliases,
      completionChanges
    case restorationFamilies
  }

  init(
    categories: [CategorySnapshot],
    items: [ItemSnapshot], lists: [ListSnapshot], memberships: [MembershipSnapshot],
    deletionMarkers: [PortableDeletionMarker]
  ) {
    self.memberships = memberships.map(PortableMembershipRecord.init).sorted {
      $0.id.uuidString < $1.id.uuidString
    }
    self.deletionMarkers = deletionMarkers.sorted {
      $0.deletionId.uuidString < $1.deletionId.uuidString
    }
    format = "planner-data"
    formatVersion = 1
    sources =
      (items.map { PortableSourceRecord.item(PortableItemRecord($0)) }
      + lists.map { PortableSourceRecord.list(PortableListRecord($0)) }
      + categories.map { PortableSourceRecord.category(PortableCategoryRecord($0)) }).sorted {
        $0.id.uuidString < $1.id.uuidString
      }
    ownedLinks = items.flatMap { item in
      item.links.map { PortableOwnedLink($0, owner: item) }
    }.sorted { $0.id.uuidString < $1.id.uuidString }
    schedules = items.flatMap { item in
      item.schedules.map { PortableScheduleRecord($0, owner: item) }
    }.sorted { $0.id.uuidString < $1.id.uuidString }
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    format = try container.decode(String.self, forKey: .format)
    formatVersion = try container.decode(Int.self, forKey: .formatVersion)
    sources = try container.decode([PortableSourceRecord].self, forKey: .sources)
    memberships = try container.decode([PortableMembershipRecord].self, forKey: .memberships)
    ownedLinks = try container.decode([PortableOwnedLink].self, forKey: .ownedLinks)
    schedules = try container.decode([PortableScheduleRecord].self, forKey: .schedules)
    deletionMarkers = try container.decode([PortableDeletionMarker].self, forKey: .deletionMarkers)
    for key in CodingKeys.allCases
    where key != .format && key != .formatVersion && key != .sources && key != .ownedLinks
      && key != .schedules && key != .deletionMarkers && key != .memberships
    {
      guard try container.decode([String].self, forKey: key).isEmpty else {
        throw PlannerFailure(
          "recoveryIntegrityFailure",
          "This snapshot slice cannot validate nonempty \(key.rawValue).")
      }
    }
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(format, forKey: .format)
    try container.encode(formatVersion, forKey: .formatVersion)
    try container.encode(sources, forKey: .sources)
    try container.encode(memberships, forKey: .memberships)
    try container.encode(ownedLinks, forKey: .ownedLinks)
    try container.encode(schedules, forKey: .schedules)
    try container.encode(deletionMarkers, forKey: .deletionMarkers)
    for key in CodingKeys.allCases
    where key != .format && key != .formatVersion && key != .sources && key != .ownedLinks
      && key != .schedules && key != .deletionMarkers && key != .memberships
    {
      try container.encode([String](), forKey: key)
    }
  }

  func validated() throws -> PlannerDecodedBackup {
    guard format == "planner-data", formatVersion == 1 else {
      throw PlannerFailure("recoveryIntegrityFailure", "Unsupported portable recovery format.")
    }
    guard Set(sources.map(\.id)).count == sources.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot contains duplicate source identities.")
    }
    guard Set(ownedLinks.map(\.id)).count == ownedLinks.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot contains duplicate link identities.")
    }
    guard Set(memberships.map(\.id)).count == memberships.count,
      Set(memberships.map { $0.list.id.uuidString + "/" + $0.item.id.uuidString }).count
        == memberships.count
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot contains duplicate memberships.")
    }
    let itemRecords = sources.compactMap {
      if case .item(let item) = $0 { return item }
      return nil
    }
    let listRecords = sources.compactMap {
      if case .list(let list) = $0 { return list }
      return nil
    }
    let lists = try listRecords.map { try $0.validated() }
    let categories = try sources.compactMap { source -> PlannerPortableCategory? in
      guard case .category(let category) = source else { return nil }
      return try category.validated()
    }
    let linksByOwner = try Dictionary(
      grouping: ownedLinks.map { try $0.validated(sources: itemRecords) }, by: \.ownerId)
    let items = try itemRecords.map { source in
      let item = try source.validated()
      let links = (linksByOwner[item.id] ?? []).sorted { left, right in
        if left.rank != right.rank { return left.rank < right.rank }
        return left.id.uuidString < right.id.uuidString
      }.map(\.read)
      return PlannerPortableItem(
        kind: item.kind, id: item.id, lifetimeId: item.lifetimeId,
        createdAt: item.createdAt, updatedAt: item.updatedAt,
        content: source.content.input.readContent(links: links),
        globalDone: item.globalDone, archived: item.archived, contentOrigins: item.contentOrigins)
    }
    guard Set(schedules.map(\.id)).count == schedules.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot contains duplicate Schedule identities.")
    }
    guard Set(deletionMarkers.map(\.deletionId)).count == deletionMarkers.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot contains duplicate deletion markers.")
    }
    return PlannerDecodedBackup(
      backup: PlannerPortableBackup(
        sources: items.map(PlannerPortableSource.item) + lists.map(PlannerPortableSource.list)
          + categories.map(PlannerPortableSource.category),
        memberships: try memberships.map {
          try $0.validated(items: itemRecords, lists: listRecords)
        },
        schedules: try schedules.map { try $0.validated(sources: itemRecords) },
        deletionMarkers: try deletionMarkers.map {
          try $0.validated(schedules: schedules, memberships: memberships)
        }))
  }
}

struct RecoveryReceipt: Codable {
  let operationId: UUID
  let payloadDigest: String
  let datasetId: UUID
  let ownershipBinding: String
  let result: PlannerAppliedResult
  let commitState: String
  let checkpointGeneration: String?

  init(_ receipt: PlannerSchemaV1.Receipt, checkpoint: Int64?) throws {
    guard let operationId = receipt.operationId, let datasetId = receipt.datasetId
    else {
      throw PlannerFailure(
        "readUnavailable", "Operation evidence has unresolved identity or result.")
    }
    self.operationId = operationId
    self.datasetId = datasetId
    payloadDigest = receipt.payloadDigest
    ownershipBinding = receipt.ownershipBinding
    result = try receipt.evidence().result
    commitState = "applied"
    checkpointGeneration = checkpoint.map(String.init)
  }
}

struct RecoveryPreparedProposal: Codable {
  let proposalId: UUID
  let originalOperationId: UUID
  let datasetId: UUID
  let ownershipBinding: String
  let proposedBackup: PlannerDataSnapshot
  let payloadDigest: String
  let evidence: String

  var summary: PlannerProposalSummary {
    PlannerProposalSummary(
      proposalId: proposalId, originalOperationId: originalOperationId,
      evidence: "preparedUnverified", requiresFreshReview: true
    )
  }
}

struct RecoveryEnvelope: Codable {
  let format: String
  let formatVersion: Int
  let namespaceId: UUID
  let datasetId: UUID
  let ownershipBinding: String
  let storageSchemaVersion: String
  let checkpointGeneration: String
  let portablePayloadBase64: String
  let dataDigest: String
  let receipts: [RecoveryReceipt]
  let preparedProposals: [RecoveryPreparedProposal]

  func validated(identity: PlannerStoreIdentity) throws -> (Data, PlannerDecodedBackup, Int64) {
    guard format == "planner-recovery", formatVersion == 1,
      ["1", "2", "3", "4", "5", "6", "7", "8"].contains(storageSchemaVersion),
      namespaceId == identity.namespaceId, datasetId == identity.datasetId,
      ownershipBinding == identity.ownershipBinding, !ownershipBinding.isEmpty,
      let generation = Int64(checkpointGeneration), generation > 0,
      String(generation) == checkpointGeneration,
      let bytes = Data(base64Encoded: portablePayloadBase64),
      plannerDigest(bytes, prefix: "sha256:") == dataDigest,
      Set(receipts.map(\.operationId)).count == receipts.count
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "Recovery ownership, version or digest validation failed.")
    }
    let decoded = try JSONDecoder().decode(PlannerDataSnapshot.self, from: bytes).validated()
    for receipt in receipts {
      guard receipt.datasetId == datasetId, receipt.ownershipBinding == ownershipBinding,
        receipt.commitState == "applied", let checkpoint = receipt.checkpointGeneration,
        let receiptGeneration = Int64(checkpoint), receiptGeneration > 0,
        receiptGeneration <= generation, String(receiptGeneration) == checkpoint
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "Recovery operation evidence is inconsistent.")
      }
    }
    return (bytes, decoded, generation)
  }
}

struct PlannerRecoveryArchive {
  let rootURL: URL
  let identity: PlannerStoreIdentity

  var namespaceURL: URL { rootURL.appendingPathComponent(identity.namespaceId.uuidString) }

  func prepare(_ proposal: RecoveryPreparedProposal) throws {
    try plannerWriteDurably(
      JSONEncoder().encode(proposal),
      to: namespaceURL.appendingPathComponent("proposal-\(proposal.proposalId.uuidString).json")
    )
  }

  func latest() throws -> RecoveryEnvelope? {
    let files = try FileManager.default.contentsOfDirectory(
      at: namespaceURL, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("checkpoint-") && $0.pathExtension == "json" }
    var latest: RecoveryEnvelope?
    var latestGeneration: Int64 = 0
    for file in files {
      let envelope = try JSONDecoder().decode(RecoveryEnvelope.self, from: Data(contentsOf: file))
      let (_, _, generation) = try envelope.validated(identity: identity)
      if generation > latestGeneration {
        latest = envelope
        latestGeneration = generation
      }
    }
    return latest
  }

  func proposals() throws -> [RecoveryPreparedProposal] {
    let files = try FileManager.default.contentsOfDirectory(
      at: namespaceURL, includingPropertiesForKeys: nil
    )
    .filter { $0.lastPathComponent.hasPrefix("proposal-") && $0.pathExtension == "json" }
    let completed = Set(try latest()?.receipts.map(\.operationId) ?? [])
    return try files.map { file in
      let proposal = try JSONDecoder().decode(
        RecoveryPreparedProposal.self, from: Data(contentsOf: file))
      guard proposal.datasetId == identity.datasetId,
        proposal.ownershipBinding == identity.ownershipBinding,
        proposal.evidence == "preparedUnverified"
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "Prepared recovery evidence has an invalid owner.")
      }
      _ = try proposal.proposedBackup.validated()
      return proposal
    }.filter { !completed.contains($0.originalOperationId) }
      .sorted { $0.proposalId.uuidString < $1.proposalId.uuidString }
  }

  func publish(
    categories: [CategorySnapshot],
    items: [ItemSnapshot], lists: [ListSnapshot], memberships: [MembershipSnapshot],
    deletionMarkers: [PortableDeletionMarker],
    receipts: [PlannerSchemaV1.Receipt]
  ) throws -> Int64 {
    let previous = try latest()
    let previousGeneration = try previous?.validated(identity: identity).2 ?? 0
    let (generation, overflow) = previousGeneration.addingReportingOverflow(1)
    guard !overflow else {
      throw PlannerFailure("recoveryIncomplete", "Recovery checkpoint capacity was exceeded.")
    }
    let bytes = try JSONEncoder().encode(
      PlannerDataSnapshot(
        categories: categories, items: items, lists: lists, memberships: memberships,
        deletionMarkers: deletionMarkers))
    let priorCheckpoints = Dictionary(
      uniqueKeysWithValues: (previous?.receipts ?? []).map {
        ($0.operationId, $0.checkpointGeneration.flatMap(Int64.init))
      })
    let evidence = try receipts.map { receipt in
      try RecoveryReceipt(
        receipt,
        checkpoint: receipt.operationId.flatMap { priorCheckpoints[$0] ?? nil } ?? generation)
    }.sorted { $0.operationId.uuidString < $1.operationId.uuidString }
    let envelope = RecoveryEnvelope(
      format: "planner-recovery", formatVersion: 1, namespaceId: identity.namespaceId,
      datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
      storageSchemaVersion: String(identity.schemaVersion),
      checkpointGeneration: String(generation),
      portablePayloadBase64: bytes.base64EncodedString(),
      dataDigest: plannerDigest(bytes, prefix: "sha256:"),
      receipts: evidence, preparedProposals: []
    )
    _ = try envelope.validated(identity: identity)
    try plannerWriteDurably(
      JSONEncoder().encode(envelope),
      to: namespaceURL.appendingPathComponent("checkpoint-\(generation).json"))
    return generation
  }

  func view() throws -> PlannerRecoveryView {
    let envelope = try latest()
    let generation = try envelope?.validated(identity: identity).2
    let snapshot = generation.map {
      PlannerSnapshotSummary(
        storageSchemaVersion: Int64(envelope?.storageSchemaVersion ?? "") ?? 0,
        portableFormatVersion: 1, checkpointGeneration: $0,
        integrity: "verified")
    }
    return PlannerRecoveryView(
      namespaceId: identity.namespaceId, datasetId: identity.datasetId,
      ownershipDescription: nil, acknowledgedSnapshot: snapshot,
      preparedProposals: try proposals().map(\.summary), availability: .available
    )
  }

  func selection(generation: Int64) throws -> PlannerRecoverySelection {
    let file = namespaceURL.appendingPathComponent("checkpoint-\(generation).json")
    let envelope = try JSONDecoder().decode(RecoveryEnvelope.self, from: Data(contentsOf: file))
    let (bytes, decoded, recordedGeneration) = try envelope.validated(identity: identity)
    guard generation == recordedGeneration else {
      throw PlannerFailure(
        "recoveryIntegrityFailure",
        "The requested checkpoint does not match its recorded generation.")
    }
    return PlannerRecoverySelection(
      selectionId: UUID(), namespaceId: identity.namespaceId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding, evidence: .acknowledgedSnapshot,
      checkpointGeneration: generation, proposalId: nil, originalOperationId: nil,
      portableData: bytes, decodedBackup: decoded
    )
  }
}
