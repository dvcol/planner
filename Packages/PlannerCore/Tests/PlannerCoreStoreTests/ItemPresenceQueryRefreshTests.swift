import Foundation
import PlannerCore
import Testing

struct ItemPresenceQueryRefreshTests {
  @Test func anotherWriterAddressAndLinkReplacementRefreshesPresenceWithoutChangingSourceIdentity()
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
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let creation, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: .init(
              title: "Hotel", notes: "Retain original notes",
              location: .init(displayName: "Hotel", formattedAddress: "Tokyo", coordinate: nil),
              links: [.init(originalUrl: "https://example.com/original")])))
      ).outcome,
      let item = creation.generated.first,
      case .source(.item(let original)) = await planner.read(
        session: session, request: .source(item)),
      case .snapshot(let issued) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(hasAddress: true, hasLinks: true))))
    else {
      Issue.record("Save and query the owned location and link through public Core.")
      return
    }
    #expect(issued.rows == [.source(item)])
    let otherWriter = Planner(configuration: configuration)
    guard case .ready(let otherSession) = await otherWriter.bootstrap(),
      case .applied(_, .complete) = await otherWriter.execute(
        PlannerOperation(
          operationId: UUID(), session: otherSession,
          command: .editItem(
            sourceId: item.id, changes: .init(location: .clear, links: .set([])),
            expectedFieldHashes: original.fieldHashes))
      ).outcome,
      case .failed(let stale) = await planner.read(
        session: session, request: .rows(generation: issued.generation, offset: 0, limit: 1)),
      case .snapshot(let withoutAddress) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(hasAddress: true)))),
      case .snapshot(let withoutLinks) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(hasLinks: true)))),
      case .snapshot(let unfiltered) = await planner.query(
        PlannerQuery(session: session, request: .items(.init()))),
      case .source(.item(let cleared)) = await otherWriter.read(
        session: otherSession, request: .source(item))
    else {
      Issue.record(
        "Another writer's clear must invalidate the old window and refresh both filters.")
      return
    }
    #expect(stale.code == "staleSnapshot")
    #expect(withoutAddress.rows.isEmpty)
    #expect(withoutLinks.rows.isEmpty)
    #expect(unfiltered.rows == [.source(item)])
    #expect(cleared.content.location == nil)
    #expect(cleared.content.links.isEmpty)
    guard
      case .applied(_, .complete) = await otherWriter.execute(
        PlannerOperation(
          operationId: UUID(), session: otherSession,
          command: .editItem(
            sourceId: item.id,
            changes: .init(
              location: .set(.init(displayName: nil, formattedAddress: "Paris", coordinate: nil)),
              links: .set([.init(originalUrl: "https://maps.apple.com/?q=Paris")])),
            expectedFieldHashes: cleared.fieldHashes))
      ).outcome,
      case .failed(let staleEmpty) = await planner.read(
        session: session, request: .rows(generation: withoutLinks.generation, offset: 0, limit: 1)),
      case .snapshot(let restored) = await planner.query(
        PlannerQuery(session: session, request: .items(.init(hasAddress: true, hasLinks: true)))),
      case .rows(let currentWindow) = await planner.read(
        session: session, request: .rows(generation: restored.generation, offset: 0, limit: 1))
    else {
      Issue.record("Replacing owned values restores the same source's cumulative presence match.")
      return
    }
    #expect(staleEmpty.code == "staleSnapshot")
    #expect(restored.rows == [.source(item)])
    #expect(currentWindow.rows.first?.ownedLocation?.formattedAddress == "Paris")
    #expect(currentWindow.rows.first?.hasLinks == true)
    #expect(currentWindow.rows.first?.previewLink == nil)
    #expect(currentWindow.rows.first?.sourceLifetimeId == original.sourceLifetimeId)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .snapshot(let reopenedQuery) = await reopened.query(
        PlannerQuery(
          session: reopenedSession, request: .items(.init(hasAddress: true, hasLinks: true)))),
      case .source(.item(let current)) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Reopen must preserve owned content and the new presence matches.")
      return
    }
    #expect(reopenedQuery.rows == [.source(item)])
    #expect(current.sourceLifetimeId == original.sourceLifetimeId)
    #expect(current.createdAt == original.createdAt)
    #expect(current.content.title == "Hotel")
    #expect(current.content.notes == "Retain original notes")
    #expect(current.content.location?.formattedAddress == "Paris")
    #expect(current.content.links.first?.originalUrl == "https://maps.apple.com/?q=Paris")
    #expect(current.content.links.first?.linkId != original.content.links.first?.linkId)
    #expect(current.fieldHashes[.title] == original.fieldHashes[.title])
    #expect(current.fieldHashes[.notes] == original.fieldHashes[.notes])
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == 3)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }
}
