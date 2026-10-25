import Foundation
import Testing

/// Compare current grammar with legacy fixture values while testing historical bytes separately.
func canonicalPortableFixtureExpectations(_ data: Data) throws -> [String: Any] {
  var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  object["formatVersion"] = 4
  if object["membershipProvenance"] == nil { object["membershipProvenance"] = [] }
  if object["membershipRemovals"] == nil { object["membershipRemovals"] = [] }
  let changes = try #require(object["completionChanges"] as? [[String: Any]])
  object["completionChanges"] = changes.map { change in
    var change = change
    if change["observedExpandedCompletionDeletionIds"] == nil {
      change["observedExpandedCompletionDeletionIds"] = []
    }
    return change
  }
  let sources = try #require(object["sources"] as? [[String: Any]])
  object["sources"] = try sources.map { source in
    var source = source
    var content = try #require(source["content"] as? [String: Any])
    if ["list", "itinerary"].contains(source["kind"] as? String ?? ""),
      content["manualEstimate"] == nil
    {
      content["manualEstimate"] = NSNull()
    }
    if var estimate = content["estimate"] as? [String: Any],
      let minutes = estimate["minutes"] as? Int64
    {
      estimate["minutes"] = String(minutes)
      content["estimate"] = estimate
    }
    if var location = content["location"] as? [String: Any] {
      for name in ["displayName", "formattedAddress", "coordinate"] where location[name] == nil {
        location[name] = NSNull()
      }
      content["location"] = location
    }
    source["content"] = content
    return source
  }
  let markers = try #require(object["deletionMarkers"] as? [[String: Any]])
  object["deletionMarkers"] = try markers.map { marker in
    var marker = marker
    var target = try #require(marker["target"] as? [String: Any])
    if target["kind"] as? String == "membership",
      let member = target["membership"] as? [String: Any]
    {
      #expect(member["kind"] as? String == "membership")
      target = [
        "kind": "membership", "id": try #require(member["id"]),
        "lifetimeId": try #require(member["lifetimeId"]),
      ]
      marker["target"] = target
    }
    return marker
  }
  return object
}
