import Foundation
import PlannerCore

@MainActor
enum PlannerLargeCollectionFixture {
  static func makeStore(directory: URL) async throws -> SavedPlannerStore {
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .snapshot(let initialItems) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all)))),
      case .snapshot(let initialLists) = await planner.query(
        .init(session: session, request: .catalog(.init(sourceKind: .list, archive: .all))))
    else { throw CancellationError() }
    if initialItems.matchingCount == 0 && initialLists.matchingCount == 0 {
      try await seed(planner, session: session)
    }
    guard
      case .snapshot(let savedItems) = await planner.query(
        .init(session: session, request: .items(.init(completion: .all, archive: .all)))),
      savedItems.matchingCount == 5000,
      case .snapshot(let savedLists) = await planner.query(
        .init(session: session, request: .catalog(.init(sourceKind: .list, archive: .all)))),
      savedLists.matchingCount == 200,
      case .exported(let savedData) = await planner.exportData(session: session),
      case .decoded(let savedBackup) = planner.decodeImport(savedData)
    else { throw CancellationError() }
    let memberships = savedBackup.backup.memberships
    let membershipsByList = Dictionary(grouping: memberships, by: \.list.id)
    guard savedBackup.externalBindings.isEmpty,
      savedBackup.backup.items.count == 5000, savedBackup.backup.lists.count == 200,
      memberships.count == 5000, memberships.allSatisfy({ !$0.localDone }),
      Set(memberships.map(\.item.id)) == Set(savedBackup.backup.items.map(\.id)),
      Set(membershipsByList.keys) == Set(savedBackup.backup.lists.map(\.id)),
      membershipsByList.values.allSatisfy({ $0.count == 25 })
    else { throw CancellationError() }
    return SavedPlannerStore(configuration: configuration)
  }

  private static func seed(_ planner: PlannerCore.Planner, session: PlannerDatasetSession)
    async throws
  {
    let data = try makePortableData()
    let decoded: PlannerDecodedBackup
    switch planner.decodeImport(data) {
    case .decoded(let backup): decoded = backup
    case .invalid(let failure): throw failure
    }
    let review: PlannerReview
    switch await planner.prepareReview(session: session, command: .applyImport(backup: decoded)) {
    case .reviewed(let prepared): review = prepared
    case .failed(let failure): throw failure
    }
    let result = await planner.execute(
      .init(
        operationId: UUID(), session: session, command: review.command,
        reviewToken: review.reviewToken))
    guard case .applied(_, .complete) = result.outcome else { throw CancellationError() }
  }

  private static func makePortableData() throws -> Data {
    var sources: [[String: Any]] = []
    var memberships: [[String: Any]] = []
    let lists = (1...200).map { index in
      (index: index, identifier: UUID().uuidString, lifetimeIdentifier: UUID().uuidString)
    }
    for list in lists {
      sources.append([
        "kind": "list", "id": list.identifier, "lifetimeId": list.lifetimeIdentifier,
        "createdAt": 813_000_000 + list.index, "updatedAt": 813_000_000 + list.index,
        "content": [
          "name": String(format: "Scale List %03d", list.index),
          "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
          "manualEstimate": NSNull(),
        ],
        "globalDone": NSNull(), "archived": false, "contentOrigins": ["name": "independent"],
      ])
    }
    for index in 1...5000 {
      let itemIdentifier = UUID().uuidString
      let itemLifetimeIdentifier = UUID().uuidString
      let list = lists[(index - 1) % lists.count]
      let membershipIdentifier = UUID().uuidString
      let minutes = index == 5000 ? 91 : index % 120 + 1
      let notes = index == 5000 ? "Far-end collection marker" : "Scale notes \(index)"
      /// Make Created sorting distinguishable from Title sorting near the end of the catalog.
      let creationOffset = index == 4999 ? 4997 : index
      sources.append([
        "kind": "item", "id": itemIdentifier, "lifetimeId": itemLifetimeIdentifier,
        "createdAt": 813_000_000 + creationOffset, "updatedAt": 813_000_000 + index,
        "content": [
          "title": String(format: "Scale Item %05d", index), "subtitle": NSNull(),
          "notes": notes, "location": NSNull(),
          "estimate": ["minutes": String(minutes), "displayUnit": "minute"],
        ],
        "globalDone": false, "archived": false,
        "contentOrigins": ["title": "independent", "notes": "independent"],
      ])
      memberships.append([
        "id": membershipIdentifier, "lifetimeId": UUID().uuidString,
        "list": ["kind": "list", "id": list.identifier, "lifetimeId": list.lifetimeIdentifier],
        "item": ["kind": "item", "id": itemIdentifier, "lifetimeId": itemLifetimeIdentifier],
        "rank": String(((index - 1) / lists.count + 1) * 1024), "localDone": false,
      ])
    }
    return try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 2, "sources": sources,
      "memberships": memberships, "itineraryEntries": [], "schedules": [],
      "labelAssociations": [], "ownedLinks": [], "completionChanges": [],
      "expandedCompletions": [], "contextAliases": [], "restorationFamilies": [],
      "deletionMarkers": [],
    ])
  }
}
