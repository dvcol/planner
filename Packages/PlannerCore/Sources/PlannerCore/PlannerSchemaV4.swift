import Foundation
import SwiftData

enum PlannerSchemaV4: VersionedSchema {
  static let versionIdentifier = Schema.Version(4, 0, 0)
  static var models: [any PersistentModel.Type] {
    PlannerSchemaV3.models + [DeletionMarker.self]
  }

  @Model final class DeletionMarker {
    var deletionId: UUID? = nil
    var operationId: UUID? = nil
    var sourceId: UUID? = nil
    var sourceLifetimeId: UUID? = nil
    var sourceKind: String = ""
    var closedFamilyId: UUID? = nil

    init(_ marker: PortableDeletionMarker) throws {
      deletionId = marker.deletionId
      operationId = marker.operationId
      closedFamilyId = marker.closedFamilyId
      switch marker.target {
      case .source(let source):
        sourceId = source.id
        sourceLifetimeId = source.lifetimeId
        sourceKind = source.kind
      case .membership(let membership):
        sourceId = membership.id
        sourceLifetimeId = membership.lifetimeId
        sourceKind = membership.kind
      case .itineraryEntry(let identifier, let lifetimeId):
        sourceId = identifier
        sourceLifetimeId = lifetimeId
        sourceKind = "itineraryEntry"
      case .labelAssociation(let identifier, let lifetimeId):
        sourceId = identifier
        sourceLifetimeId = lifetimeId
        sourceKind = "labelAssociation"
      case .ownedLink(let identifier, let lifetimeId):
        sourceId = identifier
        sourceLifetimeId = lifetimeId
        sourceKind = "ownedLink"
      case .expandedCompletion:
        throw PlannerFailure("invalidInput", "Composite closure metadata needs lineage storage.")
      }
    }

    func value() throws -> PortableDeletionMarker {
      guard let deletionId, let operationId, let sourceId, let sourceLifetimeId,
        [
          "item", "list", "itinerary", "schedule", "category", "tag", "membership",
          "labelAssociation",
          "itineraryEntry", "ownedLink",
        ]
        .contains(sourceKind)
      else {
        throw PlannerFailure(
          "readUnavailable", "The deletion marker has unresolved or unsupported metadata.")
      }
      let binding = PlannerBoundIdentity(
        kind: sourceKind, id: sourceId, lifetimeId: sourceLifetimeId)
      let target: PortableDeletionTarget
      if sourceKind == "membership" {
        target = .membership(binding)
      } else if sourceKind == "itineraryEntry" {
        target = .itineraryEntry(id: sourceId, lifetimeId: sourceLifetimeId)
      } else if sourceKind == "labelAssociation" {
        target = .labelAssociation(id: sourceId, lifetimeId: sourceLifetimeId)
      } else if sourceKind == "ownedLink" {
        target = .ownedLink(id: sourceId, lifetimeId: sourceLifetimeId)
      } else {
        target = .source(binding)
      }
      return PortableDeletionMarker(
        deletionId: deletionId, operationId: operationId,
        target: target,
        closedFamilyId: closedFamilyId)
    }
  }
}
