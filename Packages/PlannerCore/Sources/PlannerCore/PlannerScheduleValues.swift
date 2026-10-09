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

public enum PlannerScheduleField: String, Sendable, CaseIterable { case form }

public struct PlannerScheduleChanges: Sendable {
  public let form: PlannerScheduleForm

  public init(form: PlannerScheduleForm) { self.form = form }
}

public struct PlannerScheduleContent: Sendable, Equatable {
  public let source: PlannerEntityReference
  public let form: PlannerScheduleForm
}

public struct PlannerScheduleSourceRead: Sendable {
  public let source: PlannerEntityReference
  public let content: PlannerScheduleContent
  public let fieldHashes: [PlannerScheduleField: PlannerFieldHash]
}

struct ScheduleSnapshot {
  let id: UUID
  let lifetimeId: UUID
  let form: PlannerScheduleForm

  var reference: PlannerEntityReference { PlannerEntityReference(kind: .schedule, id: id) }
}

extension PlannerScheduleForm {
  func validate(propertyPath: String = "/command/form") throws {
    switch self {
    case .timed(let start, let end, let planningTimeZone):
      guard start.timeIntervalSinceReferenceDate.isFinite else {
        throw PlannerFailure(
          "invalidInput", "The Schedule start must be finite.",
          propertyPath: propertyPath + "/start")
      }
      if let end {
        guard end.timeIntervalSinceReferenceDate.isFinite, end > start else {
          throw PlannerFailure(
            "invalidInput", "A supplied Schedule end must be finite and later than its start.",
            propertyPath: propertyPath + "/end")
        }
      }
      guard TimeZone(identifier: planningTimeZone) != nil else {
        throw PlannerFailure(
          "invalidInput", "The planning timezone must be valid.",
          propertyPath: propertyPath + "/planningTimeZone")
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

enum ScheduleChange {
  case form(PlannerScheduleForm)
  case zone(String)

  func validate() throws {
    switch self {
    case .form(let form): try form.validate(propertyPath: "/command/changes/form")
    case .zone(let planningTimeZone):
      guard TimeZone(identifier: planningTimeZone) != nil else {
        throw PlannerFailure(
          "invalidInput", "The planning timezone must be valid.",
          propertyPath: "/command/planningTimeZone")
      }
    }
  }

  func applying(to current: PlannerScheduleForm) -> PlannerScheduleForm {
    switch self {
    case .form(let form): return form
    case .zone(let planningTimeZone):
      switch current {
      case .timed(let start, let end, _):
        return .timed(start: start, end: end, planningTimeZone: planningTimeZone)
      }
    }
  }

  func editDigest(
    scheduleId: UUID, expectedFormHash: PlannerFieldHash, identity: PlannerStoreIdentity,
    bindings: [PlannerBoundIdentity]
  ) -> String {
    var command: [String: PlannerCanonicalValue] = [
      "scheduleId": .identity(scheduleId),
      "expectedFieldHashes": .record(["form": .string(expectedFormHash.value)]),
    ]
    switch self {
    case .form(let form):
      command["type"] = .string("editSchedule")
      command["changes"] = .record(["form": form.canonicalValue])
    case .zone(let planningTimeZone):
      command["type"] = .string("changeScheduleZone")
      command["planningTimeZone"] = .string(planningTimeZone)
    }
    let value = PlannerCanonicalValue.record([
      "command": .record(command),
      "datasetId": .identity(identity.datasetId),
      "ownershipBinding": .string(identity.ownershipBinding),
      "resolvedBindings": .identitySet(bindings.map(\.canonicalValue)),
    ])
    let bytes = Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + value.encoded()
    return plannerDigest(bytes, prefix: "sha256-payload-v1:")
  }
}
