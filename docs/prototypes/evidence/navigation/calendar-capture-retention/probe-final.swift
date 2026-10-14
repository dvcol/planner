import Foundation
import PlannerCore
import Darwin

@main
struct CalendarRetentionProbe {
  @MainActor
  static func main() async throws {
    let directory = URL(fileURLWithPath: "/private/tmp/PlannerCalendarRetentionRuns")
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
    var firstGeneration: UUID?
    var generations: Set<UUID> = []
    for iteration in 1...100 {
      mark("QUERY \(iteration) START")
      let startingMemory = try residentMemory()
      let started = ContinuousClock.now
      guard case .snapshot(let snapshot) = await planner.query(
        .init(session: session, request: .calendar(
          .init(startDay: .init(year: 2026, month: 1, day: 1),
                endDay: .init(year: 2039, month: 12, day: 31), displayTimeZone: "GMT"))))
      else { throw probeFailure("Read the small date window") }
      let queried = ContinuousClock.now
      let expected = (40000..<45000).map { identifier($0) }
      guard snapshot.matchingCount == 5000,
        snapshot.rows == expected.map({ .source(.init(kind: .schedule, id: $0)) })
      else { throw probeFailure("Retain exactly the three requested Schedule identities") }
      generations.insert(snapshot.generation)
      if firstGeneration == nil { firstGeneration = snapshot.generation }
      if iteration == 100 {
        for generation in [firstGeneration!, snapshot.generation] {
          guard case .calendarRows(let page) = await planner.read(
            session: session, request: .calendarRows(generation: generation, offset: 0, limit: 5)),
            page.matchingCount == 5000,
            page.rows.map(\.schedule.id) == Array(expected.prefix(5)),
            page.rows.map(\.title) == ["Travel stop 1", "Travel stop 2", "Travel stop 3", "Travel stop 4", "Travel stop 5"]
          else { throw probeFailure("Retain early and latest valid generation pages") }
        }
      }
      let finished = ContinuousClock.now
      measurements.append([
        "iteration": iteration, "querySeconds": seconds(started.duration(to: queried)),
        "iterationSeconds": seconds(started.duration(to: finished)),
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
      "schedules": 5000, "queryRepeats": 100, "uniqueGenerations": generations.count, "matchingSchedules": 5000,
      "savedDataUnchanged": true, "measurements": measurements,
    ]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: "/private/tmp/PlannerCalendarRetentionBaseline.json"))
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
    NSError(domain: "PlannerCalendarRetentionProbe", code: 1,
            userInfo: [NSLocalizedDescriptionKey: description])
  }
}
