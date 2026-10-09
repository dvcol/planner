import Foundation

public enum PlannerScheduleForm: Sendable, Equatable, Codable {
  case timed(start: Date, end: Date?, planningTimeZone: String)

  private enum CodingKeys: String, CodingKey { case kind, start, end, planningTimeZone }

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    guard try fields.decode(String.self, forKey: .kind) == "timed" else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "This prototype supports timed Schedule forms only.")
    }
    self = .timed(
      start: try fields.decode(Date.self, forKey: .start),
      end: try fields.decode(Date?.self, forKey: .end),
      planningTimeZone: try fields.decode(String.self, forKey: .planningTimeZone))
  }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .timed(let start, let end, let planningTimeZone):
      try fields.encode("timed", forKey: .kind)
      try fields.encode(start, forKey: .start)
      try fields.encode(end, forKey: .end)
      try fields.encode(planningTimeZone, forKey: .planningTimeZone)
    }
  }
}

public struct PlannerPortableSchedule: Sendable {
  public let id: UUID
  public let lifetimeId: UUID
  public let source: PlannerEntityReference
  public let sourceLifetimeId: UUID
  public let form: PlannerScheduleForm
}

struct ScheduleSnapshot {
  let id: UUID
  let lifetimeId: UUID
  let form: PlannerScheduleForm

  var reference: PlannerEntityReference { PlannerEntityReference(kind: .schedule, id: id) }
}

extension PlannerScheduleForm {
  func validate() throws {
    switch self {
    case .timed(let start, let end, let planningTimeZone):
      guard start.timeIntervalSinceReferenceDate.isFinite else {
        throw PlannerFailure(
          "invalidInput", "The Schedule start must be finite.", propertyPath: "/command/form/start")
      }
      if let end {
        guard end.timeIntervalSinceReferenceDate.isFinite, end > start else {
          throw PlannerFailure(
            "invalidInput", "A supplied Schedule end must be finite and later than its start.",
            propertyPath: "/command/form/end")
        }
      }
      guard TimeZone(identifier: planningTimeZone) != nil else {
        throw PlannerFailure(
          "invalidInput", "The planning timezone must be valid.",
          propertyPath: "/command/form/planningTimeZone")
      }
    }
  }

  var canonicalValue: PlannerCanonicalValue {
    switch self {
    case .timed(let start, let end, let planningTimeZone):
      return .record([
        "kind": .string("timed"), "start": .date(start),
        "end": .optional(end.map(PlannerCanonicalValue.date)),
        "planningTimeZone": .string(planningTimeZone),
      ])
    }
  }

  func creationDigest(
    source: PlannerEntityReference, identity: PlannerStoreIdentity, bindings: [PlannerBoundIdentity]
  ) -> String {
    let value = PlannerCanonicalValue.record([
      "command": .record([
        "type": .string("createSchedule"),
        "source": .record(["kind": .string(source.kind.rawValue), "id": .identity(source.id)]),
        "form": canonicalValue,
      ]),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
  }
}
