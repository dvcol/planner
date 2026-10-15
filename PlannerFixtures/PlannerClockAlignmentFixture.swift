import Foundation
import PlannerCore

@MainActor
enum PlannerClockAlignmentFixture {
  static func seed(_ planner: PlannerCore.Planner, session: PlannerDatasetSession) async throws {
    let schedules: [(title: String, start: String, end: String?, zone: String)] = [
      ("Midnight boundary", "2026-03-29T00:00:00Z", "2026-03-29T01:00:00Z", "America/Nuuk"),
      ("Spring boundary", "2026-03-08T06:00:00Z", "2026-03-08T07:00:00Z", "America/New_York"),
      ("Spring museum", "2026-03-08T06:00:00Z", "2026-03-08T08:00:00Z", "America/New_York"),
      ("Monday museum", "2026-03-09T05:00:00Z", "2026-03-09T08:00:00Z", "America/New_York"),
      ("Autumn museum", "2026-11-01T07:00:00Z", "2026-11-01T09:00:00Z", "America/New_York"),
      ("Monday autumn", "2026-11-02T07:00:00Z", "2026-11-02T09:00:00Z", "America/New_York"),
      ("Backward span", "2026-11-01T05:55:00Z", "2026-11-01T06:05:00Z", "America/New_York"),
      ("Island spring", "2026-10-03T14:30:00Z", "2026-10-03T16:00:00Z", "Australia/Lord_Howe"),
      ("Island Monday", "2026-10-04T14:00:00Z", "2026-10-04T16:00:00Z", "Australia/Lord_Howe"),
      ("Island first", "2026-04-04T14:45:00Z", nil, "Australia/Lord_Howe"),
      ("Island second", "2026-04-04T15:15:00Z", nil, "Australia/Lord_Howe"),
      ("Overnight museum", "2026-05-03T03:00:00Z", "2026-05-03T06:00:00Z", "America/New_York"),
    ]
    let formatter = ISO8601DateFormatter()
    for schedule in schedules {
      guard let start = formatter.date(from: schedule.start) else { throw CancellationError() }
      let end = schedule.end.flatMap { formatter.date(from: $0) }
      guard schedule.end == nil || end != nil,
        case .applied(let creation, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createItem(content: .init(title: schedule.title)))
        ).outcome,
        let source = creation.generated.first,
        case .applied(_, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createSchedule(
              source: source,
              form: .timed(start: start, end: end, planningTimeZone: schedule.zone)))
        ).outcome
      else { throw CancellationError() }
    }
  }
}
