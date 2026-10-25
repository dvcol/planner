import Foundation
import SwiftData

public enum PlannerMaintenanceRecoveryResult: Sendable {
  case complete(checkpointGeneration: Int64)
  case incomplete(reason: PlannerFailure)
  case rejected(reason: PlannerFailure)
}

struct PlannerPreparedMaintenance: Codable {
  let format: String
  let formatVersion: Int
  let maintenanceId: UUID
  let namespaceId: UUID
  let datasetId: UUID
  let epochId: UUID
  let ownershipBinding: String
  let kind: String
  let ruleVersion: Int
  let proposedBackup: PlannerDataSnapshot
  let evidence: String

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case format, formatVersion, maintenanceId, namespaceId, datasetId, epochId, ownershipBinding,
      kind, ruleVersion, proposedBackup, evidence
  }

  init(from decoder: any Decoder) throws {
    guard case .object(let fields) = try PlannerImportJSON(from: decoder),
      Set(fields.keys) == Set(CodingKeys.allCases.map(\.rawValue)),
      let proposedBackupValue = fields[CodingKeys.proposedBackup.rawValue]
    else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "A maintenance preparation must contain its exact fields.")
    }
    do {
      var portableDecoder = PlannerPortableImportDecoder(
        root: .init(value: proposedBackupValue, path: "/proposedBackup"))
      _ = try portableDecoder.decode()
      let container = try decoder.container(keyedBy: CodingKeys.self)
      format = try container.decode(String.self, forKey: .format)
      formatVersion = try container.decode(Int.self, forKey: .formatVersion)
      maintenanceId = try container.decode(UUID.self, forKey: .maintenanceId)
      namespaceId = try container.decode(UUID.self, forKey: .namespaceId)
      datasetId = try container.decode(UUID.self, forKey: .datasetId)
      epochId = try container.decode(UUID.self, forKey: .epochId)
      ownershipBinding = try container.decode(String.self, forKey: .ownershipBinding)
      kind = try container.decode(String.self, forKey: .kind)
      ruleVersion = try container.decode(Int.self, forKey: .ruleVersion)
      proposedBackup = try container.decode(PlannerDataSnapshot.self, forKey: .proposedBackup)
      evidence = try container.decode(String.self, forKey: .evidence)
    } catch let reason as PlannerFailure {
      throw PlannerFailure(
        "recoveryIntegrityFailure", reason.message, propertyPath: reason.propertyPath)
    } catch {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "A maintenance preparation contains malformed data.")
    }
  }

  var summary: PlannerPreparedMaintenanceSummary {
    .init(
      maintenanceId: maintenanceId, evidence: "preparedMaintenanceUnverified",
      requiresFreshReview: true)
  }

  init(
    maintenanceId: UUID, identity: PlannerStoreIdentity, kind: String = "membershipConsolidation",
    ruleVersion: Int = 2, proposedBackup: PlannerDataSnapshot
  ) {
    format = "planner-maintenance-preparation"
    formatVersion = 1
    self.maintenanceId = maintenanceId
    namespaceId = identity.namespaceId
    datasetId = identity.datasetId
    epochId = identity.epochId
    ownershipBinding = identity.ownershipBinding
    self.kind = kind
    self.ruleVersion = ruleVersion
    self.proposedBackup = proposedBackup
    evidence = "preparedUnverified"
  }

  func validated(identity: PlannerStoreIdentity, bytes: Data) throws -> PlannerMaintenanceEvidence {
    guard format == "planner-maintenance-preparation", formatVersion == 1,
      evidence == "preparedUnverified",
      (kind == "membershipConsolidation" && ruleVersion == 1 && proposedBackup.formatVersion == 3)
        || (kind == "membershipConsolidation" && ruleVersion == 2
          && proposedBackup.formatVersion == 4)
        || (kind == "sourceRestorationConsolidation" && (1...2).contains(ruleVersion)
          && proposedBackup.formatVersion == 4)
        || ((kind == "sourceRestorationConsolidation" || kind == "membershipConsolidation")
          && ruleVersion == 3 && proposedBackup.formatVersion == 5)
    else { throw PlannerFailure("recoveryIntegrityFailure", "Maintenance preparation is invalid.") }
    let value = PlannerMaintenanceEvidence(
      maintenanceId: maintenanceId, namespaceId: namespaceId, datasetId: datasetId,
      epochId: epochId,
      ownershipBinding: ownershipBinding, kind: kind, ruleVersion: ruleVersion,
      preparationDigest: plannerDigest(bytes, prefix: "sha256:"))
    try value.validate(identity: identity)
    _ = try proposedBackup.validated()
    return value
  }
}

struct PlannerMaintenanceEvidence: Codable, Equatable {
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
      !ownershipBinding.isEmpty,
      (kind == "membershipConsolidation" && (1...3).contains(ruleVersion))
        || (kind == "sourceRestorationConsolidation" && (1...3).contains(ruleVersion)),
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

  init(evidence: PlannerMaintenanceEvidence, checkpointGeneration: Int64) {
    self.evidence = evidence
    commitState = "applied"
    self.checkpointGeneration = String(checkpointGeneration)
  }

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

extension PlannerRecoveryArchive {
  func prepareMaintenance(_ proposal: PlannerPreparedMaintenance) throws
    -> PlannerMaintenanceEvidence
  {
    let bytes = try JSONEncoder().encode(proposal)
    let evidence = try proposal.validated(identity: identity, bytes: bytes)
    try plannerWriteDurably(
      bytes,
      to: namespaceURL.appendingPathComponent(
        "maintenance-\(proposal.maintenanceId.uuidString).json"))
    return evidence
  }

  func maintenanceCommits(in context: ModelContext) throws -> [PlannerMaintenanceEvidence] {
    let records = try context.fetch(FetchDescriptor<PlannerSchemaV19.MaintenanceCommit>())
    var evidence: [PlannerMaintenanceEvidence] = []
    for record in records {
      guard let identifier = record.maintenanceId, let bytes = record.evidenceData,
        case .object(let fields) = try JSONDecoder().decode(PlannerImportJSON.self, from: bytes),
        Set(fields.keys) == Set(PlannerMaintenanceEvidence.CodingKeys.allCases.map(\.rawValue))
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "Native maintenance evidence is unresolved.")
      }
      let decoded = try JSONDecoder().decode(PlannerMaintenanceEvidence.self, from: bytes)
      guard decoded.maintenanceId == identifier else {
        throw PlannerFailure(
          "recoveryIntegrityFailure", "The maintenance commit identity is inconsistent.")
      }
      try decoded.validate(identity: identity)
      evidence.append(decoded)
    }
    guard Set(evidence.map(\.maintenanceId)).count == evidence.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "Native maintenance identities are duplicated.")
    }
    return evidence.sorted { $0.maintenanceId.uuidString < $1.maintenanceId.uuidString }
  }

  func verifyMaintenancePreparation(_ evidence: PlannerMaintenanceEvidence) throws {
    let file = namespaceURL.appendingPathComponent(
      "maintenance-\(evidence.maintenanceId.uuidString).json")
    let bytes = try Data(contentsOf: file)
    let prepared = try JSONDecoder().decode(PlannerPreparedMaintenance.self, from: bytes)
    guard try prepared.validated(identity: identity, bytes: bytes) == evidence else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "Maintenance commit does not match its durable preparation.")
    }
  }

  func preparedMaintenance() throws -> [PlannerPreparedMaintenance] {
    let completed = Set(try latest()?.maintenanceReceipts.map { $0.evidence.maintenanceId } ?? [])
    let files = try FileManager.default.contentsOfDirectory(
      at: namespaceURL, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("maintenance-") && $0.pathExtension == "json" }
    let preparations = try files.map { file in
      let bytes = try Data(contentsOf: file)
      let preparation = try JSONDecoder().decode(PlannerPreparedMaintenance.self, from: bytes)
      _ = try preparation.validated(identity: identity, bytes: bytes)
      guard file.lastPathComponent == "maintenance-\(preparation.maintenanceId.uuidString).json"
      else {
        throw PlannerFailure(
          "recoveryIntegrityFailure",
          "The maintenance preparation identity does not match its file.")
      }
      return preparation
    }
    guard Set(preparations.map(\.maintenanceId)).count == preparations.count else {
      throw PlannerFailure(
        "recoveryIntegrityFailure", "Prepared maintenance identities are duplicated.")
    }
    return preparations.filter { !completed.contains($0.maintenanceId) }
      .sorted { $0.maintenanceId.uuidString < $1.maintenanceId.uuidString }
  }

  func incompleteMaintenance(in context: ModelContext, envelope: RecoveryEnvelope?) throws -> [UUID]
  {
    let known = Dictionary(
      uniqueKeysWithValues: (envelope?.maintenanceReceipts ?? []).map {
        ($0.evidence.maintenanceId, $0.evidence)
      })
    var pending: [UUID] = []
    for value in try maintenanceCommits(in: context) {
      if let acknowledged = known[value.maintenanceId] {
        guard acknowledged == value else {
          throw PlannerFailure(
            "recoveryIntegrityFailure", "Acknowledged maintenance differs from its native commit.")
        }
      } else {
        try verifyMaintenancePreparation(value)
        pending.append(value.maintenanceId)
      }
    }
    return pending
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
