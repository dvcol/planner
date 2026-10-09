import Foundation
import PlannerCore
import Testing

struct ItemRowReadTests {
  @Test func windowsKeepTheirOwnContextAndClampLargeRangesWithoutLosingRows() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let hotelResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel")))
      ).outcome,
      case .applied(let museumResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Museum")))
      ).outcome
    else {
      Issue.record("The two generic fixture Items must be saved.")
      return
    }
    let hotel = try #require(hotelResult.generated.first)
    let museum = try #require(museumResult.generated.first)
    let tokyo = PlannerRowPresentationContext(
      referenceInstant: Date(timeIntervalSinceReferenceDate: 813_198_600),
      displayTimeZone: "Asia/Tokyo")
    let paris = PlannerRowPresentationContext(
      referenceInstant: Date(timeIntervalSinceReferenceDate: 813_202_200),
      displayTimeZone: "Europe/Paris")
    guard
      case .snapshot(let original) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery(rowPresentation: tokyo)))),
      case .snapshot(let other) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery(rowPresentation: paris)))),
      case .rows(let first) = await planner.read(
        session: session, request: .rows(generation: original.generation, offset: 0, limit: 1)),
      case .rows(let last) = await planner.read(
        session: session,
        request: .rows(generation: original.generation, offset: 1, limit: .max)),
      case .rows(let empty) = await planner.read(
        session: session,
        request: .rows(generation: original.generation, offset: .max, limit: .max)),
      case .rows(let separate) = await planner.read(
        session: session, request: .rows(generation: other.generation, offset: 0, limit: 2))
    else {
      Issue.record("Independent query contexts and valid extreme ranges must remain readable.")
      return
    }
    #expect(original.generation != other.generation)
    #expect(first.rowPresentation == tokyo)
    #expect(last.rowPresentation == tokyo)
    #expect(first.rows.map(\.identity) == [.source(hotel)])
    #expect(last.rows.map(\.identity) == [.source(museum)])
    #expect(last.matchingCount == 2)
    #expect(last.offset == 1)
    #expect(empty.rows.isEmpty)
    #expect(empty.offset == .max)
    #expect(empty.matchingCount == 2)
    #expect(empty.rowPresentation == tokyo)
    #expect(separate.rowPresentation == paris)
    #expect(separate.rows.map(\.identity) == [.source(hotel), .source(museum)])
    #expect(separate.rows.allSatisfy { !$0.hasLocation && $0.ownedLocation == nil })
    #expect(separate.rows.allSatisfy { !$0.hasLinks && $0.previewLink == nil })
    #expect(separate.rows.allSatisfy { $0.estimate == nil && $0.localDone == nil })
    for (offset, limit) in [(Int64(-1), Int64(1)), (0, 0), (0, -1)] {
      guard
        case .failed(let failure) = await planner.read(
          session: session,
          request: .rows(generation: original.generation, offset: offset, limit: limit))
      else {
        Issue.record("Invalid row ranges must fail rather than produce an empty success.")
        return
      }
      #expect(failure.code == "invalidInput")
    }
    guard case .ready(let otherSession) = await planner.bootstrap(),
      case .failed(let unauthorizedWindow) = await planner.read(
        session: otherSession,
        request: .rows(generation: original.generation, offset: 0, limit: 1))
    else {
      Issue.record("A snapshot must remain bound to the dataset session that requested it.")
      return
    }
    #expect(unauthorizedWindow.code == "staleSnapshot")
  }

  @Test func invalidPresentationContextRejectsWithoutChangingTheValidQuery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let original) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery())))
    else {
      Issue.record("The empty dataset must have a valid default query.")
      return
    }
    let contexts: [(PlannerRowPresentationContext, String)] = [
      (
        PlannerRowPresentationContext(
          referenceInstant: Date(timeIntervalSinceReferenceDate: .infinity),
          displayTimeZone: "Asia/Tokyo"),
        "/query/rowPresentation/referenceInstant"
      ),
      (
        PlannerRowPresentationContext(
          referenceInstant: Date(timeIntervalSinceReferenceDate: 813_198_600),
          displayTimeZone: "Planner/Invalid"),
        "/query/rowPresentation/displayTimeZone"
      ),
    ]
    for (presentation, expectedPath) in contexts {
      guard
        case .failed(let failure) = await planner.query(
          PlannerQuery(
            session: session, request: .items(PlannerItemQuery(rowPresentation: presentation))))
      else {
        Issue.record("Invalid row presentation values must be rejected.")
        return
      }
      #expect(failure.code == "invalidInput")
      #expect(failure.propertyPath == expectedPath)
    }
    guard
      case .rows(let window) = await planner.read(
        session: session, request: .rows(generation: original.generation, offset: 0, limit: 1))
    else {
      Issue.record("Rejected queries must leave the original snapshot available.")
      return
    }
    #expect(original.rowPresentation != nil)
    #expect(window.rowPresentation == original.rowPresentation)
    #expect(window.matchingCount == 0)
    #expect(window.rows.isEmpty)
  }

  @Test func anotherWriterInvalidatesTheOldWindowInsteadOfMixingCurrentRows() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let hotelResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel")))
      ).outcome,
      case .applied(let museumResult, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Museum")))
      ).outcome,
      case .snapshot(let original) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery())))
    else {
      Issue.record("Both saved Items must belong to the original query.")
      return
    }
    let hotel = try #require(hotelResult.generated.first)
    let museum = try #require(museumResult.generated.first)
    #expect(original.rows == [.source(hotel), .source(museum)])
    let otherWriter = Planner(configuration: configuration)
    guard case .ready(let otherSession) = await otherWriter.bootstrap(),
      case .applied(_, .complete) = await otherWriter.execute(
        PlannerOperation(
          operationId: UUID(), session: otherSession,
          command: .setArchive(source: hotel, archived: true))
      ).outcome,
      case .failed(let failure) = await planner.read(
        session: session, request: .rows(generation: original.generation, offset: 0, limit: 2))
    else {
      Issue.record("Another writer's archive must invalidate the original row generation.")
      return
    }
    #expect(failure.code == "staleSnapshot")
    #expect(
      failure.details
        == .staleSnapshot(
          requestedGeneration: original.generation, currentGeneration: nil))
    guard
      case .snapshot(let current) = await planner.query(
        PlannerQuery(session: session, request: .items(PlannerItemQuery()))),
      case .rows(let currentWindow) = await planner.read(
        session: session, request: .rows(generation: current.generation, offset: 0, limit: 2))
    else {
      Issue.record("A fresh query/window must discover only the surviving Active Item.")
      return
    }
    #expect(current.matchingCount == 1)
    #expect(current.rows == [.source(museum)])
    #expect(currentWindow.matchingCount == 1)
    #expect(currentWindow.rows.map(\.identity) == [.source(museum)])
    #expect(currentWindow.rows.map(\.title) == ["Museum"])
  }

  @Test func rowWindowReturnsOwnedMetadataInItsFixedQueryContextAfterReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly
    )
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let result, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(
            content: PlannerItemContentInput(
              title: "Nezu Museum", subtitle: "Museum", notes: "Original notes",
              location: PlannerOwnedLocation(
                displayName: "Meeting point", formattedAddress: "Meeting point A",
                coordinate: PlannerCoordinate(latitude: 35, longitude: 139)),
              estimate: PlannerEstimate(minutes: 120, displayUnit: .hour)
            ))
        )
      ).outcome
    else {
      Issue.record("The owned Item must be saved with independent recovery.")
      return
    }
    let item = try #require(result.generated.first)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap() else {
      Issue.record("The actual local store must reopen.")
      return
    }
    let presentation = PlannerRowPresentationContext(
      referenceInstant: Date(timeIntervalSinceReferenceDate: 813_198_600),
      displayTimeZone: "Asia/Tokyo")
    guard
      case .snapshot(let snapshot) = await reopened.query(
        PlannerQuery(
          session: reopenedSession,
          request: .items(PlannerItemQuery(rowPresentation: presentation)))),
      case .rows(let window) = await reopened.read(
        session: reopenedSession,
        request: .rows(generation: snapshot.generation, offset: 0, limit: 1))
    else {
      Issue.record("The public row reader must return a snapshot window after reopening.")
      return
    }
    #expect(snapshot.rowPresentation == presentation)
    #expect(window.rowPresentation == presentation)
    #expect(window.generation == snapshot.generation)
    #expect(window.offset == 0)
    #expect(window.matchingCount == 1)
    let row = try #require(window.rows.first)
    #expect(window.rows.count == 1)
    #expect(row.identity == .source(item))
    #expect(row.title == "Nezu Museum")
    #expect(row.subtitle == "Museum")
    #expect(row.ownedLocation?.displayName == "Meeting point")
    #expect(row.ownedLocation?.formattedAddress == "Meeting point A")
    #expect(row.ownedLocation?.coordinate == PlannerCoordinate(latitude: 35, longitude: 139))
    #expect(row.estimate == PlannerEstimate(minutes: 120, displayUnit: .hour))
    #expect(row.globalDone == false)
    #expect(row.localDone == nil)
    #expect(row.effectiveDone == false)
    #expect(row.archived == false)
    #expect(row.hasLocation)
    #expect(!row.hasLinks)
    #expect(row.previewLink == nil)
    #expect(row.scheduleSummary == .none)
  }
}
