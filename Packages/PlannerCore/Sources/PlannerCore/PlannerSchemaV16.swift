import Foundation
import SwiftData

enum PlannerSchemaV16: VersionedSchema {
  static let versionIdentifier = Schema.Version(16, 0, 0)
  static var models: [any PersistentModel.Type] {
    PlannerSchemaV15.models + [LineageRecord.self]
  }

  @Model final class LineageRecord {
    var recordIdentifier: UUID? = nil
    var recordKind: String = ""
    var recordData: Data? = nil

    init(identifier: UUID, kind: String, data: Data) {
      recordIdentifier = identifier
      recordKind = kind
      recordData = data
    }
  }
}
