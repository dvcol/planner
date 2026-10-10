import Foundation
import SwiftData

enum PlannerSchemaV8: VersionedSchema {
  static let versionIdentifier = Schema.Version(8, 0, 0)
  static var models: [any PersistentModel.Type] { PlannerSchemaV7.models + [Category.self] }

  @Model final class Category {
    var id: UUID? = nil
    var lifetimeId: UUID? = nil
    var name: String = ""
    var colorData: Data? = nil
    var iconName: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

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
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt, content: content
      )
    }
  }
}
