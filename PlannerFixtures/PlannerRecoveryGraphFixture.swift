import Foundation
import PlannerCore

@MainActor
enum PlannerRecoveryGraphFixture {
  static func makeStore(directory: URL) async throws -> SavedPlannerStore {
    func configuration(_ name: String) -> PlannerStorageConfiguration {
      let datasetDirectory = directory.appendingPathComponent(name, isDirectory: true)
      return .init(
        storeURL: datasetDirectory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: datasetDirectory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly)
    }
    let currentConfiguration = configuration("current")
    let current = PlannerCore.Planner(configuration: currentConfiguration)
    guard case .ready = await current.bootstrap() else { throw CancellationError() }
    let retained = PlannerCore.Planner(configuration: configuration("retained"))
    guard case .ready(let session) = await retained.bootstrap(),
      case .exported(let data) = await retained.exportData(session: session),
      case .decoded(let decoded) = retained.decodeImport(data)
    else { throw CancellationError() }
    if decoded.backup.sources.isEmpty { try await seed(retained, session: session) }
    return SavedPlannerStore(configuration: currentConfiguration)
  }

  private static func seed(_ planner: PlannerCore.Planner, session: PlannerDatasetSession)
    async throws
  {
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      guard let reference = try await save(command).generated.first else {
        throw CancellationError()
      }
      return reference
    }
    let category = try await create(.createCategory(content: .init(name: "Recovery culture")))
    let tag = try await create(.createTag(content: .init(name: "Recovery rainy day")))
    let museum = try await create(
      .createItem(
        content: .init(
          title: "Recovery museum", notes: "Museum notes from retained data",
          location: .init(
            displayName: "Museum entrance", formattedAddress: "Retained museum address",
            coordinate: .init(latitude: 35.662, longitude: 139.717)),
          estimate: .init(minutes: 120, displayUnit: .hour),
          links: [.init(originalUrl: "https://maps.apple.com/?q=Tokyo", label: "Museum map")],
          categoryIds: [category.id], tagIds: [tag.id])))
    let lunch = try await create(
      .createItem(
        content: .init(
          title: "Recovery lunch", notes: "Archived lunch notes",
          estimate: .init(minutes: 60, displayUnit: .hour))))
    let list = try await create(
      .createList(
        content: .init(
          name: "Recovery food list", notes: "Retained list notes",
          manualEstimate: .init(minutes: 240, displayUnit: .hour))))
    guard
      case .membership(let membershipIdentifier, _, _)? = try await save(
        .addMembership(itemId: museum.id, listId: list.id, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    _ = try await save(.addMembership(itemId: lunch.id, listId: list.id, placement: .last))
    _ = try await save(
      .setCompletion(
        scope: .appearance(.listMembership(listId: list.id, membershipId: membershipIdentifier)),
        done: true))
    _ = try await save(.setArchive(source: lunch, archived: true))
    let itinerary = try await create(
      .createItinerary(
        content: .init(
          title: "Recovery weekend", notes: "Retained itinerary notes",
          categoryIds: [category.id], tagIds: [tag.id])))
    guard
      case .itineraryEntry(let firstEntryIdentifier, _, _)? = try await save(
        .addItineraryEntry(itineraryId: itinerary.id, source: museum, placement: .last)
      ).generatedReferences.first
    else { throw CancellationError() }
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
    _ = try await save(
      .addItineraryEntry(itineraryId: itinerary.id, source: museum, placement: .last))
    _ = try await save(
      .setCompletion(
        scope: .appearance(
          .directItineraryItem(itineraryId: itinerary.id, entryId: firstEntryIdentifier)),
        done: true))
    guard let start = ISO8601DateFormatter().date(from: "2026-10-09T01:00:00Z") else {
      throw CancellationError()
    }
    _ = try await save(
      .createSchedule(
        source: museum,
        form: .timed(start: start, end: nil, planningTimeZone: "Asia/Tokyo")))
    _ = try await save(
      .createSchedule(
        source: itinerary,
        form: .allDay(
          start: .init(year: 2026, month: 10, day: 9),
          end: .init(year: 2026, month: 10, day: 11))))
  }
}
