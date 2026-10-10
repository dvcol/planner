import Foundation
import SwiftData

enum PlannerSchemaV9: VersionedSchema {
  static let versionIdentifier = Schema.Version(9, 0, 0)
  static var models: [any PersistentModel.Type] { PlannerSchemaV8.models + [Tag.self] }

  @Model final class Tag {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var name: String = ""
    var colorData: Data? = nil
    var iconName: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

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
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt, content: content
      )
    }
  }
}
