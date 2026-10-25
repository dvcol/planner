import Foundation
import SwiftData

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

  init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    title = try fields.decode(String.self, forKey: .title)
    subtitle = try fields.decodeIfPresent(String.self, forKey: .subtitle)
    notes = try fields.decodeIfPresent(String.self, forKey: .notes)
    location = try fields.decodeIfPresent(PlannerOwnedLocation.self, forKey: .location)
    estimate = try fields.decodeIfPresent(PortableEstimateRecord.self, forKey: .estimate)?.value
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
    try container.encode(estimate.map(PortableEstimateRecord.init), forKey: .estimate)
  }
}

struct PortableEstimateRecord: Codable {
  let minutes: String
  let displayUnit: PlannerEstimateUnit

  private enum CodingKeys: String, CodingKey { case minutes, displayUnit }

  init(_ estimate: PlannerEstimate) {
    minutes = String(estimate.minutes)
    displayUnit = estimate.displayUnit
  }

  init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    if let text = try? fields.decode(String.self, forKey: .minutes) {
      guard let integer = Int64(text), String(integer) == text else {
        throw PlannerFailure("recoveryIntegrityFailure", "Invalid portable estimate minutes.")
      }
      minutes = text
    } else {
      /// Existing internal prototype recovery snapshots encoded native integer minutes.
      minutes = String(try fields.decode(Int64.self, forKey: .minutes))
    }
    displayUnit = try fields.decode(PlannerEstimateUnit.self, forKey: .displayUnit)
  }

  var value: PlannerEstimate { .init(minutes: Int64(minutes)!, displayUnit: displayUnit) }
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
    contentOrigins = item.contentOrigins ?? item.independentContentOrigins
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
    try plannerValidateContentOrigins(contentOrigins, expected: expected)
    return PlannerPortableItem(
      kind: kind, id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
      content: content.input.readContent(), globalDone: globalDone, archived: archived,
      contentOrigins: contentOrigins
    )
  }
}

/// Portable recovery snapshot retaining completion history and restoration lineage.
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
  let contextAliases: [PlannerPortableContextAlias]
  let completionChanges: [PlannerPortableCompletionChange]
  let restorationFamilies: [PlannerPortableRestorationFamily]
  let membershipProvenance: [PlannerPortableMembershipProvenance]
  let membershipRemovals: [PlannerPortableMembershipRemoval]

  init(snapshot: PlannerDataSnapshot, lineage: PlannerNativeLineage) {
    format = snapshot.format
    formatVersion = snapshot.formatVersion
    sources = snapshot.sources
    memberships = snapshot.memberships
    itineraryEntries = snapshot.itineraryEntries
    expandedCompletions = snapshot.expandedCompletions
    labelAssociations = snapshot.labelAssociations
    ownedLinks = snapshot.ownedLinks
    schedules = snapshot.schedules
    deletionMarkers = snapshot.deletionMarkers
    contextAliases = lineage.contextAliases
    completionChanges = lineage.completionChanges
    restorationFamilies = lineage.restorationFamilies
    membershipProvenance = lineage.membershipProvenance
    membershipRemovals = lineage.membershipRemovals
  }

  enum CodingKeys: String, CodingKey, CaseIterable {
    case format, formatVersion, sources, memberships, itineraryEntries, expandedCompletions
    case schedules, labelAssociations, ownedLinks, deletionMarkers, contextAliases,
      completionChanges
    case restorationFamilies, membershipProvenance, membershipRemovals
  }

  init(
    itineraries: [ItinerarySnapshot], labelAssociations: [LabelAssociationSnapshot],
    tags: [TagSnapshot],
    categories: [CategorySnapshot],
    items: [ItemSnapshot], lists: [ListSnapshot], memberships: [MembershipSnapshot],
    deletionMarkers: [PortableDeletionMarker],
    contextAliases: [PlannerPortableContextAlias] = [],
    completionChanges: [PlannerPortableCompletionChange] = [],
    restorationFamilies: [PlannerPortableRestorationFamily] = [],
    membershipProvenance: [PlannerPortableMembershipProvenance] = [],
    membershipRemovals: [PlannerPortableMembershipRemoval] = []
  ) {
    self.membershipProvenance = membershipProvenance.map(\.normalized).sorted {
      if $0.membershipId != $1.membershipId {
        return $0.membershipId.uuidString < $1.membershipId.uuidString
      }
      return $0.membershipLifetimeId.uuidString < $1.membershipLifetimeId.uuidString
    }
    self.membershipRemovals = membershipRemovals.sorted {
      $0.deletionId.uuidString < $1.deletionId.uuidString
    }
    self.contextAliases = contextAliases.sorted { $0.aliasId.uuidString < $1.aliasId.uuidString }
    self.completionChanges = completionChanges.sorted { $0.id.uuidString < $1.id.uuidString }
    self.restorationFamilies = restorationFamilies.sorted {
      $0.familyId.uuidString < $1.familyId.uuidString
    }
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
    formatVersion = 5
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
    if formatVersion >= 4 {
      var validation = PlannerPortableImportDecoder(
        root: .init(value: try PlannerImportJSON(from: decoder), path: ""))
      do {
        _ = try validation.decode()
      } catch let failure as PlannerFailure {
        throw PlannerFailure(
          "recoveryIntegrityFailure", failure.message, propertyPath: failure.propertyPath)
      }
    }
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
    contextAliases = try container.decode(
      [PlannerPortableContextAlias].self, forKey: .contextAliases)
    completionChanges = try container.decode(
      [PlannerPortableCompletionChange].self, forKey: .completionChanges)
    restorationFamilies = try container.decode(
      [PlannerPortableRestorationFamily].self, forKey: .restorationFamilies)
    if formatVersion >= 3 {
      membershipProvenance = try container.decode(
        [PlannerPortableMembershipProvenance].self, forKey: .membershipProvenance)
      membershipRemovals = try container.decode(
        [PlannerPortableMembershipRemoval].self, forKey: .membershipRemovals)
    } else {
      guard !container.contains(.membershipProvenance), !container.contains(.membershipRemovals)
      else {
        throw DecodingError.dataCorruptedError(
          forKey: .formatVersion, in: container,
          debugDescription: "Membership provenance requires portable version 3.")
      }
      membershipProvenance = []
      membershipRemovals = []
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
    try container.encode(contextAliases, forKey: .contextAliases)
    if formatVersion >= 4 {
      try container.encode(completionChanges, forKey: .completionChanges)
    } else {
      try container.encode(
        completionChanges.map(PlannerLegacyPortableCompletionChange.init),
        forKey: .completionChanges)
    }
    try container.encode(restorationFamilies, forKey: .restorationFamilies)
    if formatVersion >= 3 {
      try container.encode(membershipProvenance, forKey: .membershipProvenance)
      try container.encode(membershipRemovals, forKey: .membershipRemovals)
    }
  }

  func validated() throws -> PlannerDecodedBackup {
    let decoded = try decodedRecords()
    guard Set(memberships.map(\.id)).count == memberships.count,
      Set(memberships.map { $0.list.id.uuidString + "/" + $0.item.id.uuidString }).count
        == memberships.count
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot contains duplicate memberships.")
    }
    guard Set(expandedCompletions.map(\.context)).count == expandedCompletions.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot contains duplicate expanded completion contexts.")
    }
    do { try PlannerImportGraph(backup: decoded.backup).validate() } catch let failure
      as PlannerFailure
    {
      throw PlannerFailure(
        "recoveryIntegrityFailure", failure.message, propertyPath: failure.propertyPath)
    }
    return decoded
  }

  func decodedRecords() throws -> PlannerDecodedBackup {
    guard format == "planner-data", (1...5).contains(formatVersion) else {
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
    guard Set(itineraryEntries.map(\.id)).count == itineraryEntries.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "The snapshot contains duplicate itinerary entries.")
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
    let itemLifetimesByIdentity = Dictionary(
      uniqueKeysWithValues: itemRecords.map { ($0.id, $0.lifetimeId) })
    let listLifetimesByIdentity = Dictionary(
      uniqueKeysWithValues: listRecords.map { ($0.id, $0.lifetimeId) })
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
    let portableLinks = try ownedLinks.map { record in
      let link = try record.validated(sources: itemRecords, itineraries: itineraryRecords)
      return PlannerPortableOwnedLink(
        id: record.id, lifetimeId: record.lifetimeId,
        owner: .init(kind: link.owner.kind, id: link.owner.id, lifetimeId: record.owner.lifetimeId),
        rank: link.rank, originalUrl: link.read.originalUrl, label: link.read.label,
        kind: link.read.kind, providerReference: link.read.providerReference)
    }
    let linksByOwner = Dictionary(
      grouping: portableLinks, by: { $0.owner.kind.rawValue + ":" + $0.owner.id.uuidString })
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
          }.map { $0.label.id }), manualEstimate: itinerary.content.manualEstimate)
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
    let decoded = PlannerDecodedBackup(
      backup: PlannerPortableBackup(
        sources: items.map(PlannerPortableSource.item) + lists.map(PlannerPortableSource.list)
          + itineraries.map(PlannerPortableSource.itinerary)
          + categories.map(PlannerPortableSource.category)
          + tags.map(PlannerPortableSource.tag),
        labelAssociations: labels,
        memberships: try memberships.map {
          try $0.validated(
            itemLifetimesByIdentity: itemLifetimesByIdentity,
            listLifetimesByIdentity: listLifetimesByIdentity)
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
            labelAssociations: labelAssociations,
            entries: itineraryEntries, ownedLinks: portableLinks,
            expandedCompletions: expandedCompletions,
            allowsObservedExpandedAssertions: formatVersion >= 4)
        }, ownedLinks: portableLinks, contextAliases: contextAliases,
        completionChanges: completionChanges, restorationFamilies: restorationFamilies,
        formatVersion: formatVersion, membershipProvenance: membershipProvenance,
        membershipRemovals: membershipRemovals))
    return decoded
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
  let formatVersion: Int?
  let resolvedBindings: [PlannerBoundIdentity]?
  let resolvedMembershipEvidence: [PlannerPortableMembershipProvenance]?
  let resolvedExpandedCompletionEvidence: [PlannerExpandedCompletionEvidence]?

  init(
    proposalId: UUID, originalOperationId: UUID, datasetId: UUID, ownershipBinding: String,
    proposedBackup: PlannerDataSnapshot, payloadDigest: String, evidence: String,
    resolvedBindings: [PlannerBoundIdentity]? = nil,
    resolvedMembershipEvidence: [PlannerPortableMembershipProvenance]? = nil,
    resolvedExpandedCompletionEvidence: [PlannerExpandedCompletionEvidence]? = nil
  ) {
    self.proposalId = proposalId
    self.originalOperationId = originalOperationId
    self.datasetId = datasetId
    self.ownershipBinding = ownershipBinding
    self.proposedBackup = proposedBackup
    self.payloadDigest = payloadDigest
    self.evidence = evidence
    if resolvedExpandedCompletionEvidence != nil {
      formatVersion = 3
    } else {
      formatVersion = resolvedMembershipEvidence == nil ? nil : 2
    }
    self.resolvedExpandedCompletionEvidence = resolvedExpandedCompletionEvidence.map(
      plannerSortedExpandedCompletionEvidence)
    self.resolvedBindings = resolvedBindings
    self.resolvedMembershipEvidence = resolvedMembershipEvidence.map(
      plannerSortedMembershipEvidence)
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case proposalId, originalOperationId, datasetId, ownershipBinding, proposedBackup,
      payloadDigest, evidence, formatVersion, resolvedBindings, resolvedMembershipEvidence,
      resolvedExpandedCompletionEvidence
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    proposalId = try container.decode(UUID.self, forKey: .proposalId)
    originalOperationId = try container.decode(UUID.self, forKey: .originalOperationId)
    datasetId = try container.decode(UUID.self, forKey: .datasetId)
    ownershipBinding = try container.decode(String.self, forKey: .ownershipBinding)
    proposedBackup = try container.decode(PlannerDataSnapshot.self, forKey: .proposedBackup)
    payloadDigest = try container.decode(String.self, forKey: .payloadDigest)
    evidence = try container.decode(String.self, forKey: .evidence)
    formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion)
    if let formatVersion {
      var expected = Set(CodingKeys.allCases.map(\.rawValue))
      if formatVersion == 2 { expected.remove("resolvedExpandedCompletionEvidence") }
      guard (2...3).contains(formatVersion),
        case .object(let fields) = try PlannerImportJSON(from: decoder),
        Set(fields.keys) == expected
      else {
        throw PlannerFailure("recoveryIntegrityFailure", "Prepared membership evidence is invalid.")
      }
      resolvedBindings = try container.decode(
        [PlannerBoundIdentity].self, forKey: .resolvedBindings)
      resolvedMembershipEvidence = try container.decode(
        [PlannerPortableMembershipProvenance].self, forKey: .resolvedMembershipEvidence)
      if formatVersion == 3 {
        resolvedExpandedCompletionEvidence = try container.decode(
          [PlannerExpandedCompletionEvidence].self, forKey: .resolvedExpandedCompletionEvidence)
      } else {
        resolvedExpandedCompletionEvidence = nil
      }
    } else {
      guard !container.contains(.resolvedBindings), !container.contains(.resolvedMembershipEvidence)
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "Prepared membership evidence needs its version.")
      }
      resolvedBindings = nil
      guard !container.contains(.resolvedExpandedCompletionEvidence) else {
        throw PlannerFailure("recoveryIntegrityFailure", "Expanded evidence needs its version.")
      }
      resolvedExpandedCompletionEvidence = nil
      resolvedMembershipEvidence = nil
    }
  }

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
  let maintenanceReceipts: [RecoveryMaintenanceReceipt]

  func validated(identity: PlannerStoreIdentity) throws -> (Data, PlannerDecodedBackup, Int64) {
    guard format == "planner-recovery", (1...2).contains(formatVersion),
      formatVersion == 2 || maintenanceReceipts.isEmpty,
      [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17",
        "18", "19", "20", "21", "22", "23",
      ]
      .contains(
        storageSchemaVersion),
      namespaceId == identity.namespaceId, datasetId == identity.datasetId,
      ownershipBinding == identity.ownershipBinding, !ownershipBinding.isEmpty,
      let generation = Int64(checkpointGeneration), generation > 0,
      String(generation) == checkpointGeneration,
      let bytes = Data(base64Encoded: portablePayloadBase64),
      plannerDigest(bytes, prefix: "sha256:") == dataDigest,
      Set(receipts.map(\.operationId)).count == receipts.count,
      Set(maintenanceReceipts.map(\.evidence.maintenanceId)).count == maintenanceReceipts.count
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
    for receipt in maintenanceReceipts {
      try receipt.validate(identity: identity, generation: generation)
      let minimumVersion: Int
      if receipt.evidence.ruleVersion == 3 {
        minimumVersion = 5
      } else if receipt.evidence.kind == "sourceRestorationConsolidation"
        || receipt.evidence.ruleVersion == 2
      {
        minimumVersion = 4
      } else {
        minimumVersion = 3
      }
      guard decoded.backup.formatVersion >= minimumVersion else {
        throw PlannerFailure(
          "recoveryIntegrityFailure",
          "This maintenance rule requires its declared portable recovery version."
        )
      }
    }
    return (bytes, decoded, generation)
  }
}

struct PlannerRecoveryArchive {
  let rootURL: URL
  let identity: PlannerStoreIdentity
  let nativeContext: ModelContext?

  var namespaceURL: URL { rootURL.appendingPathComponent(identity.namespaceId.uuidString) }

  func prepare(_ proposal: RecoveryPreparedProposal) throws {
    var retained = proposal
    if let nativeContext {
      let lineage = try PlannerNativeLineage(context: nativeContext)
        .reconciling(proposal.proposedBackup, context: nativeContext)
      retained = .init(
        proposalId: proposal.proposalId, originalOperationId: proposal.originalOperationId,
        datasetId: proposal.datasetId, ownershipBinding: proposal.ownershipBinding,
        proposedBackup: .init(
          snapshot: proposal.proposedBackup, lineage: lineage),
        payloadDigest: proposal.payloadDigest, evidence: proposal.evidence,
        resolvedBindings: proposal.resolvedBindings,
        resolvedMembershipEvidence: proposal.resolvedMembershipEvidence,
        resolvedExpandedCompletionEvidence: proposal.resolvedExpandedCompletionEvidence)
    }
    _ = try retained.proposedBackup.validated()
    try plannerWriteDurably(
      JSONEncoder().encode(retained),
      to: namespaceURL.appendingPathComponent("proposal-\(proposal.proposalId.uuidString).json")
    )
  }

  func discardPreparedProposal(_ proposalId: UUID) throws {
    let proposalURL = namespaceURL.appendingPathComponent("proposal-\(proposalId.uuidString).json")
    if FileManager.default.fileExists(atPath: proposalURL.path) {
      try FileManager.default.removeItem(at: proposalURL)
    }
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
    contextAliases: [PlannerPortableContextAlias] = [],
    completionChanges: [PlannerPortableCompletionChange] = [],
    restorationFamilies: [PlannerPortableRestorationFamily] = [],
    membershipProvenance: [PlannerPortableMembershipProvenance] = [],
    membershipRemovals: [PlannerPortableMembershipRemoval] = [],
    receipts: [PlannerSchemaV1.Receipt]
  ) throws -> Int64 {
    let lineage = try nativeContext.map { try PlannerNativeLineage(context: $0) }
    return try publish(
      snapshot: PlannerDataSnapshot(
        itineraries: itineraries, labelAssociations: labelAssociations, tags: tags,
        categories: categories,
        items: items, lists: lists, memberships: memberships,
        deletionMarkers: deletionMarkers, contextAliases: lineage?.contextAliases ?? contextAliases,
        completionChanges: lineage?.completionChanges ?? completionChanges,
        restorationFamilies: lineage?.restorationFamilies ?? restorationFamilies,
        membershipProvenance: lineage?.membershipProvenance ?? membershipProvenance,
        membershipRemovals: lineage?.membershipRemovals ?? membershipRemovals),
      receipts: receipts)
  }

  func publish(snapshot: PlannerDataSnapshot, receipts: [PlannerSchemaV1.Receipt]) throws -> Int64 {
    let previous = try latest()
    let previousGeneration = try previous?.validated(identity: identity).2 ?? 0
    let (generation, overflow) = previousGeneration.addingReportingOverflow(1)
    guard !overflow else {
      throw PlannerFailure("recoveryIncomplete", "Recovery checkpoint capacity was exceeded.")
    }
    let bytes = try JSONEncoder().encode(snapshot)
    let priorCheckpoints = Dictionary(
      uniqueKeysWithValues: (previous?.receipts ?? []).map {
        ($0.operationId, $0.checkpointGeneration.flatMap(Int64.init))
      })
    var acknowledgedCommands = Dictionary(
      uniqueKeysWithValues: (previous?.receipts ?? []).map { ($0.operationId, $0) })
    for receipt in receipts {
      let evidence = try RecoveryReceipt(
        receipt,
        checkpoint: receipt.operationId.flatMap { priorCheckpoints[$0] ?? nil } ?? generation)
      if let prior = acknowledgedCommands[evidence.operationId] {
        guard prior.payloadDigest == evidence.payloadDigest, prior.datasetId == evidence.datasetId,
          prior.ownershipBinding == evidence.ownershipBinding, prior.result == evidence.result
        else {
          throw PlannerFailure(
            "recoveryIntegrityFailure", "Command acknowledgement differs from its commit.")
        }
      }
      acknowledgedCommands[evidence.operationId] = evidence
    }
    let evidence = acknowledgedCommands.values.sorted {
      $0.operationId.uuidString < $1.operationId.uuidString
    }
    var acknowledgedMaintenance = Dictionary(
      uniqueKeysWithValues: (previous?.maintenanceReceipts ?? []).map {
        ($0.evidence.maintenanceId, $0)
      })
    if let nativeContext {
      for commit in try maintenanceCommits(in: nativeContext) {
        if let prior = acknowledgedMaintenance[commit.maintenanceId] {
          guard prior.evidence == commit else {
            throw PlannerFailure(
              "recoveryIntegrityFailure", "Maintenance acknowledgement differs from its commit.")
          }
          continue
        }
        try verifyMaintenancePreparation(commit)
        acknowledgedMaintenance[commit.maintenanceId] = .init(
          evidence: commit, checkpointGeneration: generation)
      }
    }
    let maintenance = acknowledgedMaintenance.values.sorted {
      $0.evidence.maintenanceId.uuidString < $1.evidence.maintenanceId.uuidString
    }
    let envelope = RecoveryEnvelope(
      format: "planner-recovery",
      formatVersion: maintenance.isEmpty ? (previous?.formatVersion ?? 1) : 2,
      namespaceId: identity.namespaceId,
      datasetId: identity.datasetId, ownershipBinding: identity.ownershipBinding,
      storageSchemaVersion: String(identity.schemaVersion),
      checkpointGeneration: String(generation),
      portablePayloadBase64: bytes.base64EncodedString(),
      dataDigest: plannerDigest(bytes, prefix: "sha256:"),
      receipts: evidence, preparedProposals: [],
      maintenanceReceipts: maintenance
    )
    _ = try envelope.validated(identity: identity)
    try plannerWriteDurably(
      JSONEncoder().encode(envelope),
      to: namespaceURL.appendingPathComponent("checkpoint-\(generation).json"))
    return generation
  }

  func view() throws -> PlannerRecoveryView {
    let envelope = try latest()
    let validated = try envelope?.validated(identity: identity)
    let snapshot = validated.map { _, decoded, generation in
      PlannerSnapshotSummary(
        storageSchemaVersion: Int64(envelope?.storageSchemaVersion ?? "") ?? 0,
        portableFormatVersion: decoded.backup.formatVersion, checkpointGeneration: generation,
        integrity: "verified")
    }
    return PlannerRecoveryView(
      namespaceId: identity.namespaceId, datasetId: identity.datasetId,
      ownershipDescription: nil, acknowledgedSnapshot: snapshot,
      preparedProposals: try proposals().map(\.summary),
      preparedMaintenance: try preparedMaintenance().map(\.summary),
      availability: .available
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
      maintenanceId: nil,
      portableData: bytes, decodedBackup: decoded
    )
  }

  func selection(maintenanceId: UUID) throws -> PlannerRecoverySelection {
    let matches = try preparedMaintenance().filter { $0.maintenanceId == maintenanceId }
    guard let preparation = matches.first else {
      throw PlannerFailure("missingReference", "The selected prepared maintenance is unavailable.")
    }
    guard matches.count == 1 else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "Prepared maintenance identities are duplicated.")
    }
    let decoded = try preparation.proposedBackup.validated()
    let bytes = try JSONEncoder().encode(preparation.proposedBackup)
    return PlannerRecoverySelection(
      selectionId: UUID(), namespaceId: identity.namespaceId, datasetId: identity.datasetId,
      ownershipBinding: identity.ownershipBinding, evidence: .preparedMaintenanceUnverified,
      checkpointGeneration: nil, proposalId: nil, originalOperationId: nil,
      maintenanceId: preparation.maintenanceId, portableData: bytes, decodedBackup: decoded)
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
      originalOperationId: proposal.originalOperationId, maintenanceId: nil,
      portableData: bytes, decodedBackup: decoded)
  }
}
