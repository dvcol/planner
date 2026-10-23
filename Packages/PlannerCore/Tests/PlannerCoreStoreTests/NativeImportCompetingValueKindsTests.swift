import Foundation
import PlannerCore
import SwiftData
import Testing

struct NativeImportCompetingValueKindsTests {
  @Test(
    arguments: [101, 201, 301, 501, 601],
    [(813, false), (813, true), (816, false), (816, true), (815, false)])
  func overwriteRetainsEveryCurrentFamilyAndProjectsOnlyDeclaredBindings(
    sourceSuffix: Int, incomingCase: (Int, Bool)
  ) async throws {
    let (incomingLifetimeSuffix, sharesFamilyIdentifier) = incomingCase
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let fixture = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    let fixtureSources = try #require(fixture["sources"] as? [[String: Any]])
    let sourceIdentifier = candidateKindIdentifier(sourceSuffix)
    let original = try #require(fixtureSources.first { $0["id"] as? String == sourceIdentifier })
    let kind = try #require(original["kind"] as? String)
    let originalLifetime = try #require(original["lifetimeId"] as? String)
    let retainedLifetime = candidateKindIdentifier(814)
    let incomingLifetime = candidateKindIdentifier(incomingLifetimeSuffix)
    let usesKnownCandidate = incomingLifetimeSuffix == 815
    let predecessor: [String: Any] = [
      "kind": kind, "id": sourceIdentifier, "lifetimeId": originalLifetime,
    ]
    let retainedCandidate = [
      "lifetimeId": retainedLifetime, "operationId": candidateKindIdentifier(994),
    ]
    var currentCandidates = [retainedCandidate]
    if usesKnownCandidate {
      currentCandidates.append([
        "lifetimeId": incomingLifetime, "operationId": candidateKindIdentifier(996),
      ])
    }
    var current = try #require(
      candidateKindRebinding(
        fixture, kind: kind, identifier: sourceIdentifier,
        oldLifetime: originalLifetime, newLifetime: retainedLifetime) as? [String: Any])
    current["deletionMarkers"] = [
      [
        "deletionId": candidateKindIdentifier(892), "operationId": candidateKindIdentifier(992),
        "target": ["kind": "source", "source": predecessor], "closedFamilyId": NSNull(),
      ]
    ]
    current["restorationFamilies"] = [
      [
        "familyId": candidateKindIdentifier(890), "predecessor": predecessor,
        "candidates": currentCandidates,
      ]
    ]
    guard
      case .decoded(let seed) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: current)),
      case .reviewed(let initial) = await planner.prepareReview(
        session: session, command: .applyImport(backup: seed)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: initial.command,
          reviewToken: initial.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let currentObject = try #require(
      JSONSerialization.jsonObject(with: before) as? [String: Any])
    let currentSources = try #require(currentObject["sources"] as? [[String: Any]])
    var incoming = try #require(
      candidateKindRebinding(
        currentObject, kind: kind, identifier: sourceIdentifier,
        oldLifetime: retainedLifetime, newLifetime: incomingLifetime) as? [String: Any])
    var incomingSources = try #require(incoming["sources"] as? [[String: Any]])
    let sourceIndex = try #require(
      incomingSources.firstIndex { $0["id"] as? String == sourceIdentifier })
    var content = try #require(incomingSources[sourceIndex]["content"] as? [String: Any])
    content[content["name"] == nil ? "title" : "name"] = "Incoming \(kind)"
    incomingSources[sourceIndex]["content"] = content
    var candidates = [
      ["lifetimeId": incomingLifetime, "operationId": candidateKindIdentifier(996)]
    ]
    var familyIdentifier = candidateKindIdentifier(893)
    if sharesFamilyIdentifier {
      familyIdentifier = candidateKindIdentifier(890)
      candidates.append(retainedCandidate)
      incomingSources[sourceIndex]["lifetimeId"] = min(retainedLifetime, incomingLifetime)
    }
    incoming["restorationFamilies"] = [
      ["familyId": familyIdentifier, "predecessor": predecessor, "candidates": candidates]
    ]
    var tag = try #require(currentSources.first { $0["kind"] as? String == "tag" })
    tag["id"] = candidateKindIdentifier(602)
    tag["lifetimeId"] = candidateKindIdentifier(862)
    var tagContent = try #require(tag["content"] as? [String: Any])
    tagContent["name"] = "Independent Rainy day"
    tag["content"] = tagContent
    incomingSources.append(tag)
    var expected = currentObject
    var expectedSources = currentSources
    expectedSources[sourceIndex]["content"] = content
    expectedSources.append(tag)
    let incomingBinding: [String: Any] = [
      "kind": kind, "id": sourceIdentifier, "lifetimeId": incomingLifetime,
    ]
    let retainedBinding: [String: Any] = [
      "kind": kind, "id": sourceIdentifier, "lifetimeId": retainedLifetime,
    ]
    func appendReference(_ row: [String: Any], table: String, bindingField: String) throws {
      incoming[table] = try #require(incoming[table] as? [[String: Any]]) + [row]
      var expectedRow = row
      expectedRow[bindingField] = retainedBinding
      expected[table] = try #require(expected[table] as? [[String: Any]]) + [expectedRow]
    }
    if kind == "itinerary" {
      var link = try #require((currentObject["ownedLinks"] as? [[String: Any]])?.first)
      link["id"] = candidateKindIdentifier(779)
      link["lifetimeId"] = candidateKindIdentifier(879)
      link["owner"] = incomingBinding
      try appendReference(link, table: "ownedLinks", bindingField: "owner")
      var schedule = try #require((currentObject["schedules"] as? [[String: Any]])?.first)
      schedule["id"] = candidateKindIdentifier(703)
      schedule["lifetimeId"] = candidateKindIdentifier(873)
      schedule["source"] = incomingBinding
      try appendReference(schedule, table: "schedules", bindingField: "source")
    } else {
      let dependentKind: String
      let dependentSuffix: Int
      switch kind {
      case "item":
        dependentKind = "list"
        dependentSuffix = 277
      case "list":
        dependentKind = "itinerary"
        dependentSuffix = 377
      default:
        dependentKind = "item"
        dependentSuffix = 177
      }
      var dependent = try #require(currentSources.first { $0["kind"] as? String == dependentKind })
      dependent["id"] = candidateKindIdentifier(dependentSuffix)
      dependent["lifetimeId"] = candidateKindIdentifier(837)
      incomingSources.append(dependent)
      expectedSources.append(dependent)
      let dependentBinding: [String: Any] = [
        "kind": dependentKind, "id": candidateKindIdentifier(dependentSuffix),
        "lifetimeId": candidateKindIdentifier(837),
      ]
      switch kind {
      case "item":
        try appendReference(
          [
            "id": candidateKindIdentifier(477), "lifetimeId": candidateKindIdentifier(477),
            "list": dependentBinding, "item": incomingBinding, "rank": "1024", "localDone": true,
          ], table: "memberships", bindingField: "item")
      case "list":
        try appendReference(
          [
            "id": candidateKindIdentifier(478), "lifetimeId": candidateKindIdentifier(478),
            "itinerary": dependentBinding, "source": incomingBinding,
            "rank": "1024", "localDone": NSNull(),
          ], table: "itineraryEntries", bindingField: "source")
      default:
        try appendReference(
          [
            "id": candidateKindIdentifier(577), "lifetimeId": candidateKindIdentifier(577),
            "owner": dependentBinding, "label": incomingBinding,
          ], table: "labelAssociations", bindingField: "label")
      }
    }
    incoming["sources"] = incomingSources
    expected["sources"] = expectedSources
    func reject(_ object: [String: Any], code: String) async throws {
      guard
        case .decoded(let rejectedBackup) = planner.decodeImport(
          try JSONSerialization.data(withJSONObject: object)),
        case .failed(let failure) = await planner.prepareReview(
          session: session, command: .applyImport(backup: rejectedBackup, mode: .overwrite)),
        case .exported(let unchanged) = await planner.exportData(session: session)
      else {
        Issue.record("Reject a valid backup outside the authorized projection: \(kind), \(code)")
        throw CancellationError()
      }
      #expect(failure.code == code)
      #expect(unchanged == before)
    }
    var contradictory = incoming
    var contradictorySources = incomingSources
    contradictorySources[sourceIndex]["lifetimeId"] = min(retainedLifetime, incomingLifetime)
    contradictory["sources"] = contradictorySources
    var contradictoryCandidates = candidates.filter { $0["lifetimeId"] != retainedLifetime }
    contradictoryCandidates.append([
      "lifetimeId": retainedLifetime, "operationId": candidateKindIdentifier(999),
    ])
    contradictory["restorationFamilies"] = [
      [
        "familyId": familyIdentifier, "predecessor": predecessor,
        "candidates": contradictoryCandidates,
      ]
    ]
    try await reject(contradictory, code: "unavailable")
    if !usesKnownCandidate {
      var omitted = incoming
      omitted["sources"] = incomingSources.filter { $0["id"] as? String != sourceIdentifier }
      try await reject(omitted, code: "missingReference")
    }
    var closingCurrent = incoming
    var closingSources = incomingSources
    closingSources[sourceIndex]["lifetimeId"] = incomingLifetime
    closingCurrent["sources"] = closingSources
    closingCurrent["restorationFamilies"] = [
      [
        "familyId": candidateKindIdentifier(893), "predecessor": predecessor,
        "candidates": [
          ["lifetimeId": incomingLifetime, "operationId": candidateKindIdentifier(996)]
        ],
      ]
    ]
    closingCurrent["deletionMarkers"] =
      try #require(currentObject["deletionMarkers"] as? [[String: Any]]) + [
        [
          "deletionId": candidateKindIdentifier(895), "operationId": candidateKindIdentifier(997),
          "target": ["kind": "source", "source": retainedBinding], "closedFamilyId": NSNull(),
        ]
      ]
    try await reject(closingCurrent, code: "unavailable")
    guard
      case .decoded(let backup) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: incoming)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .overwrite))
    else { throw CancellationError() }
    #expect(review.impact.importDetails?.replacements.count == 1)
    #expect(review.impact.importDetails?.restorations.isEmpty == true)
    #expect(review.impact.importDetails?.skippedDependents.isEmpty == true)
    let operationIdentifier = UUID()
    guard
      case .listedNamespaces(let preparationNamespaces) = await planner.inspectRecovery(
        request: .namespaces), let preparationNamespace = preparationNamespaces.first
    else { throw CancellationError() }
    let namespaceURL = configuration.recoveryDirectoryURL.appendingPathComponent(
      preparationNamespace.namespaceId.uuidString)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: namespaceURL.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: namespaceURL.path)
    }
    guard
      case .rejected = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationIdentifier)
    else { throw CancellationError() }
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: namespaceURL.path)
    guard case .exported(let afterFailure) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterFailure == before)
    let obstruction = NativeSaveRecoveryObstruction(configuration: configuration)
    let observer = NotificationCenter.default.addObserver(
      forName: ModelContext.didSave, object: nil, queue: nil
    ) { notification in obstruction.observe(notification) }
    defer {
      NotificationCenter.default.removeObserver(observer)
      try? obstruction.restore()
    }
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .incomplete) = response.outcome else {
      Issue.record(
        "Retain the applied \(kind) projection when its recovery write fails: \(response)")
      return
    }
    #expect(obstruction.didObstruct && obstruction.failure == nil)
    try obstruction.restore()
    guard
      case .appliedRecoveryIncomplete(let pending, _) = await planner.operationStatus(
        session: session, operationId: operationIdentifier),
      case .applied(let repaired, .complete(let checkpoint)) = await planner.retryRecovery(
        session: session, operationId: operationIdentifier
      ).outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else { throw CancellationError() }
    #expect(pending == result && repaired == result)
    let expectedData = try JSONSerialization.data(withJSONObject: expected)
    #expect(try competingValueGraph(after) == competingValueGraph(expectedData))
    #expect(try competingValueGraph(recovered.portableData) == competingValueGraph(expectedData))
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeated) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: backup, mode: .overwrite)),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeated.command,
          reviewToken: repeated.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after && repeatedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
  }
}
