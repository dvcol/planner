import Foundation

public enum PlannerAppliedIdentity: Sendable, Equatable, Codable {
  case source(PlannerEntityReference)
  case reference(PlannerReferenceRead)

  private enum CodingKeys: String, CodingKey { case owner, source, appearance }

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    if fields.contains(.owner) || fields.contains(.source) || fields.contains(.appearance) {
      self = .reference(try PlannerReferenceRead(from: decoder))
    } else {
      self = .source(try PlannerEntityReference(from: decoder))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    switch self {
    case .source(let source): try source.encode(to: encoder)
    case .reference(let reference): try reference.encode(to: encoder)
    }
  }
}

public struct PlannerAppliedResult: Sendable, Equatable, Codable {
  public let generatedIdentities: [PlannerAppliedIdentity]
  public let affectedIdentities: [PlannerAppliedIdentity]
  public let importSummary: PlannerImportReview?

  public var generated: [PlannerEntityReference] {
    generatedIdentities.compactMap {
      if case .source(let value) = $0 { return value }
      return nil
    }
  }

  public var affected: [PlannerEntityReference] {
    affectedIdentities.compactMap {
      if case .source(let value) = $0 { return value }
      return nil
    }
  }

  public var generatedReferences: [PlannerReferenceRead] {
    generatedIdentities.compactMap {
      if case .reference(let value) = $0 { return value }
      return nil
    }
  }

  public var affectedReferences: [PlannerReferenceRead] {
    affectedIdentities.compactMap {
      if case .reference(let value) = $0 { return value }
      return nil
    }
  }

  init(generated: [PlannerEntityReference], affected: [PlannerEntityReference]) {
    generatedIdentities = generated.map(PlannerAppliedIdentity.source)
    affectedIdentities = affected.map(PlannerAppliedIdentity.source)
    importSummary = nil
  }

  init(
    generatedIdentities: [PlannerAppliedIdentity], affectedIdentities: [PlannerAppliedIdentity],
    importSummary: PlannerImportReview? = nil
  ) {
    self.generatedIdentities = generatedIdentities
    self.affectedIdentities = affectedIdentities
    self.importSummary = importSummary
  }

  private enum CodingKeys: String, CodingKey { case generated, affected, importSummary }

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    generatedIdentities = try fields.decode([PlannerAppliedIdentity].self, forKey: .generated)
    affectedIdentities = try fields.decode([PlannerAppliedIdentity].self, forKey: .affected)
    importSummary = try fields.decodeIfPresent(PlannerImportReview.self, forKey: .importSummary)
  }

  public func encode(to encoder: any Encoder) throws {
    var fields = encoder.container(keyedBy: CodingKeys.self)
    try fields.encode(generatedIdentities, forKey: .generated)
    try fields.encode(affectedIdentities, forKey: .affected)
    try fields.encodeIfPresent(importSummary, forKey: .importSummary)
  }
}
