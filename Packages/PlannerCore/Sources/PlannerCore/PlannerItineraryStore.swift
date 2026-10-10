import Foundation
import SwiftData

extension PlannerSchemaV13.Itinerary {
  func replaceLinks(with snapshots: [OwnedLinkSnapshot], context: ModelContext) throws {
    let previous = links ?? []
    let retainedIdentifiers = Set(snapshots.map(\.id))
    links = try snapshots.map { snapshot in
      let record: PlannerSchemaV13.OwnedLink
      if let existing = previous.first(where: {
        $0.id == snapshot.id && $0.lifetimeId == snapshot.lifetimeId
      }) {
        record = existing
      } else {
        record = try PlannerSchemaV13.OwnedLink(
          input: .init(originalUrl: snapshot.originalUrl, label: snapshot.label),
          rank: snapshot.rank, owner: self)
        record.id = snapshot.id
        record.lifetimeId = snapshot.lifetimeId
        context.insert(record)
      }
      record.rank = snapshot.rank
      record.originalUrl = snapshot.originalUrl
      record.label = snapshot.label
      record.kind = snapshot.kind.rawValue
      return record
    }
    for record in previous where record.id.map(retainedIdentifiers.contains) != true {
      context.delete(record)
    }
  }

  func replaceLabelAssociations(
    with snapshots: [LabelAssociationSnapshot], categories: [PlannerSchemaV13.Category],
    tags: [PlannerSchemaV13.Tag], context: ModelContext
  ) throws {
    let previous = labelAssociations ?? []
    labelAssociations = try snapshots.map { snapshot in
      if let existing = previous.first(where: {
        $0.id == snapshot.id && $0.lifetimeId == snapshot.lifetimeId
      }) {
        return existing
      }
      let association: PlannerSchemaV13.LabelAssociation
      if let category = categories.first(where: {
        $0.id == snapshot.label.id && $0.lifetimeId == snapshot.label.lifetimeId
          && snapshot.label.kind == "category"
      }) {
        association = PlannerSchemaV13.LabelAssociation(itinerary: self, category: category)
      } else if let tag = tags.first(where: {
        $0.id == snapshot.label.id && $0.lifetimeId == snapshot.label.lifetimeId
          && snapshot.label.kind == "tag"
      }) {
        association = PlannerSchemaV13.LabelAssociation(itinerary: self, tag: tag)
      } else {
        throw PlannerFailure("readUnavailable", "A replacement label has no native source.")
      }
      association.id = snapshot.id
      association.lifetimeId = snapshot.lifetimeId
      context.insert(association)
      return association
    }
    let identifiers = Set(snapshots.map(\.id))
    for removed in previous where removed.id.map({ !identifiers.contains($0) }) ?? true {
      context.delete(removed)
    }
  }
}
