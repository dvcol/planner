import Foundation
import SwiftData
import Testing

@testable import PlannerCore

struct PrivateSyncImportIsolationTests {
  enum Fault: CaseIterable {
    case malformedTag, insertedInvalidTitle, insertedLateDecodeFailure
  }

  @Test(
    arguments: [
      "all", "item", "ownedLink", "category", "tag", "labelAssociation", "list", "itinerary",
      "membership", "itineraryEntry", "expandedCompletion", "schedule",
    ], Fault.allCases)
  @MainActor func rejectedIncomingGraphIsDiscardedWithoutChangingSavedData(
    kind: String, fault: Fault
  ) throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let schema = Schema(versionedSchema: PlannerPrivateSchemaV20.self)
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(
        schema: schema, url: directory.appending(path: "Probe.sqlite"), cloudKitDatabase: .none))
    let seed = ModelContext(container)
    seed.autosaveEnabled = false
    let category = try PlannerSchemaV18.Category(content: .init(name: "Category"))
    let tag = try PlannerSchemaV18.Tag(content: .init(name: "Tag"))
    let item = try PlannerSchemaV18.Item(
      input: .init(title: "Retained Item", links: [.init(originalUrl: "https://example.com")]))
    item.labelAssociations = [
      .init(item: item, category: category), .init(item: item, tag: tag),
    ]
    let list = try PlannerSchemaV18.List(content: .init(name: "List"))
    let itinerary = try PlannerSchemaV18.Itinerary(input: .init(title: "Itinerary"))
    let membership = PlannerSchemaV18.Membership()
    membership.id = UUID()
    membership.lifetimeId = UUID()
    membership.listId = list.id
    membership.listLifetimeId = list.lifetimeId
    membership.itemId = item.id
    membership.itemLifetimeId = item.lifetimeId
    membership.list = list
    membership.item = item
    let entry = PlannerSchemaV18.ItineraryEntry()
    entry.id = UUID()
    entry.lifetimeId = UUID()
    entry.itineraryId = itinerary.id
    entry.itineraryLifetimeId = itinerary.lifetimeId
    entry.sourceKind = "list"
    entry.sourceId = list.id
    entry.sourceLifetimeId = list.lifetimeId
    entry.itinerary = itinerary
    entry.list = list
    let expanded = PlannerSchemaV18.ExpandedCompletion(
      listEntry: entry, membership: membership, localDone: false)
    let schedule = try PlannerSchemaV18.Schedule(
      snapshot: .init(
        id: UUID(), lifetimeId: UUID(),
        form: .timed(start: .now, end: .now.addingTimeInterval(60), planningTimeZone: "UTC")),
      owner: item)
    seed.insert(category)
    seed.insert(tag)
    seed.insert(item)
    seed.insert(list)
    seed.insert(itinerary)
    seed.insert(membership)
    seed.insert(entry)
    seed.insert(expanded)
    seed.insert(schedule)
    try seed.save()

    let original = try PlannerCloudGraph.nodes(in: seed)
    var deleted = Set(original.filter { kind == "all" || $0.kind == kind }.map(\.name))
    var upserts: [PlannerCloudNode] = []
    if fault == .malformedTag {
      var invalid = try #require(original.first { $0.kind == "tag" })
      invalid.fields["name"] = Data("[]".utf8)
      deleted.remove(invalid.name)
      upserts.append(invalid)
    } else if fault == .insertedInvalidTitle || fault == .insertedLateDecodeFailure {
      upserts = try insertedNodes(from: original, invalidTitle: fault == .insertedInvalidTitle)
      if fault == .insertedLateDecodeFailure {
        upserts.append(
          try .init(
            kind: "membershipProvenance", identity: [Data(UUID().uuidString.utf8)], fields: [:]))
      }
    }
    do {
      let incoming = ModelContext(container)
      incoming.autosaveEnabled = false
      try PlannerCloudGraph.stage(
        .init(upserts: upserts, deletions: deleted, bases: [:]), in: incoming)
      for staged in try incoming.fetch(FetchDescriptor<PlannerSchemaV18.Item>()) {
        _ = try staged.value()
      }
      Issue.record("The malformed incoming graph must be rejected before saving.")
    } catch {
      // Match private-sync failure cleanup: discard the unsaved context without rollback.
      if fault == .malformedTag {
        #expect(error is DecodingError)
      } else {
        let failure = try #require(error as? PlannerFailure)
        if fault == .insertedLateDecodeFailure {
          #expect(failure.code == "cloudRecordInvalid")
        } else {
          #expect(failure.code == "invalidInput" || failure.code == "readUnavailable")
        }
      }
    }
    let reopened = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(
        schema: schema, url: directory.appending(path: "Probe.sqlite"), cloudKitDatabase: .none))
    let current = ModelContext(reopened)
    current.autosaveEnabled = false
    #expect(try PlannerCloudGraph.nodes(in: current) == original)
    let retained = try #require(current.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first)
    #expect(try retained.value().input.title == "Retained Item")
    let validIncoming = try insertedNodes(from: original, invalidTitle: false)
    try PlannerCloudGraph.stage(
      .init(upserts: validIncoming, deletions: [], bases: [:]), in: current)
    try current.save()
    let committed = ModelContext(reopened)
    #expect(try committed.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).count == 2)
    #expect(
      try PlannerCloudGraph.nodes(in: committed).count == original.count + validIncoming.count)
  }

  /// Serializes new related records in an independent store, as the private transport does.
  @MainActor private func insertedNodes(from original: [PlannerCloudNode], invalidTitle: Bool)
    throws -> [PlannerCloudNode]
  {
    let schema = Schema(versionedSchema: PlannerPrivateSchemaV20.self)
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(
        schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    let context = ModelContext(container)
    context.autosaveEnabled = false
    try PlannerCloudGraph.stage(.init(upserts: original, deletions: [], bases: [:]), in: context)
    try context.save()
    let category = try #require(context.fetch(FetchDescriptor<PlannerSchemaV18.Category>()).first)
    let tag = try #require(context.fetch(FetchDescriptor<PlannerSchemaV18.Tag>()).first)
    let item = try PlannerSchemaV18.Item(
      input: .init(
        title: invalidTitle ? "" : "Incoming Item",
        links: [.init(originalUrl: "https://example.com/new")]))
    item.labelAssociations = [
      .init(item: item, category: category), .init(item: item, tag: tag),
    ]
    context.insert(item)
    try context.save()
    let oldNames = Set(original.map(\.name))
    return try PlannerCloudGraph.nodes(in: context).filter { !oldNames.contains($0.name) }
  }
}
