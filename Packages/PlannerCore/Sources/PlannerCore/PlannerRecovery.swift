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

/// This slice supports Items, Lists, Categories, Tags, label associations, memberships, owned links, direct timed/all-day Schedules and minimal deletion metadata. Other graph groups must be empty.
struct PlannerDataSnapshot: Codable {
  let format: String
  let formatVersion: Int
  let sources: [PortableSourceRecord]
  let memberships: [PortableMembershipRecord]
  let itineraryEntries: [PortableItineraryEntryRecord]
  let expandedCompletions: [PortableExpandedCompletionRecord]
  let labelAssociations: [PortableLabelAssociationRecord]
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
    itineraries: [ItinerarySnapshot], labelAssociations: [LabelAssociationSnapshot],
    tags: [TagSnapshot],
    categories: [CategorySnapshot],
    items: [ItemSnapshot], lists: [ListSnapshot], memberships: [MembershipSnapshot],
    deletionMarkers: [PortableDeletionMarker]
  ) {
    self.itineraryEntries = itineraries.flatMap(\.entries).map(PortableItineraryEntryRecord.init)
      .sorted { $0.id.uuidString < $1.id.uuidString }
    self.expandedCompletions = itineraries.flatMap(\.entries).flatMap(\.expandedCompletions).map(
      PortableExpandedCompletionRecord.init
    ).sorted { $0.context.orderingKey < $1.context.orderingKey }
    self.labelAssociations = labelAssociations.map(PortableLabelAssociationRecord.init).sorted {
      $0.id.uuidString < $1.id.uuidString
    }
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
      + itineraries.map { PortableSourceRecord.itinerary(PortableItineraryRecord($0)) }
      + categories.map { PortableSourceRecord.category(PortableCategoryRecord($0)) }
      + tags.map { PortableSourceRecord.tag(PortableTagRecord($0)) }).sorted {
        $0.id.uuidString < $1.id.uuidString
      }
    ownedLinks =
      (items.flatMap { item in
        item.links.map { PortableOwnedLink($0, owner: item) }
      }
      + itineraries.flatMap { itinerary in
        itinerary.links.map { PortableOwnedLink($0, owner: itinerary) }
      }).sorted { $0.id.uuidString < $1.id.uuidString }
    schedules =
      (items.flatMap { item in
        item.schedules.map { PortableScheduleRecord($0, owner: item) }
      }
      + itineraries.flatMap { itinerary in
        itinerary.schedules.map { PortableScheduleRecord($0, owner: itinerary) }
      }).sorted { $0.id.uuidString < $1.id.uuidString }
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    format = try container.decode(String.self, forKey: .format)
    formatVersion = try container.decode(Int.self, forKey: .formatVersion)
    sources = try container.decode([PortableSourceRecord].self, forKey: .sources)
    memberships = try container.decode([PortableMembershipRecord].self, forKey: .memberships)
    itineraryEntries = try container.decode(
      [PortableItineraryEntryRecord].self, forKey: .itineraryEntries)
    expandedCompletions = try container.decode(
      [PortableExpandedCompletionRecord].self, forKey: .expandedCompletions)
    labelAssociations = try container.decode(
      [PortableLabelAssociationRecord].self, forKey: .labelAssociations)
    ownedLinks = try container.decode([PortableOwnedLink].self, forKey: .ownedLinks)
    schedules = try container.decode([PortableScheduleRecord].self, forKey: .schedules)
    deletionMarkers = try container.decode([PortableDeletionMarker].self, forKey: .deletionMarkers)
    for key in CodingKeys.allCases
    where key != .format && key != .formatVersion && key != .sources && key != .ownedLinks
      && key != .schedules && key != .deletionMarkers && key != .memberships
      && key != .labelAssociations && key != .itineraryEntries && key != .expandedCompletions
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
    try container.encode(itineraryEntries, forKey: .itineraryEntries)
    try container.encode(expandedCompletions, forKey: .expandedCompletions)
    try container.encode(labelAssociations, forKey: .labelAssociations)
    try container.encode(ownedLinks, forKey: .ownedLinks)
    try container.encode(schedules, forKey: .schedules)
    try container.encode(deletionMarkers, forKey: .deletionMarkers)
    for key in CodingKeys.allCases
    where key != .format && key != .formatVersion && key != .sources && key != .ownedLinks
      && key != .schedules && key != .deletionMarkers && key != .memberships
      && key != .labelAssociations && key != .itineraryEntries && key != .expandedCompletions
    {
      try container.encode([String](), forKey: key)
    }
  }

  func validated() throws -> PlannerDecodedBackup {
    guard format == "planner-data", formatVersion == 1 else {
      throw PlannerFailure("recoveryIntegrityFailure", "Unsupported portable recovery format.")
    }
    guard Set(sources.map { $0.kind.rawValue + ":" + $0.id.uuidString }).count == sources.count
    else {
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
    guard Set(itineraryEntries.map(\.id)).count == itineraryEntries.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot contains duplicate itinerary entries.")
    }
    guard Set(expandedCompletions.map(\.context)).count == expandedCompletions.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot contains duplicate expanded completion contexts.")
    }
    let itemRecords = sources.compactMap {
      if case .item(let item) = $0 { return item }
      return nil
    }
    let listRecords = sources.compactMap {
      if case .list(let list) = $0 { return list }
      return nil
    }
    let itineraryRecords = sources.compactMap { source -> PortableItineraryRecord? in
      guard case .itinerary(let itinerary) = source else { return nil }
      return itinerary
    }
    let lists = try listRecords.map { try $0.validated() }
    let categories = try sources.compactMap { source -> PlannerPortableCategory? in
      guard case .category(let category) = source else { return nil }
      return try category.validated()
    }
    let tags = try sources.compactMap { source -> PlannerPortableTag? in
      guard case .tag(let tag) = source else { return nil }
      return try tag.validated()
    }
    let labels = try labelAssociations.map {
      try $0.validated(
        items: itemRecords, itineraries: itineraryRecords, categories: categories, tags: tags)
    }
    let pairs = labels.map {
      $0.owner.kind.rawValue + ":" + $0.owner.id.uuidString + ":" + $0.label.kind.rawValue + ":"
        + $0.label.id.uuidString
    }
    guard Set(labels.map(\.id)).count == labels.count, Set(pairs).count == labels.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot contains duplicate label associations or pairs.")
    }
    let linksByOwner = try Dictionary(
      grouping: ownedLinks.map {
        try $0.validated(sources: itemRecords, itineraries: itineraryRecords)
      }, by: { $0.owner.kind.rawValue + ":" + $0.owner.id.uuidString })
    let items = try itemRecords.map { source in
      let item = try source.validated()
      let links = (linksByOwner["item:" + item.id.uuidString] ?? []).sorted { left, right in
        if left.rank != right.rank { return left.rank < right.rank }
        return left.id.uuidString < right.id.uuidString
      }.map(\.read)
      return PlannerPortableItem(
        kind: item.kind, id: item.id, lifetimeId: item.lifetimeId,
        createdAt: item.createdAt, updatedAt: item.updatedAt,
        content: PlannerItemContentInput(
          title: item.content.title, subtitle: item.content.subtitle,
          notes: item.content.notes, location: item.content.location,
          estimate: item.content.estimate,
          categoryIds: Set(
            labels.filter {
              $0.owner.kind == .item && $0.owner.id == item.id && $0.label.kind == .category
            }.map {
              $0.label.id
            }),
          tagIds: Set(
            labels.filter {
              $0.owner.kind == .item && $0.owner.id == item.id && $0.label.kind == .tag
            }.map { $0.label.id })
        )
        .readContent(links: links),
        globalDone: item.globalDone, archived: item.archived, contentOrigins: item.contentOrigins)
    }
    let itineraries = try itineraryRecords.map { record in
      let itinerary = try record.validated()
      let links = (linksByOwner["itinerary:" + itinerary.id.uuidString] ?? []).sorted {
        left, right in
        if left.rank != right.rank { return left.rank < right.rank }
        return left.id.uuidString < right.id.uuidString
      }.map(\.read)
      let input = PlannerItineraryContentInput(
        title: itinerary.content.title, notes: itinerary.content.notes,
        color: itinerary.content.color,
        iconName: itinerary.content.iconName, location: itinerary.content.location,
        categoryIds: Set(
          labels.filter {
            $0.owner.kind == .itinerary && $0.owner.id == itinerary.id && $0.label.kind == .category
          }.map { $0.label.id }),
        tagIds: Set(
          labels.filter {
            $0.owner.kind == .itinerary && $0.owner.id == itinerary.id && $0.label.kind == .tag
          }.map { $0.label.id }))
      return PlannerPortableItinerary(
        id: itinerary.id, lifetimeId: itinerary.lifetimeId,
        createdAt: itinerary.createdAt, updatedAt: itinerary.updatedAt,
        content: input.readContent(links: links), archived: itinerary.archived,
        contentOrigins: itinerary.contentOrigins)
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
          + itineraries.map(PlannerPortableSource.itinerary)
          + categories.map(PlannerPortableSource.category)
          + tags.map(PlannerPortableSource.tag),
        labelAssociations: labels,
        memberships: try memberships.map {
          try $0.validated(items: itemRecords, lists: listRecords)
        },
        itineraryEntries: try itineraryEntries.map {
          try $0.validated(items: itemRecords, lists: listRecords, itineraries: itineraryRecords)
        },
        expandedCompletions: try expandedCompletions.map {
          try $0.validated(entries: itineraryEntries, memberships: memberships)
        },
        schedules: try schedules.map {
          try $0.validated(sources: itemRecords, itineraries: itineraryRecords)
        },
        deletionMarkers: try deletionMarkers.map {
          try $0.validated(
            items: itemRecords, lists: listRecords, itineraries: itineraryRecords,
            schedules: schedules, categories: categories,
            tags: tags,
            memberships: memberships,
            labelAssociations: labelAssociations,
            entries: itineraryEntries)
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
      ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14"].contains(
        storageSchemaVersion),
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
    let decoded: PlannerDecodedBackup
    do {
      decoded = try JSONDecoder().decode(PlannerDataSnapshot.self, from: bytes).validated()
    } catch is DecodingError {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The recovery snapshot contains malformed data records.")
    }
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
    itineraries: [ItinerarySnapshot], labelAssociations: [LabelAssociationSnapshot],
    tags: [TagSnapshot],
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
        itineraries: itineraries, labelAssociations: labelAssociations, tags: tags,
        categories: categories,
        items: items, lists: lists, memberships: memberships,
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

  func selection(proposalId: UUID) throws -> PlannerRecoverySelection {
    let matches = try proposals().filter { $0.proposalId == proposalId }
    guard let proposal = matches.first else {
      throw PlannerFailure("missingReference", "The selected prepared proposal is unavailable.")
    }
    guard matches.count == 1 else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "Prepared proposal identities are duplicated.")
    }
    let decoded = try proposal.proposedBackup.validated()
    let bytes = try JSONEncoder().encode(proposal.proposedBackup)
    return PlannerRecoverySelection(
      selectionId: UUID(), namespaceId: identity.namespaceId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding, evidence: .preparedUnverified,
      checkpointGeneration: nil, proposalId: proposal.proposalId,
      originalOperationId: proposal.originalOperationId,
      portableData: bytes, decodedBackup: decoded)
  }
}
