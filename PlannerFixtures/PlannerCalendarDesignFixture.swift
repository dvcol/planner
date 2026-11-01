import Foundation
import PlannerCore

@MainActor
enum PlannerCalendarDesignFixture {
  /// One real import prepares the visual fixture without dozens of durable user-command receipts.
  static func seed(_ planner: PlannerCore.Planner, session: PlannerDatasetSession) async throws {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    var sources: [[String: Any]] = []
    var schedules: [[String: Any]] = []
    func source(title: String, kind: String = "item") -> [String: Any] {
      let reference: [String: Any] = [
        "kind": kind, "id": UUID().uuidString, "lifetimeId": UUID().uuidString,
      ]
      var record = reference
      record["createdAt"] = today.timeIntervalSinceReferenceDate
      record["updatedAt"] = today.timeIntervalSinceReferenceDate
      record["archived"] = false
      record["globalDone"] = kind == "item" ? false as Any : NSNull()
      record["contentOrigins"] = ["title": "independent"]
      if kind == "item" {
        record["content"] = [
          "title": title, "subtitle": NSNull(), "notes": NSNull(),
          "location": NSNull(), "estimate": NSNull(),
        ]
      } else {
        record["content"] = [
          "title": title, "notes": NSNull(), "color": NSNull(),
          "iconName": NSNull(), "location": NSNull(), "manualEstimate": NSNull(),
        ]
      }
      sources.append(record)
      return reference
    }
    func schedule(source: [String: Any], form: PlannerScheduleForm) throws {
      let encoded = try JSONEncoder().encode(form)
      let formObject = try JSONSerialization.jsonObject(with: encoded)
      schedules.append([
        "id": UUID().uuidString, "lifetimeId": UUID().uuidString,
        "source": source, "form": formObject,
      ])
    }
    let trip = source(title: "City weekend", kind: "itinerary")
    guard let lastDay = calendar.date(byAdding: .day, value: 3, to: today) else {
      throw CancellationError()
    }
    func civilDate(_ date: Date) throws -> PlannerCivilDate {
      let fields = calendar.dateComponents([.year, .month, .day], from: date)
      guard let year = fields.year, let month = fields.month, let day = fields.day else {
        throw CancellationError()
      }
      return .init(year: year, month: month, day: day)
    }
    try schedule(source: trip, form: .allDay(start: civilDate(today), end: civilDate(lastDay)))
    for dayOffset in 0..<10 {
      guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
        throw CancellationError()
      }
      for (title, hour, length) in [
        ("Breakfast", 8, 60), ("Museum visit", 10, 120),
        ("Lunch", 12, 60), ("Garden walk", 14, 90),
        ("Tea ceremony", 15, 60), ("Dinner", 18, 90),
      ] {
        guard let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
          let end = calendar.date(byAdding: .minute, value: length, to: start)
        else { throw CancellationError() }
        try schedule(
          source: source(title: title),
          form: .timed(start: start, end: end, planningTimeZone: calendar.timeZone.identifier))
      }
    }
    let data = try JSONSerialization.data(withJSONObject: [
      "format": "planner-data", "formatVersion": 2, "sources": sources,
      "memberships": [], "itineraryEntries": [], "schedules": schedules,
      "labelAssociations": [], "ownedLinks": [], "completionChanges": [],
      "expandedCompletions": [], "contextAliases": [], "restorationFamilies": [],
      "deletionMarkers": [],
    ])
    guard case .decoded(let backup) = planner.decodeImport(data),
      case .reviewed(let review) = await planner.prepareReview(
        session: session, command: .applyImport(backup: backup)),
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome
    else { throw CancellationError() }
  }
}
