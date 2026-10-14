import Foundation
import PlannerCore
import Darwin

@main
struct CalendarWindowScaleProbe {
  @MainActor
  static func main() async throws {
    let directory = URL(fileURLWithPath: "/private/tmp/PlannerCalendarScaleRuns")
      .appendingPathComponent(UUID().uuidString)
    let planner = makePlanner(directory: directory)
    let fixture = try Data(contentsOf: URL(fileURLWithPath: "/private/tmp/PlannerCalendarScale5000.json"))
    guard case .ready(let session) = await planner.bootstrap(),
      case .decoded(let decoded) = planner.decodeImport(fixture),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: decoded)),
      case .applied(_, .complete) = await planner.execute(
        .init(operationId: UUID(), session: session, command: review.command,
              reviewToken: review.reviewToken)).outcome,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw probeFailure("Import the complete large native graph") }
    var measurements: [[String: Any]] = []
    for iteration in 1...3 {
      mark("QUERY \(iteration) START")
      let startingMemory = try residentMemory()
      let started = ContinuousClock.now
      guard case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .calendar(
          .init(startDay: .init(year: 2026, month: 1, day: 9),
                endDay: .init(year: 2026, month: 1, day: 11), displayTimeZone: "GMT"))))
      else { throw probeFailure("Read the small date window") }
      let queried = ContinuousClock.now
      let expected = [40008, 40009, 40010].map { identifier($0) }
      guard snapshot.matchingCount == 3,
        snapshot.rows == expected.map({ .source(.init(kind: .schedule, id: $0)) })
      else { throw probeFailure("Retain exactly the three requested Schedule identities") }
      var titles: [String] = []
      var identities: [UUID] = []
      for offset in 0..<3 {
        guard case .calendarRows(let page) = await planner.read(
          session: session, request: .calendarRows(
            generation: snapshot.generation, offset: Int64(offset), limit: 1)),
          page.matchingCount == 3, page.rows.count == 1
        else { throw probeFailure("Read each generation-bound page") }
        identities.append(contentsOf: page.rows.map(\.schedule.id))
        titles.append(contentsOf: page.rows.map(\.title))
      }
      guard identities == expected, titles == ["Travel stop 9", "Travel stop 10", "Travel stop 11"]
      else { throw probeFailure("Preserve live titles and complete ordered pages") }
      let finished = ContinuousClock.now
      measurements.append([
        "iteration": iteration, "querySeconds": seconds(started.duration(to: queried)),
        "queryAndThreePagesSeconds": seconds(started.duration(to: finished)),
        "residentBeforeBytes": startingMemory, "residentAfterBytes": try residentMemory(),
        "matchingCount": snapshot.matchingCount,
      ])
      mark("QUERY \(iteration) END")
    }
    guard case .exported(let after) = await planner.exportData(session: session), before == after else {
      throw probeFailure("Calendar reads must preserve the saved backup")
    }
    let result: [String: Any] = [
      "dataset": directory.path, "items": 5000, "lists": 200, "memberships": 5000,
      "schedules": 5000, "queryDays": 3, "matchingSchedules": 3,
      "savedDataUnchanged": true, "measurements": measurements,
    ]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: "/private/tmp/PlannerCalendarScaleBaseline.json"))
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
      informationPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), integerPointer, &count)
      }
    }
    guard status == KERN_SUCCESS else { throw probeFailure("Read this process's resident memory") }
    return information.resident_size
  }

  private static func probeFailure(_ description: String) -> NSError {
    NSError(domain: "PlannerCalendarWindowScaleProbe", code: 1,
            userInfo: [NSLocalizedDescriptionKey: description])
  }
}
