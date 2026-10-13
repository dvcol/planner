import Foundation

extension PlannerPortableDeletionTarget: Codable {
  public init(from decoder: any Decoder) throws {
    switch try PortableDeletionTarget(from: decoder) {
    case .source(let source):
      guard let kind = PlannerEntityKind(rawValue: source.kind) else {
        throw PlannerFailure("recoveryIntegrityFailure", "The deletion source kind is unsupported.")
      }
      self = .source(.init(kind: kind, id: source.id), lifetimeId: source.lifetimeId)
    case .membership(let membership):
      self = .membership(id: membership.id, lifetimeId: membership.lifetimeId)
    case .itineraryEntry(let identifier, let lifetime):
      self = .itineraryEntry(id: identifier, lifetimeId: lifetime)
    case .labelAssociation(let identifier, let lifetime):
      self = .labelAssociation(id: identifier, lifetimeId: lifetime)
    case .ownedLink(let identifier, let lifetime):
      self = .ownedLink(id: identifier, lifetimeId: lifetime)
    case .expandedCompletion(let context): self = .expandedCompletion(context)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    let target: PortableDeletionTarget
    switch self {
    case .source(let source, let lifetime):
      target = .source(.init(kind: source.kind.rawValue, id: source.id, lifetimeId: lifetime))
    case .membership(let identifier, let lifetime):
      target = .membership(.init(kind: "membership", id: identifier, lifetimeId: lifetime))
    case .itineraryEntry(let identifier, let lifetime):
      target = .itineraryEntry(id: identifier, lifetimeId: lifetime)
    case .labelAssociation(let identifier, let lifetime):
      target = .labelAssociation(id: identifier, lifetimeId: lifetime)
    case .ownedLink(let identifier, let lifetime):
      target = .ownedLink(id: identifier, lifetimeId: lifetime)
    case .expandedCompletion(let context): target = .expandedCompletion(context)
    }
    try target.encode(to: encoder)
  }
}
