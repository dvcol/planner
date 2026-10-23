import Foundation
import PlannerCore
import SwiftData
import Testing

struct NativeImportUnknownCandidateKindsTests {
  @Test(arguments: [101, 201, 301, 501, 601], [813, 816])
  func skipRetainsEachCurrentSourceFamilyAndAllOmittedOwnedData(
    sourceSuffix: Int, incomingLifetimeSuffix: Int
  ) async throws {
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
    let sources = try #require(fixture["sources"] as? [[String: Any]])
    let originalSource = try #require(
      sources.first {
        $0["id"] as? String == candidateKindIdentifier(sourceSuffix)
      })
    let kind = try #require(originalSource["kind"] as? String)
    let oldLifetime = try #require(originalSource["lifetimeId"] as? String)
    var current = try #require(
      candidateKindRebinding(
        fixture, kind: kind, identifier: candidateKindIdentifier(sourceSuffix),
        oldLifetime: oldLifetime, newLifetime: candidateKindIdentifier(814)) as? [String: Any])
    let predecessor: [String: Any] = [
      "kind": kind, "id": candidateKindIdentifier(sourceSuffix), "lifetimeId": oldLifetime,
    ]
    current["deletionMarkers"] = [
      [
        "deletionId": candidateKindIdentifier(892), "operationId": candidateKindIdentifier(992),
        "target": ["kind": "source", "source": predecessor], "closedFamilyId": NSNull(),
      ]
    ]
    current["restorationFamilies"] = [
      [
        "familyId": candidateKindIdentifier(890), "predecessor": predecessor,
        "candidates": [
          [
            "lifetimeId": candidateKindIdentifier(814),
            "operationId": candidateKindIdentifier(994),
          ]
        ],
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
    var incoming = current
    for key in incoming.keys where key != "format" && key != "formatVersion" { incoming[key] = [] }
    incoming["deletionMarkers"] = current["deletionMarkers"]
    incoming["restorationFamilies"] = [
      [
        "familyId": candidateKindIdentifier(893), "predecessor": predecessor,
        "candidates": [
          [
            "lifetimeId": candidateKindIdentifier(incomingLifetimeSuffix),
            "operationId": candidateKindIdentifier(996),
          ]
        ],
      ]
    ]
    var represented = originalSource
    represented["lifetimeId"] = candidateKindIdentifier(incomingLifetimeSuffix)
    var content = try #require(represented["content"] as? [String: Any])
    content[content["name"] == nil ? "title" : "name"] = "Unknown incoming \(kind)"
    represented["content"] = content
    var independentTag = try #require(sources.first { $0["kind"] as? String == "tag" })
    independentTag["id"] = candidateKindIdentifier(602)
    independentTag["lifetimeId"] = candidateKindIdentifier(862)
    var tagContent = try #require(independentTag["content"] as? [String: Any])
    tagContent["name"] = "Independent Rainy day"
    independentTag["content"] = tagContent
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
    var dependent = try #require(sources.first { $0["kind"] as? String == dependentKind })
    dependent["id"] = candidateKindIdentifier(dependentSuffix)
    dependent["lifetimeId"] = candidateKindIdentifier(837)
    let dependentBinding: [String: Any] = [
      "kind": dependentKind, "id": candidateKindIdentifier(dependentSuffix),
      "lifetimeId": candidateKindIdentifier(837),
    ]
    let excludedBinding: [String: Any] = [
      "kind": kind, "id": candidateKindIdentifier(sourceSuffix),
      "lifetimeId": candidateKindIdentifier(incomingLifetimeSuffix),
    ]
    var incomingSources = [represented]
    if kind != "itinerary" { incomingSources.append(dependent) }
    incomingSources.append(independentTag)
    incoming["sources"] = incomingSources
    if kind == "item" {
      incoming["memberships"] = [
        [
          "id": candidateKindIdentifier(477), "lifetimeId": candidateKindIdentifier(477),
          "list": dependentBinding, "item": excludedBinding, "rank": "1024", "localDone": true,
        ]
      ]
    } else if kind == "list" {
      incoming["itineraryEntries"] = [
        [
          "id": candidateKindIdentifier(478), "lifetimeId": candidateKindIdentifier(478),
          "itinerary": dependentBinding, "source": excludedBinding,
          "rank": "1024", "localDone": NSNull(),
        ]
      ]
    } else if kind != "itinerary" {
      incoming["labelAssociations"] = [
        [
          "id": candidateKindIdentifier(577), "lifetimeId": candidateKindIdentifier(577),
          "owner": dependentBinding, "label": excludedBinding,
        ]
      ]
    }
    if kind != "item" {
      let ownedBinding = kind == "itinerary" ? excludedBinding : dependentBinding
      var link = try #require((fixture["ownedLinks"] as? [[String: Any]])?.first)
      link["id"] = candidateKindIdentifier(779)
      link["lifetimeId"] = candidateKindIdentifier(879)
      link["owner"] = ownedBinding
      incoming["ownedLinks"] = [link]
      var schedule = try #require((fixture["schedules"] as? [[String: Any]])?.first)
      schedule["id"] = candidateKindIdentifier(703)
      schedule["lifetimeId"] = candidateKindIdentifier(873)
      schedule["source"] = ownedBinding
      incoming["schedules"] = [schedule]
    }
    let incomingData = try JSONSerialization.data(withJSONObject: incoming)
    guard case .decoded(let backup) = planner.decodeImport(incomingData),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup, mode: .skip)),
      case .exported(let afterReview) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(afterReview == before)
    #expect(
      backup.backup.restorationFamilies.first?.candidates.map(\.lifetimeId.uuidString) == [
        candidateKindIdentifier(incomingLifetimeSuffix)
      ])
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.map(\.owner.id.uuidString) == [candidateKindIdentifier(602)])
    #expect(
      details.skippedConflicts.map(\.owner.lifetimeId.uuidString) == [candidateKindIdentifier(814)])
    #expect(details.replacements.isEmpty && details.restorations.isEmpty)
    #expect(details.referenceChanges.allSatisfy { $0.change == .retain })
    if kind == "itinerary" {
      #expect(details.skippedDependents.isEmpty)
    } else {
      let skipped = try #require(details.skippedDependents.first)
      #expect(details.skippedDependents.count == 1)
      #expect(skipped.owner.id.uuidString == candidateKindIdentifier(dependentSuffix))
      #expect(
        skipped.dependencies.map(\.lifetimeId.uuidString) == [
          candidateKindIdentifier(incomingLifetimeSuffix)
        ])
      let paths: [String]
      switch kind {
      case "item": paths = ["/sources/1", "/memberships/0"]
      case "list": paths = ["/sources/1", "/itineraryEntries/0", "/ownedLinks/0", "/schedules/0"]
      default: paths = ["/sources/1", "/labelAssociations/0", "/ownedLinks/0", "/schedules/0"]
      }
      #expect(skipped.propertyPaths == paths)
    }
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
    let preparationFailure = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .rejected = preparationFailure.outcome,
      case .noReliableEvidence = await planner.operationStatus(
        session: session, operationId: operationIdentifier)
    else {
      Issue.record(
        "Failed Skip preparation must leave independent data and family authority unapplied.")
      return
    }
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: namespaceURL.path)
    guard case .exported(let afterPreparationFailure) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(afterPreparationFailure == before)
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
      Issue.record("Keep saved Skip data and report incomplete recovery truthfully: \(response)")
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
      case .decoded = planner.decodeImport(after),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId,
          checkpointGeneration: checkpoint))
    else {
      Issue.record(
        "Keep the current \(kind) and its complete family/owned graph under Skip: \(response)")
      return
    }
    #expect(pending == result && repaired == result)
    var expected = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    var expectedSources = try #require(expected["sources"] as? [[String: Any]])
    expectedSources.append(independentTag)
    expectedSources.sort { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    expected["sources"] = expectedSources
    let actual = try #require(JSONSerialization.jsonObject(with: after) as? [String: Any])
    let recovery = try #require(
      JSONSerialization.jsonObject(with: recovered.portableData) as? [String: Any])
    #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
    #expect(NSDictionary(dictionary: recovery).isEqual(to: expected))
    #expect(
      result.importSummary?.imports.map(\.owner.id.uuidString) == [candidateKindIdentifier(602)])
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: operationIdentifier, session: reopenedSession, command: review.command)
      ).outcome,
      case .reviewed(let repeated) = await reopened.prepareReview(
        session: reopenedSession, command: .applyImport(backup: backup, mode: .skip)),
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession, command: repeated.command,
          reviewToken: repeated.reviewToken)
      ).outcome,
      case .exported(let repeatedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedData == after && repeatedData == after)
    #expect(replayed == result && replayCheckpoint == checkpoint)
    #expect(repeated.impact.importDetails?.imports.isEmpty == true)
  }
}

private func candidateKindIdentifier(_ suffix: Int) -> String {
  String(format: "00000000-0000-4000-8000-%012d", suffix)
}

private func candidateKindRebinding(
  _ value: Any, kind: String, identifier: String, oldLifetime: String, newLifetime: String
) -> Any {
  if let array = value as? [Any] {
    return array.map {
      candidateKindRebinding(
        $0, kind: kind, identifier: identifier,
        oldLifetime: oldLifetime, newLifetime: newLifetime)
    }
  }
  guard var object = value as? [String: Any] else { return value }
  if object["kind"] as? String == kind && object["id"] as? String == identifier
    && object["lifetimeId"] as? String == oldLifetime
  {
    object["lifetimeId"] = newLifetime
  }
  return object.mapValues {
    candidateKindRebinding(
      $0, kind: kind, identifier: identifier,
      oldLifetime: oldLifetime, newLifetime: newLifetime)
  }
}
