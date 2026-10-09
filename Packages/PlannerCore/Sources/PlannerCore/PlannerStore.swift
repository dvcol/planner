import Foundation
import SwiftData

enum PlannerSchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)
  static var models: [any PersistentModel.Type] { [Item.self, Receipt.self] }

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
    }

    func value() throws -> ItemSnapshot {
      guard let id, let lifetimeId, let createdAt, let updatedAt else {
        throw PlannerFailure("readUnavailable", "The Item has unresolved identity or timestamps.")
      }
      let input = PlannerItemContentInput(
        title: title, subtitle: subtitle, notes: notes,
        location: try locationData.map {
          try JSONDecoder().decode(PlannerOwnedLocation.self, from: $0)
        },
        estimate: try estimateData.map { try JSONDecoder().decode(PlannerEstimate.self, from: $0) }
      )
      try input.validate()
      return ItemSnapshot(
        id: id, lifetimeId: lifetimeId, createdAt: createdAt, updatedAt: updatedAt,
        input: input, globalDone: globalDone, archived: archived
      )
    }
  }

  @Model final class Receipt {
    var operationId: UUID? = nil
    var payloadDigest: String = ""
    var resultData: Data? = nil
    var datasetId: UUID? = nil
    var ownershipBinding: String = ""

    init(
      operation: PlannerOperation, digest: String, result: PlannerAppliedResult,
      bindings: [PlannerBoundIdentity] = []
    ) throws {
      operationId = operation.operationId
      payloadDigest = digest
      resultData = try JSONEncoder().encode(
        PlannerStoredOperationEvidence(result: result, bindings: bindings))
      datasetId = operation.session.datasetId
      ownershipBinding = operation.session.ownershipBinding
    }

    func evidence() throws -> PlannerStoredOperationEvidence {
      guard let resultData else {
        throw PlannerFailure("readUnavailable", "Operation result evidence is missing.")
      }
      if let value = try? JSONDecoder().decode(
        PlannerStoredOperationEvidence.self, from: resultData)
      {
        return value
      }
      // The original creation-only prototype stored AppliedResult directly with no resolved bindings.
      return PlannerStoredOperationEvidence(
        result: try JSONDecoder().decode(PlannerAppliedResult.self, from: resultData), bindings: []
      )
    }
  }
}

struct PlannerBoundIdentity: Codable {
  let kind: String
  let id: UUID
  let lifetimeId: UUID

  var canonicalValue: PlannerCanonicalValue {
    .record(["kind": .string(kind), "id": .identity(id), "lifetimeId": .identity(lifetimeId)])
  }
}

struct PlannerStoredOperationEvidence: Codable {
  let result: PlannerAppliedResult
  let bindings: [PlannerBoundIdentity]
}

enum PlannerMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] { [PlannerSchemaV1.self] }
  static var stages: [MigrationStage] { [] }
}

struct ItemSnapshot {
  let id: UUID
  let lifetimeId: UUID
  let createdAt: Date
  let updatedAt: Date
  let input: PlannerItemContentInput
  let globalDone: Bool
  let archived: Bool

  var reference: PlannerEntityReference { PlannerEntityReference(kind: .item, id: id) }

  func read(datasetId: UUID) -> PlannerSourceRead {
    PlannerSourceRead(
      source: reference, content: input.readContent, createdAt: createdAt, updatedAt: updatedAt,
      fieldHashes: input.fieldHashes(datasetId: datasetId, itemId: id, lifetimeId: lifetimeId),
      state: PlannerSourceState(globalDone: globalDone, archived: archived), labels: [],
      references: []
    )
  }
}

struct PlannerStoreIdentity: Codable {
  let schemaVersion: Int
  let datasetId: UUID
  let epochId: UUID
  let namespaceId: UUID
  let ownershipBinding: String
}

func plannerWriteDurably(_ data: Data, to destination: URL) throws {
  let directory = destination.deletingLastPathComponent()
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let temporaryURL = directory.appendingPathComponent(".\(UUID().uuidString).pending")
  defer { try? FileManager.default.removeItem(at: temporaryURL) }
  try data.write(to: temporaryURL, options: .withoutOverwriting)
  let handle = try FileHandle(forWritingTo: temporaryURL)
  do {
    try handle.synchronize()
    try handle.close()
  } catch {
    try? handle.close()
    throw error
  }
  if FileManager.default.fileExists(atPath: destination.path) {
    _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporaryURL)
  } else {
    try FileManager.default.moveItem(at: temporaryURL, to: destination)
  }
}
