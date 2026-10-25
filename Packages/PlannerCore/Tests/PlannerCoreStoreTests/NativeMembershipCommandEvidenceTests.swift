import Foundation
import SwiftData
import Testing

@testable import PlannerCore

struct NativeMembershipCommandEvidenceTests {
  @MainActor
  @Test(
    arguments: [
      "list", "expanded", "direct", "reorderAlias", "reorderAnchor", "bulkList", "bulkBranch",
      "bulkItinerary",
      "bulkEmptyBranch",
    ].flatMap { scope in [scope, "legacy:" + scope] },
    ["empty", "newer", "maintenance"])
  func savedContextPreparationsStayUnverifiedBeforeResolvingMissingOrNewerTargets(
    rawScope: String, environment: String
  ) async throws {
    let legacyPreparation = rawScope.hasPrefix("legacy:")
    let scope: String
    if legacyPreparation {
      scope = String(rawScope.dropFirst("legacy:".count))
    } else {
      scope = rawScope
    }
    let directory = try makePlannerStoreFixtureDirectory()
    func configuration(_ base: URL) -> PlannerStorageConfiguration {
      .init(
        storeURL: base.appendingPathComponent("store/Planner.sqlite"),
        controlURL: base.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: base.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
    }
    let producerConfiguration = configuration(directory.appendingPathComponent("producer"))
    let literal = try #require(
      JSONSerialization.jsonObject(
        with: fixtureData("strict-overwrite-fingerprint-v3")) as? [String: Any])
    var identity = try #require(literal["identity"] as? [String: Any])
    identity["schemaVersion"] = 19
    func initialize(_ configuration: PlannerStorageConfiguration) throws {
      try initializeEmptyStore(configuration)
      try FileManager.default.createDirectory(
        at: configuration.controlURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONSerialization.data(withJSONObject: identity).write(
        to: configuration.controlURL, options: .atomic)
    }
    try initialize(producerConfiguration)
    let producer = Planner(configuration: producerConfiguration)
    guard case .ready(let session) = await producer.bootstrap(),
      case .decoded(let seed) = producer.decodeImport(
        try fixtureData("retired-expanded-membership-alias-v3")),
      case .reviewed(let importReview) = await producer.prepareReview(
        session: session, command: .applyImport(backup: seed, mode: .overwrite)),
      case .applied(_, .complete) = await producer.execute(
        .init(
          operationId: UUID(), session: session, command: importReview.command,
          reviewToken: importReview.reviewToken)
      ).outcome
    else { throw CancellationError() }
    func save(_ planner: Planner, session: PlannerDatasetSession, command: PlannerCommand)
      async throws -> PlannerAppliedResult
    {
      let response = await planner.execute(
        .init(operationId: UUID(), session: session, command: command))
      guard case .applied(let result, .complete) = response.outcome else {
        Issue.record("The independent replay fixture command must save: \(response)")
        throw CancellationError()
      }
      return result
    }
    let listIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000201")!
    let itineraryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000301")!
    let canonicalIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
    let retiredIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000402")!
    let firstEntry = UUID(uuidString: "00000000-0000-4000-8000-000000000451")!
    let directEntry = UUID(uuidString: "00000000-0000-4000-8000-000000000453")!
    let hotel = PlannerEntityReference(
      kind: .item,
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!)
    let other = try #require(
      try await save(
        producer, session: session,
        command: .createItem(content: .init(title: "Other activity"))
      ).generated.first)
    let otherAddition = try await save(
      producer, session: session,
      command: .addMembership(itemId: other.id, listId: listIdentifier, placement: .last))
    guard case .membership(let otherMembership, _, _)? = otherAddition.generatedReferences.first
    else {
      throw CancellationError()
    }
    let emptyList = try #require(
      try await save(
        producer, session: session,
        command: .createList(content: .init(name: "Empty branch"))
      ).generated.first)
    let emptyAddition = try await save(
      producer, session: session,
      command: .addItineraryEntry(
        itineraryId: itineraryIdentifier, source: emptyList, placement: .last))
    guard case .itineraryEntry(let emptyEntry, _, _)? = emptyAddition.generatedReferences.first
    else {
      throw CancellationError()
    }
    let command: PlannerCommand
    switch scope {
    case "list":
      command = .setCompletion(
        scope: .appearance(
          .listMembership(
            listId: listIdentifier, membershipId: retiredIdentifier)), done: false)
    case "expanded":
      command = .setCompletion(
        scope: .appearance(
          .expandedListItem(
            itineraryId: itineraryIdentifier, listEntryId: firstEntry,
            membershipId: retiredIdentifier)), done: true)
    case "direct":
      command = .setCompletion(
        scope: .appearance(
          .directItineraryItem(
            itineraryId: itineraryIdentifier, entryId: directEntry)), done: true)
    case "reorderAlias":
      command = .reorderMembership(
        listId: listIdentifier, membershipId: retiredIdentifier, placement: .last)
    case "reorderAnchor":
      command = .reorderMembership(
        listId: listIdentifier, membershipId: otherMembership,
        placement: .before(associationId: retiredIdentifier))
    case "bulkList":
      command = .setBulkCompletion(scope: .list(listId: listIdentifier), done: true)
    case "bulkBranch":
      command = .setBulkCompletion(
        scope: .itineraryListEntry(
          itineraryId: itineraryIdentifier, listEntryId: firstEntry), done: true)
    case "bulkEmptyBranch":
      command = .setBulkCompletion(
        scope: .itineraryListEntry(
          itineraryId: itineraryIdentifier, listEntryId: emptyEntry), done: true)
    case "bulkItinerary":
      command = .setBulkCompletion(scope: .itinerary(itineraryId: itineraryIdentifier), done: true)
    default: throw CancellationError()
    }
    let reviewToken: PlannerReviewToken?
    if case .setBulkCompletion = command {
      guard
        case .reviewed(let review) = await producer.prepareReview(
          session: session, command: command)
      else {
        throw CancellationError()
      }
      reviewToken = review.reviewToken
    } else {
      reviewToken = nil
    }
    let operationIdentifier = UUID()
    guard
      case .applied(_, .complete) = await producer.execute(
        .init(
          operationId: operationIdentifier, session: session, command: command,
          reviewToken: reviewToken)
      ).outcome
    else { throw CancellationError() }
    let namespaceName = try #require(identity["namespaceId"] as? String)
    let producerNamespace = producerConfiguration.recoveryDirectoryURL.appendingPathComponent(
      namespaceName)
    let files = try FileManager.default.contentsOfDirectory(
      at: producerNamespace, includingPropertiesForKeys: nil
    )
    .filter { $0.lastPathComponent.hasPrefix("proposal-") }
    let proposals = try files.compactMap { file -> (URL, Data, [String: Any])? in
      let data = try Data(contentsOf: file)
      let value = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      guard value["originalOperationId"] as? String == operationIdentifier.uuidString else {
        return nil
      }
      return (file, data, value)
    }
    #expect(proposals.count == 1)
    let proposal = try #require(proposals.first)
    let hasExpandedEvidence = ["expanded", "bulkBranch", "bulkItinerary"].contains(scope)
    #expect(proposal.2["formatVersion"] as? Int == (hasExpandedEvidence ? 3 : 2))
    #expect((proposal.2["resolvedBindings"] as? [[String: Any]])?.isEmpty == false)
    #expect((proposal.2["resolvedMembershipEvidence"] as? [[String: Any]])?.isEmpty == true)
    let expectedPrefix = hasExpandedEvidence ? "sha256-payload-v4:" : "sha256-payload-v1:"
    #expect((proposal.2["payloadDigest"] as? String)?.hasPrefix(expectedPrefix) == true)
    let proposalIdentifier = try #require(
      (proposal.2["proposalId"] as? String).flatMap(UUID.init(uuidString:)))
    let currentConfiguration = configuration(directory.appendingPathComponent("current"))
    try initialize(currentConfiguration)
    let current = Planner(configuration: currentConfiguration)
    guard case .ready(let currentSession) = await current.bootstrap() else {
      throw CancellationError()
    }
    if environment != "empty" {
      let proposed = try #require(proposal.2["proposedBackup"])
      guard
        case .decoded(let incoming) = current.decodeImport(
          try JSONSerialization.data(withJSONObject: proposed)),
        case .reviewed(let review) = await current.prepareReview(
          session: currentSession, command: .applyImport(backup: incoming, mode: .overwrite)),
        case .applied(_, .complete) = await current.execute(
          .init(
            operationId: UUID(), session: currentSession, command: review.command,
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
      if environment == "newer" {
        _ = try await save(
          current, session: currentSession,
          command: .removeMembership(listId: listIdentifier, membershipId: canonicalIdentifier))
        _ = try await save(
          current, session: currentSession,
          command: .addMembership(itemId: hotel.id, listId: listIdentifier, placement: .last))
        _ = try await save(
          current, session: currentSession,
          command: .removeItineraryEntry(itineraryId: itineraryIdentifier, entryId: directEntry))
        _ = try await save(
          current, session: currentSession,
          command: .addItineraryEntry(
            itineraryId: itineraryIdentifier, source: hotel, placement: .last))
      }
    }
    let currentNamespace = currentConfiguration.recoveryDirectoryURL.appendingPathComponent(
      namespaceName)
    if environment == "maintenance" {
      do {
        let schema = Schema(versionedSchema: PlannerSchemaV19.self)
        let container = try ModelContainer(
          for: schema, migrationPlan: PlannerMigrationPlan.self,
          configurations: [
            ModelConfiguration(
              schema: schema, url: currentConfiguration.storeURL,
              cloudKitDatabase: .none)
          ])
        let nativeContext = ModelContext(container)
        nativeContext.autosaveEnabled = false
        let item = try #require(
          nativeContext.fetch(FetchDescriptor<PlannerSchemaV18.Item>()).first { $0.id == hotel.id })
        let list = try #require(
          nativeContext.fetch(FetchDescriptor<PlannerSchemaV18.List>()).first {
            $0.id == listIdentifier
          })
        nativeContext.insert(
          PlannerSchemaV18.Membership(
            snapshot: .init(
              id: UUID(uuidString: "00000000-0000-4000-8000-000000000400")!,
              lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000840")!,
              list: .init(
                kind: "list", id: listIdentifier,
                lifetimeId: try #require(list.lifetimeId)),
              item: .init(
                kind: "item", id: hotel.id,
                lifetimeId: try #require(item.lifetimeId)),
              rank: 4096, localDone: false), list: list, item: item))
        try nativeContext.save()
      }
      let obstruction = NativeSaveRecoveryObstruction(configuration: currentConfiguration)
      let observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: nil, queue: nil
      ) { notification in obstruction.observe(notification) }
      defer {
        NotificationCenter.default.removeObserver(observer)
        try? obstruction.restore()
      }
      let waitingIdentifier = UUID()
      let waiting = await current.execute(
        .init(
          operationId: waitingIdentifier, session: currentSession,
          command: .createTag(content: .init(name: "Must wait for maintenance"))))
      guard case .rejected(let reason) = waiting.outcome else {
        Issue.record("Maintenance recovery must leave the new command unapplied: \(waiting)")
        return
      }
      #expect(reason.code == "persistenceFailure")
      #expect(obstruction.didObstruct && obstruction.failure == nil)
      try obstruction.restore()
      guard
        case .noReliableEvidence = await current.operationStatus(
          session: currentSession, operationId: waitingIdentifier),
        case .status(let status) = await current.read(session: currentSession, request: .status),
        case .known(_, let operations, let maintenance, let mutationBlocked) = status.recovery
      else { throw CancellationError() }
      #expect(operations.isEmpty && maintenance.count == 1 && mutationBlocked)
    }
    var replayData = proposal.1
    if legacyPreparation {
      var unversioned = proposal.2
      let savedIdentity = try JSONDecoder().decode(
        PlannerStoreIdentity.self, from: JSONSerialization.data(withJSONObject: identity))
      let savedBindings = try JSONDecoder().decode(
        [PlannerBoundIdentity].self,
        from: JSONSerialization.data(withJSONObject: try #require(proposal.2["resolvedBindings"])))
      if case .setBulkCompletion(let bulkScope, let done) = command {
        unversioned["payloadDigest"] = bulkCompletionDigest(
          scope: bulkScope, done: done, identity: savedIdentity, bindings: savedBindings)
      } else if scope == "expanded" {
        let oldPayload = PlannerCanonicalValue.record([
          "command": .record([
            "type": .string("setCompletion"),
            "scope": .record([
              "kind": .string("appearance"),
              "appearance": .record([
                "kind": .string("expandedListItem"), "itineraryId": .identity(itineraryIdentifier),
                "listEntryId": .identity(firstEntry), "membershipId": .identity(retiredIdentifier),
              ]),
            ]), "done": .boolean(true),
          ]),
          "datasetId": .identity(savedIdentity.datasetId),
          "ownershipBinding": .string(savedIdentity.ownershipBinding),
          "resolvedBindings": .identitySet(savedBindings.map(\.canonicalValue)),
        ])
        unversioned["payloadDigest"] = plannerDigest(
          Data("PlannerOperationPayload".utf8) + Data([0, 0, 0, 0, 1]) + oldPayload.encoded(),
          prefix: "sha256-payload-v1:")
      }
      var legacyGraph = try #require(unversioned["proposedBackup"] as? [String: Any])
      legacyGraph["formatVersion"] = 3
      let currentChanges = try #require(legacyGraph["completionChanges"] as? [[String: Any]])
      legacyGraph["completionChanges"] = currentChanges.map { change in
        var change = change
        change.removeValue(forKey: "observedExpandedCompletionDeletionIds")
        return change
      }
      unversioned["proposedBackup"] = legacyGraph
      for key in [
        "formatVersion", "resolvedBindings", "resolvedMembershipEvidence",
        "resolvedExpandedCompletionEvidence",
      ] {
        unversioned.removeValue(forKey: key)
      }
      replayData = try JSONSerialization.data(withJSONObject: unversioned)
    }
    try replayData.write(
      to: currentNamespace.appendingPathComponent(proposal.0.lastPathComponent), options: .atomic)
    func namespaceFiles() throws -> [String: Data] {
      try Dictionary(
        uniqueKeysWithValues: FileManager.default.contentsOfDirectory(
          at: currentNamespace, includingPropertiesForKeys: nil
        ).map { ($0.lastPathComponent, try Data(contentsOf: $0)) })
    }
    guard case .exported(let before) = await current.exportData(session: currentSession),
      case .preparedUnverified(let known) = await current.operationStatus(
        session: currentSession, operationId: operationIdentifier)
    else { throw CancellationError() }
    #expect(known.proposalId == proposalIdentifier && known.requiresFreshReview)
    let beforeFiles = try namespaceFiles()
    let retry = await current.execute(
      .init(operationId: operationIdentifier, session: currentSession, command: command))
    guard case .unverified(let summary) = retry.outcome else {
      Issue.record(
        "Saved preparation must be read before missing/new targets or a fresh review: \(retry)")
      return
    }
    #expect(
      summary.originalOperationId == operationIdentifier && summary.proposalId == proposalIdentifier
    )
    #expect(summary.evidence == "preparedUnverified" && summary.requiresFreshReview)
    let altered: PlannerCommand
    switch command {
    case .setCompletion(let selected, let done):
      altered = .setCompletion(scope: selected, done: !done)
    case .setBulkCompletion(let selected, let done):
      altered = .setBulkCompletion(scope: selected, done: !done)
    case .reorderMembership(let owner, let member, _):
      altered = .reorderMembership(listId: owner, membershipId: member, placement: .first)
    default: throw CancellationError()
    }
    guard
      case .rejected(let mismatched) = await current.execute(
        .init(operationId: operationIdentifier, session: currentSession, command: altered)
      ).outcome,
      case .exported(let after) = await current.exportData(session: currentSession)
    else { throw CancellationError() }
    #expect(mismatched.code == "operationPayloadMismatch")
    #expect(before == after)
    #expect(try namespaceFiles() == beforeFiles)
    if environment == "maintenance" {
      guard
        case .rejected(let blocked) = await current.execute(
          .init(
            operationId: UUID(), session: currentSession,
            command: .createTag(content: .init(name: "Still must wait")))
        )
        .outcome
      else { throw CancellationError() }
      #expect(blocked.code == "mutationBlocked")
      #expect(try namespaceFiles() == beforeFiles)
    }
    let reopened = Planner(configuration: currentConfiguration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .unverified(let repeated) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .preparedUnverified(let repeatedStatus) = await reopened.operationStatus(
        session: reopenedSession, operationId: operationIdentifier),
      case .exported(let reopenedExport) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(repeated.proposalId == proposalIdentifier && repeated.requiresFreshReview)
    #expect(repeatedStatus.proposalId == proposalIdentifier)
    #expect(reopenedExport == before)
    #expect(try namespaceFiles() == beforeFiles)
  }

  @MainActor @Test func overwriteRetainsRemovedMembershipBasisAndReplaysItsFrozenFingerprint()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let literal = try #require(
      JSONSerialization.jsonObject(with: fixtureData("strict-overwrite-fingerprint-v3"))
        as? [String: Any])
    var identity = try #require(literal["identity"] as? [String: Any])
    identity["schemaVersion"] = 19
    try initializeEmptyStore(configuration)
    try FileManager.default.createDirectory(
      at: configuration.controlURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: identity).write(
      to: configuration.controlURL, options: .atomic)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(try fixtureData("informed-readd-v3")),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: #require(literal["incoming"]))),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: incoming, mode: .overwrite))
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let applied, .complete(let generation)) = response.outcome else {
      Issue.record("Apply the reviewed membership removal: \(response)")
      return
    }
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      "00000000-0000-4000-8000-000000000920")
    let acknowledged = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf: namespaceDirectory.appendingPathComponent("checkpoint-\(generation).json")))
        as? [String: Any])
    let receipts = try #require(acknowledged["receipts"] as? [[String: Any]])
    let receipt = try #require(
      receipts.first { $0["operationId"] as? String == operationIdentifier.uuidString })
    #expect(receipt["payloadDigest"] as? String == literal["payloadDigest"] as? String)
    let proposals = try FileManager.default.contentsOfDirectory(
      at: namespaceDirectory, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("proposal-") }
    let matchingProposals = try proposals.compactMap { file -> [String: Any]? in
      let value = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
      guard value?["originalOperationId"] as? String == operationIdentifier.uuidString else {
        return nil
      }
      return value
    }
    let preparation = try #require(matchingProposals.first)
    #expect(preparation["formatVersion"] as? Int == 2)
    #expect(preparation["payloadDigest"] as? String == literal["payloadDigest"] as? String)
    #expect(
      NSDictionary(dictionary: ["evidence": try #require(preparation["resolvedMembershipEvidence"])]
      )
      .isEqual(to: ["evidence": try #require(literal["expectedMembershipEvidence"])]))
    let actualBindings = try #require(preparation["resolvedBindings"] as? [[String: Any]])
    let expectedBindings = try #require(literal["expectedBindings"] as? [[String: Any]])
    #expect(
      Set(
        try actualBindings.map {
          try JSONSerialization.data(withJSONObject: $0, options: .sortedKeys)
        })
        == Set(
          try expectedBindings.map {
            try JSONSerialization.data(withJSONObject: $0, options: .sortedKeys)
          }))
    guard
      case .applied(let added, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(
            itemId: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!,
            listId: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!, placement: .last))
      ).outcome,
      !added.generatedReferences.isEmpty,
      case .exported(let beforeReplay) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayed, .complete(let replayedGeneration)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .exported(let afterReplay) = await reopened.exportData(session: reopenedSession)
    else {
      Issue.record("Replay the original import before resolving the newly added membership.")
      return
    }
    #expect(replayed == applied && replayedGeneration == generation)
    #expect(afterReplay == beforeReplay)
    let unverifiedDirectory = directory.appendingPathComponent("unverified")
    let unverifiedConfiguration = PlannerStorageConfiguration(
      storeURL: unverifiedDirectory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: unverifiedDirectory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: unverifiedDirectory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    try initializeEmptyStore(unverifiedConfiguration)
    try FileManager.default.createDirectory(
      at: unverifiedConfiguration.controlURL.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: identity).write(
      to: unverifiedConfiguration.controlURL, options: .atomic)
    let unverified = Planner(configuration: unverifiedConfiguration)
    guard case .ready(let unverifiedSession) = await unverified.bootstrap(),
      case .exported(let originalEmptyData) = await unverified.exportData(
        session: unverifiedSession)
    else { throw CancellationError() }
    let proposalIdentifier = try #require(preparation["proposalId"] as? String)
    let unverifiedNamespace = unverifiedConfiguration.recoveryDirectoryURL.appendingPathComponent(
      "00000000-0000-4000-8000-000000000920")
    try JSONSerialization.data(withJSONObject: preparation).write(
      to: unverifiedNamespace.appendingPathComponent("proposal-\(proposalIdentifier).json"),
      options: .atomic)
    let unverifiedResponse = await unverified.execute(
      .init(operationId: operationIdentifier, session: unverifiedSession, command: review.command))
    guard case .unverified(let summary) = unverifiedResponse.outcome,
      case .exported(let afterUnverifiedRetry) = await unverified.exportData(
        session: unverifiedSession)
    else {
      Issue.record(
        "A preparation alone remains unverified without a fresh review: \(unverifiedResponse)")
      return
    }
    #expect(summary.originalOperationId == operationIdentifier)
    #expect(afterUnverifiedRetry == originalEmptyData)
  }

  @MainActor @Test func legacyRestorationImportReceiptKeepsItsVersionTwoFingerprint() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let literals = try #require(
      JSONSerialization.jsonObject(with: fixtureData("operation-fingerprint-literals"))
        as? [String: Any])
    let cases = try #require(literals["cases"] as? [[String: Any]])
    let literal = try #require(cases.first { $0["name"] as? String == "legacy-restoration-v2" })
    let digest = try #require(literal["payloadDigest"] as? String)
    var identity = try #require(literals["identity"] as? [String: Any])
    identity["schemaVersion"] = 19
    try initializeEmptyStore(configuration)
    try FileManager.default.createDirectory(
      at: configuration.controlURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: identity).write(
      to: configuration.controlURL, options: .atomic)
    let planner = Planner(configuration: configuration)
    let empty: [String: Any] = [
      "format": "planner-data", "formatVersion": 2, "sources": [], "memberships": [],
      "itineraryEntries": [], "expandedCompletions": [], "labelAssociations": [],
      "ownedLinks": [], "schedules": [], "deletionMarkers": [], "contextAliases": [],
      "completionChanges": [], "restorationFamilies": [],
    ]
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: empty)),
      case .decoded(let seed) = planner.decodeImport(try fixtureData("informed-readd-v3")),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let command = PlannerCommand.applyImport(
      backup: backup, mode: .overwrite, restoreDeletedData: true)
    let operationIdentifier = UUID()
    let expected = PlannerAppliedResult(generatedIdentities: [], affectedIdentities: [])
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [
        ModelConfiguration(schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
      ])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    context.insert(
      try PlannerSchemaV1.Receipt(
        operation: .init(operationId: operationIdentifier, session: session, command: command),
        digest: digest, result: expected, bindings: []))
    try context.save()
    guard case .exported(let before) = await planner.exportData(session: session),
      case .applied(let replayed, .incomplete) = await planner.execute(
        .init(operationId: operationIdentifier, session: session, command: command)
      ).outcome,
      case .applied(let repaired, .complete(let generation)) = await planner.retryRecovery(
        session: session, operationId: operationIdentifier
      ).outcome,
      case .applied(let repeated, .complete(let repeatedGeneration)) = await planner.execute(
        .init(operationId: operationIdentifier, session: session, command: command)
      ).outcome,
      case .exported(let after) = await planner.exportData(session: session)
    else {
      Issue.record(
        "Replay the old restoration fingerprint without upgrading its format or evidence.")
      return
    }
    #expect(replayed == expected && repaired == expected && repeated == expected)
    #expect(repeatedGeneration == generation && before == after)
    let checkpointURL = configuration.recoveryDirectoryURL
      .appendingPathComponent("00000000-0000-4000-8000-000000000920")
      .appendingPathComponent("checkpoint-\(generation).json")
    let checkpoint = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: checkpointURL)) as? [String: Any])
    let receipts = try #require(checkpoint["receipts"] as? [[String: Any]])
    let receipt = try #require(
      receipts.first { $0["operationId"] as? String == operationIdentifier.uuidString })
    #expect(receipt["payloadDigest"] as? String == digest)
  }

  @MainActor @Test func legacyMoveReceiptReplaysBeforeCurrentTargetResolutionAndKeepsItsDigest()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let literal = try #require(
      JSONSerialization.jsonObject(
        with: fixtureData("legacy-move-fingerprint-v1")) as? [String: Any])
    let digest = try #require(literal["payloadDigest"] as? String)
    var identity = try #require(literal["identity"] as? [String: Any])
    identity["schemaVersion"] = 19
    try initializeEmptyStore(configuration)
    try FileManager.default.createDirectory(
      at: configuration.controlURL.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: identity).write(
      to: configuration.controlURL,
      options: .atomic)
    var graph = try #require(
      JSONSerialization.jsonObject(
        with: fixtureData("informed-readd-v3")) as? [String: Any])
    var sources = try #require(graph["sources"] as? [[String: Any]])
    var destinationList = sources[1]
    destinationList["id"] = "00000000-0000-4000-8000-000000000202"
    destinationList["lifetimeId"] = "00000000-0000-4000-8000-000000000822"
    sources.append(destinationList)
    graph["sources"] = sources
    var members = try #require(graph["memberships"] as? [[String: Any]])
    members[0]["id"] = "00000000-0000-4000-8000-000000000406"
    members[0]["lifetimeId"] = "00000000-0000-4000-8000-000000000846"
    members[0]["list"] = [
      "kind": "list", "id": destinationList["id"],
      "lifetimeId": destinationList["lifetimeId"],
    ]
    graph["memberships"] = members
    let operationIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000993")!
    var markers = try #require(graph["deletionMarkers"] as? [[String: Any]])
    markers.append([
      "deletionId": "00000000-0000-4000-8000-000000000893",
      "operationId": operationIdentifier.uuidString,
      "target": [
        "kind": "membership", "id": "00000000-0000-4000-8000-000000000405",
        "lifetimeId": "00000000-0000-4000-8000-000000000845",
      ],
      "closedFamilyId": NSNull(),
    ])
    graph["deletionMarkers"] = markers
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let incoming) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: graph)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyImport(backup: incoming, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: review.command, reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let item = PlannerEntityReference(
      kind: .item,
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!)
    let origin = PlannerEntityReference(
      kind: .list,
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!)
    let destination = PlannerEntityReference(
      kind: .list,
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000202")!)
    let originalReference = PlannerReferenceRead.membership(
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000405")!, list: origin, item: item)
    let destinationReference = PlannerReferenceRead.membership(
      id: UUID(uuidString: "00000000-0000-4000-8000-000000000406")!, list: destination, item: item)
    let expected = PlannerAppliedResult(
      generatedIdentities: [.reference(destinationReference)],
      affectedIdentities: [
        .reference(originalReference), .reference(destinationReference),
        .source(origin), .source(destination),
      ])
    let command = PlannerCommand.moveMembership(
      listId: origin.id,
      membershipId: UUID(uuidString: "00000000-0000-4000-8000-000000000405")!,
      destinationListId: destination.id, placement: .last)
    try insertLegacyMoveReceipt(
      configuration: configuration,
      operation: .init(operationId: operationIdentifier, session: session, command: command),
      digest: digest, result: expected)
    guard case .exported(let beforeReplay) = await planner.exportData(session: session),
      case .applied(let replayed, .incomplete) = await planner.execute(
        .init(operationId: operationIdentifier, session: session, command: command)
      ).outcome,
      case .applied(let repaired, .complete(let checkpoint)) = await planner.retryRecovery(
        session: session, operationId: operationIdentifier
      ).outcome,
      case .applied(let repeated, .complete(let repeatedCheckpoint)) = await planner.execute(
        .init(operationId: operationIdentifier, session: session, command: command)
      ).outcome,
      case .exported(let afterReplay) = await planner.exportData(session: session),
      case .decoded(let saved) = planner.decodeImport(afterReplay)
    else {
      Issue.record("A valid legacy Move receipt must replay without its removed original target.")
      return
    }
    #expect(replayed == expected && repaired == expected && repeated == expected)
    #expect(checkpoint == repeatedCheckpoint)
    #expect(afterReplay == beforeReplay)
    #expect(saved.backup.membershipRemovals.count == 1)
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      "00000000-0000-4000-8000-000000000920")
    let acknowledged = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf:
            namespaceDirectory.appendingPathComponent("checkpoint-\(checkpoint).json")))
        as? [String: Any])
    let receipts = try #require(acknowledged["receipts"] as? [[String: Any]])
    let oldReceipt = try #require(
      receipts.first { $0["operationId"] as? String == operationIdentifier.uuidString })
    #expect(oldReceipt["payloadDigest"] as? String == digest)
  }

  /// Construct historical native evidence; public replay and recovery supply all observations.
  @MainActor private func insertLegacyMoveReceipt(
    configuration: PlannerStorageConfiguration,
    operation: PlannerOperation, digest: String, result: PlannerAppliedResult
  ) throws {
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [
        ModelConfiguration(schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
      ])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let bindings = [
      PlannerBoundIdentity(
        kind: "membership", id: UUID(uuidString: "00000000-0000-4000-8000-000000000405")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000845")!),
      PlannerBoundIdentity(
        kind: "list", id: UUID(uuidString: "00000000-0000-4000-8000-000000000201")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000821")!),
      PlannerBoundIdentity(
        kind: "item", id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000811")!),
      PlannerBoundIdentity(
        kind: "list", id: UUID(uuidString: "00000000-0000-4000-8000-000000000202")!,
        lifetimeId: UUID(uuidString: "00000000-0000-4000-8000-000000000822")!),
    ]
    context.insert(
      try PlannerSchemaV1.Receipt(
        operation: operation, digest: digest, result: result,
        bindings: bindings))
    try context.save()
  }

  @Test func ordinaryReAddRetainsItsOriginalObservationBasisForReplay() async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let itemCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Museum")))
      ).outcome,
      let item = itemCreation.generated.first,
      case .applied(let listCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .createList(content: .init(name: "Tokyo"))
        )
      ).outcome,
      let list = listCreation.generated.first,
      case .applied(let initialAddition, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
      ).outcome,
      case .membership(let originalIdentifier, _, _) = initialAddition.generatedReferences.first,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: list.id, membershipId: originalIdentifier))
      ).outcome,
      case .exported(let removedData) = await planner.exportData(session: session),
      case .decoded(let removedBackup) = planner.decodeImport(removedData)
    else { throw CancellationError() }
    let operationIdentifier = UUID()
    let command = PlannerCommand.addMembership(itemId: item.id, listId: list.id, placement: .last)
    guard
      case .applied(let added, .complete(let generation)) = await planner.execute(
        .init(operationId: operationIdentifier, session: session, command: command)
      ).outcome,
      case .membership(let addedIdentifier, _, _) = added.generatedReferences.first,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else { throw CancellationError() }
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      namespace.namespaceId.uuidString)
    let checkpoint = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf: namespaceDirectory.appendingPathComponent("checkpoint-\(generation).json")))
        as? [String: Any])
    let receipts = try #require(checkpoint["receipts"] as? [[String: Any]])
    let receiptValue = receipts.first {
      $0["operationId"] as? String == operationIdentifier.uuidString
    }
    let receipt = try #require(receiptValue)
    #expect((receipt["payloadDigest"] as? String)?.hasPrefix("sha256-payload-v3:") == true)
    let proposals = try FileManager.default.contentsOfDirectory(
      at: namespaceDirectory, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("proposal-") }
    let candidates = try proposals.compactMap { file -> [String: Any]? in
      let value = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
      return value?["originalOperationId"] as? String == operationIdentifier.uuidString
        ? value : nil
    }
    let preparedValue = candidates.first
    let preparation = try #require(preparedValue)
    #expect(preparation["formatVersion"] as? Int == 2)
    #expect((preparation["resolvedBindings"] as? [[String: Any]])?.count == 2)
    let evidence = preparation["resolvedMembershipEvidence"] as? [[String: Any]]
    #expect(evidence?.count == 1)
    #expect(evidence?.first?["membershipId"] as? String == addedIdentifier.uuidString)
    #expect(
      evidence?.first?["observedRemovalIds"] as? [String]
        == removedBackup.backup.membershipRemovals.map { $0.deletionId.uuidString }.sorted())
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: list.id, membershipId: addedIdentifier))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome,
      case .exported(let currentData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayed, .complete(let replayedGeneration)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome,
      case .exported(let afterReplay) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(replayed == added && replayedGeneration == generation)
    #expect(afterReplay == currentData)
  }

  @MainActor @Test func strictRemoveUsesTheFrozenVersionThreeFingerprintAndPreparedBindings()
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let literals = try #require(
      JSONSerialization.jsonObject(with: fixtureData("operation-fingerprint-literals"))
        as? [String: Any])
    var identity = try #require(literals["identity"] as? [String: Any])
    identity["schemaVersion"] = 19
    try initializeEmptyStore(configuration)
    try FileManager.default.createDirectory(
      at: configuration.controlURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: identity).write(
      to: configuration.controlURL, options: .atomic)
    var graph = try #require(
      JSONSerialization.jsonObject(with: fixtureData("informed-readd-v3")) as? [String: Any])
    var memberships = try #require(graph["memberships"] as? [[String: Any]])
    var provenance = try #require(graph["membershipProvenance"] as? [[String: Any]])
    #expect(memberships.count == 1 && provenance.count == 2)
    memberships[0]["id"] = "00000000-0000-4000-8000-000000000405"
    memberships[0]["lifetimeId"] = "00000000-0000-4000-8000-000000000845"
    provenance[1]["membershipId"] = memberships[0]["id"]
    provenance[1]["membershipLifetimeId"] = memberships[0]["lifetimeId"]
    graph["memberships"] = memberships
    graph["membershipProvenance"] = provenance
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: graph)),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let listIdentifier = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000201"))
    let membershipIdentifier = try #require(
      UUID(uuidString: "00000000-0000-4000-8000-000000000405"))
    let operationIdentifier = UUID()
    let command = PlannerCommand.removeMembership(
      listId: listIdentifier, membershipId: membershipIdentifier)
    let outcome = await planner.execute(
      .init(operationId: operationIdentifier, session: session, command: command))
    guard case .applied(let removed, .complete(let generation)) = outcome.outcome else {
      Issue.record("The literal's informed membership must be removable: \(outcome)")
      return
    }
    let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
      "00000000-0000-4000-8000-000000000920")
    let checkpoint = try #require(
      JSONSerialization.jsonObject(
        with: Data(
          contentsOf: namespaceDirectory.appendingPathComponent("checkpoint-\(generation).json")))
        as? [String: Any])
    let receipts = try #require(checkpoint["receipts"] as? [[String: Any]])
    let receipt = try #require(
      receipts.first { $0["operationId"] as? String == operationIdentifier.uuidString })
    let cases = try #require(literals["cases"] as? [[String: Any]])
    let literal = try #require(cases.first { $0["name"] as? String == "observed-remove-v3" })
    #expect(receipt["payloadDigest"] as? String == literal["payloadDigest"] as? String)
    let proposals = try FileManager.default.contentsOfDirectory(
      at: namespaceDirectory, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("proposal-") }
    let candidates = try proposals.compactMap { file -> [String: Any]? in
      let value = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
      return value?["originalOperationId"] as? String == operationIdentifier.uuidString
        ? value : nil
    }
    let preparedValue = candidates.first
    let preparation = try #require(preparedValue)
    #expect(preparation["formatVersion"] as? Int == 2)
    #expect((preparation["resolvedBindings"] as? [[String: Any]])?.count == 3)
    #expect((preparation["resolvedMembershipEvidence"] as? [[String: Any]])?.count == 1)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayed, .complete(let replayedGeneration)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: command)
      ).outcome
    else { throw CancellationError() }
    #expect(replayed == removed && replayedGeneration == generation)
  }

  @MainActor private func initializeEmptyStore(_ configuration: PlannerStorageConfiguration) throws
  {
    try FileManager.default.createDirectory(
      at: configuration.storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let schema = Schema(versionedSchema: PlannerSchemaV19.self)
    let container = try ModelContainer(
      for: schema, migrationPlan: PlannerMigrationPlan.self,
      configurations: [
        ModelConfiguration(schema: schema, url: configuration.storeURL, cloudKitDatabase: .none)
      ])
    let context = ModelContext(container)
    context.autosaveEnabled = false
    try context.save()
  }

  private func fixtureData(_ name: String) throws -> Data {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: NativeMembershipCommandEvidenceFixtureBundle.self)
    #endif
    return try Data(
      contentsOf: #require(
        bundle.url(
          forResource: name, withExtension: "json", subdirectory: "Fixtures/MembershipConsolidation"
        )))
  }
}

private final class NativeMembershipCommandEvidenceFixtureBundle: NSObject {}
