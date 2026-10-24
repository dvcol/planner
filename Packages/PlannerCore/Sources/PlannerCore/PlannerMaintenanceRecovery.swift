import Foundation

struct PlannerMaintenanceEvidence: Codable {
  let maintenanceId: UUID
  let namespaceId: UUID
  let datasetId: UUID
  let epochId: UUID
  let ownershipBinding: String
  let kind: String
  let ruleVersion: Int
  let preparationDigest: String

  enum CodingKeys: String, CodingKey, CaseIterable {
    case maintenanceId, namespaceId, datasetId, epochId, ownershipBinding, kind, ruleVersion,
      preparationDigest
  }

  func validate(identity: PlannerStoreIdentity) throws {
    guard namespaceId == identity.namespaceId, datasetId == identity.datasetId,
      epochId == identity.epochId, ownershipBinding == identity.ownershipBinding,
      !ownershipBinding.isEmpty, kind == "membershipConsolidation", ruleVersion == 1,
      preparationDigest.hasPrefix("sha256:"), preparationDigest.utf8.count == 71,
      preparationDigest.utf8.dropFirst(7).allSatisfy({
        (48...57).contains($0) || (97...102).contains($0)
      })
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "Maintenance evidence has invalid ownership, rule or digest.")
    }
  }
}

struct RecoveryMaintenanceReceipt: Codable {
  let evidence: PlannerMaintenanceEvidence
  let commitState: String
  let checkpointGeneration: String

  enum CodingKeys: String, CodingKey, CaseIterable { case commitState, checkpointGeneration }

  init(from decoder: any Decoder) throws {
    let expectedKeys = Set(
      PlannerMaintenanceEvidence.CodingKeys.allCases.map(\.rawValue)
        + CodingKeys.allCases.map(\.rawValue))
    guard case .object(let fields) = try PlannerImportJSON(from: decoder),
      Set(fields.keys) == expectedKeys
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "A maintenance receipt must contain its exact evidence fields.")
    }
    do {
      evidence = try PlannerMaintenanceEvidence(from: decoder)
      let container = try decoder.container(keyedBy: CodingKeys.self)
      commitState = try container.decode(String.self, forKey: .commitState)
      checkpointGeneration = try container.decode(String.self, forKey: .checkpointGeneration)
    } catch {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "A maintenance receipt contains malformed data.")
    }
  }

  func encode(to encoder: any Encoder) throws {
    try evidence.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(commitState, forKey: .commitState)
    try container.encode(checkpointGeneration, forKey: .checkpointGeneration)
  }

  func validate(identity: PlannerStoreIdentity, generation: Int64) throws {
    try evidence.validate(identity: identity)
    guard commitState == "applied", let checkpoint = Int64(checkpointGeneration), checkpoint > 0,
      checkpoint <= generation, String(checkpoint) == checkpointGeneration
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "Recovery maintenance acknowledgement is inconsistent.")
    }
  }
}

extension RecoveryEnvelope {
  enum CodingKeys: String, CodingKey {
    case format, formatVersion, namespaceId, datasetId, ownershipBinding, storageSchemaVersion,
      checkpointGeneration, portablePayloadBase64, dataDigest, receipts, preparedProposals,
      maintenanceReceipts
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    format = try container.decode(String.self, forKey: .format)
    formatVersion = try container.decode(Int.self, forKey: .formatVersion)
    namespaceId = try container.decode(UUID.self, forKey: .namespaceId)
    datasetId = try container.decode(UUID.self, forKey: .datasetId)
    ownershipBinding = try container.decode(String.self, forKey: .ownershipBinding)
    storageSchemaVersion = try container.decode(String.self, forKey: .storageSchemaVersion)
    checkpointGeneration = try container.decode(String.self, forKey: .checkpointGeneration)
    portablePayloadBase64 = try container.decode(String.self, forKey: .portablePayloadBase64)
    dataDigest = try container.decode(String.self, forKey: .dataDigest)
    receipts = try container.decode([RecoveryReceipt].self, forKey: .receipts)
    preparedProposals = try container.decode(
      [RecoveryPreparedProposal].self, forKey: .preparedProposals)
    if formatVersion == 2 {
      do {
        maintenanceReceipts = try container.decode(
          [RecoveryMaintenanceReceipt].self, forKey: .maintenanceReceipts)
      } catch let failure as PlannerFailure {
        throw failure
      } catch {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "Version 2 requires valid maintenance acknowledgements.")
      }
    } else {
      guard !container.contains(.maintenanceReceipts) else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "Maintenance evidence requires recovery envelope version 2.")
      }
      maintenanceReceipts = []
    }
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(format, forKey: .format)
    try container.encode(formatVersion, forKey: .formatVersion)
    try container.encode(namespaceId, forKey: .namespaceId)
    try container.encode(datasetId, forKey: .datasetId)
    try container.encode(ownershipBinding, forKey: .ownershipBinding)
    try container.encode(storageSchemaVersion, forKey: .storageSchemaVersion)
    try container.encode(checkpointGeneration, forKey: .checkpointGeneration)
    try container.encode(portablePayloadBase64, forKey: .portablePayloadBase64)
    try container.encode(dataDigest, forKey: .dataDigest)
    try container.encode(receipts, forKey: .receipts)
    try container.encode(preparedProposals, forKey: .preparedProposals)
    if formatVersion == 2 {
      try container.encode(maintenanceReceipts, forKey: .maintenanceReceipts)
    }
  }
}
