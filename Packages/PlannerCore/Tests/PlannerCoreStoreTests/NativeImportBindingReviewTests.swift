import Foundation
import PlannerCore
import Testing

struct NativeImportBindingReviewTests {
  @Test(arguments: [101, 201, 301, 501, 601], [PlannerImportMode.skip, .overwrite])
  func emptyPlannerRestoresIncomingFamilyReferencesAndItsCompleteGraph(
    sourceIdentifierSuffix: Int, mode: PlannerImportMode
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let expectedFixture = try knownFamilyImportFixture()
    let sourceIdentifier = knownFamilyFixtureIdentifier(sourceIdentifierSuffix)
    let canonicalLifetime = knownFamilyFixtureIdentifier(sourceIdentifierSuffix + 1000)
    let otherCandidateLifetime = knownFamilyFixtureIdentifier(sourceIdentifierSuffix + 2000)
    let sources = try #require(expectedFixture["sources"] as? [[String: Any]])
    let source = try #require(sources.first { $0["id"] as? String == sourceIdentifier })
    let kind = try #require(source["kind"] as? String)
    var incoming = try #require(
      rebindingKnownFamilyFixture(
        expectedFixture,
        replacements: ["\(kind):\(sourceIdentifier):\(canonicalLifetime)": otherCandidateLifetime])
        as? [String: Any])
    incoming["sources"] = expectedFixture["sources"]
    let incomingData = try JSONSerialization.data(withJSONObject: incoming)
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let backup) = planner.decodeImport(incomingData),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: mode))
    else { throw CancellationError() }
    #expect(backup.externalBindings.isEmpty)
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let exported) = await planner.exportData(session: session)
    else {
      Issue.record("Restore the complete self-contained family graph: \(response)")
      return
    }
    let expected = try canonicalPortableFixtureExpectations(
      JSONSerialization.data(withJSONObject: expectedFixture))
    let actual = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
    #expect(backup.backup.restorationFamilies.count == 5)
    #expect(backup.backup.restorationFamilies.allSatisfy { $0.candidates.count == 2 })
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let recovered = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: recovered).isEqual(to: expected))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeatedReview) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: backup, mode: mode)),
      case .applied(let repeated, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeatedReview.command,
          reviewToken: repeatedReview.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == exported)
    #expect(replayed == result && replayCheckpoint == checkpoint)
    #expect(repeated.generated.isEmpty && repeatedData == exported)
  }

  enum BindingCase: CaseIterable { case live, missing, wrongLifetime }
  enum KnownFamilyImportCase: CaseIterable { case externalSkip, externalOverwrite, declaredSkip }

  @Test(arguments: [false, true])
  func skipResolvesAnInternallyDeclaredKnownCandidateWithoutReplacingTheLiveOwner(
    declaresCurrentCandidate: Bool
  ) async throws {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    var seed = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    let fixtureSources = try #require(seed["sources"] as? [[String: Any]])
    var museum = try #require(fixtureSources.first { $0["kind"] as? String == "item" })
    museum["lifetimeId"] = "00000000-0000-4000-8000-000000000814"
    for name in seed.keys where name != "format" && name != "formatVersion" { seed[name] = [] }
    seed["sources"] = [museum]
    let predecessor: [String: Any] = [
      "kind": "item", "id": "00000000-0000-4000-8000-000000000101",
      "lifetimeId": "00000000-0000-4000-8000-000000000811",
    ]
    seed["deletionMarkers"] = [
      [
        "deletionId": "00000000-0000-4000-8000-000000000892",
        "operationId": "00000000-0000-4000-8000-000000000992",
        "target": ["kind": "source", "source": predecessor], "closedFamilyId": NSNull(),
      ]
    ]
    seed["restorationFamilies"] = [
      [
        "familyId": "00000000-0000-4000-8000-000000000890", "predecessor": predecessor,
        "candidates": [
          [
            "lifetimeId": "00000000-0000-4000-8000-000000000814",
            "operationId": "00000000-0000-4000-8000-000000000994",
          ],
          [
            "lifetimeId": "00000000-0000-4000-8000-000000000815",
            "operationId": "00000000-0000-4000-8000-000000000995",
          ],
        ],
      ]
    ]
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seedBackup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: seed)),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seedBackup)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(before)
    else { throw CancellationError() }
    #expect(
      current.backup.restorationFamilies.first?.candidates.map(\.lifetimeId.uuidString)
        == [
          "00000000-0000-4000-8000-000000000814", "00000000-0000-4000-8000-000000000815",
        ])
    #expect(
      current.backup.items.first?.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000814")
    var incoming = seed
    for name in incoming.keys where name != "format" && name != "formatVersion" {
      incoming[name] = []
    }
    var declaredMuseum = museum
    let declaredLifetime: String
    if declaresCurrentCandidate {
      declaredLifetime = "00000000-0000-4000-8000-000000000814"
      incoming["deletionMarkers"] = seed["deletionMarkers"]
      incoming["restorationFamilies"] = seed["restorationFamilies"]
    } else {
      declaredLifetime = "00000000-0000-4000-8000-000000000815"
    }
    declaredMuseum["lifetimeId"] = declaredLifetime
    var declaredContent = try #require(declaredMuseum["content"] as? [String: Any])
    declaredContent["title"] = "Ignored candidate title"
    declaredMuseum["content"] = declaredContent
    var list = try #require(fixtureSources.first { $0["kind"] as? String == "list" })
    list["id"] = "00000000-0000-4000-8000-000000000277"
    list["lifetimeId"] = "00000000-0000-4000-8000-000000000827"
    incoming["sources"] = [declaredMuseum, list]
    incoming["memberships"] = [
      [
        "id": "00000000-0000-4000-8000-000000000477",
        "lifetimeId": "00000000-0000-4000-8000-000000000477",
        "list": [
          "kind": "list", "id": "00000000-0000-4000-8000-000000000277",
          "lifetimeId": "00000000-0000-4000-8000-000000000827",
        ],
        "item": [
          "kind": "item", "id": "00000000-0000-4000-8000-000000000101",
          "lifetimeId": "00000000-0000-4000-8000-000000000815",
        ],
        "rank": "1024", "localDone": true,
      ]
    ]
    let decoded = planner.decodeImport(try JSONSerialization.data(withJSONObject: incoming))
    guard case .decoded(let backup) = decoded else {
      Issue.record("The internally declared candidate fixture must decode: \(decoded)")
      return
    }
    #expect(backup.externalBindings.isEmpty && backup.originPaths.isEmpty)
    #expect(backup.backup.restorationFamilies.isEmpty == !declaresCurrentCandidate)
    let outcome = await planner.prepareReview(
      session: session, command: .applyImport(backup: backup, mode: .skip))
    guard case .reviewed(let review) = outcome else {
      Issue.record("Skip must resolve an already-known open-family candidate: \(outcome)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.map(\.owner.id.uuidString) == ["00000000-0000-4000-8000-000000000277"])
    #expect(
      details.skippedConflicts.map(\.owner.id.uuidString) == [
        "00000000-0000-4000-8000-000000000101"
      ])
    #expect(
      details.skippedConflicts.first?.owner.lifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000814")
    #expect(
      details.skippedDependents.isEmpty && details.replacements.isEmpty
        && details.restorations.isEmpty)
    #expect(
      details.imports.first?.dependencies.first?.lifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000814")
    guard case .exported(let afterReview) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterReview == before)
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded(let saved) = planner.decodeImport(after)
    else {
      Issue.record("Apply the complete new List without replacing its current Item: \(response)")
      return
    }
    #expect(saved.backup.memberships.count == 1)
    #expect(
      saved.backup.memberships.first?.itemLifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000814")
    #expect(saved.backup.memberships.first?.localDone == true)
    var retainedGraph = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let savedSources = try #require(retainedGraph["sources"] as? [[String: Any]])
    retainedGraph["sources"] = savedSources.filter {
      $0["id"] as? String != "00000000-0000-4000-8000-000000000277"
    }
    retainedGraph["memberships"] = []
    let currentGraph = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    #expect(NSDictionary(dictionary: retainedGraph).isEqual(to: currentGraph))
    let listIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000277")!
    guard
      case .snapshot(let snapshot) = await planner.query(
        .init(
          session: session,
          request: .items(.init(scope: .list(listIdentifier), completion: .all, archive: .all)))),
      case .rows(let page) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 64)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(snapshot.matchingCount == 1 && snapshot.progress.first?.totalCount == 1)
    #expect(page.rows.map(\.title) == ["Nezu Museum"])
    #expect(page.rows.first?.effectiveDone == true)
    let recoveredGraph = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    let savedGraph = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    #expect(NSDictionary(dictionary: recoveredGraph).isEqual(to: savedGraph))
    #expect(
      backup.backup.items.first?.lifetimeId.uuidString == declaredLifetime)
    #expect(
      backup.backup.memberships.first?.itemLifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000815")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeatedReview) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: backup, mode: .skip)),
      case .applied(let repeated, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeatedReview.command,
          reviewToken: repeatedReview.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
    #expect(repeated.generated.isEmpty && repeatedData == after)
  }

  @Test(arguments: [PlannerImportMode.skip, .overwrite])
  func aNewListCanReferenceAnotherKnownCandidateOfTheOpenFamily(mode: PlannerImportMode)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    var seed = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    let fixtureSources = try #require(seed["sources"] as? [[String: Any]])
    var museum = try #require(fixtureSources.first { $0["kind"] as? String == "item" })
    museum["lifetimeId"] = "00000000-0000-4000-8000-000000000814"
    for name in seed.keys where name != "format" && name != "formatVersion" { seed[name] = [] }
    seed["sources"] = [museum]
    let predecessor: [String: Any] = [
      "kind": "item", "id": "00000000-0000-4000-8000-000000000101",
      "lifetimeId": "00000000-0000-4000-8000-000000000811",
    ]
    seed["deletionMarkers"] = [
      [
        "deletionId": "00000000-0000-4000-8000-000000000892",
        "operationId": "00000000-0000-4000-8000-000000000992",
        "target": ["kind": "source", "source": predecessor], "closedFamilyId": NSNull(),
      ]
    ]
    seed["restorationFamilies"] = [
      [
        "familyId": "00000000-0000-4000-8000-000000000890", "predecessor": predecessor,
        "candidates": [
          [
            "lifetimeId": "00000000-0000-4000-8000-000000000814",
            "operationId": "00000000-0000-4000-8000-000000000994",
          ],
          [
            "lifetimeId": "00000000-0000-4000-8000-000000000815",
            "operationId": "00000000-0000-4000-8000-000000000995",
          ],
        ],
      ]
    ]
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seedBackup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: seed)),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seedBackup)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(before)
    else { throw CancellationError() }
    #expect(
      current.backup.restorationFamilies.first?.candidates.map(\.lifetimeId.uuidString)
        == [
          "00000000-0000-4000-8000-000000000814", "00000000-0000-4000-8000-000000000815",
        ])
    #expect(
      current.backup.items.first?.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000814")
    var incoming = seed
    for name in incoming.keys where name != "format" && name != "formatVersion" {
      incoming[name] = []
    }
    var list = try #require(fixtureSources.first { $0["kind"] as? String == "list" })
    list["id"] = "00000000-0000-4000-8000-000000000277"
    list["lifetimeId"] = "00000000-0000-4000-8000-000000000827"
    incoming["sources"] = [list]
    incoming["memberships"] = [
      [
        "id": "00000000-0000-4000-8000-000000000477",
        "lifetimeId": "00000000-0000-4000-8000-000000000477",
        "list": [
          "kind": "list", "id": "00000000-0000-4000-8000-000000000277",
          "lifetimeId": "00000000-0000-4000-8000-000000000827",
        ],
        "item": [
          "kind": "item", "id": "00000000-0000-4000-8000-000000000101",
          "lifetimeId": "00000000-0000-4000-8000-000000000815",
        ],
        "rank": "1024", "localDone": false,
      ]
    ]
    guard
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming))
    else { throw CancellationError() }
    #expect(backup.externalBindings.count == 1)
    #expect(
      backup.externalBindings.first?.lifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000815")
    #expect(backup.backup.restorationFamilies.isEmpty)
    for invalidLifetime in [
      "00000000-0000-4000-8000-000000000811", "00000000-0000-4000-8000-000000000999",
    ] {
      var invalid = incoming
      var memberships = try #require(invalid["memberships"] as? [[String: Any]])
      var item = try #require(memberships[0]["item"] as? [String: Any])
      item["lifetimeId"] = invalidLifetime
      memberships[0]["item"] = item
      invalid["memberships"] = memberships
      guard
        case .decoded(let invalidBackup) = planner.decodeImport(
          try JSONSerialization.data(withJSONObject: invalid)),
        case .failed(let failure) = await planner.prepareReview(
          session: session, command: .applyImport(backup: invalidBackup, mode: mode)),
        case .exported(let unchangedData) = await planner.exportData(session: session)
      else {
        Issue.record("Predecessor and unrelated bindings cannot redirect to the live Item.")
        return
      }
      #expect(failure.code == "missingReference")
      #expect(failure.propertyPath == "/memberships/0/item/lifetimeId")
      #expect(unchangedData == before)
    }
    let outcome = await planner.prepareReview(
      session: session, command: .applyImport(backup: backup, mode: mode))
    guard case .reviewed(let review) = outcome else {
      Issue.record("The current open family authorizes the candidate reference: \(outcome)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.map(\.owner.id.uuidString) == ["00000000-0000-4000-8000-000000000277"])
    #expect(details.skippedConflicts.isEmpty && details.skippedDependents.isEmpty)
    #expect(details.replacements.isEmpty && details.restorations.isEmpty)
    #expect(
      details.imports.first?.dependencies.first?.lifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000814")
    guard case .exported(let afterReview) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterReview == before)
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded(let saved) = planner.decodeImport(after)
    else {
      Issue.record("Save the complete new List against its authorized candidate: \(response)")
      return
    }
    #expect(saved.backup.items.count == 1 && saved.backup.lists.count == 1)
    #expect(
      saved.backup.items.first?.lifetimeId.uuidString == "00000000-0000-4000-8000-000000000814")
    #expect(saved.backup.memberships.count == 1)
    #expect(
      saved.backup.memberships.first?.itemLifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000814")
    var protectedGraph = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let protectedSources = try #require(protectedGraph["sources"] as? [[String: Any]])
    protectedGraph["sources"] = protectedSources.filter { $0["kind"] as? String != "list" }
    protectedGraph["memberships"] = []
    let originalGraph = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    #expect(NSDictionary(dictionary: protectedGraph).isEqual(to: originalGraph))
    let listIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000277")!
    guard
      case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .items(.init(scope: .list(listIdentifier))))),
      case .rows(let page) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 64)),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(snapshot.matchingCount == 1)
    #expect(snapshot.progress.first?.totalCount == 1)
    #expect(page.rows.map(\.title) == ["Nezu Museum"])
    let recoveredGraph = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    let savedGraph = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    #expect(NSDictionary(dictionary: recoveredGraph).isEqual(to: savedGraph))
    #expect(
      result.importSummary?.imports.first?.dependencies.first?.lifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000814")
    #expect(
      backup.externalBindings.first?.lifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000815")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeatedReview) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: backup, mode: mode)),
      case .applied(let repeated, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeatedReview.command,
          reviewToken: repeatedReview.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
    #expect(repeated.generated.isEmpty && repeatedData == after)
    let itemIdentifier = UUID(uuidString: "00000000-0000-4000-8000-000000000101")!
    var late = incoming
    var lateList = list
    lateList["id"] = "00000000-0000-4000-8000-000000000278"
    lateList["lifetimeId"] = "00000000-0000-4000-8000-000000000828"
    let independentTag = try #require(fixtureSources.first { $0["kind"] as? String == "tag" })
    late["sources"] = [lateList, independentTag]
    var lateMemberships = try #require(late["memberships"] as? [[String: Any]])
    lateMemberships[0]["id"] = "00000000-0000-4000-8000-000000000478"
    lateMemberships[0]["lifetimeId"] = "00000000-0000-4000-8000-000000000478"
    lateMemberships[0]["list"] = [
      "kind": "list", "id": "00000000-0000-4000-8000-000000000278",
      "lifetimeId": "00000000-0000-4000-8000-000000000828",
    ]
    late["memberships"] = lateMemberships
    guard
      case .decoded(let lateBackup) = reopened.decodeImport(
        try JSONSerialization.data(withJSONObject: late)),
      case .reviewed(let staleReview) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: lateBackup, mode: mode)),
      case .reviewed(let deletion) = await reopened.prepareReview(
        session: reopenedSession,
        command: .deleteSource(source: .init(kind: .item, id: itemIdentifier))),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome,
      case .exported(let deletedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    let staleOperationIdentifier = UUID()
    guard
      case .rejected(let staleFailure) = await reopened.execute(
        .init(
          operationId: staleOperationIdentifier, session: reopenedSession,
          command: staleReview.command, reviewToken: staleReview.reviewToken)
      ).outcome,
      case .noReliableEvidence = await reopened.operationStatus(
        session: reopenedSession, operationId: staleOperationIdentifier),
      case .exported(let afterStale) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(staleFailure.code == "staleReview")
    #expect(afterStale == deletedData)
    let lateOutcome = await reopened.prepareReview(
      session: reopenedSession, command: .applyImport(backup: lateBackup, mode: mode))
    guard case .reviewed(let lateReview) = lateOutcome else {
      Issue.record("Skip the whole dependent owner after family Delete: \(lateOutcome)")
      return
    }
    let lateDetails = try #require(lateReview.impact.importDetails)
    #expect(
      lateDetails.imports.map(\.owner.id.uuidString) == ["00000000-0000-4000-8000-000000000601"])
    #expect(
      lateDetails.skippedDependents.map(\.owner.id.uuidString)
        == ["00000000-0000-4000-8000-000000000278"])
    #expect(lateDetails.restorations.isEmpty && lateDetails.replacements.isEmpty)
    guard
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: lateReview.command,
          reviewToken: lateReview.reviewToken)
      ).outcome,
      case .exported(let lateData) = await reopened.exportData(session: reopenedSession),
      case .decoded(let lateSaved) = reopened.decodeImport(lateData)
    else { throw CancellationError() }
    #expect(lateSaved.backup.items.isEmpty && lateSaved.backup.memberships.isEmpty)
    #expect(lateSaved.backup.lists.map(\.id) == [listIdentifier])
    var lateGraph = try #require(JSONSerialization.jsonObject(with: lateData) as? [String: Any])
    let lateSources = try #require(lateGraph["sources"] as? [[String: Any]])
    lateGraph["sources"] = lateSources.filter { $0["kind"] as? String != "tag" }
    let deletedGraph = try #require(
      JSONSerialization.jsonObject(with: deletedData) as? [String: Any])
    #expect(NSDictionary(dictionary: lateGraph).isEqual(to: deletedGraph))
  }

  @Test(arguments: KnownFamilyImportCase.allCases)
  func routeAndLabelBindingsResolveKnownFamiliesWithoutReplacingCurrentOwners(
    importCase: KnownFamilyImportCase
  ) async throws {
    let mode: PlannerImportMode
    if importCase == .externalOverwrite { mode = .overwrite } else { mode = .skip }
    let declaresSources = importCase == .declaredSkip
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let seed = try knownFamilyImportFixture()
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let seedBackup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: seed)),
      case .reviewed(let seedReview) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seedBackup)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: seedReview.command,
          reviewToken: seedReview.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var incoming = seed
    for name in incoming.keys where name != "format" && name != "formatVersion" {
      incoming[name] = []
    }
    let seedSources = try #require(seed["sources"] as? [[String: Any]])
    var newSources: [[String: Any]] = []
    for (kind, suffix) in [("item", 7001), ("itinerary", 7002), ("list", 7003)] {
      var source = try #require(seedSources.first { $0["kind"] as? String == kind })
      source["id"] = knownFamilyFixtureIdentifier(suffix)
      source["lifetimeId"] = knownFamilyFixtureIdentifier(suffix)
      newSources.append(source)
    }
    incoming["sources"] = newSources
    if declaresSources {
      let candidateLifetimes = Dictionary(
        uniqueKeysWithValues: [(101, 2101), (201, 2201), (301, 2301), (501, 2501), (601, 2601)]
          .map { (knownFamilyFixtureIdentifier($0.0), knownFamilyFixtureIdentifier($0.1)) })
      let declaredSources = seedSources.compactMap { source -> [String: Any]? in
        guard let identifier = source["id"] as? String,
          let lifetime = candidateLifetimes[identifier]
        else { return nil }
        var declared = source
        declared["lifetimeId"] = lifetime
        return declared
      }
      #expect(declaredSources.count == 5)
      incoming["sources"] = newSources + declaredSources
    }
    let newItem = knownFamilyFixtureBinding("item", 7001, 7001)
    let newItinerary = knownFamilyFixtureBinding("itinerary", 7002, 7002)
    let newList = knownFamilyFixtureBinding("list", 7003, 7003)
    let otherItem = knownFamilyFixtureBinding("item", 101, 2101)
    let otherList = knownFamilyFixtureBinding("list", 201, 2201)
    let otherItinerary = knownFamilyFixtureBinding("itinerary", 301, 2301)
    let otherCategory = knownFamilyFixtureBinding("category", 501, 2501)
    let otherTag = knownFamilyFixtureBinding("tag", 601, 2601)
    incoming["memberships"] = [
      [
        "id": knownFamilyFixtureIdentifier(7203),
        "lifetimeId": knownFamilyFixtureIdentifier(7203), "list": newList,
        "item": otherItem, "rank": "1024", "localDone": false,
      ]
    ]
    incoming["itineraryEntries"] = [
      [
        "id": knownFamilyFixtureIdentifier(7201),
        "lifetimeId": knownFamilyFixtureIdentifier(7201), "itinerary": newItinerary,
        "source": otherItem, "rank": "1024", "localDone": false,
      ],
      [
        "id": knownFamilyFixtureIdentifier(7202),
        "lifetimeId": knownFamilyFixtureIdentifier(7202), "itinerary": newItinerary,
        "source": otherList, "rank": "2048", "localDone": NSNull(),
      ],
    ]
    incoming["labelAssociations"] = [
      [
        "id": knownFamilyFixtureIdentifier(7301),
        "lifetimeId": knownFamilyFixtureIdentifier(7301), "owner": newItem,
        "label": otherCategory,
      ],
      [
        "id": knownFamilyFixtureIdentifier(7302),
        "lifetimeId": knownFamilyFixtureIdentifier(7302), "owner": newItem, "label": otherTag,
      ],
    ]
    let seedLinks = try #require(seed["ownedLinks"] as? [[String: Any]])
    incoming["ownedLinks"] = try seedLinks.map { link -> [String: Any] in
      var link = link
      let owner = try #require(link["owner"] as? [String: Any])
      if owner["kind"] as? String == "item" { link["owner"] = otherItem }
      if owner["kind"] as? String == "itinerary" { link["owner"] = otherItinerary }
      link["label"] = "Do not replace the omitted owner's link"
      return link
    }
    let seedSchedules = try #require(seed["schedules"] as? [[String: Any]])
    incoming["schedules"] = try seedSchedules.map { schedule -> [String: Any] in
      var schedule = schedule
      let source = try #require(schedule["source"] as? [String: Any])
      if source["kind"] as? String == "item" { schedule["source"] = otherItem }
      if source["kind"] as? String == "itinerary" { schedule["source"] = otherItinerary }
      return schedule
    }
    guard
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming))
    else { throw CancellationError() }
    if declaresSources {
      #expect(backup.externalBindings.isEmpty && backup.originPaths.isEmpty)
    } else {
      #expect(backup.externalBindings.count == 5)
    }
    let outcome = await planner.prepareReview(
      session: session, command: .applyImport(backup: backup, mode: mode))
    guard case .reviewed(let review) = outcome else {
      Issue.record(
        "Resolve route and label candidates without replacing current owners: \(outcome)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(
      Set(details.imports.map(\.owner.id.uuidString))
        == Set((7001...7003).map(knownFamilyFixtureIdentifier)))
    if declaresSources {
      #expect(
        Set(details.skippedConflicts.map(\.owner.id.uuidString))
          == Set([101, 201, 301, 501, 601].map(knownFamilyFixtureIdentifier)))
      #expect(details.skippedConflicts.allSatisfy { $0.reasonCode == "matchingRecordConflict" })
    } else {
      #expect(
        Set(details.skippedConflicts.map(\.owner.id.uuidString))
          == Set([101, 301].map(knownFamilyFixtureIdentifier)))
      #expect(details.skippedConflicts.allSatisfy { $0.reasonCode == "omittedOwner" })
    }
    #expect(details.replacements.isEmpty && details.restorations.isEmpty)
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded(let saved) = planner.decodeImport(after)
    else {
      Issue.record("Persist all authorized source dependencies: \(response)")
      return
    }
    let listMembership = try #require(
      saved.backup.memberships.first { $0.id.uuidString == knownFamilyFixtureIdentifier(7203) })
    #expect(listMembership.itemLifetimeId.uuidString == knownFamilyFixtureIdentifier(1101))
    let entries = saved.backup.itineraryEntries.filter {
      $0.itinerary.id.uuidString == knownFamilyFixtureIdentifier(7002)
    }
    #expect(
      Set(entries.map(\.sourceLifetimeId.uuidString))
        == Set([1101, 1201].map(knownFamilyFixtureIdentifier)))
    let labels = saved.backup.labelAssociations.filter {
      $0.owner.id.uuidString == knownFamilyFixtureIdentifier(7001)
    }
    #expect(
      Set(labels.map(\.labelLifetimeId.uuidString))
        == Set([1501, 1601].map(knownFamilyFixtureIdentifier)))
    var protectedGraph = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    for (group, identifiers) in [
      ("sources", [7001, 7002, 7003]), ("memberships", [7203]),
      ("itineraryEntries", [7201, 7202]), ("labelAssociations", [7301, 7302]),
    ] {
      let records = try #require(protectedGraph[group] as? [[String: Any]])
      let removed = Set(identifiers.map(knownFamilyFixtureIdentifier))
      protectedGraph[group] = records.filter { ($0["id"] as? String).map(removed.contains) != true }
    }
    let originalGraph = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    #expect(NSDictionary(dictionary: protectedGraph).isEqual(to: originalGraph))
    let itineraryIdentifier = UUID(uuidString: knownFamilyFixtureIdentifier(7002))!
    let itemIdentifier = UUID(uuidString: knownFamilyFixtureIdentifier(7001))!
    guard
      case .snapshot(let route) = await planner.query(
        .init(
          session: session,
          request: .items(
            .init(scope: .itinerary(itineraryIdentifier), completion: .all, archive: .all)))),
      case .rows(let page) = await planner.read(
        session: session, request: .rows(generation: route.generation, offset: 0, limit: 64)),
      case .source(.item(let item)) = await planner.read(
        session: session, request: .source(.init(kind: .item, id: itemIdentifier)))
    else { throw CancellationError() }
    #expect(route.matchingCount == 3 && page.rows.count == 3)
    #expect(item.content.categoryIds.map(\.uuidString) == [knownFamilyFixtureIdentifier(501)])
    #expect(item.content.tagIds.map(\.uuidString) == [knownFamilyFixtureIdentifier(601)])
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    let recoveredGraph = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    let savedGraph = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    #expect(NSDictionary(dictionary: recoveredGraph).isEqual(to: savedGraph))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeatedReview) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: backup, mode: mode)),
      case .applied(let repeated, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeatedReview.command,
          reviewToken: repeatedReview.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
    #expect(repeated.generated.isEmpty && repeatedData == after)
  }

  @Test(arguments: BindingCase.allCases)
  func declaredNewOwnerResolvesItsExternalItemOrRejectsTheWholeReview(bindingCase: BindingCase)
    async throws
  {
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Current museum")))
      ).outcome,
      let item = created.generated.first,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var object = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let currentItem = try #require((object["sources"] as? [[String: Any]])?.first)
    let itemId =
      bindingCase == .missing ? "00000000-0000-4000-8000-000000000199" : item.id.uuidString
    let itemLifetime =
      bindingCase == .wrongLifetime
      ? "00000000-0000-4000-8000-000000000999" : try #require(currentItem["lifetimeId"] as? String)
    object["sources"] = [
      [
        "kind": "list", "id": "00000000-0000-4000-8000-000000000277",
        "lifetimeId": "00000000-0000-4000-8000-000000000827",
        "createdAt": 10.25, "updatedAt": 20.125,
        "content": [
          "name": "New plan", "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
          "manualEstimate": NSNull(),
        ],
        "globalDone": NSNull(), "archived": false, "contentOrigins": ["name": "independent"],
      ]
    ]
    object["memberships"] = [
      [
        "id": "00000000-0000-4000-8000-000000000477",
        "lifetimeId": "00000000-0000-4000-8000-000000000477",
        "list": [
          "kind": "list", "id": "00000000-0000-4000-8000-000000000277",
          "lifetimeId": "00000000-0000-4000-8000-000000000827",
        ],
        "item": ["kind": "item", "id": itemId, "lifetimeId": itemLifetime],
        "rank": "1024", "localDone": false,
      ]
    ]
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else { throw CancellationError() }
    #expect(decoded.externalBindings.count == 1)
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: decoded))
    if bindingCase == .live {
      guard case .reviewed(let review) = response else {
        Issue.record("Use the current live external Item for a complete new List: \(response)")
        return
      }
      let details = try #require(review.impact.importDetails)
      #expect(details.imports.count == 1 && details.imports.first?.after?.title == "New plan")
      #expect(details.imports.first?.dependencies.first?.id == item.id)
      #expect(details.skippedConflicts.isEmpty && details.skippedDependents.isEmpty)
      #expect(
        details.unchanged.isEmpty && details.replacements.isEmpty && details.restorations.isEmpty)
      #expect(details.referenceChanges.count == 1 && details.referenceChanges.first?.change == .add)
    } else {
      guard case .failed(let failure) = response else {
        Issue.record("Reject every unresolved binding before issuing an import review.")
        return
      }
      #expect(failure.code == "missingReference")
      #expect(
        failure.propertyPath
          == (bindingCase == .missing ? "/memberships/0/item/id" : "/memberships/0/item/lifetimeId")
      )
    }
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
  }
}

private func knownFamilyFixtureIdentifier(_ suffix: Int) -> String {
  String(format: "00000000-0000-4000-8000-%012d", suffix)
}

private func knownFamilyFixtureBinding(_ kind: String, _ identifier: Int, _ lifetime: Int)
  -> [String: Any]
{
  [
    "kind": kind, "id": knownFamilyFixtureIdentifier(identifier),
    "lifetimeId": knownFamilyFixtureIdentifier(lifetime),
  ]
}

private func knownFamilyImportFixture() throws -> [String: Any] {
  let fixture = try #require(
    JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
  let sources = try #require(fixture["sources"] as? [[String: Any]])
  var replacements: [String: String] = [:]
  var markers = try #require(fixture["deletionMarkers"] as? [[String: Any]])
  var families: [[String: Any]] = []
  for (kind, identifier, winner, candidate) in [
    ("item", 101, 1101, 2101), ("list", 201, 1201, 2201),
    ("itinerary", 301, 1301, 2301), ("category", 501, 1501, 2501),
    ("tag", 601, 1601, 2601),
  ] {
    let source = try #require(
      sources.first { $0["id"] as? String == knownFamilyFixtureIdentifier(identifier) })
    let originalLifetime = try #require(source["lifetimeId"] as? String)
    let predecessor: [String: Any] = [
      "kind": kind, "id": knownFamilyFixtureIdentifier(identifier), "lifetimeId": originalLifetime,
    ]
    replacements[kind + ":" + knownFamilyFixtureIdentifier(identifier) + ":" + originalLifetime] =
      knownFamilyFixtureIdentifier(winner)
    markers.append([
      "deletionId": knownFamilyFixtureIdentifier(identifier + 7000),
      "operationId": knownFamilyFixtureIdentifier(identifier + 8000),
      "target": ["kind": "source", "source": predecessor], "closedFamilyId": NSNull(),
    ])
    families.append([
      "familyId": knownFamilyFixtureIdentifier(identifier + 4000), "predecessor": predecessor,
      "candidates": [
        [
          "lifetimeId": knownFamilyFixtureIdentifier(winner),
          "operationId": knownFamilyFixtureIdentifier(identifier + 5000),
        ],
        [
          "lifetimeId": knownFamilyFixtureIdentifier(candidate),
          "operationId": knownFamilyFixtureIdentifier(identifier + 6000),
        ],
      ],
    ])
  }
  var result = try #require(
    rebindingKnownFamilyFixture(fixture, replacements: replacements) as? [String: Any])
  result["deletionMarkers"] = markers
  result["restorationFamilies"] = families
  return result
}

private func rebindingKnownFamilyFixture(_ value: Any, replacements: [String: String]) -> Any {
  if let array = value as? [Any] {
    return array.map { rebindingKnownFamilyFixture($0, replacements: replacements) }
  }
  guard var object = value as? [String: Any] else { return value }
  if let kind = object["kind"] as? String, let identifier = object["id"] as? String,
    let lifetime = object["lifetimeId"] as? String,
    let replacement = replacements[kind + ":" + identifier + ":" + lifetime]
  {
    object["lifetimeId"] = replacement
  }
  return object.mapValues { rebindingKnownFamilyFixture($0, replacements: replacements) }
}
