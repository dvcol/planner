import Foundation
import PlannerCore
import Testing

struct NativeImportScaleTests {
  @Test func largePortableListRetainsAllSourcesAndMembershipBindings() throws {
    var object = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    var sources = try #require(object["sources"] as? [[String: Any]])
    var memberships = try #require(object["memberships"] as? [[String: Any]])
    for index in 1...5000 {
      let itemId = UUID().uuidString
      let lifetimeId = UUID().uuidString
      let membershipId = UUID().uuidString
      sources.append([
        "kind": "item", "id": itemId, "lifetimeId": lifetimeId, "createdAt": 10.25,
        "updatedAt": 20.125,
        "content": [
          "title": "Travel stop \(index)", "subtitle": NSNull(), "notes": NSNull(),
          "location": NSNull(), "estimate": ["minutes": "60", "displayUnit": "hour"],
        ],
        "globalDone": false, "archived": false, "contentOrigins": ["title": "independent"],
      ])
      memberships.append([
        "id": membershipId, "lifetimeId": membershipId,
        "list": [
          "kind": "list", "id": "00000000-0000-4000-8000-000000000201",
          "lifetimeId": "00000000-0000-4000-8000-000000000821",
        ],
        "item": ["kind": "item", "id": itemId, "lifetimeId": lifetimeId],
        "rank": String(index + 2048), "localDone": false,
      ])
    }
    object["sources"] = sources
    object["memberships"] = memberships
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let result = nativeImportPlanner(directory: directory).decodeImport(
      try JSONSerialization.data(withJSONObject: object))
    guard case .decoded(let decoded) = result else {
      Issue.record("Decode the complete large planner graph: \(result)")
      return
    }
    #expect(decoded.backup.sources.count == 5007 && decoded.backup.memberships.count == 5003)
    #expect(decoded.backup.items.last?.content.title == "Travel stop 5000")
    #expect(decoded.backup.items.last?.content.estimate?.minutes == 60)
    #expect(decoded.externalBindings.isEmpty && decoded.originPaths.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }
}
