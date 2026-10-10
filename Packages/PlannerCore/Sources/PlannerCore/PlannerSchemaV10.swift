import Foundation
import SwiftData

enum PlannerSchemaV10: VersionedSchema {
  static let versionIdentifier = Schema.Version(10, 0, 0)
  static var models: [any PersistentModel.Type] {
    [
      Item.self, PlannerSchemaV1.Receipt.self, OwnedLink.self, Schedule.self,
      PlannerSchemaV4.DeletionMarker.self, List.self, Membership.self,
      Category.self, Tag.self, LabelAssociation.self,
    ]
  }

  @Model final class Membership {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var listId: UUID? = nil
    var listLifetimeId: UUID? = nil
    var itemId: UUID? = nil
    var itemLifetimeId: UUID? = nil
    var rank: Int64 = 0
    var localDone: Bool = false
    var list: List? = nil
    var item: Item? = nil

    init(snapshot: MembershipSnapshot, list: List, item: Item) {
      id = snapshot.id
      lifetimeId = snapshot.lifetimeId
      listId = snapshot.list.id
      listLifetimeId = snapshot.list.lifetimeId
      itemId = snapshot.item.id
      itemLifetimeId = snapshot.item.lifetimeId
      rank = snapshot.rank
      localDone = snapshot.localDone
      self.list = list
      self.item = item
    }

    func value() throws -> MembershipSnapshot {
      guard let id, let lifetimeId, let listId, let listLifetimeId, let itemId,
        let itemLifetimeId, list?.id == listId, list?.lifetimeId == listLifetimeId,
        item?.id == itemId, item?.lifetimeId == itemLifetimeId
      else {
        throw PlannerFailure("readUnavailable", "The membership has unresolved source bindings.")
      }
      return MembershipSnapshot(
        id: id, lifetimeId: lifetimeId,
        list: PlannerBoundIdentity(kind: "list", id: listId, lifetimeId: listLifetimeId),
        item: PlannerBoundIdentity(kind: "item", id: itemId, lifetimeId: itemLifetimeId),
        rank: rank, localDone: localDone)
    }
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

    @Relationship(deleteRule: .nullify, inverse: \Membership.item)
    var memberships: [Membership]? = nil

    @Relationship(deleteRule: .nullify, inverse: \LabelAssociation.itemOwner)
    var labelAssociations: [LabelAssociation]? = nil

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
      let associations = try (labelAssociations ?? []).map { try $0.value() }
      guard Set(associations.map(\.id)).count == associations.count else {
        throw PlannerFailure("readUnavailable", "The Item has duplicate label associations.")
      }
      let input = PlannerItemContentInput(
        title: title, subtitle: subtitle, notes: notes,
        location: try locationData.map {
          try JSONDecoder().decode(PlannerOwnedLocation.self, from: $0)
        },
        estimate: try estimateData.map { try JSONDecoder().decode(PlannerEstimate.self, from: $0) },
        categoryIds: Set(associations.filter { $0.label.kind == "category" }.map { $0.label.id }),
        tagIds: Set(associations.filter { $0.label.kind == "tag" }.map { $0.label.id })
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
        }, labelAssociations: associations,
        labels: try (labelAssociations ?? []).sorted {
          ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "")
        }.map {
          try $0.labelRead()
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
  @Model final class List {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var name: String = ""
    var notes: String? = nil
    var colorData: Data? = nil
    var iconName: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
    var archived: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Membership.list)
    var memberships: [Membership]? = nil

    init(content: PlannerListContentInput) throws {
      id = UUID()
      lifetimeId = UUID()
      name = content.name
      notes = content.notes
      colorData = try content.color.map { try JSONEncoder().encode($0) }
      iconName = content.iconName
      let now = Date()
      createdAt = now
      updatedAt = now
    }

    func value() throws -> ListSnapshot {
      guard let id, let lifetimeId, let createdAt, let updatedAt else {
        throw PlannerFailure("readUnavailable", "The List has unresolved identity or timestamps.")
      }
      let content = PlannerListContentInput(
        name: name, notes: notes,
        color: try colorData.map { try JSONDecoder().decode(PlannerColor.self, from: $0) },
        iconName: iconName)
      try content.validate()
      return ListSnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
        content: content, archived: archived)
    }
  }

  @Model final class Category {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var name: String = ""
    var colorData: Data? = nil
    var iconName: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

    @Relationship(deleteRule: .nullify, inverse: \LabelAssociation.category)
    var associations: [LabelAssociation]? = nil

    init(content: PlannerCategoryContentInput) throws {
      id = UUID()
      lifetimeId = UUID()
      name = content.name
      colorData = try content.color.map { try JSONEncoder().encode($0) }
      iconName = content.iconName
      let now = Date()
      createdAt = now
      updatedAt = now
    }

    func value() throws -> CategorySnapshot {
      guard let id, let lifetimeId, let createdAt, let updatedAt else {
        throw PlannerFailure(
          "readUnavailable", "The Category has unresolved identity or timestamps.")
      }
      let content = PlannerCategoryContentInput(
        name: name,
        color: try colorData.map { try JSONDecoder().decode(PlannerColor.self, from: $0) },
        iconName: iconName)
      try content.validate()
      return CategorySnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
        content: content,
        associations: try (associations ?? []).map { try $0.value() }
      )
    }
  }

  @Model final class Tag {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var name: String = ""
    var colorData: Data? = nil
    var iconName: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

    @Relationship(deleteRule: .nullify, inverse: \LabelAssociation.tag)
    var associations: [LabelAssociation]? = nil

    init(content: PlannerTagContentInput) throws {
      id = UUID()
      lifetimeId = UUID()
      name = content.name
      colorData = try content.color.map { try JSONEncoder().encode($0) }
      iconName = content.iconName
      let now = Date()
      createdAt = now
      updatedAt = now
    }

    func value() throws -> TagSnapshot {
      guard let id, let lifetimeId, let createdAt, let updatedAt else {
        throw PlannerFailure(
          "readUnavailable", "The Tag has unresolved identity or timestamps.")
      }
      let content = PlannerTagContentInput(
        name: name,
        color: try colorData.map { try JSONDecoder().decode(PlannerColor.self, from: $0) },
        iconName: iconName)
      try content.validate()
      return TagSnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
        content: content,
        associations: try (associations ?? []).map { try $0.value() }
      )
    }
  }

  @Model final class LabelAssociation {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var ownerId: UUID? = nil
    var ownerLifetimeId: UUID? = nil
    var labelKind: String = ""
    var labelId: UUID? = nil
    var labelLifetimeId: UUID? = nil
    var itemOwner: Item? = nil
    var category: Category? = nil
    var tag: Tag? = nil

    init(item: Item, category: Category) {
      id = UUID()
      lifetimeId = id
      ownerId = item.id
      ownerLifetimeId = item.lifetimeId
      labelKind = "category"
      labelId = category.id
      labelLifetimeId = category.lifetimeId
      itemOwner = item
      self.category = category
    }

    init(item: Item, tag: Tag) {
      id = UUID()
      lifetimeId = id
      ownerId = item.id
      ownerLifetimeId = item.lifetimeId
      labelKind = "tag"
      labelId = tag.id
      labelLifetimeId = tag.lifetimeId
      itemOwner = item
      self.tag = tag
    }

    func value() throws -> LabelAssociationSnapshot {
      guard let id, let lifetimeId, let ownerId, let ownerLifetimeId, let labelId,
        let labelLifetimeId, itemOwner?.id == ownerId,
        itemOwner?.lifetimeId == ownerLifetimeId,
        itemOwner?.labelAssociations?.contains(where: { $0.id == id && $0.lifetimeId == lifetimeId }
        ) == true
      else {
        throw PlannerFailure(
          "readUnavailable", "The label association has unresolved owner bindings.")
      }
      switch labelKind {
      case "category":
        guard category?.id == labelId, category?.lifetimeId == labelLifetimeId, tag == nil,
          category?.associations?.contains(where: { $0.id == id && $0.lifetimeId == lifetimeId })
            == true
        else {
          throw PlannerFailure(
            "readUnavailable", "The Category association has unresolved label bindings.")
        }
      case "tag":
        guard tag?.id == labelId, tag?.lifetimeId == labelLifetimeId, category == nil,
          tag?.associations?.contains(where: { $0.id == id && $0.lifetimeId == lifetimeId }) == true
        else {
          throw PlannerFailure(
            "readUnavailable", "The Tag association has unresolved label bindings.")
        }
      default:
        throw PlannerFailure("readUnavailable", "The association has an unsupported label kind.")
      }
      return LabelAssociationSnapshot(
        id: id, lifetimeId: lifetimeId,
        owner: PlannerBoundIdentity(kind: "item", id: ownerId, lifetimeId: ownerLifetimeId),
        label: PlannerBoundIdentity(kind: labelKind, id: labelId, lifetimeId: labelLifetimeId))
    }

    func labelRead() throws -> PlannerLabelRead {
      let snapshot = try value()
      if let category {
        let content = try category.value().content
        return PlannerLabelRead(
          reference: snapshot.labelReference, name: content.name,
          color: content.color, iconName: content.iconName)
      }
      guard let tag else {
        throw PlannerFailure("readUnavailable", "The association has no resolved label.")
      }
      let content = try tag.value().content
      return PlannerLabelRead(
        reference: snapshot.labelReference, name: content.name,
        color: content.color, iconName: content.iconName)
    }
  }

}
