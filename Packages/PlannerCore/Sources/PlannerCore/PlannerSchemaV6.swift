import Foundation
import SwiftData

enum PlannerSchemaV6: VersionedSchema {
  static let versionIdentifier = Schema.Version(6, 0, 0)
  static var models: [any PersistentModel.Type] { PlannerSchemaV5.models + [List.self] }

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
}
