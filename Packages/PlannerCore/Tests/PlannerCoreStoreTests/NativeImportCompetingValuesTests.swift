import Foundation
import PlannerCore
import Testing

struct NativeImportCompetingValuesTests {
  @Test(arguments: [(true, false), (true, true), (false, false), (false, true)], [1, 2])
  func overwriteAppliesCompetingValuesWithoutAdoptingItsFamily(
    incomingCase: (Bool, Bool), restorationCount: Int
  ) async throws {
    let (incomingSortsBeforeCurrent, sharesFamilyIdentifier) = incomingCase
    let directory = try makePlannerStoreFixtureDirectory()
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    func save(_ command: PlannerCommand, reviewToken: PlannerReviewToken? = nil) async throws
      -> PlannerAppliedResult
    {
      let response = await planner.execute(
        .init(operationId: UUID(), session: session, command: command, reviewToken: reviewToken))
      guard case .applied(let result, .complete) = response.outcome else {
        Issue.record("Save the actual restoration workflow: \(response)")
        throw CancellationError()
      }
      return result
    }
    let item = try #require(
      try await save(.createItem(content: .init(title: "Current museum", notes: "Current notes")))
        .generated.first)
    guard case .exported(let originalData) = await planner.exportData(session: session),
      case .decoded(let original) = planner.decodeImport(originalData)
    else { throw CancellationError() }
    for _ in 0..<restorationCount {
      guard
        case .reviewed(let deletion) = await planner.prepareReview(
          session: session, command: .deleteSource(source: item))
      else { throw CancellationError() }
      _ = try await save(deletion.command, reviewToken: deletion.reviewToken)
      guard
        case .reviewed(let restoration) = await planner.prepareReview(
          session: session,
          command: .applyImport(backup: original, mode: .overwrite, restoreDeletedData: true))
      else { throw CancellationError() }
      _ = try await save(restoration.command, reviewToken: restoration.reviewToken)
    }
    let keptList = try #require(
      try await save(.createList(content: .init(name: "Kept list"))).generated.first)
    _ = try await save(.addMembership(itemId: item.id, listId: keptList.id, placement: .last))
    guard case .exported(let organizedData) = await planner.exportData(session: session),
      case .decoded(let organized) = planner.decodeImport(organizedData),
      let membership = organized.backup.memberships.first
    else { throw CancellationError() }
    _ = try await save(
      .setCompletion(
        scope: .appearance(.listMembership(listId: keptList.id, membershipId: membership.id)),
        done: true))
    guard case .exported(let before) = await planner.exportData(session: session),
      case .decoded(let current) = planner.decodeImport(before),
      let currentItem = current.backup.items.first,
      let currentFamily = current.backup.restorationFamilies.first(where: { family in
        family.candidates.contains { $0.lifetimeId == currentItem.lifetimeId }
          && !current.backup.deletionMarkers.contains { $0.closedFamilyId == family.familyId }
      })
    else { throw CancellationError() }
    let currentObject = try #require(
      JSONSerialization.jsonObject(with: before) as? [String: Any])
    let currentSources = try #require(currentObject["sources"] as? [[String: Any]])
    var museum = try #require(currentSources.first { $0["kind"] as? String == "item" })
    let incomingLifetime: String
    if incomingSortsBeforeCurrent {
      incomingLifetime = competingValueIdentifier(813)
    } else {
      incomingLifetime = "FFFFFFFF-FFFF-4FFF-BFFF-FFFFFFFFF816"
    }
    var representedLifetime = incomingLifetime
    var familyIdentifier = competingValueIdentifier(893)
    var candidates = [
      ["lifetimeId": incomingLifetime, "operationId": competingValueIdentifier(996)]
    ]
    if sharesFamilyIdentifier {
      familyIdentifier = currentFamily.familyId.uuidString
      candidates += currentFamily.candidates.map {
        ["lifetimeId": $0.lifetimeId.uuidString, "operationId": $0.operationId.uuidString]
      }
      representedLifetime = min(incomingLifetime, currentItem.lifetimeId.uuidString)
    }
    museum["lifetimeId"] = representedLifetime
    var museumContent = try #require(museum["content"] as? [String: Any])
    museumContent["title"] = "Other museum"
    museumContent["notes"] = "Incoming notes"
    museum["content"] = museumContent
    var tour = try #require(currentSources.first { $0["kind"] as? String == "list" })
    tour["id"] = competingValueIdentifier(277)
    tour["lifetimeId"] = competingValueIdentifier(827)
    var tourContent = try #require(tour["content"] as? [String: Any])
    tourContent["name"] = "Tour"
    tour["content"] = tourContent
    let fixture = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    var tag = try #require(
      (fixture["sources"] as? [[String: Any]])?.first { $0["kind"] as? String == "tag" })
    tag["id"] = competingValueIdentifier(602)
    tag["lifetimeId"] = competingValueIdentifier(862)
    var tagContent = try #require(tag["content"] as? [String: Any])
    tagContent["name"] = "Independent Rainy day"
    tag["content"] = tagContent
    let incomingMembership: [String: Any] = [
      "id": competingValueIdentifier(477), "lifetimeId": competingValueIdentifier(477),
      "list": [
        "kind": "list", "id": competingValueIdentifier(277),
        "lifetimeId": competingValueIdentifier(827),
      ],
      "item": ["kind": "item", "id": item.id.uuidString, "lifetimeId": incomingLifetime],
      "rank": "1024", "localDone": true,
    ]
    let currentFamilies = try #require(currentObject["restorationFamilies"] as? [[String: Any]])
    let family = try #require(
      currentFamilies.first { $0["familyId"] as? String == currentFamily.familyId.uuidString })
    var incoming = currentObject
    for key in incoming.keys where key != "format" && key != "formatVersion" { incoming[key] = [] }
    incoming["sources"] = [museum, tour, tag]
    incoming["memberships"] = [incomingMembership]
    incoming["deletionMarkers"] = currentObject["deletionMarkers"]
    incoming["restorationFamilies"] =
      currentFamilies.filter {
        $0["familyId"] as? String != currentFamily.familyId.uuidString
      } + [
        [
          "familyId": familyIdentifier,
          "predecessor": try #require(family["predecessor"]),
          "candidates": candidates,
        ]
      ]
    let incomingData = try JSONSerialization.data(withJSONObject: incoming)
    guard case .decoded(let backup) = planner.decodeImport(incomingData) else {
      Issue.record("The competing candidate and its declared Tour must form a valid backup.")
      return
    }
    let outcome = await planner.prepareReview(
      session: session, command: .applyImport(backup: backup, mode: .overwrite))
    guard case .reviewed(let review) = outcome else {
      Issue.record(
        "Explicit Overwrite must project the competing values onto current B: \(outcome)")
      return
    }
    let details = try #require(review.impact.importDetails)
    let replacement = try #require(details.replacements.first)
    #expect(details.replacements.count == 1 && details.restorations.isEmpty)
    #expect(replacement.owner.id == item.id)
    #expect(replacement.before?.identity.lifetimeId == currentItem.lifetimeId)
    #expect(replacement.after?.identity.lifetimeId == currentItem.lifetimeId)
    #expect(replacement.before?.title == "Current museum")
    #expect(replacement.after?.title == "Other museum")
    #expect(
      Set(details.imports.map(\.owner.id.uuidString)) == [
        competingValueIdentifier(277), competingValueIdentifier(602),
      ])
    let tourReview = try #require(details.imports.first { $0.owner.kind == .list })
    #expect(tourReview.dependencies.map(\.lifetimeId) == [currentItem.lifetimeId])
    guard case .exported(let afterReview) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(afterReview == before)
    #expect(backup.backup.items.first?.lifetimeId.uuidString == representedLifetime)
    let operationIdentifier = UUID()
    let response = await planner.execute(
      .init(
        operationId: operationIdentifier, session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(let result, .complete(let checkpoint)) = response.outcome,
      case .exported(let after) = await planner.exportData(session: session),
      case .decoded(let applied) = planner.decodeImport(after),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovered) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("Apply the reviewed values and Tour without admitting D or G: \(response)")
      return
    }
    var expected = currentObject
    museum["lifetimeId"] = currentItem.lifetimeId.uuidString
    expected["sources"] =
      currentSources.map { source in
        source["kind"] as? String == "item" ? museum : source
      } + [tour, tag]
    var expectedMembership = incomingMembership
    expectedMembership["item"] = [
      "kind": "item", "id": item.id.uuidString, "lifetimeId": currentItem.lifetimeId.uuidString,
    ]
    expected["memberships"] =
      try #require(currentObject["memberships"] as? [[String: Any]]) + [expectedMembership]
    let expectedData = try JSONSerialization.data(withJSONObject: expected)
    #expect(try competingValueGraph(after) == competingValueGraph(expectedData))
    #expect(try competingValueGraph(recovered.portableData) == competingValueGraph(expectedData))
    #expect(applied.backup.restorationFamilies.count == restorationCount)
    #expect(
      Set(applied.backup.restorationFamilies.map(\.familyId))
        == Set(current.backup.restorationFamilies.map(\.familyId)))
    #expect(applied.backup.memberships.first { $0.id == membership.id }?.localDone == true)
    #expect(result.importSummary?.replacements.first?.owner.lifetimeId == currentItem.lifetimeId)
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
    #expect(repeated.impact.importDetails?.replacements.isEmpty == true)
  }
}

private func competingValueIdentifier(_ suffix: Int) -> String {
  String(format: "00000000-0000-4000-8000-%012d", suffix)
}

/// Top-level record collections are unordered; nested history sequences remain exact.
func competingValueGraph(_ data: Data) throws -> Data {
  var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  for (key, value) in object {
    guard let records = value as? [[String: Any]] else { continue }
    object[key] = try records.map { record in
      String(
        decoding: try JSONSerialization.data(withJSONObject: record, options: .sortedKeys),
        as: UTF8.self)
    }.sorted()
  }
  return try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
}
