import Foundation
import SwiftData

struct PlannerCloudField<Model: PersistentModel> {
  let name: String
  let encode: (Model) throws -> Data
  let decode: (Data, Model) throws -> Void

  init<Value: Codable>(_ name: String, _ path: ReferenceWritableKeyPath<Model, Value>) {
    self.name = name
    encode = { model in
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      return try encoder.encode(model[keyPath: path])
    }
    decode = { data, model in
      model[keyPath: path] = try JSONDecoder().decode(Value.self, from: data)
    }
  }
}

protocol PlannerCloudModel: PersistentModel {
  init()
  static var cloudKind: String { get }
  static var cloudIdentity: [String] { get }
  static var cloudFields: [PlannerCloudField<Self>] { get }
}

extension PlannerCloudModel {
  func cloudNode() throws -> PlannerCloudNode {
    let fields = try Dictionary(
      uniqueKeysWithValues: Self.cloudFields.map {
        ($0.name, try $0.encode(self))
      })
    let identity = try Self.cloudIdentity.map { name in
      guard let value = fields[name] else {
        throw PlannerFailure("readUnavailable", "A cloud identity field is missing.")
      }
      return value
    }
    return try .init(kind: Self.cloudKind, identity: identity, fields: fields)
  }
}

extension PlannerSchemaV18.Itinerary: PlannerCloudModel {
  static var cloudKind: String { "itinerary" }
  static var cloudIdentity: [String] { ["id", "lifetimeId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV18.Itinerary>] {
    [
      .init("id", \.id),
      .init("lifetimeId", \.lifetimeId),
      .init("titleContentOrigin", \.titleContentOrigin),
      .init("notesContentOrigin", \.notesContentOrigin),
      .init("locationContentOrigin", \.locationContentOrigin),
      .init("title", \.title),
      .init("notes", \.notes),
      .init("colorData", \.colorData),
      .init("iconName", \.iconName),
      .init("manualEstimateData", \.manualEstimateData),
      .init("locationData", \.locationData),
      .init("createdAt", \.createdAt),
      .init("updatedAt", \.updatedAt),
      .init("archived", \.archived),
    ]
  }
}

extension PlannerSchemaV18.Membership: PlannerCloudModel {
  static var cloudKind: String { "membership" }
  static var cloudIdentity: [String] { ["id", "lifetimeId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV18.Membership>] {
    [
      .init("id", \.id),
      .init("lifetimeId", \.lifetimeId),
      .init("listId", \.listId),
      .init("listLifetimeId", \.listLifetimeId),
      .init("itemId", \.itemId),
      .init("itemLifetimeId", \.itemLifetimeId),
      .init("rank", \.rank),
      .init("localDone", \.localDone),
    ]
  }
}

extension PlannerSchemaV18.ItineraryEntry: PlannerCloudModel {
  static var cloudKind: String { "itineraryEntry" }
  static var cloudIdentity: [String] { ["id", "lifetimeId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV18.ItineraryEntry>] {
    [
      .init("id", \.id),
      .init("lifetimeId", \.lifetimeId),
      .init("itineraryId", \.itineraryId),
      .init("itineraryLifetimeId", \.itineraryLifetimeId),
      .init("sourceKind", \.sourceKind),
      .init("sourceId", \.sourceId),
      .init("sourceLifetimeId", \.sourceLifetimeId),
      .init("rank", \.rank),
      .init("localDone", \.localDone),
    ]
  }
}

extension PlannerSchemaV18.ExpandedCompletion: PlannerCloudModel {
  static var cloudKind: String { "expandedCompletion" }
  static var cloudIdentity: [String] {
    ["listEntryId", "listEntryLifetimeId", "membershipId", "membershipLifetimeId"]
  }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV18.ExpandedCompletion>] {
    [
      .init("listEntryId", \.listEntryId),
      .init("listEntryLifetimeId", \.listEntryLifetimeId),
      .init("membershipId", \.membershipId),
      .init("membershipLifetimeId", \.membershipLifetimeId),
      .init("localDone", \.localDone),
    ]
  }
}

extension PlannerSchemaV18.Item: PlannerCloudModel {
  static var cloudKind: String { "item" }
  static var cloudIdentity: [String] { ["id", "lifetimeId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV18.Item>] {
    [
      .init("id", \.id),
      .init("lifetimeId", \.lifetimeId),
      .init("titleContentOrigin", \.titleContentOrigin),
      .init("subtitleContentOrigin", \.subtitleContentOrigin),
      .init("notesContentOrigin", \.notesContentOrigin),
      .init("locationContentOrigin", \.locationContentOrigin),
      .init("title", \.title),
      .init("subtitle", \.subtitle),
      .init("notes", \.notes),
      .init("locationData", \.locationData),
      .init("estimateData", \.estimateData),
      .init("createdAt", \.createdAt),
      .init("updatedAt", \.updatedAt),
      .init("globalDone", \.globalDone),
      .init("archived", \.archived),
    ]
  }
}

extension PlannerSchemaV18.OwnedLink: PlannerCloudModel {
  static var cloudKind: String { "ownedLink" }
  static var cloudIdentity: [String] { ["id", "lifetimeId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV18.OwnedLink>] {
    [
      .init("id", \.id),
      .init("lifetimeId", \.lifetimeId),
      .init("ownerId", \.ownerId),
      .init("ownerLifetimeId", \.ownerLifetimeId),
      .init("rank", \.rank),
      .init("originalUrl", \.originalUrl),
      .init("label", \.label),
      .init("kind", \.kind),
      .init("providerReferenceValue", \.providerReferenceValue),
      .init("ownerKind", \.ownerKind),
    ]
  }
}

extension PlannerSchemaV18.Schedule: PlannerCloudModel {
  static var cloudKind: String { "schedule" }
  static var cloudIdentity: [String] { ["id", "lifetimeId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV18.Schedule>] {
    [
      .init("id", \.id),
      .init("lifetimeId", \.lifetimeId),
      .init("sourceKind", \.sourceKind),
      .init("sourceId", \.sourceId),
      .init("sourceLifetimeId", \.sourceLifetimeId),
      .init("start", \.start),
      .init("end", \.end),
      .init("planningTimeZone", \.planningTimeZone),
      .init("formKind", \.formKind),
      .init("civilStartData", \.civilStartData),
      .init("civilEndData", \.civilEndData),
    ]
  }
}

extension PlannerSchemaV18.List: PlannerCloudModel {
  static var cloudKind: String { "list" }
  static var cloudIdentity: [String] { ["id", "lifetimeId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV18.List>] {
    [
      .init("id", \.id),
      .init("lifetimeId", \.lifetimeId),
      .init("nameContentOrigin", \.nameContentOrigin),
      .init("notesContentOrigin", \.notesContentOrigin),
      .init("name", \.name),
      .init("notes", \.notes),
      .init("colorData", \.colorData),
      .init("iconName", \.iconName),
      .init("manualEstimateData", \.manualEstimateData),
      .init("createdAt", \.createdAt),
      .init("updatedAt", \.updatedAt),
      .init("archived", \.archived),
    ]
  }
}

extension PlannerSchemaV18.Category: PlannerCloudModel {
  static var cloudKind: String { "category" }
  static var cloudIdentity: [String] { ["id", "lifetimeId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV18.Category>] {
    [
      .init("id", \.id),
      .init("lifetimeId", \.lifetimeId),
      .init("nameContentOrigin", \.nameContentOrigin),
      .init("name", \.name),
      .init("colorData", \.colorData),
      .init("iconName", \.iconName),
      .init("createdAt", \.createdAt),
      .init("updatedAt", \.updatedAt),
    ]
  }
}

extension PlannerSchemaV18.Tag: PlannerCloudModel {
  static var cloudKind: String { "tag" }
  static var cloudIdentity: [String] { ["id", "lifetimeId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV18.Tag>] {
    [
      .init("id", \.id),
      .init("lifetimeId", \.lifetimeId),
      .init("nameContentOrigin", \.nameContentOrigin),
      .init("name", \.name),
      .init("colorData", \.colorData),
      .init("iconName", \.iconName),
      .init("createdAt", \.createdAt),
      .init("updatedAt", \.updatedAt),
    ]
  }
}

extension PlannerSchemaV18.LabelAssociation: PlannerCloudModel {
  static var cloudKind: String { "labelAssociation" }
  static var cloudIdentity: [String] { ["id", "lifetimeId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV18.LabelAssociation>] {
    [
      .init("id", \.id),
      .init("lifetimeId", \.lifetimeId),
      .init("ownerId", \.ownerId),
      .init("ownerLifetimeId", \.ownerLifetimeId),
      .init("labelKind", \.labelKind),
      .init("labelId", \.labelId),
      .init("labelLifetimeId", \.labelLifetimeId),
      .init("ownerKind", \.ownerKind),
    ]
  }
}

extension PlannerSchemaV4.DeletionMarker: PlannerCloudModel {
  static var cloudKind: String { "deletionMarker" }
  static var cloudIdentity: [String] { ["deletionId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV4.DeletionMarker>] {
    [
      .init("deletionId", \.deletionId),
      .init("operationId", \.operationId),
      .init("sourceId", \.sourceId),
      .init("sourceLifetimeId", \.sourceLifetimeId),
      .init("sourceKind", \.sourceKind),
      .init("closedFamilyId", \.closedFamilyId),
    ]
  }
}

extension PlannerSchemaV16.LineageRecord: PlannerCloudModel {
  static var cloudKind: String { "lineageRecord" }
  static var cloudIdentity: [String] { ["recordKind", "recordIdentifier"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV16.LineageRecord>] {
    [
      .init("recordIdentifier", \.recordIdentifier),
      .init("recordKind", \.recordKind),
      .init("recordData", \.recordData),
    ]
  }
}

extension PlannerSchemaV19.MembershipProvenance: PlannerCloudModel {
  static var cloudKind: String { "membershipProvenance" }
  static var cloudIdentity: [String] { ["membershipId", "membershipLifetimeId"] }
  static var cloudFields: [PlannerCloudField<PlannerSchemaV19.MembershipProvenance>] {
    [
      .init("membershipId", \.membershipId),
      .init("membershipLifetimeId", \.membershipLifetimeId),
      .init("recordData", \.recordData),
    ]
  }
}

enum PlannerCloudGraph {
  struct Changes: Sendable {
    let upserts: [PlannerCloudNode]
    let deletions: Set<String>
    let bases: [String: PlannerCloudNode]
  }

  static func nodes(in context: ModelContext) throws -> [PlannerCloudNode] {
    var nodes: [PlannerCloudNode] = []
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>()).map {
      try $0.cloudNode()
    }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>()).map {
      try $0.cloudNode()
    }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>()).map {
      try $0.cloudNode()
    }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()).map {
      try $0.cloudNode()
    }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).map { try $0.cloudNode() }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV18.OwnedLink>()).map {
      try $0.cloudNode()
    }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV18.Schedule>()).map {
      try $0.cloudNode()
    }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV18.List>()).map { try $0.cloudNode() }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).map {
      try $0.cloudNode()
    }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).map { try $0.cloudNode() }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>()).map {
      try $0.cloudNode()
    }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV4.DeletionMarker>()).map {
      try $0.cloudNode()
    }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV16.LineageRecord>()).map {
      try $0.cloudNode()
    }
    nodes += try context.fetch(FetchDescriptor<PlannerSchemaV19.MembershipProvenance>()).map {
      try $0.cloudNode()
    }
    guard Set(nodes.map(\.name)).count == nodes.count else {
      throw PlannerFailure("readUnavailable", "Cloud record identities are duplicated locally.")
    }
    return nodes.sorted { $0.name < $1.name }
  }

  static func stage(_ changes: Changes, in context: ModelContext) throws {
    let groups = Dictionary(grouping: changes.upserts, by: \.kind)
    let knownKinds: Set<String> = [
      "itinerary",
      "membership",
      "itineraryEntry",
      "expandedCompletion",
      "item",
      "ownedLink",
      "schedule",
      "list",
      "category",
      "tag",
      "labelAssociation",
      "deletionMarker",
      "lineageRecord",
      "membershipProvenance",
    ]
    guard Set(groups.keys).isSubset(of: knownKinds) else {
      throw PlannerFailure("cloudRecordInvalid", "A private record uses an unsupported kind.")
    }
    try stage(
      PlannerSchemaV18.Itinerary.self, updates: groups["itinerary"] ?? [],
      deleted: changes.deletions, in: context)
    try stage(
      PlannerSchemaV18.Membership.self, updates: groups["membership"] ?? [],
      deleted: changes.deletions, in: context)
    try stage(
      PlannerSchemaV18.ItineraryEntry.self, updates: groups["itineraryEntry"] ?? [],
      deleted: changes.deletions, in: context)
    try stage(
      PlannerSchemaV18.ExpandedCompletion.self, updates: groups["expandedCompletion"] ?? [],
      deleted: changes.deletions, in: context)
    try stage(
      PlannerSchemaV18.Item.self, updates: groups["item"] ?? [], deleted: changes.deletions,
      in: context)
    try stage(
      PlannerSchemaV18.OwnedLink.self, updates: groups["ownedLink"] ?? [],
      deleted: changes.deletions, in: context)
    try stage(
      PlannerSchemaV18.Schedule.self, updates: groups["schedule"] ?? [], deleted: changes.deletions,
      in: context)
    try stage(
      PlannerSchemaV18.List.self, updates: groups["list"] ?? [], deleted: changes.deletions,
      in: context)
    try stage(
      PlannerSchemaV18.Category.self, updates: groups["category"] ?? [], deleted: changes.deletions,
      in: context)
    try stage(
      PlannerSchemaV18.Tag.self, updates: groups["tag"] ?? [], deleted: changes.deletions,
      in: context)
    try stage(
      PlannerSchemaV18.LabelAssociation.self, updates: groups["labelAssociation"] ?? [],
      deleted: changes.deletions, in: context)
    try stage(
      PlannerSchemaV4.DeletionMarker.self, updates: groups["deletionMarker"] ?? [],
      deleted: changes.deletions, in: context)
    try stage(
      PlannerSchemaV16.LineageRecord.self, updates: groups["lineageRecord"] ?? [],
      deleted: changes.deletions, in: context)
    try stage(
      PlannerSchemaV19.MembershipProvenance.self, updates: groups["membershipProvenance"] ?? [],
      deleted: changes.deletions, in: context)
    context.processPendingChanges()
    try reconnect(in: context)
  }

  private static func stage<Model: PlannerCloudModel>(
    _ model: Model.Type, updates: [PlannerCloudNode], deleted: Set<String>, in context: ModelContext
  ) throws {
    var existing: [String: Model] = [:]
    for record in try context.fetch(FetchDescriptor<Model>()) {
      let name = try record.cloudNode().name
      guard existing[name] == nil else {
        throw PlannerFailure("readUnavailable", "A cloud binding is duplicated locally.")
      }
      if deleted.contains(name) { context.delete(record) } else { existing[name] = record }
    }
    for node in updates where !deleted.contains(node.name) {
      guard Set(node.fields.keys) == Set(Model.cloudFields.map(\.name)) else {
        throw PlannerFailure(
          "cloudRecordInvalid", "A private record uses unsupported fields.")
      }
      let record = existing[node.name] ?? Model()
      for field in Model.cloudFields {
        guard let value = node.fields[field.name] else {
          throw PlannerFailure(
            "cloudRecordInvalid", "A private record is missing a required field.")
        }
        if try field.encode(record) != value { try field.decode(value, record) }
      }
      guard try record.cloudNode().name == node.name else {
        throw PlannerFailure("cloudRecordInvalid", "A private record has inconsistent identity.")
      }
      if existing[node.name] == nil { context.insert(record) }
    }
  }

  private static func binding(_ identifier: UUID?, _ lifetime: UUID?) -> String? {
    guard let identifier, let lifetime else { return nil }
    return identifier.uuidString + ":" + lifetime.uuidString
  }

  private static func index<Model>(
    _ models: [Model], binding: (Model) -> String?
  ) throws -> [String: Model] {
    var result: [String: Model] = [:]
    for model in models {
      guard let key = binding(model), result[key] == nil else {
        throw PlannerFailure("readUnavailable", "A private relationship binding is unresolved.")
      }
      result[key] = model
    }
    return result
  }

  /// Scalar lifetime bindings are authoritative; SwiftData inverses are repaired together.
  private static func reconnect(in context: ModelContext) throws {
    let items = try index(context.fetch(FetchDescriptor<PlannerSchemaV18.Item>())) {
      binding($0.id, $0.lifetimeId)
    }
    let lists = try index(context.fetch(FetchDescriptor<PlannerSchemaV18.List>())) {
      binding($0.id, $0.lifetimeId)
    }
    let itineraries = try index(context.fetch(FetchDescriptor<PlannerSchemaV18.Itinerary>())) {
      binding($0.id, $0.lifetimeId)
    }
    let categories = try index(context.fetch(FetchDescriptor<PlannerSchemaV18.Category>())) {
      binding($0.id, $0.lifetimeId)
    }
    let tags = try index(context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>())) {
      binding($0.id, $0.lifetimeId)
    }
    let memberships = try context.fetch(FetchDescriptor<PlannerSchemaV18.Membership>())
    let entries = try context.fetch(FetchDescriptor<PlannerSchemaV18.ItineraryEntry>())
    let membershipIndex = try index(memberships) { binding($0.id, $0.lifetimeId) }
    let entryIndex = try index(entries) { binding($0.id, $0.lifetimeId) }
    for membership in memberships {
      membership.item = binding(membership.itemId, membership.itemLifetimeId).flatMap { items[$0] }
      membership.list = binding(membership.listId, membership.listLifetimeId).flatMap { lists[$0] }
    }
    for entry in entries {
      entry.itinerary = binding(entry.itineraryId, entry.itineraryLifetimeId).flatMap {
        itineraries[$0]
      }
      entry.item =
        entry.sourceKind == "item"
        ? binding(entry.sourceId, entry.sourceLifetimeId).flatMap { items[$0] } : nil
      entry.list =
        entry.sourceKind == "list"
        ? binding(entry.sourceId, entry.sourceLifetimeId).flatMap { lists[$0] } : nil
    }
    for expanded in try context.fetch(FetchDescriptor<PlannerSchemaV18.ExpandedCompletion>()) {
      expanded.listEntry = binding(expanded.listEntryId, expanded.listEntryLifetimeId).flatMap {
        entryIndex[$0]
      }
      expanded.membership = binding(expanded.membershipId, expanded.membershipLifetimeId).flatMap {
        membershipIndex[$0]
      }
    }
    for link in try context.fetch(FetchDescriptor<PlannerSchemaV18.OwnedLink>()) {
      link.itemOwner =
        link.ownerKind == "item"
        ? binding(link.ownerId, link.ownerLifetimeId).flatMap { items[$0] } : nil
      link.itineraryOwner =
        link.ownerKind == "itinerary"
        ? binding(link.ownerId, link.ownerLifetimeId).flatMap { itineraries[$0] } : nil
    }
    for schedule in try context.fetch(FetchDescriptor<PlannerSchemaV18.Schedule>()) {
      schedule.itemOwner =
        schedule.sourceKind == "item"
        ? binding(schedule.sourceId, schedule.sourceLifetimeId).flatMap { items[$0] } : nil
      schedule.itineraryOwner =
        schedule.sourceKind == "itinerary"
        ? binding(schedule.sourceId, schedule.sourceLifetimeId).flatMap { itineraries[$0] } : nil
    }
    for label in try context.fetch(FetchDescriptor<PlannerSchemaV18.LabelAssociation>()) {
      label.itemOwner =
        label.ownerKind == "item"
        ? binding(label.ownerId, label.ownerLifetimeId).flatMap { items[$0] } : nil
      label.itineraryOwner =
        label.ownerKind == "itinerary"
        ? binding(label.ownerId, label.ownerLifetimeId).flatMap { itineraries[$0] } : nil
      label.category =
        label.labelKind == "category"
        ? binding(label.labelId, label.labelLifetimeId).flatMap { categories[$0] } : nil
      label.tag =
        label.labelKind == "tag"
        ? binding(label.labelId, label.labelLifetimeId).flatMap { tags[$0] } : nil
    }
  }
}
