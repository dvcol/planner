import Foundation

enum PortableDeletionTarget: Codable {
  case source(PlannerBoundIdentity)

  private enum CodingKeys: String, CodingKey { case kind, source }

  init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    guard try fields.decode(String.self, forKey: .kind) == "source" else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "This slice supports source deletion targets only.")
    }
    self = .source(try fields.decode(PlannerBoundIdentity.self, forKey: .source))
  }

  func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .source(let source):
      try fields.encode("source", forKey: .kind)
      try fields.encode(source, forKey: .source)
    }
  }
}

struct PortableDeletionMarker: Codable {
  let deletionId: UUID
  let operationId: UUID
  let target: PortableDeletionTarget
  let closedFamilyId: UUID?

  private enum CodingKeys: String, CodingKey {
    case deletionId, operationId, target, closedFamilyId
  }

  func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(deletionId, forKey: .deletionId)
    try fields.encode(operationId, forKey: .operationId)
    try fields.encode(target, forKey: .target)
    try fields.encode(closedFamilyId, forKey: .closedFamilyId)
  }

  func validated(schedules: [PortableScheduleRecord]) throws -> PlannerPortableDeletionMarker {
    switch target {
    case .source(let source):
      guard source.kind == "schedule", closedFamilyId == nil,
        !schedules.contains(where: { $0.id == source.id && $0.lifetimeId == source.lifetimeId })
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The deletion target is unsupported or still live.")
      }
      return PlannerPortableDeletionMarker(
        deletionId: deletionId, operationId: operationId,
        target: .source(
          PlannerEntityReference(kind: .schedule, id: source.id), lifetimeId: source.lifetimeId),
        closedFamilyId: closedFamilyId)
    }
  }
}
