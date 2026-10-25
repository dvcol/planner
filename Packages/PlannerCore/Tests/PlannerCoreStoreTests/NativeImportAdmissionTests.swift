import Foundation
import PlannerCore
import Testing

struct NativeImportAdmissionTests {
  enum InvalidCase: String, CaseIterable {
    case malformed, overflowDate, missingGroup, unknownProperty, escapedProperty, unknownContent
    case unsupportedVersion, duplicateSource, duplicateMembership, duplicatePair, duplicateChange
    case noncanonicalRank, numericRank, numericBool, missingNull, emptyTitle, coordinate, estimate
    case wrongKind, wrongLifetime, missingChange, observedMissingChange, completionCycle
    case wrongCanonicalContext, inconsistentCompletion, invalidZone, invalidCivilDate
    case liveDeletion, wrongClassification, contextualPlace

    var path: String {
      switch self {
      case .malformed: ""
      case .overflowDate: ""
      case .missingGroup: "/memberships"
      case .unknownProperty: "/devicePreferences"
      case .escapedProperty: "/a~1b~0c"
      case .unknownContent: "/sources/0/content/provider"
      case .unsupportedVersion: "/formatVersion"
      case .duplicateSource: "/sources/7/id"
      case .duplicateMembership: "/memberships/3/id"
      case .duplicatePair: "/memberships/3/item"
      case .duplicateChange: "/completionChanges/1/id"
      case .noncanonicalRank, .numericRank: "/memberships/0/rank"
      case .numericBool: "/sources/0/globalDone"
      case .missingNull: "/sources/0/content/subtitle"
      case .emptyTitle: "/sources/0/content/title"
      case .coordinate: "/sources/0/content/location/coordinate/latitude"
      case .estimate: "/sources/0/content/estimate/minutes"
      case .wrongKind: "/memberships/0/list/kind"
      case .wrongLifetime: "/memberships/0/item/lifetimeId"
      case .missingChange: "/contextAliases/0/currentChangeId"
      case .observedMissingChange: "/completionChanges/0/observedChangeIds/0"
      case .completionCycle: "/completionChanges/0/observedChangeIds"
      case .wrongCanonicalContext, .inconsistentCompletion: "/contextAliases/0/canonicalContext"
      case .invalidZone: "/schedules/0/form/planningTimeZone"
      case .invalidCivilDate: "/schedules/1/form/start"
      case .liveDeletion: "/sources/0/lifetimeId"
      case .wrongClassification: "/ownedLinks/0/kind"
      case .contextualPlace: "/ownedLinks/0/providerReference/value"
      }
    }
  }

  @Test(arguments: InvalidCase.allCases)
  func invalidPortableInputRejectsTheWholeDecodeAtItsExactProperty(testCase: InvalidCase) throws {
    let fixture = try nativeImportFixtureData()
    var object = try #require(JSONSerialization.jsonObject(with: fixture) as? [String: Any])
    var sources = try #require(object["sources"] as? [[String: Any]])
    var memberships = try #require(object["memberships"] as? [[String: Any]])
    var changes = try #require(object["completionChanges"] as? [[String: Any]])
    var aliases = try #require(object["contextAliases"] as? [[String: Any]])
    var links = try #require(object["ownedLinks"] as? [[String: Any]])
    var schedules = try #require(object["schedules"] as? [[String: Any]])
    switch testCase {
    case .malformed, .overflowDate: break
    case .missingGroup: object.removeValue(forKey: "memberships")
    case .unknownProperty: object["devicePreferences"] = [:]
    case .escapedProperty: object["a/b~c"] = true
    case .unknownContent:
      var content = try #require(sources[0]["content"] as? [String: Any])
      content["provider"] = [:]
      sources[0]["content"] = content
    case .unsupportedVersion: object["formatVersion"] = 5
    case .duplicateSource: sources.append(sources[0])
    case .duplicateMembership: memberships.append(memberships[0])
    case .duplicatePair:
      var duplicate = memberships[0]
      duplicate["id"] = "00000000-0000-4000-8000-000000000404"
      duplicate["lifetimeId"] = "00000000-0000-4000-8000-000000000404"
      memberships.append(duplicate)
    case .duplicateChange: changes.append(changes[0])
    case .noncanonicalRank: memberships[0]["rank"] = "01"
    case .numericRank: memberships[0]["rank"] = 1024
    case .numericBool: sources[0]["globalDone"] = 1
    case .missingNull:
      var content = try #require(sources[0]["content"] as? [String: Any])
      content.removeValue(forKey: "subtitle")
      sources[0]["content"] = content
    case .emptyTitle:
      var content = try #require(sources[0]["content"] as? [String: Any])
      content["title"] = " \n "
      sources[0]["content"] = content
    case .coordinate:
      var content = try #require(sources[0]["content"] as? [String: Any])
      var location = try #require(content["location"] as? [String: Any])
      var coordinate = try #require(location["coordinate"] as? [String: Any])
      coordinate["latitude"] = 91
      location["coordinate"] = coordinate
      content["location"] = location
      sources[0]["content"] = content
    case .estimate:
      var content = try #require(sources[0]["content"] as? [String: Any])
      var estimate = try #require(content["estimate"] as? [String: Any])
      estimate["minutes"] = "0"
      content["estimate"] = estimate
      sources[0]["content"] = content
    case .wrongKind:
      var list = try #require(memberships[0]["list"] as? [String: Any])
      list["kind"] = "item"
      memberships[0]["list"] = list
    case .wrongLifetime:
      var item = try #require(memberships[0]["item"] as? [String: Any])
      item["lifetimeId"] = "00000000-0000-4000-8000-000000000999"
      memberships[0]["item"] = item
    case .missingChange: aliases[0]["currentChangeId"] = "00000000-0000-4000-8000-000000000999"
    case .observedMissingChange:
      changes[0]["observedChangeIds"] = ["00000000-0000-4000-8000-000000000999"]
    case .completionCycle:
      changes[0]["observedChangeIds"] = ["00000000-0000-4000-8000-000000000881"]
    case .wrongCanonicalContext:
      aliases[0]["canonicalContext"] = [
        "kind": "directItineraryItem", "entryId": "00000000-0000-4000-8000-000000000451",
        "entryLifetimeId": "00000000-0000-4000-8000-000000000451",
      ]
    case .inconsistentCompletion: memberships[0]["localDone"] = false
    case .invalidZone:
      var form = try #require(schedules[0]["form"] as? [String: Any])
      form["planningTimeZone"] = "Not/AZone"
      schedules[0]["form"] = form
    case .invalidCivilDate:
      var form = try #require(schedules[1]["form"] as? [String: Any])
      form["start"] = ["year": 2026, "month": 2, "day": 30]
      schedules[1]["form"] = form
    case .liveDeletion:
      object["deletionMarkers"] = [
        [
          "deletionId": "00000000-0000-4000-8000-000000000892",
          "operationId": "00000000-0000-4000-8000-000000000992",
          "target": [
            "kind": "source",
            "source": [
              "kind": "item", "id": sources[0]["id"], "lifetimeId": sources[0]["lifetimeId"],
            ],
          ], "closedFamilyId": NSNull(),
        ]
      ]
    case .wrongClassification: links[0]["kind"] = "website"
    case .contextualPlace:
      links[0]["originalUrl"] = "https://maps.apple.com/place?place-id=parked-car"
      links[0]["kind"] = "appleMaps"
      links[0]["providerReference"] = ["kind": "applePlaceId", "value": "parked-car"]
    }
    if testCase != .missingGroup { object["memberships"] = memberships }
    object["sources"] = sources
    object["completionChanges"] = changes
    object["contextAliases"] = aliases
    object["ownedLinks"] = links
    object["schedules"] = schedules
    var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    if testCase == .malformed { data = Data("{\"format\": ".utf8) }
    if testCase == .overflowDate {
      let text = try #require(String(data: data, encoding: .utf8))
      data = Data(
        text.replacingOccurrences(of: "\"createdAt\":10.25", with: "\"createdAt\":1e999").utf8)
    }
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = nativeImportPlanner(directory: directory)
    guard case .invalid(let failure) = planner.decodeImport(data) else {
      Issue.record("Reject the entire \(testCase.rawValue) input.")
      return
    }
    #expect(
      failure.code == (testCase == .unsupportedVersion ? "unsupportedVersion" : "invalidInput"))
    #expect(failure.propertyPath == testCase.path)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    guard case .decoded(let valid) = planner.decodeImport(fixture) else {
      Issue.record("A rejected file must not poison the next independent decode.")
      return
    }
    #expect(valid.backup.sources.count == 7 && valid.backup.memberships.count == 3)
  }

  @Test func absentSourceBindingsRemainExplicitWithoutShorteningOwnersOrChoosingADataset() throws {
    var object = try #require(
      JSONSerialization.jsonObject(with: nativeImportFixtureData()) as? [String: Any])
    var sources = try #require(object["sources"] as? [[String: Any]])
    sources.removeFirst()
    object["sources"] = sources
    let data = try JSONSerialization.data(withJSONObject: object)
    let directory = try makePlannerStoreFixtureDirectory()
    let planner = nativeImportPlanner(directory: directory)
    guard case .decoded(let decoded) = planner.decodeImport(data) else {
      Issue.record("Record external source bindings for the later authorized dataset review.")
      return
    }
    #expect(decoded.backup.sources.count == 6 && decoded.backup.memberships.count == 3)
    #expect(decoded.backup.itineraryEntries.count == 2 && decoded.backup.ownedLinks.count == 2)
    #expect(decoded.externalBindings.count == 1)
    #expect(decoded.externalBindings.first?.kind == .item)
    #expect(decoded.externalBindings.first?.id.uuidString == "00000000-0000-4000-8000-000000000101")
    #expect(
      decoded.externalBindings.first?.lifetimeId.uuidString
        == "00000000-0000-4000-8000-000000000811")
    #expect(
      Set(decoded.originPaths.map(\.propertyPath)) == [
        "/memberships/0/item", "/memberships/2/item", "/itineraryEntries/0/source",
        "/schedules/0/source",
        "/labelAssociations/0/owner", "/labelAssociations/2/owner", "/ownedLinks/0/owner",
        "/ownedLinks/1/owner",
      ])
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }
}

func nativeImportFixtureData() throws -> Data {
  #if SWIFT_PACKAGE
    let fixtureBundle = Bundle.module
  #else
    let fixtureBundle = Bundle(for: NativeImportFixtureBundle.self)
  #endif
  let fixture = try #require(
    fixtureBundle.url(
      forResource: "portable-backup-v1", withExtension: "json",
      subdirectory: "Fixtures/PortableImport"))
  return try Data(contentsOf: fixture)
}

func nativeImportPlanner(directory: URL) -> Planner {
  .init(
    configuration: .init(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .shareExtension, storageMode: .localOnly))
}

#if !SWIFT_PACKAGE
  final class NativeImportFixtureBundle: NSObject {}
#endif
