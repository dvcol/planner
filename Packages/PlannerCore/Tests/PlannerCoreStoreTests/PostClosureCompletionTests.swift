import Foundation
import PlannerCore
import Testing

#if os(macOS)
  import Darwin
#endif

struct PostClosureCompletionTests {
  @Test func aNewCompletionObservesItsImportedClosureAndKeepsOtherAppearancesIndependent()
    async throws
  {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: PostClosureCompletionFixtureBundle.self)
    #endif
    let fixture = try #require(
      bundle.url(
        forResource: "retired-expanded-membership-alias-v3", withExtension: "json",
        subdirectory: "Fixtures/MembershipConsolidation"))
    var backup = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as? [String: Any])
    var expanded = try #require(backup["expandedCompletions"] as? [[String: Any]])
    let removed = expanded.removeFirst()
    let originalContext = try #require(removed["context"] as? [String: Any])
    let deletionIdentifier = "00000000-0000-4000-8000-000000000891"
    backup["expandedCompletions"] = expanded
    backup["deletionMarkers"] = [
      [
        "deletionId": deletionIdentifier,
        "operationId": "00000000-0000-4000-8000-000000000991",
        "target": ["kind": "expandedCompletion", "context": originalContext],
        "closedFamilyId": NSNull(),
      ]
    ]
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: backup)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite)),
      case .applied(_, .complete(let importedCheckpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let originalData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let itineraryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000301")!
    let membershipIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
    let firstEntryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000451")!
    let secondEntryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000452")!
    let directEntryIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000453")!
    let appearance = PlannerAppearance.expandedListItem(
      itineraryId: itineraryIdentifier, listEntryId: firstEntryIdentifier,
      membershipId: membershipIdentifier)
    guard
      case .appearance(let before) = await planner.read(
        session: session, request: .appearance(appearance))
    else { throw CancellationError() }
    #expect(!before.localDone && !before.effectiveDone && !before.globalDone)
    let operation = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .appearance(appearance), done: true))
    let result = await planner.execute(operation)
    guard case .applied(_, .complete(let completedCheckpoint)) = result.outcome else {
      Issue.record("A deliberate completion must observe the imported closure: \(result.outcome)")
      return
    }
    guard
      case .appearance(let completed) = await planner.read(
        session: session, request: .appearance(appearance)),
      case .appearance(let otherBranch) = await planner.read(
        session: session,
        request: .appearance(
          .expandedListItem(
            itineraryId: itineraryIdentifier, listEntryId: secondEntryIdentifier,
            membershipId: membershipIdentifier))),
      case .appearance(let direct) = await planner.read(
        session: session,
        request: .appearance(
          .directItineraryItem(
            itineraryId: itineraryIdentifier, entryId: directEntryIdentifier))),
      case .exported(let completedData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(completedCheckpoint == importedCheckpoint + 1)
    #expect(completed.localDone && completed.effectiveDone && !completed.globalDone)
    #expect(otherBranch.localDone && otherBranch.effectiveDone && !otherBranch.globalDone)
    #expect(!direct.localDone && !direct.effectiveDone && !direct.globalDone)
    let original = try #require(
      JSONSerialization.jsonObject(with: originalData) as? [String: Any])
    let saved = try #require(
      JSONSerialization.jsonObject(with: completedData) as? [String: Any])
    #expect(saved["formatVersion"] as? Int == 4)
    let changes = try #require(saved["completionChanges"] as? [[String: Any]])
    #expect(changes.count == 1)
    let change = try #require(changes.first)
    #expect(change["done"] as? Bool == true)
    #expect(change["aliasId"] as? String == "00000000-0000-4000-8000-000000000861")
    #expect(change["observedExpandedCompletionDeletionIds"] as? [String] == [deletionIdentifier])
    let context = try #require(change["context"] as? [String: Any])
    #expect(context["listEntryId"] as? String == "00000000-0000-4000-8000-000000000451")
    #expect(context["listEntryLifetimeId"] as? String == "00000000-0000-4000-8000-000000000851")
    #expect(context["membershipId"] as? String == "00000000-0000-4000-8000-000000000401")
    #expect(context["membershipLifetimeId"] as? String == "00000000-0000-4000-8000-000000000841")
    for field in ["memberships", "itineraryEntries", "deletionMarkers", "restorationFamilies"] {
      let previous = try #require(original[field] as? [Any])
      let current = try #require(saved[field] as? [Any])
      #expect(NSArray(array: current).isEqual(to: previous), Comment(rawValue: field))
    }
    let originalSources = try #require(original["sources"] as? [[String: Any]])
    let savedSources = try #require(saved["sources"] as? [[String: Any]])
    for kind in ["item", "list"] {
      let previous = try #require(originalSources.first { $0["kind"] as? String == kind })
      let current = try #require(savedSources.first { $0["kind"] as? String == kind })
      #expect(NSDictionary(dictionary: current).isEqual(to: previous), Comment(rawValue: kind))
    }
  }
  @Test(arguments: ["complete", "reopen", "laterClosure", "observedBoth", "sameAliasLateHead"])
  func portableHistoryRetainsOnlyAssertionsThatObservedEveryApplicableClosure(scenario: String)
    async throws
  {
    var backup = try Self.informedFixture()
    var changes = try #require(backup["completionChanges"] as? [[String: Any]])
    var aliases = try #require(backup["contextAliases"] as? [[String: Any]])
    var expanded = try #require(backup["expandedCompletions"] as? [[String: Any]])
    let firstContext = try #require(changes[0]["context"] as? [String: Any])
    let expectedDone =
      scenario == "complete" || scenario == "observedBoth" || scenario == "sameAliasLateHead"
    changes[0]["done"] = expectedDone
    expanded[0]["localDone"] = expectedDone
    var markers = try #require(backup["deletionMarkers"] as? [[String: Any]])
    if scenario == "laterClosure" || scenario == "observedBoth" {
      var later = markers[0]
      later["deletionId"] = "00000000-0000-4000-8000-000000000892"
      later["operationId"] = "00000000-0000-4000-8000-000000000992"
      markers.append(later)
      if scenario == "observedBoth" {
        changes[0]["observedExpandedCompletionDeletionIds"] = [
          "00000000-0000-4000-8000-000000000891", "00000000-0000-4000-8000-000000000892",
        ]
      } else {
        expanded.removeFirst()
      }
    }
    // This independently delivered assertion has the larger UUID but predates every closure.
    let delayedAliasIdentifier: String
    if scenario == "sameAliasLateHead" {
      changes[0]["id"] = "00000000-0000-0000-0000-000000000000"
      delayedAliasIdentifier = "00000000-0000-4000-8000-000000000861"
      let index = try #require(
        aliases.firstIndex {
          $0["aliasId"] as? String == delayedAliasIdentifier
        })
      aliases[index]["currentChangeId"] = "00000000-0000-4000-8000-000000001999"
    } else {
      delayedAliasIdentifier = "00000000-0000-4000-8000-000000000865"
      aliases.append([
        "aliasId": delayedAliasIdentifier, "context": firstContext,
        "canonicalContext": firstContext, "initialDone": true,
        "currentChangeId": "00000000-0000-4000-8000-000000001999",
      ])
    }
    changes.append([
      "id": "00000000-0000-4000-8000-000000001999",
      "aliasId": delayedAliasIdentifier, "context": firstContext,
      "done": !expectedDone, "observedChangeIds": [],
      "observedExpandedCompletionDeletionIds": [],
    ])
    backup["contextAliases"] = aliases
    backup["completionChanges"] = changes
    backup["expandedCompletions"] = expanded
    backup["deletionMarkers"] = markers
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(configuration: Self.configuration(directory))
    let bytes = try JSONSerialization.data(withJSONObject: backup)
    let decodedResult = planner.decodeImport(bytes)
    guard case .decoded(let decoded) = decodedResult else {
      Issue.record("A valid causal history must decode: \(decodedResult)")
      return
    }
    guard case .ready(let session) = await planner.bootstrap(),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .appearance(let value) = await planner.read(
        session: session, request: .appearance(Self.firstAppearance)),
      case .exported(let exported) = await planner.exportData(session: session),
      case .decoded(let roundTrip) = planner.decodeImport(exported)
    else { throw CancellationError() }
    #expect(value.localDone == expectedDone && !value.globalDone)
    #expect(roundTrip.backup.formatVersion == 4)
    #expect(roundTrip.backup.completionChanges.count == 2)
    #expect(roundTrip.backup.deletionMarkers.count == markers.count)
    let reopened = Planner(configuration: Self.configuration(directory))
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedBytes) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(exported == reopenedBytes)
    if scenario == "sameAliasLateHead" {
      let reopening = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .setCompletion(scope: .appearance(Self.firstAppearance), done: false)))
      guard case .applied(_, .complete) = reopening.outcome,
        case .appearance(let current) = await reopened.read(
          session: reopenedSession, request: .appearance(Self.firstAppearance))
      else {
        Issue.record("A deliberate Reopen must observe the retained informed head: \(reopening)")
        return
      }
      #expect(!current.localDone && !current.globalDone)
    }
  }

  @Test(arguments: ["missing", "duplicate", "unknown", "otherBranch", "nonExpanded"])
  func malformedClosureClaimsRejectWithTheExactPointer(scenario: String) throws {
    var backup = try Self.informedFixture()
    var changes = try #require(backup["completionChanges"] as? [[String: Any]])
    let path = "/completionChanges/0/observedExpandedCompletionDeletionIds"
    var expectedPath = path + "/0"
    switch scenario {
    case "missing":
      changes[0].removeValue(forKey: "observedExpandedCompletionDeletionIds")
      expectedPath = path
    case "duplicate":
      changes[0]["observedExpandedCompletionDeletionIds"] = [
        "00000000-0000-4000-8000-000000000891", "00000000-0000-4000-8000-000000000891",
      ]
      expectedPath = path
    case "unknown":
      changes[0]["observedExpandedCompletionDeletionIds"] = [
        "00000000-0000-4000-8000-000000000899"
      ]
    case "otherBranch":
      var markers = try #require(backup["deletionMarkers"] as? [[String: Any]])
      var expanded = try #require(backup["expandedCompletions"] as? [[String: Any]])
      let removed = expanded.remove(at: 1)
      markers[0]["target"] = ["kind": "expandedCompletion", "context": removed["context"]!]
      backup["deletionMarkers"] = markers
      backup["expandedCompletions"] = expanded
    default:
      let context: [String: Any] = [
        "kind": "directItineraryItem", "entryId": "00000000-0000-4000-8000-000000000453",
        "entryLifetimeId": "00000000-0000-4000-8000-000000000853",
      ]
      var aliases = try #require(backup["contextAliases"] as? [[String: Any]])
      let aliasIndex = try #require(
        aliases.firstIndex {
          $0["aliasId"] as? String == "00000000-0000-4000-8000-000000000861"
        })
      aliases[aliasIndex]["context"] = context
      aliases[aliasIndex]["canonicalContext"] = context
      changes[0]["context"] = context
      backup["contextAliases"] = aliases
      var expanded = try #require(backup["expandedCompletions"] as? [[String: Any]])
      expanded.removeFirst()
      backup["expandedCompletions"] = expanded
    }
    backup["completionChanges"] = changes
    let planner = Planner(configuration: Self.configuration(URL(fileURLWithPath: "/unused")))
    let result = planner.decodeImport(try JSONSerialization.data(withJSONObject: backup))
    guard case .invalid(let reason) = result else {
      Issue.record("Invalid closure evidence must reject: \(result)")
      return
    }
    #expect(reason.propertyPath == expectedPath)
  }

  @Test(arguments: ["legacyOverwrite", "legacySkip", "explicitOverwrite", "explicitSkip"])
  func sameChangeIdentityPreservesProvenObservationsAndRejectsExplicitConflicts(scenario: String)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = Self.configuration(directory)
    let planner = Planner(configuration: configuration)
    let seedBytes = try JSONSerialization.data(withJSONObject: Self.informedFixture())
    let seedResult = planner.decodeImport(seedBytes)
    guard case .decoded(let seed) = seedResult else {
      Issue.record("The informed fixture must decode: \(seedResult)")
      return
    }
    guard case .ready(let session) = await planner.bootstrap(),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let operation = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .appearance(Self.firstAppearance), done: false))
    guard
      case .applied(let originalResult, .complete(let originalCheckpoint)) =
        await planner.execute(operation).outcome,
      case .exported(let beforeBytes) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var incoming = try #require(
      JSONSerialization.jsonObject(with: beforeBytes) as? [String: Any])
    let explicit = scenario.hasPrefix("explicit")
    incoming["formatVersion"] = explicit ? 4 : 3
    incoming["deletionMarkers"] = []
    var changes = try #require(incoming["completionChanges"] as? [[String: Any]])
    for index in changes.indices {
      if explicit {
        changes[index]["observedExpandedCompletionDeletionIds"] = []
      } else {
        changes[index].removeValue(forKey: "observedExpandedCompletionDeletionIds")
      }
    }
    incoming["completionChanges"] = changes
    var sources = try #require(incoming["sources"] as? [[String: Any]])
    var content = try #require(sources[0]["content"] as? [String: Any])
    content["notes"] = "Later independent source edit"
    sources[0]["content"] = content
    incoming["sources"] = sources
    let decodedResult = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    guard case .decoded(let decoded) = decodedResult else {
      Issue.record(
        "The independent incoming graph must reach current-data admission: \(decodedResult)")
      return
    }
    let mode: PlannerImportMode = scenario.hasSuffix("Skip") ? .skip : .overwrite
    let reviewed = await planner.prepareReview(
      session: session, command: .applyImport(backup: decoded, mode: mode))
    if explicit {
      guard case .failed(let reason) = reviewed else {
        Issue.record(
          "An explicit same-ID observation conflict must reject before selection: \(reviewed)")
        return
      }
      #expect(reason.propertyPath?.hasSuffix("/observedExpandedCompletionDeletionIds") == true)
      guard case .exported(let afterBytes) = await planner.exportData(session: session) else {
        throw CancellationError()
      }
      #expect(afterBytes == beforeBytes)
    } else {
      guard case .reviewed(let importReview) = reviewed else {
        Issue.record("Legacy absence must preserve known metadata: \(reviewed)")
        return
      }
      let applied = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: importReview.command,
          reviewToken: importReview.reviewToken))
      guard case .applied(_, .complete) = applied.outcome,
        case .exported(let afterBytes) = await planner.exportData(session: session),
        case .decoded(let after) = planner.decodeImport(afterBytes),
        case .appearance(let appearance) = await planner.read(
          session: session, request: .appearance(Self.firstAppearance))
      else {
        Issue.record("Legacy import must retain proven completion evidence: \(applied)")
        return
      }
      #expect(!appearance.localDone)
      #expect(after.backup.completionChanges.count == 2)
      #expect(
        after.backup.completionChanges.allSatisfy {
          $0.observedExpandedCompletionDeletionIds == [
            UUID(uuidString: "00000000-0000-4000-8000-000000000891")!
          ]
        })
      #expect(
        after.backup.items.first?.content.notes
          == (mode == .overwrite ? "Later independent source edit" : "A shared stop"))
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayedResult, .complete(let replayedCheckpoint)) =
        await reopened.execute(
          .init(
            operationId: operation.operationId, session: reopenedSession,
            command: operation.command)
        ).outcome
    else { throw CancellationError() }
    #expect(originalResult == replayedResult && originalCheckpoint == replayedCheckpoint)
  }

  @Test(arguments: ["ordinary", "recoveryFailure", "controlFailure"])
  func compatibilityUpgradePublishesTheNewBaselineBeforeEnablingWriters(scenario: String)
    async throws
  {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: PostClosureCompletionFixtureBundle.self)
    #endif
    let fixture = try #require(
      bundle.url(
        forResource: "SchemaV18", withExtension: nil, subdirectory: "Fixtures"))
    let directory = try makePlannerStoreFixtureDirectory()
    try FileManager.default.copyItem(at: fixture, to: directory)
    let configuration = Self.configuration(directory)
    let beforeControl = try Data(contentsOf: configuration.controlURL)
    let before = try #require(JSONSerialization.jsonObject(with: beforeControl) as? [String: Any])
    let namespace = try #require(before["namespaceId"] as? String)
    let historicalDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(namespace)
    let historicalFiles = try FileManager.default.contentsOfDirectory(
      at: historicalDirectory, includingPropertiesForKeys: nil
    ).filter {
      $0.lastPathComponent.hasPrefix("checkpoint-") || $0.lastPathComponent.hasPrefix("proposal-")
    }
    let historicalBytes = try Dictionary(
      uniqueKeysWithValues: historicalFiles.map {
        ($0, try Data(contentsOf: $0))
      })
    let share = Planner(
      configuration: .init(
        storeURL: configuration.storeURL, controlURL: configuration.controlURL,
        recoveryDirectoryURL: configuration.recoveryDirectoryURL, processRole: .shareExtension,
        storageMode: .localOnly))
    guard case .mainAppMigrationRequired = await share.bootstrap() else {
      Issue.record("Share must wait for the main-app compatibility baseline")
      return
    }
    #expect(try Data(contentsOf: configuration.controlURL) == beforeControl)
    let planner = Planner(configuration: configuration)
    if scenario != "ordinary" {
      let obstructedDirectory: URL
      if scenario == "controlFailure" {
        obstructedDirectory = configuration.controlURL.deletingLastPathComponent()
      } else {
        obstructedDirectory = historicalDirectory
      }
      let originalAttributes = try FileManager.default.attributesOfItem(
        atPath: obstructedDirectory.path)
      let originalMode = try #require(originalAttributes[.posixPermissions])
      defer {
        try? FileManager.default.setAttributes(
          [.posixPermissions: originalMode], ofItemAtPath: obstructedDirectory.path)
      }
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o500], ofItemAtPath: obstructedDirectory.path)
      let failed = await planner.bootstrap()
      guard case .unavailable = failed else {
        Issue.record("A failed compatibility write must not activate writers: \(failed)")
        return
      }
      #expect(try Data(contentsOf: configuration.controlURL) == beforeControl)
      if scenario == "controlFailure" {
        let interruptedIdentity = try #require(
          JSONSerialization.jsonObject(
            with: Data(contentsOf: historicalDirectory.appendingPathComponent("identity.json")))
            as? [String: Any])
        #expect(interruptedIdentity["schemaVersion"] as? Int == 21)
        guard
          case .listedNamespaces(let interruptedNamespaces) = await planner.inspectRecovery(
            request: .namespaces),
          let interrupted = interruptedNamespaces.first?.acknowledgedSnapshot,
          case .selected(let copy) = await planner.inspectRecovery(
            request: .acknowledgedSnapshot(
              namespaceId: UUID(uuidString: namespace)!,
              checkpointGeneration: interrupted.checkpointGeneration))
        else {
          Issue.record(
            "The published compatibility baseline must remain inspectable before activation")
          return
        }
        #expect(interrupted.storageSchemaVersion == 21)
        #expect(copy.decodedBackup.backup.formatVersion == 4)
      }
      try FileManager.default.setAttributes(
        [.posixPermissions: originalMode], ofItemAtPath: obstructedDirectory.path)
      guard case .mainAppMigrationRequired = await share.bootstrap() else {
        Issue.record("Share must still wait after interrupted activation")
        return
      }
    }
    guard case .ready = await planner.bootstrap(),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let current = namespaces.first?.acknowledgedSnapshot,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: UUID(uuidString: namespace)!,
          checkpointGeneration: current.checkpointGeneration))
    else { throw CancellationError() }
    let control = try #require(
      JSONSerialization.jsonObject(
        with: Data(contentsOf: configuration.controlURL)) as? [String: Any])
    #expect(control["schemaVersion"] as? Int == 21)
    for field in ["datasetId", "namespaceId", "epochId", "ownershipBinding"] {
      #expect(control[field] as? String == before[field] as? String)
    }
    #expect(current.storageSchemaVersion == 21)
    #expect(recovered.decodedBackup.backup.formatVersion == 4)
    #expect(current.checkpointGeneration > 7)
    for (file, bytes) in historicalBytes {
      #expect(try Data(contentsOf: file) == bytes)
    }
    guard case .ready = await share.bootstrap() else {
      Issue.record("Share must work only after the main app activates compatibility 20")
      return
    }
  }

  @Test func laterClosureInvalidatesBulkReviewAndOldCompletionReplayKeepsItsOriginalCheckpoint()
    async throws
  {
    let planner = Planner(configuration: Self.configuration(try makePlannerStoreFixtureDirectory()))
    let seedBytes = try JSONSerialization.data(withJSONObject: Self.informedFixture())
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seed) = planner.decodeImport(seedBytes),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome
    else { throw CancellationError() }
    let single = PlannerOperation(
      operationId: UUID(), session: session,
      command: .setCompletion(scope: .appearance(Self.firstAppearance), done: true))
    let bulk = PlannerCommand.setBulkCompletion(
      scope: .itineraryListEntry(
        itineraryId: UUID(uuidString: "00000000-0000-4000-8000-000000000301")!,
        listEntryId: UUID(uuidString: "00000000-0000-4000-8000-000000000451")!), done: true)
    guard
      case .applied(let singleResult, .complete(let singleCheckpoint)) =
        await planner.execute(single).outcome,
      case .reviewed(let priorReview) = await planner.prepareReview(session: session, command: bulk),
      case .exported(let completedBytes) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var cleared = try #require(
      JSONSerialization.jsonObject(with: completedBytes) as? [String: Any])
    var expanded = try #require(cleared["expandedCompletions"] as? [[String: Any]])
    let removed = expanded.removeFirst()
    var markers = try #require(cleared["deletionMarkers"] as? [[String: Any]])
    markers.append([
      "deletionId": "00000000-0000-4000-8000-000000000892",
      "operationId": "00000000-0000-4000-8000-000000000992",
      "target": ["kind": "expandedCompletion", "context": removed["context"]!],
      "closedFamilyId": NSNull(),
    ])
    cleared["deletionMarkers"] = markers
    cleared["expandedCompletions"] = expanded
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: cleared)),
      case .reviewed(let clearingReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: clearingReview.command,
          reviewToken: clearingReview.reviewToken)
      ).outcome,
      case .appearance(let unfinished) = await planner.read(
        session: session, request: .appearance(Self.firstAppearance)),
      case .exported(let beforeReplay) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(!unfinished.localDone)
    guard
      case .applied(let replayed, .complete(let replayedCheckpoint)) =
        await planner.execute(single).outcome,
      case .exported(let afterReplay) = await planner.exportData(session: session),
      case .rejected(let stale) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: bulk,
          reviewToken: priorReview.reviewToken)
      ).outcome
    else { throw CancellationError() }
    #expect(replayed == singleResult && replayedCheckpoint == singleCheckpoint)
    #expect(beforeReplay == afterReplay)
    #expect(stale.code == "staleReview")
    guard
      case .reviewed(let freshReview) = await planner.prepareReview(session: session, command: bulk),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: bulk,
          reviewToken: freshReview.reviewToken)
      ).outcome,
      case .appearance(let finished) = await planner.read(
        session: session, request: .appearance(Self.firstAppearance)),
      case .exported(let finishedBytes) = await planner.exportData(session: session),
      case .decoded(let final) = planner.decodeImport(finishedBytes)
    else { throw CancellationError() }
    #expect(finished.localDone && !finished.globalDone)
    let allClosures = Set(
      final.backup.deletionMarkers.compactMap { marker -> UUID? in
        guard case .expandedCompletion(let context) = marker.target,
          context.listEntryId == UUID(uuidString: "00000000-0000-4000-8000-000000000451")!
        else { return nil }
        return marker.deletionId
      })
    #expect(allClosures.contains(UUID(uuidString: "00000000-0000-4000-8000-000000000891")!))
    #expect(allClosures.contains(UUID(uuidString: "00000000-0000-4000-8000-000000000892")!))
    #expect(
      final.backup.completionChanges.contains {
        $0.done && Set($0.observedExpandedCompletionDeletionIds) == allClosures
      })
  }

  @Test(arguments: [false, true])
  func informedExpandedCompletionReadsDoNotPublishRepeatedMaintenance(done: Bool) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(configuration: Self.configuration(directory))
    var backup = try Self.informedFixture()
    var changes = try #require(backup["completionChanges"] as? [[String: Any]])
    changes[0]["done"] = done
    backup["completionChanges"] = changes
    var expanded = try #require(backup["expandedCompletions"] as? [[String: Any]])
    expanded[0]["localDone"] = done
    backup["expandedCompletions"] = expanded
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: backup)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded, mode: .overwrite)),
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
    for _ in 0..<4 {
      guard
        case .snapshot = await planner.query(
          .init(session: session, request: .items(.init(completion: .all, archive: .all)))),
        case .appearance(let appearance) = await planner.read(
          session: session, request: .appearance(Self.firstAppearance)),
        case .exported = await planner.exportData(session: session)
      else { throw CancellationError() }
      #expect(appearance.localDone == done && !appearance.globalDone)
    }
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let actualCheckpoint = namespaces.first?.acknowledgedSnapshot?.checkpointGeneration
    else { throw CancellationError() }
    #expect(actualCheckpoint == checkpoint)
  }

  private static var firstAppearance: PlannerAppearance {
    .expandedListItem(
      itineraryId: UUID(uuidString: "00000000-0000-4000-8000-000000000301")!,
      listEntryId: UUID(uuidString: "00000000-0000-4000-8000-000000000451")!,
      membershipId: UUID(uuidString: "00000000-0000-4000-8000-000000000401")!)
  }

  private static func configuration(_ directory: URL) -> PlannerStorageConfiguration {
    .init(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
  }

  private static func informedFixture() throws -> [String: Any] {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle(for: PostClosureCompletionFixtureBundle.self)
    #endif
    let fixture = try #require(
      bundle.url(
        forResource: "retired-expanded-membership-alias-v3", withExtension: "json",
        subdirectory: "Fixtures/MembershipConsolidation"))
    var backup = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as? [String: Any])
    var expanded = try #require(backup["expandedCompletions"] as? [[String: Any]])
    expanded[0]["localDone"] = true
    backup["expandedCompletions"] = expanded
    let context = try #require(expanded[0]["context"] as? [String: Any])
    var aliases = try #require(backup["contextAliases"] as? [[String: Any]])
    let aliasIndex = try #require(
      aliases.firstIndex {
        $0["aliasId"] as? String == "00000000-0000-4000-8000-000000000861"
      })
    aliases[aliasIndex]["currentChangeId"] = "00000000-0000-4000-8000-000000001001"
    backup["formatVersion"] = 4
    backup["contextAliases"] = aliases
    backup["completionChanges"] = [
      [
        "id": "00000000-0000-4000-8000-000000001001", "aliasId": aliases[aliasIndex]["aliasId"]!,
        "context": aliases[aliasIndex]["context"]!, "done": true, "observedChangeIds": [],
        "observedExpandedCompletionDeletionIds": ["00000000-0000-4000-8000-000000000891"],
      ]
    ]
    backup["deletionMarkers"] = [
      [
        "deletionId": "00000000-0000-4000-8000-000000000891",
        "operationId": "00000000-0000-4000-8000-000000000991",
        "target": ["kind": "expandedCompletion", "context": context], "closedFamilyId": NSNull(),
      ]
    ]
    return backup
  }
}

private final class PostClosureCompletionFixtureBundle: NSObject {}

#if os(macOS)
  extension PostClosureCompletionTests {
    @Test func interruptedCompatibilityPublicationKeepsTheOldBaselineAndRetries() async throws {
      if let workPath = ProcessInfo.processInfo.environment[
        "PLANNER_COMPLETION_COMPATIBILITY_INTERRUPT_WORK"]
      {
        let workDirectory = URL(fileURLWithPath: workPath)
        #if SWIFT_PACKAGE
          let bundle = Bundle.module
        #else
          let bundle = Bundle(for: PostClosureCompletionFixtureBundle.self)
        #endif
        let fixture = try #require(
          bundle.url(forResource: "SchemaV18", withExtension: nil, subdirectory: "Fixtures"))
        let directory = try makePlannerStoreFixtureDirectory()
        try FileManager.default.copyItem(at: fixture, to: directory)
        let configuration = Self.configuration(directory)
        let controlData = try Data(contentsOf: configuration.controlURL)
        let control = try #require(
          JSONSerialization.jsonObject(with: controlData) as? [String: Any])
        let namespace = try #require(control["namespaceId"] as? String)
        let namespaceIdentifier = try #require(UUID(uuidString: namespace))
        let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
          namespace)
        let attributes = try FileManager.default.attributesOfItem(atPath: namespaceDirectory.path)
        let originalMode = try #require(attributes[.posixPermissions] as? NSNumber).intValue
        let historicalFiles = try FileManager.default.contentsOfDirectory(
          at: namespaceDirectory, includingPropertiesForKeys: nil
        ).filter {
          $0.lastPathComponent.hasPrefix("checkpoint-")
            || $0.lastPathComponent.hasPrefix("proposal-")
        }
        let historicalBytes = try Dictionary(
          uniqueKeysWithValues: historicalFiles.map {
            ($0.lastPathComponent, try Data(contentsOf: $0).base64EncodedString())
          })
        let planner = Planner(configuration: configuration)
        guard
          case .listedNamespaces(let namespaces) = await planner.inspectRecovery(
            request: .namespaces),
          let snapshot = namespaces.first?.acknowledgedSnapshot,
          case .selected(let original) = await planner.inspectRecovery(
            request: .acknowledgedSnapshot(
              namespaceId: namespaceIdentifier, checkpointGeneration: snapshot.checkpointGeneration)
          )
        else { throw CancellationError() }
        try #require(snapshot.storageSchemaVersion == 18 && snapshot.checkpointGeneration == 7)
        try #require(original.decodedBackup.backup.formatVersion == 2)
        try JSONSerialization.data(
          withJSONObject: [
            "directory": directory.path, "namespaceId": namespace,
            "control": controlData.base64EncodedString(), "namespaceMode": originalMode,
            "historicalFiles": historicalBytes,
            "portableData": original.portableData.base64EncodedString(),
          ], options: [.sortedKeys]
        ).write(to: workDirectory.appendingPathComponent("input.json"), options: .atomic)
        try FileManager.default.setAttributes(
          [.posixPermissions: 0o500], ofItemAtPath: namespaceDirectory.path)
        guard case .unavailable = await planner.bootstrap(),
          case .listedNamespaces(let failedNamespaces) = await planner.inspectRecovery(
            request: .namespaces),
          let failedSnapshot = failedNamespaces.first?.acknowledgedSnapshot,
          case .selected(let retained) = await planner.inspectRecovery(
            request: .acknowledgedSnapshot(
              namespaceId: namespaceIdentifier, checkpointGeneration: 7))
        else { throw CancellationError() }
        try #require(try Data(contentsOf: configuration.controlURL) == controlData)
        try #require(
          failedSnapshot.storageSchemaVersion == 18 && failedSnapshot.checkpointGeneration == 7)
        try #require(retained.portableData == original.portableData)
        let metadata = try #require(
          JSONSerialization.jsonObject(
            with: Data(contentsOf: namespaceDirectory.appendingPathComponent("identity.json")))
            as? [String: Any])
        try #require(metadata["schemaVersion"] as? Int == 18)
        try JSONSerialization.data(
          withJSONObject: [
            "checkpointGeneration": failedSnapshot.checkpointGeneration,
            "storageSchemaVersion": failedSnapshot.storageSchemaVersion,
            "metadataSchemaVersion": metadata["schemaVersion"]!,
          ], options: [.sortedKeys]
        ).write(to: workDirectory.appendingPathComponent("unpublished.json"), options: .atomic)
        try #require(kill(getpid(), SIGKILL) == 0)
        while true { pause() }
      }
      let workDirectory = try makePlannerStoreFixtureDirectory()
      try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
      try runCompatibilityInterruption(
        workDirectory: workDirectory,
        testName: "interruptedCompatibilityPublicationKeepsTheOldBaselineAndRetries")
      let input = try #require(
        JSONSerialization.jsonObject(
          with: Data(contentsOf: workDirectory.appendingPathComponent("input.json")))
          as? [String: Any])
      let directory = URL(fileURLWithPath: try #require(input["directory"] as? String))
      let configuration = Self.configuration(directory)
      let originalControl = try #require(
        (input["control"] as? String).flatMap { Data(base64Encoded: $0) })
      let originalCopy = try #require(
        (input["portableData"] as? String).flatMap { Data(base64Encoded: $0) })
      let namespaceIdentifier = try #require(
        (input["namespaceId"] as? String).flatMap(UUID.init(uuidString:)))
      let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
        namespaceIdentifier.uuidString)
      let originalMode = try #require(input["namespaceMode"] as? Int)
      defer {
        try? FileManager.default.setAttributes(
          [.posixPermissions: originalMode], ofItemAtPath: namespaceDirectory.path)
      }
      let planner = Planner(configuration: configuration)
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let snapshot = namespaces.first?.acknowledgedSnapshot,
        case .selected(let retained) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(namespaceId: namespaceIdentifier, checkpointGeneration: 7))
      else { throw CancellationError() }
      #expect(snapshot.storageSchemaVersion == 18 && snapshot.checkpointGeneration == 7)
      #expect(retained.portableData == originalCopy)
      #expect(try Data(contentsOf: configuration.controlURL) == originalControl)
      let share = Planner(
        configuration: .init(
          storeURL: configuration.storeURL, controlURL: configuration.controlURL,
          recoveryDirectoryURL: configuration.recoveryDirectoryURL, processRole: .shareExtension,
          storageMode: .localOnly))
      guard case .mainAppMigrationRequired = await share.bootstrap() else {
        Issue.record("Share must wait while the compatibility baseline has not been published")
        return
      }
      #expect(try Data(contentsOf: configuration.controlURL) == originalControl)
      try FileManager.default.setAttributes(
        [.posixPermissions: originalMode], ofItemAtPath: namespaceDirectory.path)
      guard case .ready(let session) = await planner.bootstrap(),
        case .exported(let exported) = await planner.exportData(session: session),
        case .listedNamespaces(let upgradedNamespaces) = await planner.inspectRecovery(
          request: .namespaces),
        let upgraded = upgradedNamespaces.first?.acknowledgedSnapshot,
        case .selected(let oldCopy) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(namespaceId: namespaceIdentifier, checkpointGeneration: 7)),
        case .ready = await share.bootstrap()
      else { throw CancellationError() }
      #expect(oldCopy.portableData == originalCopy)
      #expect(upgraded.storageSchemaVersion == 21 && upgraded.checkpointGeneration > 7)
      let beforeGraph = try #require(
        JSONSerialization.jsonObject(with: originalCopy) as? [String: Any])
      let afterGraph = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
      #expect(afterGraph["formatVersion"] as? Int == 4)
      for field in [
        "sources", "memberships", "itineraryEntries", "expandedCompletions", "schedules",
        "deletionMarkers", "ownedLinks", "labelAssociations", "restorationFamilies",
      ] {
        #expect(
          NSArray(array: try #require(beforeGraph[field] as? [Any])).isEqual(
            to: try #require(afterGraph[field] as? [Any])), Comment(rawValue: field))
      }
      let control = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: configuration.controlURL))
          as? [String: Any])
      let originalIdentity = try #require(
        JSONSerialization.jsonObject(with: originalControl) as? [String: Any])
      #expect(control["schemaVersion"] as? Int == 21)
      for field in ["datasetId", "namespaceId", "epochId", "ownershipBinding"] {
        #expect(control[field] as? String == originalIdentity[field] as? String)
      }
      let historicalFiles = try #require(input["historicalFiles"] as? [String: String])
      for (name, encoded) in historicalFiles {
        #expect(
          try Data(contentsOf: namespaceDirectory.appendingPathComponent(name))
            == Data(base64Encoded: encoded))
      }
    }

    @Test func interruptedCompatibilityActivationRetainsItsPublishedBaselineAndRetries()
      async throws
    {
      if let workPath = ProcessInfo.processInfo.environment[
        "PLANNER_COMPLETION_COMPATIBILITY_INTERRUPT_WORK"]
      {
        try await interruptFailedCompatibilityActivation(
          workDirectory: URL(fileURLWithPath: workPath))
        return
      }
      let workDirectory = try makePlannerStoreFixtureDirectory()
      try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
      try runCompatibilityInterruption(workDirectory: workDirectory)
      let input = try #require(
        JSONSerialization.jsonObject(
          with: Data(contentsOf: workDirectory.appendingPathComponent("input.json")))
          as? [String: Any])
      let directory = URL(fileURLWithPath: try #require(input["directory"] as? String))
      let configuration = Self.configuration(directory)
      let originalControl = try #require(
        (input["control"] as? String).flatMap { Data(base64Encoded: $0) })
      let originalMode = try #require(input["controlMode"] as? Int)
      let controlDirectory = configuration.controlURL.deletingLastPathComponent()
      defer {
        try? FileManager.default.setAttributes(
          [.posixPermissions: originalMode], ofItemAtPath: controlDirectory.path)
      }
      #expect(try Data(contentsOf: configuration.controlURL) == originalControl)
      try FileManager.default.setAttributes(
        [.posixPermissions: originalMode], ofItemAtPath: controlDirectory.path)
      let published = try #require(
        JSONSerialization.jsonObject(
          with: Data(contentsOf: workDirectory.appendingPathComponent("published.json")))
          as? [String: Any])
      let namespaceIdentifier = try #require(
        (input["namespaceId"] as? String).flatMap(UUID.init(uuidString:)))
      let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(
        namespaceIdentifier.uuidString)
      let checkpoint = try #require(published["checkpointGeneration"] as? Int64)
      let originalCopy = try #require(
        (published["portableData"] as? String).flatMap { Data(base64Encoded: $0) })
      let planner = Planner(configuration: configuration)
      guard
        case .listedNamespaces(let interruptedNamespaces) = await planner.inspectRecovery(
          request: .namespaces),
        let interruptedSnapshot = interruptedNamespaces.first?.acknowledgedSnapshot,
        case .selected(let interrupted) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespaceIdentifier, checkpointGeneration: checkpoint))
      else { throw CancellationError() }
      #expect(interrupted.portableData == originalCopy)
      #expect(interrupted.decodedBackup.backup.formatVersion == 4)
      #expect(
        interruptedSnapshot.storageSchemaVersion == 21
          && interruptedSnapshot.checkpointGeneration == checkpoint)
      let interruptedIdentity = try #require(
        JSONSerialization.jsonObject(
          with: Data(contentsOf: namespaceDirectory.appendingPathComponent("identity.json")))
          as? [String: Any])
      #expect(interruptedIdentity["schemaVersion"] as? Int == 21)
      let share = Planner(
        configuration: .init(
          storeURL: configuration.storeURL, controlURL: configuration.controlURL,
          recoveryDirectoryURL: configuration.recoveryDirectoryURL, processRole: .shareExtension,
          storageMode: .localOnly))
      guard case .mainAppMigrationRequired = await share.bootstrap() else {
        Issue.record("Share must wait after the interrupted activation")
        return
      }
      #expect(try Data(contentsOf: configuration.controlURL) == originalControl)
      guard case .ready(let session) = await planner.bootstrap(),
        case .exported(let exported) = await planner.exportData(session: session),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let latest = namespaces.first?.acknowledgedSnapshot,
        case .selected(let retained) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespaceIdentifier, checkpointGeneration: checkpoint)),
        case .ready = await share.bootstrap()
      else { throw CancellationError() }
      #expect(retained.portableData == originalCopy)
      let exportedGraph = try #require(
        JSONSerialization.jsonObject(with: exported) as? NSDictionary)
      let interruptedGraph = try #require(
        JSONSerialization.jsonObject(with: originalCopy) as? NSDictionary)
      #expect(exportedGraph == interruptedGraph)
      #expect(latest.storageSchemaVersion == 21 && latest.checkpointGeneration >= checkpoint)
      let control = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: configuration.controlURL))
          as? [String: Any])
      let originalIdentity = try #require(
        JSONSerialization.jsonObject(with: originalControl) as? [String: Any])
      #expect(control["schemaVersion"] as? Int == 21)
      for field in ["datasetId", "namespaceId", "epochId", "ownershipBinding"] {
        #expect(control[field] as? String == originalIdentity[field] as? String)
      }
      let historicalFiles = try #require(input["historicalFiles"] as? [String: String])
      for (name, encoded) in historicalFiles {
        #expect(
          try Data(contentsOf: namespaceDirectory.appendingPathComponent(name))
            == Data(base64Encoded: encoded))
      }
    }

    private func interruptFailedCompatibilityActivation(workDirectory: URL) async throws {
      #if SWIFT_PACKAGE
        let bundle = Bundle.module
      #else
        let bundle = Bundle(for: PostClosureCompletionFixtureBundle.self)
      #endif
      let fixture = try #require(
        bundle.url(forResource: "SchemaV18", withExtension: nil, subdirectory: "Fixtures"))
      let directory = try makePlannerStoreFixtureDirectory()
      try FileManager.default.copyItem(at: fixture, to: directory)
      let configuration = Self.configuration(directory)
      let beforeControl = try Data(contentsOf: configuration.controlURL)
      let before = try #require(
        JSONSerialization.jsonObject(with: beforeControl) as? [String: Any])
      let namespace = try #require(before["namespaceId"] as? String)
      let namespaceDirectory = configuration.recoveryDirectoryURL.appendingPathComponent(namespace)
      let historicalFiles = try FileManager.default.contentsOfDirectory(
        at: namespaceDirectory, includingPropertiesForKeys: nil
      ).filter {
        $0.lastPathComponent.hasPrefix("checkpoint-") || $0.lastPathComponent.hasPrefix("proposal-")
      }
      let historicalBytes = try Dictionary(
        uniqueKeysWithValues: historicalFiles.map {
          ($0.lastPathComponent, try Data(contentsOf: $0).base64EncodedString())
        })
      let controlDirectory = configuration.controlURL.deletingLastPathComponent()
      let attributes = try FileManager.default.attributesOfItem(atPath: controlDirectory.path)
      let originalMode = try #require(attributes[.posixPermissions] as? NSNumber).intValue
      try JSONSerialization.data(
        withJSONObject: [
          "directory": directory.path, "namespaceId": namespace,
          "control": beforeControl.base64EncodedString(), "controlMode": originalMode,
          "historicalFiles": historicalBytes,
        ], options: [.sortedKeys]
      ).write(to: workDirectory.appendingPathComponent("input.json"), options: .atomic)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o500], ofItemAtPath: controlDirectory.path)
      let planner = Planner(configuration: configuration)
      guard case .unavailable = await planner.bootstrap(),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let checkpoint = namespaces.first?.acknowledgedSnapshot,
        case .selected(let copy) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: UUID(uuidString: namespace)!,
            checkpointGeneration: checkpoint.checkpointGeneration))
      else { throw CancellationError() }
      try #require(try Data(contentsOf: configuration.controlURL) == beforeControl)
      try #require(checkpoint.storageSchemaVersion == 21)
      try #require(copy.decodedBackup.backup.formatVersion == 4)
      let identity = try #require(
        JSONSerialization.jsonObject(
          with: Data(contentsOf: namespaceDirectory.appendingPathComponent("identity.json")))
          as? [String: Any])
      try #require(identity["schemaVersion"] as? Int == 21)
      try JSONSerialization.data(
        withJSONObject: [
          "checkpointGeneration": checkpoint.checkpointGeneration,
          "storageSchemaVersion": checkpoint.storageSchemaVersion,
          "metadataSchemaVersion": identity["schemaVersion"]!,
          "portableData": copy.portableData.base64EncodedString(),
        ], options: [.sortedKeys]
      ).write(to: workDirectory.appendingPathComponent("published.json"), options: .atomic)
      try #require(kill(getpid(), SIGKILL) == 0)
      while true { pause() }
    }

    private func runCompatibilityInterruption(
      workDirectory: URL,
      testName: String = "interruptedCompatibilityActivationRetainsItsPublishedBaselineAndRetries"
    ) throws {
      let outputURL = workDirectory.appendingPathComponent("child.log")
      try Data().write(to: outputURL)
      let output = try FileHandle(forWritingTo: outputURL)
      defer { try? output.close() }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      var runnerArguments: [String] = []
      if let index = CommandLine.arguments.firstIndex(of: "--test-bundle-path"),
        CommandLine.arguments.indices.contains(index + 1)
      {
        runnerArguments = ["--test-bundle-path", CommandLine.arguments[index + 1]]
      }
      process.arguments =
        runnerArguments + [
          "--testing-library", "swift-testing", "--filter",
          "PostClosureCompletionTests/" + testName,
        ]
      var environment = ProcessInfo.processInfo.environment
      environment["PLANNER_COMPLETION_COMPATIBILITY_INTERRUPT_WORK"] = workDirectory.path
      process.environment = environment
      process.standardOutput = output
      process.standardError = output
      let completion = DispatchSemaphore(value: 0)
      process.terminationHandler = { _ in completion.signal() }
      try process.run()
      let finished = completion.wait(timeout: .now() + 45) == .success
      if !finished {
        kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
      }
      try output.close()
      let transcript = try String(contentsOf: outputURL, encoding: .utf8)
      print("COMPLETION_COMPATIBILITY_INTERRUPTION_WORK \(workDirectory.path)")
      try JSONSerialization.data(
        withJSONObject: [
          "finishedWithinDeadline": finished,
          "terminationReason": String(describing: process.terminationReason),
          "terminationStatus": process.terminationStatus,
          "childProcessIdentifier": process.processIdentifier,
        ], options: [.sortedKeys]
      ).write(to: workDirectory.appendingPathComponent("termination.json"), options: .atomic)
      #expect(finished)
      #expect(process.terminationReason == .uncaughtSignal)
      #expect(
        process.terminationStatus == SIGKILL, Comment(rawValue: String(transcript.suffix(12_000))))
    }
  }
#endif
