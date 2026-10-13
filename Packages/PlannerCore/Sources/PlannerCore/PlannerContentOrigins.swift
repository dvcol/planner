import Foundation

func plannerValidateContentOrigins(_ origins: [String: String], expected: [String: String]) throws {
  guard Set(origins.keys) == Set(expected.keys),
    origins.values.allSatisfy({ $0 == "independent" || $0 == "appFallback" })
  else {
    throw PlannerFailure("recoveryIntegrityFailure", "The saved content origins are inconsistent.")
  }
}

func plannerReadContentOrigins(_ stored: [String: String?], independent: [String: String]) throws
  -> [String: String]?
{
  guard stored.values.contains(where: { $0 != nil }) else { return nil }
  var origins = independent
  for (field, origin) in stored {
    guard let origin else { continue }
    guard origin == "independent" || origin == "appFallback" else {
      throw PlannerFailure("recoveryIntegrityFailure", "The saved content origin is unsupported.")
    }
    if independent[field] != nil { origins[field] = origin }
  }
  return origins
}

func plannerEditedContentOrigins(
  _ previous: [String: String]?, editedFields: Set<String>, independent: [String: String]
) -> [String: String]? {
  guard let previous else { return nil }
  var origins = independent
  for (field, origin) in previous where independent[field] != nil {
    origins[field] = origin
  }
  for field in editedFields where independent[field] != nil {
    origins[field] = "independent"
  }
  return origins
}

extension ItemSnapshot {
  var independentContentOrigins: [String: String] {
    var origins = ["title": "independent"]
    if input.subtitle != nil { origins["subtitle"] = "independent" }
    if input.notes != nil { origins["notes"] = "independent" }
    if input.location != nil { origins["location"] = "independent" }
    return origins
  }
}

extension ListSnapshot {
  var independentContentOrigins: [String: String] {
    var origins = ["name": "independent"]
    if content.notes != nil { origins["notes"] = "independent" }
    return origins
  }
}

extension ItinerarySnapshot {
  var independentContentOrigins: [String: String] {
    var origins = ["title": "independent"]
    if input.notes != nil { origins["notes"] = "independent" }
    if input.location != nil { origins["location"] = "independent" }
    return origins
  }
}

extension CategorySnapshot {
  var independentContentOrigins: [String: String] { ["name": "independent"] }
}

extension TagSnapshot {
  var independentContentOrigins: [String: String] { ["name": "independent"] }
}
