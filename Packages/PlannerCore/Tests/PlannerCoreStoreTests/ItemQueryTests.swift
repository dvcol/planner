import Foundation
import PlannerCore
import Testing

struct ItemQueryTests {
  @Test func defaultQueryReturnsEveryCreatedItemIdentityInTitleOrderAfterReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly
    )
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("The local dataset must initialize.")
      return
    }
    let museum = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(title: "Museum", notes: "Museum notes"))
      ))
    let hotel = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: session,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))
      ))
    guard case .applied(let museumResult, .complete) = museum.outcome,
      case .applied(let hotelResult, .complete) = hotel.outcome
    else {
      Issue.record("The two fixture Items must be saved independently.")
      return
    }
    let hotelIdentity = try #require(hotelResult.generated.first)
    let museumIdentity = try #require(museumResult.generated.first)
    let queried = await planner.query(
      PlannerQuery(session: session, request: .items(PlannerItemQuery())))
    guard case .snapshot(let snapshot) = queried else {
      Issue.record("The default query must discover the complete fixture: \(queried)")
      return
    }
    #expect(snapshot.session == session)
    #expect(snapshot.matchingCount == 2)
    #expect(snapshot.rows == [.source(hotelIdentity), .source(museumIdentity)])
    let reopenedPlanner = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopenedPlanner.bootstrap() else {
      Issue.record("The fixture must reopen.")
      return
    }
    let reopenedQuery = await reopenedPlanner.query(
      PlannerQuery(
        session: reopenedSession, request: .items(PlannerItemQuery())
      ))
    guard case .snapshot(let reopenedSnapshot) = reopenedQuery else {
      Issue.record("Query identities must survive reopening: \(reopenedQuery)")
      return
    }
    #expect(reopenedSnapshot.matchingCount == 2)
    #expect(reopenedSnapshot.rows == [.source(hotelIdentity), .source(museumIdentity)])
    for identity in [hotelIdentity, museumIdentity] {
      let read = await reopenedPlanner.read(session: reopenedSession, request: .source(identity))
      guard case .source(.item(let source)) = read else {
        Issue.record("Each discovered identity must remain readable: \(read)")
        return
      }
      #expect(source.source == identity)
      #expect(source.state.globalDone == false)
      #expect(source.state.archived == false)
    }
  }
}
