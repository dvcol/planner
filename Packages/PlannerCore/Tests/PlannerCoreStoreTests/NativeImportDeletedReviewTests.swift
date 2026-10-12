import Foundation
import PlannerCore
import Testing

struct NativeImportDeletedReviewTests {
  enum DeletedSourceCase: CaseIterable { case declared, external, externalWrongLifetime }
  @Test func deletedScheduleCannotReturnThroughANewOwnerInSkipMode() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Current owner")))
      ).outcome, let item = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createSchedule(
            source: item,
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400), end: nil,
              planningTimeZone: "Asia/Tokyo")))
      ).outcome, let schedule = scheduled.generated.first,
      case .exported(let oldBackup) = await planner.exportData(session: session),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: .removeSchedule(scheduleId: schedule.id))
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var object = try #require(JSONSerialization.jsonObject(with: oldBackup) as? [String: Any])
    var sources = try #require(object["sources"] as? [[String: Any]])
    var newItem = sources[0]
    newItem["id"] = "00000000-0000-4000-8000-000000000103"
    newItem["lifetimeId"] = "00000000-0000-4000-8000-000000000813"
    var content = try #require(newItem["content"] as? [String: Any])
    content["title"] = "Blocked owner"
    newItem["content"] = content
    sources.append(newItem)
    sources.append([
      "kind": "list", "id": "00000000-0000-4000-8000-000000000277",
      "lifetimeId": "00000000-0000-4000-8000-000000000827", "createdAt": 10.25, "updatedAt": 20.125,
      "content": [
        "name": "Independent List", "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
      ],
      "globalDone": NSNull(), "archived": false, "contentOrigins": ["name": "independent"],
    ])
    object["sources"] = sources
    var schedules = try #require(object["schedules"] as? [[String: Any]])
    schedules[0]["source"] = [
      "kind": "item", "id": "00000000-0000-4000-8000-000000000103",
      "lifetimeId": "00000000-0000-4000-8000-000000000813",
    ]
    object["schedules"] = schedules
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object)),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded))
    else { throw CancellationError() }
    let details = try #require(review.impact.importDetails)
    #expect(details.imports.count == 1 && details.imports.first?.after?.title == "Independent List")
    #expect(details.unchanged.count == 1 && details.unchanged.first?.owner.id == item.id)
    #expect(
      details.skippedDependents.count == 1
        && details.skippedDependents.first?.reasonCode == "deletedDependency")
    #expect(details.skippedDependents.first?.propertyPaths.contains("/schedules/0") == true)
    #expect(details.referenceChanges.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
  }

  @Test(arguments: DeletedSourceCase.allCases)
  func skipKeepsDeletedItemClosedAndSkipsEveryDependentOwnerWithoutShorteningThem(
    sourceCase: DeletedSourceCase
  )
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Deleted museum")))
      ).outcome,
      let item = created.generated.first,
      case .exported(let oldBackup) = await planner.exportData(session: session),
      case .reviewed(let deletion) = await planner.prepareReview(
        session: session, command: .deleteSource(source: item)),
      case .applied(_, .complete(let checkpoint)) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: deletion.command,
          reviewToken: deletion.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var object = try #require(JSONSerialization.jsonObject(with: oldBackup) as? [String: Any])
    var sources = try #require(object["sources"] as? [[String: Any]])
    let itemLifetime = try #require(sources[0]["lifetimeId"] as? String)
    let referencedLifetime =
      sourceCase == .externalWrongLifetime ? "00000000-0000-4000-8000-000000000999" : itemLifetime
    sources += [
      [
        "kind": "item", "id": "00000000-0000-4000-8000-000000000103",
        "lifetimeId": "00000000-0000-4000-8000-000000000813", "createdAt": 10.25,
        "updatedAt": 20.125,
        "content": [
          "title": "Independent adapter", "subtitle": NSNull(), "notes": NSNull(),
          "location": NSNull(), "estimate": NSNull(),
        ],
        "globalDone": false, "archived": false, "contentOrigins": ["title": "independent"],
      ],
      [
        "kind": "list", "id": "00000000-0000-4000-8000-000000000277",
        "lifetimeId": "00000000-0000-4000-8000-000000000827", "createdAt": 10.25,
        "updatedAt": 20.125,
        "content": [
          "name": "Dependent List", "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
        ],
        "globalDone": NSNull(), "archived": false, "contentOrigins": ["name": "independent"],
      ],
      [
        "kind": "itinerary", "id": "00000000-0000-4000-8000-000000000377",
        "lifetimeId": "00000000-0000-4000-8000-000000000837", "createdAt": 10.25,
        "updatedAt": 20.125,
        "content": [
          "title": "Dependent itinerary", "notes": NSNull(), "color": NSNull(),
          "iconName": NSNull(), "location": NSNull(),
        ],
        "globalDone": NSNull(), "archived": false, "contentOrigins": ["title": "independent"],
      ],
    ]
    if sourceCase != .declared { sources.removeFirst() }
    object["sources"] = sources
    let list: [String: Any] = [
      "kind": "list", "id": "00000000-0000-4000-8000-000000000277",
      "lifetimeId": "00000000-0000-4000-8000-000000000827",
    ]
    let independentItem: [String: Any] = [
      "kind": "item", "id": "00000000-0000-4000-8000-000000000103",
      "lifetimeId": "00000000-0000-4000-8000-000000000813",
    ]
    let itinerary: [String: Any] = [
      "kind": "itinerary", "id": "00000000-0000-4000-8000-000000000377",
      "lifetimeId": "00000000-0000-4000-8000-000000000837",
    ]
    object["memberships"] = [
      [
        "id": "00000000-0000-4000-8000-000000000477",
        "lifetimeId": "00000000-0000-4000-8000-000000000477",
        "list": list,
        "item": ["kind": "item", "id": item.id.uuidString, "lifetimeId": referencedLifetime],
        "rank": "1024", "localDone": false,
      ],
      [
        "id": "00000000-0000-4000-8000-000000000478",
        "lifetimeId": "00000000-0000-4000-8000-000000000478",
        "list": list, "item": independentItem, "rank": "2048", "localDone": false,
      ],
    ]
    object["itineraryEntries"] = [
      [
        "id": "00000000-0000-4000-8000-000000000457",
        "lifetimeId": "00000000-0000-4000-8000-000000000457",
        "itinerary": itinerary, "source": list, "rank": "1024", "localDone": NSNull(),
      ],
      [
        "id": "00000000-0000-4000-8000-000000000458",
        "lifetimeId": "00000000-0000-4000-8000-000000000458",
        "itinerary": itinerary, "source": independentItem, "rank": "2048", "localDone": false,
      ],
    ]
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else { throw CancellationError() }
    #expect(decoded.externalBindings.count == (sourceCase == .declared ? 0 : 1))
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: decoded))
    if sourceCase == .externalWrongLifetime {
      guard case .failed(let failure) = response,
        case .exported(let after) = await planner.exportData(session: session),
        case .status(let status) = await planner.read(session: session, request: .status),
        case .known(let afterCheckpoint, let incomplete, let blocked) = status.recovery
      else { throw CancellationError() }
      #expect(
        failure.code == "missingReference"
          && failure.propertyPath == "/memberships/0/item/lifetimeId")
      #expect(before == after && afterCheckpoint == checkpoint && incomplete.isEmpty && !blocked)
      return
    }
    guard case .reviewed(let review) = response else {
      Issue.record("Keep X deleted, skip complete B and C, and review independent Z: \(response)")
      return
    }
    let details = try #require(review.impact.importDetails)
    #expect(
      details.imports.count == 1 && details.imports.first?.after?.title == "Independent adapter")
    if sourceCase == .declared {
      #expect(
        details.skippedConflicts.count == 1 && details.skippedConflicts.first?.owner.id == item.id)
      #expect(details.skippedConflicts.first?.reasonCode == "deletedSource")
      #expect(
        details.skippedConflicts.first?.before == nil
          && details.skippedConflicts.first?.after == nil)
    } else {
      #expect(details.skippedConflicts.isEmpty)
    }
    #expect(Set(details.skippedDependents.map { $0.owner.kind }) == [.list, .itinerary])
    #expect(
      details.skippedDependents.allSatisfy {
        $0.reasonCode == "deletedDependency" && $0.before == nil && $0.after == nil
      })
    #expect(
      details.skippedDependents.first(where: { $0.owner.kind == .list })?.propertyPaths.contains(
        "/memberships/1") == true)
    #expect(
      details.skippedDependents.first(where: { $0.owner.kind == .itinerary })?.propertyPaths
        .contains("/itineraryEntries/1") == true)
    #expect(
      details.referenceChanges.isEmpty && details.replacements.isEmpty
        && details.restorations.isEmpty)
    #expect(
      details.unchanged.isEmpty && details.incomingDeletions.isEmpty && !review.globalFlagsChanged)
    guard case .exported(let after) = await planner.exportData(session: session),
      case .status(let status) = await planner.read(session: session, request: .status),
      case .known(let afterCheckpoint, let incomplete, let blocked) = status.recovery
    else { throw CancellationError() }
    #expect(before == after && afterCheckpoint == checkpoint && incomplete.isEmpty && !blocked)
  }
}
