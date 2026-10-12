import Foundation
import PlannerCore
import Testing

struct ManualContainerEstimateTests {
  @Test(arguments: [PlannerEntityKind.list, .itinerary])
  func manualEstimateClearReplayAndInvalidEditsPreserveUnrelatedContent(kind: PlannerEntityKind)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    let estimate = PlannerEstimate(minutes: 9_007_199_254_740_993, displayUnit: .year)
    let creationCommand: PlannerCommand
    if kind == .list {
      creationCommand = .createList(
        content: .init(name: "Plan", notes: "Keep", manualEstimate: estimate))
    } else {
      creationCommand = .createItinerary(
        content: .init(title: "Plan", notes: "Keep", manualEstimate: estimate))
    }
    let creationIdentifier = UUID()
    guard
      case .applied(let created, .complete(let originalCheckpoint)) = await planner.execute(
        .init(operationId: creationIdentifier, session: session, command: creationCommand)
      ).outcome,
      let source = created.generated.first
    else { throw CancellationError() }
    let clearCommand: PlannerCommand
    let invalidCommand: PlannerCommand
    let invalid = PlannerEstimate(minutes: 0, displayUnit: .hour)
    if kind == .list {
      guard
        case .source(.list(let read)) = await planner.read(
          session: session, request: .source(source))
      else { throw CancellationError() }
      clearCommand = .editList(
        sourceId: source.id, changes: .init(manualEstimate: .clear),
        expectedFieldHashes: read.fieldHashes)
      invalidCommand = .editList(
        sourceId: source.id,
        changes: .init(notes: .set("Must not apply"), manualEstimate: .set(invalid)),
        expectedFieldHashes: read.fieldHashes)
    } else {
      guard
        case .source(.itinerary(let read)) = await planner.read(
          session: session, request: .source(source))
      else { throw CancellationError() }
      clearCommand = .editItinerary(
        sourceId: source.id, changes: .init(manualEstimate: .clear),
        expectedFieldHashes: read.fieldHashes)
      invalidCommand = .editItinerary(
        sourceId: source.id,
        changes: .init(notes: .set("Must not apply"), manualEstimate: .set(invalid)),
        expectedFieldHashes: read.fieldHashes)
    }
    guard
      case .rejected(let reason) = await planner.execute(
        .init(operationId: UUID(), session: session, command: invalidCommand)
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: clearCommand)
      ).outcome
    else { throw CancellationError() }
    #expect(reason.code == "invalidInput")
    #expect(reason.propertyPath == "/command/changes/manualEstimate/minutes")
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await reopened.execute(
        .init(operationId: creationIdentifier, session: reopenedSession, command: creationCommand)
      ).outcome
    else { throw CancellationError() }
    #expect(replayed == created)
    #expect(replayCheckpoint == originalCheckpoint)
    switch await reopened.read(session: reopenedSession, request: .source(source)) {
    case .source(.list(let read)):
      #expect(read.content.manualEstimate == nil)
      #expect(read.content.notes == "Keep")
    case .source(.itinerary(let read)):
      #expect(read.content.manualEstimate == nil)
      #expect(read.content.notes == "Keep")
    default: Issue.record("The cleared container must remain readable after replay.")
    }
    guard
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let snapshot) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: originalCheckpoint))
    else { throw CancellationError() }
    if kind == .list {
      #expect(snapshot.decodedBackup.backup.lists.first?.content.manualEstimate == estimate)
    } else {
      let itineraries = snapshot.decodedBackup.backup.sources.compactMap {
        source -> PlannerPortableItinerary? in
        guard case .itinerary(let value) = source else { return nil }
        return value
      }
      #expect(itineraries.first?.content.manualEstimate == estimate)
    }
  }

  @Test func manualContainerFieldsPersistExactValuesAndGuardEditsAcrossReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let bootstrap = await planner.bootstrap()
    guard case .ready(let session) = bootstrap else {
      Issue.record("Manual estimates require a ready store: \(bootstrap)")
      return
    }
    let manualEstimate = PlannerEstimate(minutes: 240, displayUnit: .hour)
    let creation = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .createList(content: .init(name: "Morning", manualEstimate: manualEstimate)))
    )
    guard case .applied(let listCreation, .complete) = creation.outcome,
      let list = listCreation.generated.first
    else {
      Issue.record("Manual List creation must save with complete recovery: \(creation)")
      return
    }
    guard
      case .applied(let itineraryCreation, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItinerary(
            content: .init(title: "Route", manualEstimate: manualEstimate)))
      ).outcome,
      let itinerary = itineraryCreation.generated.first
    else { throw CancellationError() }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.list(let retainedList)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .source(.itinerary(let retainedItinerary)) = await reopened.read(
        session: reopenedSession, request: .source(itinerary))
    else { throw CancellationError() }
    #expect(retainedList.content.manualEstimate == manualEstimate)
    #expect(retainedItinerary.content.manualEstimate == manualEstimate)
    let revised = PlannerEstimate(minutes: 125, displayUnit: .hour)
    guard
      case .applied(_, .complete) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .editList(
            sourceId: list.id, changes: .init(manualEstimate: .set(revised)),
            expectedFieldHashes: retainedList.fieldHashes))
      ).outcome,
      case .source(.list(let edited)) = await reopened.read(
        session: reopenedSession, request: .source(list)),
      case .rejected(let stale) = await reopened.execute(
        .init(
          operationId: UUID(), session: reopenedSession,
          command: .editList(
            sourceId: list.id, changes: .init(manualEstimate: .clear),
            expectedFieldHashes: retainedList.fieldHashes))
      ).outcome
    else { throw CancellationError() }
    #expect(edited.content.manualEstimate == revised)
    #expect(stale.code == "staleEdit")
    #expect(edited.fieldHashes[.name] == retainedList.fieldHashes[.name])
    guard case .exported(let data) = await reopened.exportData(session: reopenedSession),
      case .decoded(let decoded) = reopened.decodeImport(data)
    else { throw CancellationError() }
    #expect(decoded.backup.lists.first?.content.manualEstimate == revised)
    let backedItineraries = decoded.backup.sources.compactMap {
      source -> PlannerPortableItinerary? in
      guard case .itinerary(let value) = source else { return nil }
      return value
    }
    #expect(backedItineraries.first?.content.manualEstimate == manualEstimate)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["formatVersion"] as? Int == 2)
    let sources = try #require(object["sources"] as? [[String: Any]])
    for (index, source) in sources.enumerated() {
      guard ["list", "itinerary"].contains(source["kind"] as? String ?? "") else { continue }
      for removeField in [true, false] {
        var invalidObject = object
        var invalidSources = sources
        var content = try #require(source["content"] as? [String: Any])
        let failurePath: String
        if removeField {
          content.removeValue(forKey: "manualEstimate")
          failurePath = "/sources/\(index)/content/manualEstimate"
        } else {
          content["manualEstimate"] = ["minutes": "0", "displayUnit": "hour"]
          failurePath = "/sources/\(index)/content/manualEstimate/minutes"
        }
        invalidSources[index]["content"] = content
        invalidObject["sources"] = invalidSources
        guard
          case .invalid(let failure) = reopened.decodeImport(
            try JSONSerialization.data(withJSONObject: invalidObject))
        else { throw CancellationError() }
        #expect(failure.code == "invalidInput")
        #expect(failure.propertyPath == failurePath)
      }
    }
  }
}
