import Foundation
import PlannerCore
import Testing

struct ItemLinkTests {
  @Test func invalidBookmarksAndChangedReplayLeaveItemsAndRecoveryUnchanged() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let content = PlannerItemContentInput(
      title: "Museum",
      links: [PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu")])
    let operationId = UUID()
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: operationId, session: session, command: .createItem(content: content))
      ).outcome,
      let item = created.generated.first,
      case .source(let original) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The original bookmarked Item must be saved.")
      return
    }
    let invalid: [PlannerLinkInput] = [
      PlannerLinkInput(originalUrl: "file:///private/tmp/menu"),
      PlannerLinkInput(originalUrl: "/menu"),
      PlannerLinkInput(originalUrl: "https://"),
      PlannerLinkInput(originalUrl: "https://example.com/%GG"),
      PlannerLinkInput(originalUrl: "https://example.com/bad path"),
      PlannerLinkInput(
        linkId: original.content.links.first?.linkId, originalUrl: "https://example.com/menu"),
    ]
    for link in invalid {
      let rejectedId = UUID()
      guard
        case .rejected(let reason) = await planner.execute(
          PlannerOperation(
            operationId: rejectedId, session: session,
            command: .createItem(
              content: PlannerItemContentInput(title: "Bad bookmark", links: [link])))
        ).outcome
      else {
        Issue.record("Malformed and foreign owned-link inputs must reject together.")
        return
      }
      #expect(reason.code == "invalidInput")
      #expect(
        reason.propertyPath
          == (link.linkId == nil
            ? "/command/content/links/0/originalUrl" : "/command/content/links/0/linkId"))
      guard
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: rejectedId)
      else {
        Issue.record("Validation rejection must not create an applied receipt.")
        return
      }
    }
    for replacement in [
      PlannerLinkInput(originalUrl: "https://example.com/different", label: "Menu"),
      PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Changed label"),
    ] {
      guard
        case .rejected(let reason) = await planner.execute(
          PlannerOperation(
            operationId: operationId, session: session,
            command: .createItem(
              content: PlannerItemContentInput(title: "Museum", links: [replacement])))
        ).outcome
      else {
        Issue.record("An operation identity must not accept different bookmark content.")
        return
      }
      #expect(reason.code == "operationPayloadMismatch")
    }
    guard
      case .source(let unchanged) = await planner.read(session: session, request: .source(item)),
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery()))),
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
    else {
      Issue.record("The original Item and checkpoint must remain readable after rejection.")
      return
    }
    #expect(unchanged.content.links.map(\.linkId) == original.content.links.map(\.linkId))
    #expect(unchanged.content.links.map(\.originalUrl) == ["https://example.com/menu"])
    #expect(unchanged.fieldHashes == original.fieldHashes)
    #expect(unchanged.updatedAt == original.updatedAt)
    #expect(snapshot.matchingCount == 1)
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 1)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }

  @Test func mapsOnlyRowsHaveNoWebsitePreviewAndProviderHostsUseExactBoundaries() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Map",
              links: [
                PlannerLinkInput(originalUrl: "https://maps.apple/p/test-link"),
                PlannerLinkInput(originalUrl: "https://maps.app.goo.gl/test-link"),
              ])))
      ).outcome,
      case .snapshot(let snapshot) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery()))),
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record("Maps-only owned links must save and remain useful without a website preview.")
      return
    }
    #expect(window.rows.first?.hasLinks == true)
    #expect(window.rows.first?.previewLink == nil)
    let item = try #require(created.generated.first)
    guard case .source(let maps) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("Map links must remain in full details.")
      return
    }
    #expect(maps.content.links.map(\.kind) == [.appleMaps, .googleMaps])
    let originalUrls = [
      "https://maps.apple.com.example.net/place?name=Picnic&coordinate=35,139",
      "https://www.google.com/maps.evil/",
      "https://maps.app.goo.gl.example.net/test",
      "https://tabelog.com/en/tokyo/test",
      "https://www.booking.com/hotel/test",
    ]
    guard
      case .applied(let websites, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Websites", links: originalUrls.map { PlannerLinkInput(originalUrl: $0) })))
      ).outcome, let websitesItem = websites.generated.first,
      case .source(let source) = await planner.read(
        session: session, request: .source(websitesItem))
    else {
      Issue.record("Other supported web bookmarks must retain their exact original strings.")
      return
    }
    #expect(source.content.links.map(\.originalUrl) == originalUrls)
    #expect(source.content.links.map(\.kind) == [.website, .website, .website, .tabelog, .booking])
    #expect(source.content.links.allSatisfy { $0.providerReference == nil })
    #expect(source.content.location == nil)
    #expect(source.content.title == "Websites")
  }

  @Test func completionArchiveAndNotesEditKeepOwnedLinksInEveryRecoveryCheckpoint() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Original notes",
              links: [PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu")])))
      ).outcome,
      let item = created.generated.first,
      case .source(let original) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The Item and its bookmark must be independently saved.")
      return
    }
    let linkId = try #require(original.content.links.first?.linkId)
    let notesHash = try #require(original.fieldHashes[.notes])
    let commands: [PlannerCommand] = [
      .setCompletion(scope: .globalItem(itemId: item.id), done: true),
      .setArchive(source: item, archived: true),
      .editItem(
        sourceId: item.id, changes: PlannerItemChanges(notes: .set("Monday booking")),
        expectedFieldHashes: [.notes: notesHash]),
    ]
    for (index, command) in commands.enumerated() {
      guard
        case .applied(_, .complete(let checkpoint)) = await planner.execute(
          PlannerOperation(operationId: UUID(), session: session, command: command)
        ).outcome,
        case .source(let source) = await planner.read(session: session, request: .source(item)),
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
        let namespace = namespaces.first,
        case .selected(let recovery) = await planner.inspectRecovery(
          request: .acknowledgedSnapshot(
            namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
      else {
        Issue.record("Each ordinary Item command must publish a complete recovery snapshot.")
        return
      }
      #expect(checkpoint == Int64(index + 2))
      #expect(source.content.links.map(\.linkId) == [linkId])
      #expect(source.fieldHashes[.links] == original.fieldHashes[.links])
      let recovered = try #require(recovery.decodedBackup.backup.sources.first)
      #expect(recovered.content.links.map(\.linkId) == [linkId])
      #expect(recovered.content.links.first?.originalUrl == "https://example.com/menu")
      #expect(recovered.globalDone)
      #expect(recovered.archived == (index > 0))
      #expect(recovered.content.notes == (index == 2 ? "Monday booking" : "Original notes"))
    }
  }

  @Test func savedLinksKeepIdentityOrderAndOneWebsitePreviewAfterReopenAndReplay() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let content = PlannerItemContentInput(
      title: "Museum", notes: "Bring umbrella",
      links: [
        PlannerLinkInput(originalUrl: "https://maps.apple.com/?q=Museum", label: "Apple Maps"),
        PlannerLinkInput(
          originalUrl: "https://www.google.com/maps/search/?api=1&query=Museum", label: "Map"),
        PlannerLinkInput(originalUrl: "http://example.com/menu?b=2&a=1#prices", label: "Menu"),
        PlannerLinkInput(originalUrl: "https://example.com/reservation", label: nil),
      ])
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("A real local dataset must initialize.")
      return
    }
    let operationId = UUID()
    guard
      case .applied(let created, .complete(let checkpoint)) = await planner.execute(
        PlannerOperation(
          operationId: operationId, session: session, command: .createItem(content: content))
      ).outcome
    else {
      Issue.record("An Item with owned bookmarks must save with independent recovery.")
      return
    }
    let item = try #require(created.generated.first)
    guard case .source(let source) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The saved source must return every owned link.")
      return
    }
    let linkIds = source.content.links.map(\.linkId)
    #expect(linkIds.count == 4)
    #expect(Set(linkIds).count == 4)
    #expect(source.content.links.map(\.originalUrl) == content.links.map(\.originalUrl))
    #expect(source.content.links.map(\.label) == ["Apple Maps", "Map", "Menu", nil])
    #expect(source.content.links.map(\.kind) == [.appleMaps, .googleMaps, .website, .website])
    #expect(source.content.links.allSatisfy { $0.providerReference == nil })
    #expect(source.content.notes == "Bring umbrella")
    #expect(source.content.location == nil)
    #expect(source.state.globalDone == false)
    #expect(source.state.archived == false)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(let reopenedSource) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .applied(let replayed, .complete(let replayedCheckpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: operationId, session: reopenedSession, command: .createItem(content: content)
        )
      ).outcome,
      case .snapshot(let snapshot) = await reopened.query(
        PlannerQuery(session: reopenedSession, request: .items(PlannerItemQuery()))),
      case .rows(let window) = await reopened.read(
        session: reopenedSession,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record("Reopened saved links and the original operation must remain readable.")
      return
    }
    #expect(replayed == created)
    #expect(replayedCheckpoint == checkpoint)
    #expect(snapshot.matchingCount == 1)
    #expect(reopenedSource.content.links.map(\.linkId) == linkIds)
    #expect(reopenedSource.fieldHashes == source.fieldHashes)
    #expect(reopenedSource.updatedAt == source.updatedAt)
    let row = try #require(window.rows.first)
    #expect(row.hasLinks)
    #expect(row.previewLink?.linkId == linkIds[2])
    #expect(row.previewLink?.originalUrl == "http://example.com/menu?b=2&a=1#prices")
    #expect(row.previewLink?.label == "Menu")
    guard
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: checkpoint))
    else {
      Issue.record("The independent recovery checkpoint must include owned links.")
      return
    }
    #expect(recovery.decodedBackup.backup.sources.count == 1)
    let recovered = try #require(recovery.decodedBackup.backup.sources.first)
    #expect(recovered.id == item.id)
    #expect(recovered.content.links.map(\.linkId) == linkIds)
    #expect(recovered.content.links.map(\.originalUrl) == content.links.map(\.originalUrl))
    #expect(recovered.content.notes == "Bring umbrella")
    let portable = try #require(
      JSONSerialization.jsonObject(with: recovery.portableData) as? [String: Any])
    let ownedLinks = try #require(portable["ownedLinks"] as? [[String: Any]])
    #expect(ownedLinks.count == 4)
    #expect(Set(ownedLinks.compactMap { $0["id"] as? String }) == Set(linkIds.map(\.uuidString)))
    let sources = try #require(portable["sources"] as? [[String: Any]])
    let portableContent = try #require(sources.first?["content"] as? [String: Any])
    #expect(portableContent["links"] == nil)
  }
}
