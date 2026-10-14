import Foundation

public struct PlannerCalendarQuery: Sendable {
  public let startDay: PlannerCivilDate
  public let endDay: PlannerCivilDate
  public let displayTimeZone: String

  public init(startDay: PlannerCivilDate, endDay: PlannerCivilDate, displayTimeZone: String) {
    self.startDay = startDay
    self.endDay = endDay
    self.displayTimeZone = displayTimeZone
  }

  func interval() throws -> DateInterval {
    try startDay.validate(propertyPath: "/query/startDay")
    try endDay.validate(propertyPath: "/query/endDay")
    guard !endDay.isEarlier(than: startDay) else {
      throw PlannerFailure(
        "invalidInput", "The Calendar end day must not precede its start day.",
        propertyPath: "/query/endDay")
    }
    guard let timeZone = TimeZone(identifier: displayTimeZone) else {
      throw PlannerFailure(
        "invalidInput", "The Calendar display timezone must be valid.",
        propertyPath: "/query/displayTimeZone")
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    func dayStart(_ day: PlannerCivilDate, propertyPath: String) throws -> Date {
      guard
        let date = calendar.date(
          from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))
      else {
        throw PlannerFailure(
          "invalidInput", "The Calendar day is unavailable in its display timezone.",
          propertyPath: propertyPath)
      }
      let resolved = calendar.dateComponents([.year, .month, .day], from: date)
      guard resolved.year == day.year, resolved.month == day.month, resolved.day == day.day else {
        throw PlannerFailure(
          "invalidInput", "The Calendar day is unavailable in its display timezone.",
          propertyPath: propertyPath)
      }
      return calendar.startOfDay(for: date)
    }
    let start = try dayStart(startDay, propertyPath: "/query/startDay")
    let lastDay = try dayStart(endDay, propertyPath: "/query/endDay")
    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: lastDay) else {
      throw PlannerFailure("invalidInput", "The Calendar date window is unavailable.")
    }
    let end = calendar.startOfDay(for: nextDay)
    guard end > start else {
      throw PlannerFailure("invalidInput", "The Calendar date window is unavailable.")
    }
    return DateInterval(start: start, end: end)
  }
}

public struct PlannerCalendarEntry: Sendable, Equatable {
  public let schedule: PlannerEntityReference
  public let source: PlannerEntityReference
  public let title: String
  public let form: PlannerScheduleForm
}

public struct PlannerCalendarRowWindow: Sendable {
  public let generation: UUID
  public let offset: Int64
  public let matchingCount: Int64
  public let rows: [PlannerCalendarEntry]
}
