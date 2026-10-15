import Darwin
import Foundation
import PlannerCore

@main
struct CalendarRetentionProbe {
  @MainActor
  static func main() async throws {
    let directory = URL(fileURLWithPath: "/private/tmp/PlannerCalendarDistinctRuns")
      .appendingPathComponent(UUID().uuidString)
    let planner = makePlanner(directory: directory)
    let fixture = try Data(
      contentsOf: URL(fileURLWithPath: "/private/tmp/PlannerCalendarScale5000.json"))
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(fixture),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw probeFailure("Import the complete large native graph") }
    var measurements: [[String: Any]] = []
    var retained: [(generation: UUID, count: Int64)] = []
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let firstDay = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    var generations: Set<UUID> = []
    for iteration in 1...100 {
      mark("QUERY \(iteration) START")
      let end = calendar.date(byAdding: .day, value: 2999 + iteration, to: firstDay)!
      let components = calendar.dateComponents([.year, .month, .day], from: end)
      let endDay = PlannerCivilDate(
        year: components.year!, month: components.month!, day: components.day!)
      let expectedCount = 3000 + iteration
      let startingMemory = try residentMemory()
      let started = ContinuousClock.now
      guard
        case .snapshot(let snapshot) = await planner.query(
          .init(
            session: session,
            request: .calendar(
              .init(
                startDay: .init(year: 2026, month: 1, day: 1),
                endDay: endDay, displayTimeZone: "GMT"))))
      else { throw probeFailure("Read the distinct date window") }
      let queried = ContinuousClock.now
      let expected = (40000..<(40000 + expectedCount)).map { identifier($0) }
      guard snapshot.matchingCount == expectedCount,
        snapshot.rows == expected.map({ .source(.init(kind: .schedule, id: $0)) })
      else { throw probeFailure("Retain exactly the expected Schedule identities") }
      generations.insert(snapshot.generation)
      retained.append((snapshot.generation, snapshot.matchingCount))
      let finished = ContinuousClock.now
      measurements.append([
        "iteration": iteration, "querySeconds": seconds(started.duration(to: queried)),
        "iterationSeconds": seconds(started.duration(to: finished)),
        "residentBeforeBytes": startingMemory, "residentAfterBytes": try residentMemory(),
        "matchingCount": snapshot.matchingCount,
      ])
      mark("QUERY \(iteration) END")
    }
    for issued in retained {
      guard
        case .calendarRows(let page) = await planner.read(
          session: session,
          request: .calendarRows(generation: issued.generation, offset: 0, limit: 5)),
        page.matchingCount == issued.count,
        page.rows.map(\.schedule.id) == (40000..<40005).map(identifier),
        page.rows.map(\.title) == [
          "Travel stop 1", "Travel stop 2", "Travel stop 3", "Travel stop 4", "Travel stop 5",
        ]
      else { throw probeFailure("All previously issued distinct generations remain readable") }
    }
    guard case .exported(let after) = await planner.exportData(session: session), before == after
    else {
      throw probeFailure("Calendar reads must preserve the saved backup")
    }
    let result: [String: Any] = [
      "dataset": directory.path, "items": 5000, "lists": 200, "memberships": 5000,
      "schedules": 5000, "queryRepeats": 100, "uniqueGenerations": generations.count,
      "firstMatchingCount": retained.first!.count, "lastMatchingCount": retained.last!.count,
      "readableGenerations": retained.count,
      "savedDataUnchanged": true, "measurements": measurements,
    ]
    let data = try JSONSerialization.data(
      withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: "/private/tmp/PlannerCalendarDistinctBaseline.json"))
    print(String(decoding: data, as: UTF8.self))
  }

  private static func makePlanner(directory: URL) -> Planner {
    Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
  }

  private static func identifier(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!
  }

  private static func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
  }

  private static func mark(_ value: String) {
    FileHandle.standardError.write(Data("PLANNER_SCALE \(value)\n".utf8))
  }

  private static func residentMemory() throws -> UInt64 {
    var information = mach_task_basic_info()
    var count = mach_msg_type_number_t(
      MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    let status = withUnsafeMutablePointer(to: &information) { informationPointer in
      informationPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        integerPointer in
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), integerPointer, &count)
      }
    }
    guard status == KERN_SUCCESS else { throw probeFailure("Read this process's resident memory") }
    return information.resident_size
  }

  private static func probeFailure(_ description: String) -> NSError {
    NSError(
      domain: "PlannerCalendarRetentionProbe", code: 1,
      userInfo: [NSLocalizedDescriptionKey: description])
  }
}
