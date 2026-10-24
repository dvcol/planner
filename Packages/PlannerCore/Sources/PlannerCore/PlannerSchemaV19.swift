import Foundation
import SwiftData

enum PlannerSchemaV19: VersionedSchema {
  static let versionIdentifier = Schema.Version(19, 0, 0)
  static var models: [any PersistentModel.Type] {
    PlannerSchemaV18.models + [MembershipProvenance.self, MaintenanceCommit.self]
  }

  @Model final class MembershipProvenance {
    var membershipId: UUID? = nil
    var membershipLifetimeId: UUID? = nil
    var recordData: Data? = nil

    init(membershipId: UUID, membershipLifetimeId: UUID, recordData: Data) {
      self.membershipId = membershipId
      self.membershipLifetimeId = membershipLifetimeId
      self.recordData = recordData
    }
  }

  @Model final class MaintenanceCommit {
    var maintenanceId: UUID? = nil
    var evidenceData: Data? = nil

    init(maintenanceId: UUID, evidenceData: Data) {
      self.maintenanceId = maintenanceId
      self.evidenceData = evidenceData
    }
  }
}
