import Foundation
import PlannerCore
import Testing

struct ItineraryCreationTests {
  @Test func itineraryCreationRetainsCompleteContentLiveLabelsAndRecoveryAcrossWriters()
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
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Initialize the real planner before creating an Itinerary.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard
        case .applied(let result, .complete) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome,
        let source = result.generated.first
      else {
        Issue.record("Create shared labels through the public durable writer.")
        throw CancellationError()
      }
      return source
    }
    let category = try await create(.createCategory(content: .init(name: "Food")))
    let tag = try await create(.createTag(content: .init(name: "Rain")))
    let location = PlannerOwnedLocation(
      displayName: "Meeting point", formattedAddress: "Tokyo, Japan",
      coordinate: PlannerCoordinate(latitude: 35, longitude: 139))
    let color = PlannerColor(red: 0.25, green: 0.5, blue: 1, alpha: 1)
    let content = PlannerItineraryContentInput(
      title: "  Tokyo café weekend  ", notes: "", color: color, iconName: "map",
      location: location,
      links: [PlannerLinkInput(originalUrl: "https://example.com/route?day=1", label: "Route")],
      categoryIds: [category.id], tagIds: [tag.id])
    let operation = PlannerOperation(
      operationId: UUID(), session: session, command: .createItinerary(content: content))
    guard
      case .applied(let created, .complete(let checkpoint)) = await planner.execute(operation)
        .outcome,
      let source = created.generated.first,
      case .source(.itinerary(let read)) = await planner.read(
        session: session, request: .source(source)),
      case .applied(let replayed, .complete(let replayCheckpoint)) = await planner.execute(
        operation
      ).outcome
    else {
      Issue.record("Create, read and replay the complete Itinerary at the public Core boundary.")
      return
    }
    #expect(source.kind == .itinerary)
    #expect(created.generated == [source])
    #expect(replayed.generatedIdentities == created.generatedIdentities)
    #expect(checkpoint == 3)
    #expect(replayCheckpoint == checkpoint)
    #expect(read.content.title == "  Tokyo café weekend  ")
    #expect(read.content.notes == "")
    #expect(read.content.color == color)
    #expect(read.content.iconName == "map")
    #expect(read.content.location == location)
    #expect(read.content.links.count == 1)
    #expect(read.content.links.first?.originalUrl == "https://example.com/route?day=1")
    #expect(read.content.links.first?.label == "Route")
    #expect(read.content.links.first?.kind == .website)
    #expect(read.content.categoryIds == [category.id])
    #expect(read.content.tagIds == [tag.id])
    #expect(Set(read.labels.map(\.name)) == ["Food", "Rain"])
    #expect(Set(read.fieldHashes.keys) == Set(PlannerItineraryField.allCases))
    #expect(read.state.globalDone == nil)
    #expect(read.state.archived == false)
    #expect(read.progress.state == .empty)
    #expect(read.progress.doneCount == 0)
    #expect(read.progress.totalCount == 0)
    let secondWriter = Planner(configuration: configuration)
    guard case .ready(let secondSession) = await secondWriter.bootstrap(),
      case .source(.category(let originalCategory)) = await secondWriter.read(
        session: secondSession, request: .source(category)),
      case .applied(_, .complete) = await secondWriter.execute(
        PlannerOperation(
          operationId: UUID(), session: secondSession,
          command: .editCategory(
            sourceId: category.id, changes: .init(name: .set("Dining")),
            expectedFieldHashes: [.name: try #require(originalCategory.fieldHashes[.name])]))
      ).outcome,
      case .applied = await secondWriter.execute(
        PlannerOperation(
          operationId: UUID(), session: secondSession,
          command: .createItem(content: .init(title: "Hotel", categoryIds: [category.id])))
      ).outcome
    else {
      Issue.record("Other durable writers must retain the Itinerary and its live labels.")
      return
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.itinerary(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(source)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(namespaceId: namespace.namespaceId, checkpointGeneration: 5))
    else {
      Issue.record("Reopening and independent recovery must retain the acknowledged Itinerary.")
      return
    }
    #expect(retained.content == read.content)
    #expect(Set(retained.labels.map(\.name)) == ["Dining", "Rain"])
    #expect(retained.references == read.references)
    #expect(retained.fieldHashes == read.fieldHashes)
    #expect(retained.createdAt == read.createdAt)
    #expect(retained.updatedAt == read.updatedAt)
    #expect(
      recovery.decodedBackup.backup.sources.filter { $0.kind == .itinerary }.map(\.id) == [
        source.id
      ])
    #expect(
      recovery.decodedBackup.backup.labelAssociations.filter { $0.owner == source }.count == 2)
    #expect(recovery.decodedBackup.backup.items.first?.content.categoryIds == [category.id])
    #expect(recovery.checkpointGeneration == 5)
    let payload = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    let sources = try #require(payload["sources"] as? [[String: Any]])
    let portable = try #require(sources.first { $0["kind"] as? String == "itinerary" })
    let portableContent = try #require(portable["content"] as? [String: Any])
    #expect(portableContent["title"] as? String == "  Tokyo café weekend  ")
    #expect(portableContent["notes"] as? String == "")
    #expect(portable["globalDone"] is NSNull)
    let links = try #require(payload["ownedLinks"] as? [[String: Any]])
    let ownedLink = try #require(
      links.first { ($0["owner"] as? [String: Any])?["kind"] as? String == "itinerary" })
    #expect(ownedLink["originalUrl"] as? String == "https://example.com/route?day=1")
    #expect(ownedLink["id"] as? String == read.content.links.first?.linkId.uuidString)
  }
}
