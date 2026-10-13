import Foundation
import SwiftData

enum PlannerSchemaV17: VersionedSchema {
  static let versionIdentifier = Schema.Version(17, 0, 0)
  static var models: [any PersistentModel.Type] {
    [
      Item.self, PlannerSchemaV1.Receipt.self, OwnedLink.self, Schedule.self,
      PlannerSchemaV16.LineageRecord.self,
      PlannerSchemaV4.DeletionMarker.self, List.self, Membership.self,
      Category.self, Tag.self, LabelAssociation.self, Itinerary.self, ItineraryEntry.self,
      ExpandedCompletion.self,
    ]
  }

  @Model final class Itinerary {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var titleContentOrigin: String? = nil
    var notesContentOrigin: String? = nil
    var locationContentOrigin: String? = nil
    var title: String = ""
    var notes: String? = nil
    var colorData: Data? = nil
    var iconName: String? = nil
    var manualEstimateData: Data? = nil
    var locationData: Data? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
    var archived: Bool = false
    @Relationship(deleteRule: .nullify, inverse: \OwnedLink.itineraryOwner)
    var links: [OwnedLink]? = nil
    @Relationship(deleteRule: .nullify, inverse: \LabelAssociation.itineraryOwner)
    var labelAssociations: [LabelAssociation]? = nil
    @Relationship(deleteRule: .nullify, inverse: \ItineraryEntry.itinerary)
    var entries: [ItineraryEntry]? = nil
    @Relationship(deleteRule: .nullify, inverse: \Schedule.itineraryOwner)
    var schedules: [Schedule]? = nil

    func applyContentOrigins(_ origins: [String: String]?) {
      titleContentOrigin = origins?["title"]
      notesContentOrigin = origins?["notes"]
      locationContentOrigin = origins?["location"]
    }

    init(input: PlannerItineraryContentInput) throws {
      id = UUID()
      lifetimeId = UUID()
      title = input.title
      notes = input.notes
      colorData = try input.color.map { try JSONEncoder().encode($0) }
      iconName = input.iconName
      manualEstimateData = try input.manualEstimate.map { try JSONEncoder().encode($0) }
      locationData = try input.location.map { try JSONEncoder().encode($0) }
      let now = Date()
      createdAt = now
      updatedAt = now
      links = try input.links.enumerated().map { index, link in
        try OwnedLink(input: link, rank: Int64(index), owner: self)
      }
    }

    func value() throws -> ItinerarySnapshot {
      guard let id, let lifetimeId, let createdAt, let updatedAt else {
        throw PlannerFailure(
          "readUnavailable", "The Itinerary has unresolved identity or timestamps.")
      }
      let associations = try (labelAssociations ?? []).map { try $0.value() }
      guard Set(associations.map(\.id)).count == associations.count else {
        throw PlannerFailure("readUnavailable", "The Itinerary has duplicate label associations.")
      }
      let input = PlannerItineraryContentInput(
        title: title, notes: notes,
        color: try colorData.map { try JSONDecoder().decode(PlannerColor.self, from: $0) },
        iconName: iconName,
        location: try locationData.map {
          try JSONDecoder().decode(PlannerOwnedLocation.self, from: $0)
        },
        categoryIds: Set(associations.filter { $0.label.kind == "category" }.map { $0.label.id }),
        tagIds: Set(associations.filter { $0.label.kind == "tag" }.map { $0.label.id }),
        manualEstimate: try manualEstimateData.map {
          try JSONDecoder().decode(PlannerEstimate.self, from: $0)
        })
      try input.validate()
      let ownedLinks = try (links ?? []).map {
        try $0.value(ownerId: id, ownerLifetimeId: lifetimeId, ownerKind: "itinerary")
      }.sorted { left, right in
        if left.rank != right.rank { return left.rank < right.rank }
        return left.id.uuidString < right.id.uuidString
      }
      guard Set(ownedLinks.map(\.id)).count == ownedLinks.count else {
        throw PlannerFailure(
          "readUnavailable", "The Itinerary has duplicate owned link identities.")
      }
      var snapshot = ItinerarySnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt, input: input,
        archived: archived, links: ownedLinks,
        schedules: try (schedules ?? []).map {
          try $0.value(ownerId: id, ownerLifetimeId: lifetimeId, ownerKind: "itinerary")
        }, labelAssociations: associations,
        labels: try (labelAssociations ?? []).sorted {
          ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "")
        }.map { try $0.labelRead() },
        entries: try (entries ?? []).map { try $0.value() }.sorted {
          if $0.rank != $1.rank { return $0.rank < $1.rank }
          return $0.id.uuidString < $1.id.uuidString
        })
      snapshot.contentOrigins = try plannerReadContentOrigins(
        [
          "title": titleContentOrigin, "notes": notesContentOrigin,
          "location": locationContentOrigin,
        ], independent: snapshot.independentContentOrigins)
      return snapshot
    }
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
    @Relationship(deleteRule: .nullify, inverse: \ExpandedCompletion.membership)
    var expandedCompletions: [ExpandedCompletion]? = nil

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

  @Model final class ItineraryEntry {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var itineraryId: UUID? = nil
    var itineraryLifetimeId: UUID? = nil
    var sourceKind: String = ""
    var sourceId: UUID? = nil
    var sourceLifetimeId: UUID? = nil
    var rank: Int64 = 0
    var localDone: Bool? = nil
    var itinerary: Itinerary? = nil
    var item: Item? = nil
    var list: List? = nil
    @Relationship(deleteRule: .nullify, inverse: \ExpandedCompletion.listEntry)
    var expandedCompletions: [ExpandedCompletion]? = nil

    init(snapshot: ItineraryEntrySnapshot, itinerary: Itinerary, item: Item?, list: List?) {
      id = snapshot.id
      lifetimeId = snapshot.lifetimeId
      itineraryId = snapshot.itinerary.id
      itineraryLifetimeId = snapshot.itinerary.lifetimeId
      sourceKind = snapshot.source.kind
      sourceId = snapshot.source.id
      sourceLifetimeId = snapshot.source.lifetimeId
      rank = snapshot.rank
      localDone = snapshot.localDone
      self.itinerary = itinerary
      self.item = item
      self.list = list
    }

    func value() throws -> ItineraryEntrySnapshot {
      guard let id, let lifetimeId, let itineraryId, let itineraryLifetimeId,
        let sourceId, let sourceLifetimeId,
        itinerary?.id == itineraryId, itinerary?.lifetimeId == itineraryLifetimeId
      else {
        throw PlannerFailure("readUnavailable", "The entry has unresolved itinerary bindings.")
      }
      let validSource: Bool
      switch sourceKind {
      case "item":
        validSource =
          item?.id == sourceId && item?.lifetimeId == sourceLifetimeId && list == nil
          && localDone != nil
      case "list":
        validSource =
          list?.id == sourceId && list?.lifetimeId == sourceLifetimeId && item == nil
          && localDone == nil
      default: validSource = false
      }
      guard validSource else {
        throw PlannerFailure(
          "readUnavailable", "The entry has unresolved source bindings or completion.")
      }
      let completions = try (expandedCompletions ?? []).map { try $0.value() }.sorted {
        $0.context.orderingKey < $1.context.orderingKey
      }
      guard Set(completions.map(\.context)).count == completions.count,
        sourceKind == "list" || completions.isEmpty
      else {
        throw PlannerFailure(
          "readUnavailable", "The entry has duplicate or inapplicable expanded completion.")
      }
      return .init(
        id: id, lifetimeId: lifetimeId,
        itinerary: .init(kind: "itinerary", id: itineraryId, lifetimeId: itineraryLifetimeId),
        source: .init(kind: sourceKind, id: sourceId, lifetimeId: sourceLifetimeId),
        rank: rank, localDone: localDone, expandedCompletions: completions)
    }
  }

  @Model final class ExpandedCompletion {
    var listEntryId: UUID? = nil
    var listEntryLifetimeId: UUID? = nil
    var membershipId: UUID? = nil
    var membershipLifetimeId: UUID? = nil
    var localDone: Bool = false
    var listEntry: ItineraryEntry? = nil
    var membership: Membership? = nil

    init(listEntry: ItineraryEntry, membership: Membership, localDone: Bool) {
      listEntryId = listEntry.id
      listEntryLifetimeId = listEntry.lifetimeId
      membershipId = membership.id
      membershipLifetimeId = membership.lifetimeId
      self.localDone = localDone
      self.listEntry = listEntry
      self.membership = membership
    }

    func value() throws -> ExpandedCompletionSnapshot {
      guard let listEntryId, let listEntryLifetimeId, let membershipId, let membershipLifetimeId,
        let listEntry, let membership, let itineraryId = listEntry.itineraryId,
        listEntry.id == listEntryId, listEntry.lifetimeId == listEntryLifetimeId,
        listEntry.sourceKind == "list", membership.id == membershipId,
        membership.lifetimeId == membershipLifetimeId
      else {
        throw PlannerFailure(
          "readUnavailable", "The expanded completion has unresolved context bindings.")
      }
      let binding = try membership.value()
      guard
        binding.list.id == listEntry.sourceId
          && binding.list.lifetimeId == listEntry.sourceLifetimeId
      else {
        throw PlannerFailure(
          "readUnavailable", "The completion membership no longer belongs to this List entry.")
      }
      return .init(
        context: .init(
          listEntryId: listEntryId, listEntryLifetimeId: listEntryLifetimeId,
          membershipId: membershipId, membershipLifetimeId: membershipLifetimeId),
        localDone: localDone, itineraryId: itineraryId)
    }
  }

  @Model final class Item {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var titleContentOrigin: String? = nil
    var subtitleContentOrigin: String? = nil
    var notesContentOrigin: String? = nil
    var locationContentOrigin: String? = nil
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
    @Relationship(deleteRule: .nullify, inverse: \ItineraryEntry.item)
    var itineraryEntries: [ItineraryEntry]? = nil

    @Relationship(deleteRule: .nullify, inverse: \LabelAssociation.itemOwner)
    var labelAssociations: [LabelAssociation]? = nil

    func applyContentOrigins(_ origins: [String: String]?) {
      titleContentOrigin = origins?["title"]
      subtitleContentOrigin = origins?["subtitle"]
      notesContentOrigin = origins?["notes"]
      locationContentOrigin = origins?["location"]
    }

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
      var snapshot = ItemSnapshot(
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
      snapshot.contentOrigins = try plannerReadContentOrigins(
        [
          "title": titleContentOrigin, "subtitle": subtitleContentOrigin,
          "notes": notesContentOrigin, "location": locationContentOrigin,
        ], independent: snapshot.independentContentOrigins)
      return snapshot
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

    func replaceLabelAssociations(
      with snapshots: [LabelAssociationSnapshot], categories: [Category], tags: [Tag],
      context: ModelContext
    ) throws {
      let previous = labelAssociations ?? []
      let replacements = try snapshots.map { snapshot in
        if let existing = previous.first(where: {
          $0.id == snapshot.id && $0.lifetimeId == snapshot.lifetimeId
        }) {
          return existing
        }
        let category = categories.first {
          $0.id == snapshot.label.id && $0.lifetimeId == snapshot.label.lifetimeId
            && snapshot.label.kind == "category"
        }
        let tag = tags.first {
          $0.id == snapshot.label.id && $0.lifetimeId == snapshot.label.lifetimeId
            && snapshot.label.kind == "tag"
        }
        guard category != nil || tag != nil else {
          throw PlannerFailure("missingReference", "A replacement label binding is unresolved.")
        }
        let association = LabelAssociation(
          snapshot: snapshot, item: self, category: category, tag: tag)
        context.insert(association)
        return association
      }
      labelAssociations = replacements
      let identifiers = Set(snapshots.map(\.id))
      for removed in previous where removed.id.map({ !identifiers.contains($0) }) ?? true {
        context.delete(removed)
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
    var ownerKind: String = "item"
    var itemOwner: Item? = nil
    var itineraryOwner: Itinerary? = nil

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

    init(input: PlannerLinkInput, rank: Int64, owner: Itinerary) throws {
      id = UUID()
      lifetimeId = id
      ownerKind = "itinerary"
      ownerId = owner.id
      ownerLifetimeId = owner.lifetimeId
      self.rank = rank
      originalUrl = input.originalUrl
      label = input.label
      kind = try input.validatedKind(propertyPath: "/command/content/links").rawValue
      itineraryOwner = owner
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

    func value(ownerId: UUID, ownerLifetimeId: UUID, ownerKind: String = "item") throws
      -> OwnedLinkSnapshot
    {
      guard let id, let lifetimeId, self.ownerKind == ownerKind, self.ownerId == ownerId,
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
    var sourceKind: String = "item"
    var sourceId: UUID? = nil
    var sourceLifetimeId: UUID? = nil
    var start: Date? = nil
    var end: Date? = nil
    var planningTimeZone: String = ""
    var formKind: String = "timed"
    var civilStartData: Data? = nil
    var civilEndData: Data? = nil
    var itemOwner: Item? = nil
    var itineraryOwner: Itinerary? = nil

    init(snapshot: ScheduleSnapshot, owner: Item) throws {
      id = snapshot.id
      lifetimeId = snapshot.lifetimeId
      sourceId = owner.id
      sourceLifetimeId = owner.lifetimeId
      try replace(with: snapshot.form)
      itemOwner = owner
    }

    init(snapshot: ScheduleSnapshot, owner: Itinerary) throws {
      id = snapshot.id
      lifetimeId = snapshot.lifetimeId
      sourceKind = "itinerary"
      sourceId = owner.id
      sourceLifetimeId = owner.lifetimeId
      try replace(with: snapshot.form)
      itineraryOwner = owner
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

    func value(ownerId: UUID, ownerLifetimeId: UUID, ownerKind: String = "item") throws
      -> ScheduleSnapshot
    {
      let ownerResolves: Bool
      switch ownerKind {
      case "item":
        ownerResolves =
          itemOwner?.id == ownerId && itemOwner?.lifetimeId == ownerLifetimeId
          && itineraryOwner == nil
      case "itinerary":
        ownerResolves =
          itineraryOwner?.id == ownerId
          && itineraryOwner?.lifetimeId == ownerLifetimeId && itemOwner == nil
      default:
        ownerResolves = false
      }
      guard let id, let lifetimeId, sourceKind == ownerKind, sourceId == ownerId,
        sourceLifetimeId == ownerLifetimeId, ownerResolves
      else {
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
    var nameContentOrigin: String? = nil
    var notesContentOrigin: String? = nil
    var name: String = ""
    var notes: String? = nil
    var colorData: Data? = nil
    var iconName: String? = nil
    var manualEstimateData: Data? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
    var archived: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Membership.list)
    var memberships: [Membership]? = nil
    @Relationship(deleteRule: .nullify, inverse: \ItineraryEntry.list)
    var itineraryEntries: [ItineraryEntry]? = nil

    func applyContentOrigins(_ origins: [String: String]?) {
      nameContentOrigin = origins?["name"]
      notesContentOrigin = origins?["notes"]
    }

    init(content: PlannerListContentInput) throws {
      id = UUID()
      lifetimeId = UUID()
      name = content.name
      notes = content.notes
      colorData = try content.color.map { try JSONEncoder().encode($0) }
      iconName = content.iconName
      manualEstimateData = try content.manualEstimate.map { try JSONEncoder().encode($0) }
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
        iconName: iconName,
        manualEstimate: try manualEstimateData.map {
          try JSONDecoder().decode(PlannerEstimate.self, from: $0)
        })
      try content.validate()
      var snapshot = ListSnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
        content: content, archived: archived)
      snapshot.contentOrigins = try plannerReadContentOrigins(
        ["name": nameContentOrigin, "notes": notesContentOrigin],
        independent: snapshot.independentContentOrigins)
      return snapshot
    }
  }

  @Model final class Category {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var nameContentOrigin: String? = nil
    var name: String = ""
    var colorData: Data? = nil
    var iconName: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

    @Relationship(deleteRule: .nullify, inverse: \LabelAssociation.category)
    var associations: [LabelAssociation]? = nil

    func applyContentOrigins(_ origins: [String: String]?) {
      nameContentOrigin = origins?["name"]
    }

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
      var snapshot = CategorySnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
        content: content,
        associations: try (associations ?? []).map { try $0.value() }
      )
      snapshot.contentOrigins = try plannerReadContentOrigins(
        ["name": nameContentOrigin], independent: snapshot.independentContentOrigins)
      return snapshot
    }
  }

  @Model final class Tag {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var nameContentOrigin: String? = nil
    var name: String = ""
    var colorData: Data? = nil
    var iconName: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

    @Relationship(deleteRule: .nullify, inverse: \LabelAssociation.tag)
    var associations: [LabelAssociation]? = nil

    func applyContentOrigins(_ origins: [String: String]?) {
      nameContentOrigin = origins?["name"]
    }

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
      var snapshot = TagSnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
        content: content,
        associations: try (associations ?? []).map { try $0.value() }
      )
      snapshot.contentOrigins = try plannerReadContentOrigins(
        ["name": nameContentOrigin], independent: snapshot.independentContentOrigins)
      return snapshot
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
    var ownerKind: String = "item"
    var itemOwner: Item? = nil
    var itineraryOwner: Itinerary? = nil
    var category: Category? = nil
    var tag: Tag? = nil

    init(snapshot: LabelAssociationSnapshot, item: Item, category: Category?, tag: Tag?) {
      id = snapshot.id
      lifetimeId = snapshot.lifetimeId
      ownerId = snapshot.owner.id
      ownerLifetimeId = snapshot.owner.lifetimeId
      labelKind = snapshot.label.kind
      labelId = snapshot.label.id
      labelLifetimeId = snapshot.label.lifetimeId
      itemOwner = item
      self.category = category
      self.tag = tag
    }

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

    init(itinerary: Itinerary, category: Category) {
      id = UUID()
      lifetimeId = id
      ownerKind = "itinerary"
      ownerId = itinerary.id
      ownerLifetimeId = itinerary.lifetimeId
      labelKind = "category"
      labelId = category.id
      labelLifetimeId = category.lifetimeId
      itineraryOwner = itinerary
      self.category = category
    }

    init(itinerary: Itinerary, tag: Tag) {
      id = UUID()
      lifetimeId = id
      ownerKind = "itinerary"
      ownerId = itinerary.id
      ownerLifetimeId = itinerary.lifetimeId
      labelKind = "tag"
      labelId = tag.id
      labelLifetimeId = tag.lifetimeId
      itineraryOwner = itinerary
      self.tag = tag
    }

    func value() throws -> LabelAssociationSnapshot {
      guard let id, let lifetimeId, let ownerId, let ownerLifetimeId, let labelId,
        let labelLifetimeId
      else {
        throw PlannerFailure("readUnavailable", "The label association has unresolved identity.")
      }
      let ownerAssociations: [LabelAssociation]?
      switch ownerKind {
      case "item":
        guard itemOwner?.id == ownerId, itemOwner?.lifetimeId == ownerLifetimeId,
          itineraryOwner == nil
        else {
          throw PlannerFailure(
            "readUnavailable", "The label association has unresolved Item ownership.")
        }
        ownerAssociations = itemOwner?.labelAssociations
      case "itinerary":
        guard itineraryOwner?.id == ownerId, itineraryOwner?.lifetimeId == ownerLifetimeId,
          itemOwner == nil
        else {
          throw PlannerFailure(
            "readUnavailable", "The label association has unresolved Itinerary ownership.")
        }
        ownerAssociations = itineraryOwner?.labelAssociations
      default:
        throw PlannerFailure(
          "readUnavailable", "The label association has an unsupported owner kind.")
      }
      guard
        ownerAssociations?.contains(where: { $0.id == id && $0.lifetimeId == lifetimeId }) == true
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
        owner: PlannerBoundIdentity(kind: ownerKind, id: ownerId, lifetimeId: ownerLifetimeId),
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
