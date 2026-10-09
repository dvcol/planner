import Foundation
import PlannerCore
import Testing

struct ItemReferenceReadTests {
  @Test func sourceEnumeratesEveryOwnedBookmarkAndDirectScheduleAfterReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Keep",
              links: [
                PlannerLinkInput(originalUrl: "https://maps.apple.com/?q=Hotel", label: "Map"),
                PlannerLinkInput(originalUrl: "https://example.com/menu", label: "Menu"),
              ])))
      )
      .outcome,
      let item = created.generated.first,
      case .source(let original) = await planner.read(session: session, request: .source(item))
    else {
      Issue.record("The source must retain both original owned bookmarks.")
      return
    }
    let forms: [PlannerScheduleForm] = [
      .timed(
        start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
        planningTimeZone: "Asia/Tokyo"),
      .timed(
        start: Date(timeIntervalSinceReferenceDate: 813_214_800), end: nil,
        planningTimeZone: "Asia/Tokyo"),
    ]
    var schedules: [PlannerEntityReference] = []
    for form in forms {
      guard
        case .applied(let scheduled, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createSchedule(source: item, form: form))
        )
        .outcome,
        let assignment = scheduled.generated.first
      else {
        Issue.record("Both retained Schedule identities must be saved.")
        return
      }
      schedules.append(assignment)
    }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(let read) = await reopened.read(session: reopenedSession, request: .source(item))
    else {
      Issue.record("The source and every necessary association must remain readable after reopen.")
      return
    }
    #expect(schedules.count == 2)
    #expect(read.references.count == 4)
    let expectedLinks: [PlannerReferenceRead] = original.content.links.map {
      .ownedLink(id: $0.linkId, owner: item)
    }
    let expectedSchedules: [PlannerReferenceRead] = schedules.sorted {
      $0.id.uuidString < $1.id.uuidString
    }.map { .schedule(id: $0.id, source: item) }
    #expect(read.references == expectedLinks + expectedSchedules)
    #expect(read.content.links == original.content.links)
    #expect(read.content.notes == "Keep")
    #expect(read.fieldHashes == original.fieldHashes)
    #expect(read.updatedAt == original.updatedAt)
    let menu = try #require(original.content.links.first { $0.label == "Menu" })
    guard
      case .applied(_, .complete(let checkpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: UUID(), session: reopenedSession,
          command: .editItem(
            sourceId: item.id,
            changes: PlannerItemChanges(
              links: .set([
                PlannerLinkInput(
                  linkId: menu.linkId, originalUrl: menu.originalUrl, label: menu.label)
              ])), expectedFieldHashes: read.fieldHashes))
      ).outcome,
      case .source(let current) = await reopened.read(
        session: reopenedSession, request: .source(item)),
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await reopened.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 4))
    else {
      Issue.record(
        "Removing Map must remove only its metadata while retaining Menu and both appointments.")
      return
    }
    #expect(checkpoint == 4)
    #expect(current.references == [.ownedLink(id: menu.linkId, owner: item)] + expectedSchedules)
    #expect(current.content.links == [menu])
    #expect(current.content.notes == "Keep")
    #expect(recovery.decodedBackup.backup.sources.first?.content.links == [menu])
    #expect(recovery.decodedBackup.backup.schedules.count == 2)
  }
}
