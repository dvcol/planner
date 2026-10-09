import Foundation

public struct PlannerCivilDate: Sendable, Equatable, Codable {
  public let year: Int
  public let month: Int
  public let day: Int

  public init(year: Int, month: Int, day: Int) {
    self.year = year
    self.month = month
    self.day = day
  }

  func validate(propertyPath: String) throws {
    guard year > 0, (1...12).contains(month), (1...31).contains(day) else {
      throw PlannerFailure(
        "invalidInput", "Expected a valid Gregorian civil date.", propertyPath: propertyPath)
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let components = DateComponents(era: 1, year: year, month: month, day: day, hour: 12)
    guard let date = calendar.date(from: components), date.timeIntervalSinceReferenceDate.isFinite
    else {
      throw PlannerFailure(
        "invalidInput", "The Gregorian civil date is unavailable.", propertyPath: propertyPath)
    }
    let resolved = calendar.dateComponents([.era, .year, .month, .day], from: date)
    guard resolved.era == 1, resolved.year == year, resolved.month == month, resolved.day == day
    else {
      throw PlannerFailure(
        "invalidInput", "Expected an exact Gregorian civil date.", propertyPath: propertyPath)
    }
  }

  func isEarlier(than other: PlannerCivilDate) -> Bool {
    if year != other.year { return year < other.year }
    if month != other.month { return month < other.month }
    return day < other.day
  }

  var canonicalValue: PlannerCanonicalValue {
    .record([
      "year": .integer(Int64(year)), "month": .integer(Int64(month)), "day": .integer(Int64(day)),
    ])
  }
}
