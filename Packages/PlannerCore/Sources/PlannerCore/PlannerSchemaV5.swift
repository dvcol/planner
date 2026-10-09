import Foundation
import SwiftData

enum PlannerSchemaV5: VersionedSchema {
  static let versionIdentifier = Schema.Version(5, 0, 0)
  static var models: [any PersistentModel.Type] {
    [
      Item.self, PlannerSchemaV1.Receipt.self, OwnedLink.self, Schedule.self,
      PlannerSchemaV4.DeletionMarker.self,
    ]
  }

  @Model final class Item {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var title: String = ""
    var subtitle: String? = nil
    var notes: String? = nil
    var locationData: Data? = nil
    var estimateData: Data? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
    var globalDone: Bool = false
    var archived: Bool = false
    @Relationship(deleteRule: .nullify, inverse: \OwnedLink.itemOwner)
    var links: [OwnedLink]? = nil
    @Relationship(deleteRule: .nullify, inverse: \Schedule.itemOwner)
    var schedules: [Schedule]? = nil

    init(input: PlannerItemContentInput) throws {
      id = UUID()
      lifetimeId = UUID()
      title = input.title
      subtitle = input.subtitle
      notes = input.notes
      locationData = try input.location.map { try JSONEncoder().encode($0) }
      estimateData = try input.estimate.map { try JSONEncoder().encode($0) }
      let now = Date()
      createdAt = now
      updatedAt = now
      links = try input.links.enumerated().map { index, link in
        try OwnedLink(input: link, rank: Int64(index), owner: self)
      }
    }

    func value() throws -> ItemSnapshot {
      guard let id, let lifetimeId, let createdAt, let updatedAt else {
        throw PlannerFailure("readUnavailable", "The Item has unresolved identity or timestamps.")
      }
      let input = PlannerItemContentInput(
        title: title, subtitle: subtitle, notes: notes,
        location: try locationData.map {
          try JSONDecoder().decode(PlannerOwnedLocation.self, from: $0)
        },
        estimate: try estimateData.map { try JSONDecoder().decode(PlannerEstimate.self, from: $0) }
      )
      try input.validate()
      let ownedLinks = try (links ?? []).map {
        try $0.value(ownerId: id, ownerLifetimeId: lifetimeId)
      }
      .sorted { left, right in
        if left.rank != right.rank { return left.rank < right.rank }
        return left.id.uuidString < right.id.uuidString
      }
      guard Set(ownedLinks.map(\.id)).count == ownedLinks.count else {
        throw PlannerFailure("readUnavailable", "The Item has duplicate owned link identities.")
      }
      return ItemSnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
        input: input, globalDone: globalDone, archived: archived, links: ownedLinks,
        schedules: try (schedules ?? []).map {
          try $0.value(ownerId: id, ownerLifetimeId: lifetimeId)
        }
      )
    }

    func replaceLinks(with snapshots: [OwnedLinkSnapshot], context: ModelContext) {
      let previous = links ?? []
      let retainedIdentifiers = Set(snapshots.map(\.id))
      links = snapshots.map { snapshot in
        if let existing = previous.first(where: { $0.id == snapshot.id }) {
          existing.rank = snapshot.rank
          existing.originalUrl = snapshot.originalUrl
          existing.label = snapshot.label
          existing.kind = snapshot.kind.rawValue
          return existing
        }
        return OwnedLink(snapshot: snapshot, owner: self)
      }
      for record in previous where record.id.map(retainedIdentifiers.contains) != true {
        context.delete(record)
      }
    }
  }

  @Model final class OwnedLink {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var ownerId: UUID? = nil
    var ownerLifetimeId: UUID? = nil
    var rank: Int64 = 0
    var originalUrl: String = ""
    var label: String? = nil
    var kind: String = "website"
    var itemOwner: Item? = nil

    init(input: PlannerLinkInput, rank: Int64, owner: Item) throws {
      id = UUID()
      lifetimeId = UUID()
      ownerId = owner.id
      ownerLifetimeId = owner.lifetimeId
      self.rank = rank
      originalUrl = input.originalUrl
      label = input.label
      kind = try input.validatedKind(propertyPath: "/command/content/links").rawValue
      itemOwner = owner
    }

    init(snapshot: OwnedLinkSnapshot, owner: Item) {
      id = snapshot.id
      lifetimeId = snapshot.lifetimeId
      ownerId = owner.id
      ownerLifetimeId = owner.lifetimeId
      rank = snapshot.rank
      originalUrl = snapshot.originalUrl
      label = snapshot.label
      kind = snapshot.kind.rawValue
      itemOwner = owner
    }

    func value(ownerId: UUID, ownerLifetimeId: UUID) throws -> OwnedLinkSnapshot {
      guard let id, let lifetimeId, self.ownerId == ownerId,
        self.ownerLifetimeId == ownerLifetimeId,
        let classification = PlannerLinkKind(rawValue: kind)
      else {
        throw PlannerFailure(
          "readUnavailable", "The owned link has unresolved identity or ownership.")
      }
      let input = PlannerLinkInput(originalUrl: originalUrl, label: label)
      guard try input.validatedKind(propertyPath: "/links") == classification else {
        throw PlannerFailure("readUnavailable", "The owned link has inconsistent classification.")
      }
      return OwnedLinkSnapshot(
        id: id, lifetimeId: lifetimeId, rank: rank, originalUrl: originalUrl,
        label: label, kind: classification)
    }
  }

  @Model final class Schedule {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var sourceId: UUID? = nil
    var sourceLifetimeId: UUID? = nil
    var start: Date? = nil
    var end: Date? = nil
    var planningTimeZone: String = ""
    var formKind: String = "timed"
    var civilStartData: Data? = nil
    var civilEndData: Data? = nil
    var itemOwner: Item? = nil

    init(snapshot: ScheduleSnapshot, owner: Item) throws {
      id = snapshot.id
      lifetimeId = snapshot.lifetimeId
      sourceId = owner.id
      sourceLifetimeId = owner.lifetimeId
      try replace(with: snapshot.form)
      itemOwner = owner
    }

    func replace(with form: PlannerScheduleForm) throws {
      try form.validate()
      switch form {
      case .timed(let start, let end, let planningTimeZone):
        formKind = "timed"
        self.start = start
        self.end = end
        self.planningTimeZone = planningTimeZone
        civilStartData = nil
        civilEndData = nil
      case .allDay(let start, let end):
        formKind = "allDay"
        civilStartData = try JSONEncoder().encode(start)
        civilEndData = try end.map { try JSONEncoder().encode($0) }
        self.start = nil
        self.end = nil
        planningTimeZone = ""
      }
    }

    func value(ownerId: UUID, ownerLifetimeId: UUID) throws -> ScheduleSnapshot {
      guard let id, let lifetimeId, sourceId == ownerId, sourceLifetimeId == ownerLifetimeId else {
        throw PlannerFailure(
          "readUnavailable", "The Schedule has unresolved identity or ownership.")
      }
      let form: PlannerScheduleForm
      switch formKind {
      case "timed":
        guard let start, civilStartData == nil, civilEndData == nil else {
          throw PlannerFailure("readUnavailable", "The timed Schedule has inconsistent fields.")
        }
        form = .timed(start: start, end: end, planningTimeZone: planningTimeZone)
      case "allDay":
        guard let civilStartData, start == nil, end == nil, planningTimeZone.isEmpty else {
          throw PlannerFailure("readUnavailable", "The all-day Schedule has inconsistent fields.")
        }
        form = .allDay(
          start: try JSONDecoder().decode(PlannerCivilDate.self, from: civilStartData),
          end: try civilEndData.map { try JSONDecoder().decode(PlannerCivilDate.self, from: $0) })
      default:
        throw PlannerFailure("readUnavailable", "The Schedule form kind is unsupported.")
      }
      try form.validate()
      return ScheduleSnapshot(id: id, lifetimeId: lifetimeId, form: form)
    }
  }
}
