import Foundation
import PlannerCore
import Testing

struct MembershipAppearanceTests {
  @Test func listAppearanceDetailKeepsExactContextAndReadsLiveItemContent() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let itemCreated, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Hotel", notes: "Original",
              location: .init(displayName: "Hotel", formattedAddress: "Tokyo", coordinate: nil),
              links: [PlannerLinkInput(originalUrl: "https://example.com/hotel", label: "Website")])
          ))
      ).outcome,
      let item = itemCreated.generated.first
    else {
      Issue.record("The shared Item must save before appearance detail reads.")
      return
    }
    var appearances: [PlannerAppearance] = []
    for name in ["Tokyo", "Wishlist"] {
      guard
        case .applied(let listCreated, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createList(content: PlannerListContentInput(name: name)))
        ).outcome,
        let list = listCreated.generated.first,
        case .applied(let memberCreated, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .addMembership(itemId: item.id, listId: list.id, placement: .last))
        ).outcome,
        case .membership(let identifier, _, _)? = memberCreated.generatedReferences.first
      else {
        Issue.record("Two independent appearances must reference the same saved Item.")
        return
      }
      appearances.append(.listMembership(listId: list.id, membershipId: identifier))
    }
    guard
      case .source(.item(let source)) = await planner.read(session: session, request: .source(item)),
      case .appearance(let original) = await planner.read(
        session: session, request: .appearance(appearances[0]))
    else {
      Issue.record(
        "An exact List appearance must expose live content and independent completion observations."
      )
      return
    }
    #expect(original.appearance == appearances[0])
    #expect(original.source == item)
    #expect(original.content.title == "Hotel")
    #expect(original.content.notes == "Original")
    #expect(original.content.location == source.content.location)
    #expect(original.content.links == source.content.links)
    #expect(original.fieldHashes == source.fieldHashes)
    #expect(!original.globalDone)
    #expect(!original.localDone)
    #expect(!original.effectiveDone)
    #expect(!original.archived)
    guard
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session, command: .setArchive(source: item, archived: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .editItem(
            sourceId: item.id,
            changes: PlannerItemChanges(notes: .set("Booking updated")),
            expectedFieldHashes: source.fieldHashes))
      ).outcome,
      case .snapshot(let filtered) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery())))
    else {
      Issue.record(
        "Global state and shared content updates must remain independent of the appearance.")
      return
    }
    #expect(filtered.matchingCount == 0)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.item(let changedSource)) = await reopened.read(
        session: reopenedSession, request: .source(item))
    else {
      Issue.record("Live Item content must survive relaunch.")
      return
    }
    for appearance in appearances {
      guard
        case .appearance(let read) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else {
        Issue.record("Valid filtered-out appearance detail remains attached to its exact context.")
        return
      }
      #expect(read.appearance == appearance)
      #expect(read.source == item)
      #expect(read.content.notes == "Booking updated")
      #expect(read.content.links == source.content.links)
      #expect(read.fieldHashes == changedSource.fieldHashes)
      #expect(read.globalDone)
      #expect(!read.localDone)
      #expect(read.effectiveDone)
      #expect(read.archived)
    }
    guard
      case .applied(_, .complete(let checkpoint)) = await reopened.execute(
        PlannerOperation(
          operationId: UUID(), session: reopenedSession,
          command: .setCompletion(scope: .globalItem(itemId: item.id), done: false))
      ).outcome,
      case .listMembership(let firstList, let firstMembership) = appearances[0],
      case .listMembership(let secondList, _) = appearances[1]
    else {
      Issue.record("Global Reopen must retain exact independent memberships.")
      return
    }
    #expect(checkpoint == 9)
    for appearance in appearances {
      guard
        case .appearance(let read) = await reopened.read(
          session: reopenedSession, request: .appearance(appearance))
      else {
        Issue.record("Reopening the source cannot remove valid appearance detail.")
        return
      }
      #expect(!read.globalDone)
      #expect(!read.localDone)
      #expect(!read.effectiveDone)
      #expect(read.archived)
    }
    for invalid in [
      PlannerAppearance.listMembership(listId: secondList, membershipId: firstMembership),
      .listMembership(listId: firstList, membershipId: item.id),
      .listMembership(listId: firstList, membershipId: UUID()),
    ] {
      guard
        case .failed(let reason) = await reopened.read(
          session: reopenedSession, request: .appearance(invalid))
      else {
        Issue.record("Invalid appearances must fail rather than fall back to a global Item read.")
        return
      }
      #expect(reason.code == "missingReference")
    }
    guard
      case .listedNamespaces(let namespaces) = await reopened.inspectRecovery(request: .namespaces)
    else {
      Issue.record("Read failures cannot change independent recovery.")
      return
    }
    #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
    #expect(namespaces.first?.preparedProposals.isEmpty == true)
  }
}
