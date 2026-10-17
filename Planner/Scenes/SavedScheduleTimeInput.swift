import Foundation

enum SavedScheduleTimeResolution: Sendable, Equatable {
  case unavailable
  case nonexistent
  case unique(Date)
  case repeated([Date])
}

struct SavedScheduleTimeInput {
  private(set) var pickerValue: Date
  private(set) var resolution = SavedScheduleTimeResolution.unavailable
  private(set) var selectedOccurrence: Date?
  private var planningTimeZone: TimeZone
  private var unchangedSavedInstant: Date?

  var resolvedInstant: Date? { unchangedSavedInstant ?? selectedOccurrence }

  private static var pickerCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }

  private var planningCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = planningTimeZone
    return calendar
  }

  init(proposedInstant: Date, planningTimeZone: TimeZone) {
    pickerValue = proposedInstant
    self.planningTimeZone = planningTimeZone
    guard proposedInstant.timeIntervalSinceReferenceDate.isFinite else { return }
    var components = planningCalendar.dateComponents(
      [.era, .year, .month, .day, .hour, .minute], from: proposedInstant)
    components.second = 0
    guard let civilMinute = Self.pickerCalendar.date(from: components) else { return }
    pickerValue = civilMinute
    resolve()
  }

  init(savedInstant: Date, planningTimeZone: TimeZone) {
    self.init(proposedInstant: savedInstant, planningTimeZone: planningTimeZone)
    retainSavedInstant(savedInstant)
  }

  mutating func setPickerValue(_ value: Date) {
    guard value.timeIntervalSinceReferenceDate.isFinite,
      let minute = Self.pickerCalendar.dateInterval(of: .minute, for: value)
    else {
      pickerValue = value
      resolution = .unavailable
      selectedOccurrence = nil
      unchangedSavedInstant = nil
      return
    }
    guard minute.start != pickerValue else { return }
    pickerValue = minute.start
    selectedOccurrence = nil
    unchangedSavedInstant = nil
    resolve()
  }

  mutating func selectOccurrence(_ candidate: Date) -> Bool {
    guard case .repeated(let candidates) = resolution, candidates.contains(candidate) else {
      return false
    }
    if selectedOccurrence != candidate { unchangedSavedInstant = nil }
    selectedOccurrence = candidate
    return true
  }

  mutating func changePlanningTimeZone(_ timeZone: TimeZone) {
    guard timeZone != planningTimeZone else { return }
    let instant = resolvedInstant
    let savedInstant = unchangedSavedInstant
    planningTimeZone = timeZone
    unchangedSavedInstant = nil
    selectedOccurrence = nil
    if let instant {
      var components = planningCalendar.dateComponents(
        [.era, .year, .month, .day, .hour, .minute], from: instant)
      components.second = 0
      guard let civilMinute = Self.pickerCalendar.date(from: components) else {
        resolution = .unavailable
        return
      }
      pickerValue = civilMinute
    }
    resolve()
    if let savedInstant { retainSavedInstant(savedInstant) }
  }

  private mutating func retainSavedInstant(_ instant: Date) {
    let candidates: [Date]
    switch resolution {
    case .unique(let candidate): candidates = [candidate]
    case .repeated(let repeated): candidates = repeated
    case .unavailable, .nonexistent: return
    }
    guard
      let candidate = candidates.first(where: {
        let elapsed = instant.timeIntervalSince($0)
        return elapsed >= 0 && elapsed < 60
      })
    else {
      resolution = .unavailable
      selectedOccurrence = nil
      return
    }
    selectedOccurrence = candidate
    unchangedSavedInstant = instant
  }

  private mutating func resolve() {
    selectedOccurrence = nil
    guard pickerValue.timeIntervalSinceReferenceDate.isFinite else {
      resolution = .unavailable
      return
    }
    let calendar = planningCalendar
    let components = Self.pickerCalendar.dateComponents(
      [.era, .year, .month, .day, .hour, .minute, .second], from: pickerValue)
    guard let approximate = calendar.date(from: components),
      let day = calendar.dateInterval(of: .day, for: approximate)
    else {
      resolution = .unavailable
      return
    }
    var candidateInstants = Set(
      [Calendar.RepeatedTimePolicy.first, .last].compactMap { policy -> Date? in
        guard
          let candidate = calendar.nextDate(
            after: day.start.addingTimeInterval(-1), matching: components,
            matchingPolicy: .strict, repeatedTimePolicy: policy),
          calendar.date(candidate, matchesComponents: components)
        else { return nil }
        return candidate
      }
    )
    // Check both actual day offsets when Foundation omits a repeated occurrence.
    let offsets = Set(
      [day.start, day.end.addingTimeInterval(-1)].map { planningTimeZone.secondsFromGMT(for: $0) })
    for offsetSeconds in offsets {
      let candidate = pickerValue.addingTimeInterval(-TimeInterval(offsetSeconds))
      if calendar.date(candidate, matchesComponents: components) {
        candidateInstants.insert(candidate)
      }
    }
    let candidates = candidateInstants.sorted()
    guard let first = candidates.first else {
      resolution = .nonexistent
      return
    }
    guard candidates.count == 1 else {
      resolution = .repeated(candidates)
      return
    }
    resolution = .unique(first)
    selectedOccurrence = first
  }
}
