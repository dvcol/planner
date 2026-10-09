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

    init(_ marker: PortableDeletionMarker) {
      deletionId = marker.deletionId
      operationId = marker.operationId
      closedFamilyId = marker.closedFamilyId
      switch marker.target {
      case .source(let source):
        sourceId = source.id
        sourceLifetimeId = source.lifetimeId
        sourceKind = source.kind
      }
    }

    func value() throws -> PortableDeletionMarker {
      guard let deletionId, let operationId, let sourceId, let sourceLifetimeId,
        sourceKind == "schedule", closedFamilyId == nil
      else {
        throw PlannerFailure(
          "readUnavailable", "The deletion marker has unresolved or unsupported metadata.")
      }
      return PortableDeletionMarker(
        deletionId: deletionId, operationId: operationId,
        target: .source(
          PlannerBoundIdentity(kind: sourceKind, id: sourceId, lifetimeId: sourceLifetimeId)),
        closedFamilyId: closedFamilyId)
    }
  }
}
