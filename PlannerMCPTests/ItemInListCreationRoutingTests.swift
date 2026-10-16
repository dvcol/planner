import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ItemInListCreationRoutingTests {
  @Test func ordinaryCreationOverHTTPKeepsBookmarksDestinationAndReplayIdentity() async throws {
    let directory = fixtureDirectory()
    let fixture = try await CaptureHTTPFixture.open(directory: directory)
    do {
      let list = try await fixture.save(.createList(content: .init(name: "Tokyo")))
      let operationIdentifier = UUID()
      let command: [String: Any] = [
        "type": "createItem", "listId": list.id.uuidString,
        "content": [
          "title": "Museum", "notes": "Tickets booked",
          "links": [
            ["originalUrl": "https://example.com/museum", "label": "Tickets"],
            ["originalUrl": "https://example.com/museum", "label": "Exhibitions"],
          ],
        ],
      ]
      let arguments: [String: Any] = [
        "formatVersion": 1, "operationId": operationIdentifier.uuidString, "command": command,
      ]
      let created = try await fixture.call("planner_execute", arguments: arguments)
      try #require(created["state"] as? String == "applied")
      let generated = try #require(
        (created["result"] as? [String: Any])?["generated"] as? [[String: Any]])
      let itemIdentifier = try #require(
        generated.first { $0["kind"] as? String == "item" }?["id"] as? String)
      let membership = try #require(generated.first { $0["kind"] as? String == "membership" })
      let membershipIdentifier = try #require(membership["id"] as? String)
      #expect((membership["owner"] as? [String: Any])?["id"] as? String == list.id.uuidString)
      #expect((membership["source"] as? [String: Any])?["id"] as? String == itemIdentifier)
      let saved = try await read(fixture, kind: "item", identifier: itemIdentifier)
      let links = try #require(
        (saved["content"] as? [String: Any])?["links"] as? [[String: Any]])
      #expect(links.map { $0["label"] as? String } == ["Tickets", "Exhibitions"])
      #expect(Set(links.compactMap { $0["linkId"] as? String }).count == 2)
      let populated = try await read(fixture, kind: "list", identifier: list.id.uuidString)
      #expect((populated["references"] as? [Any])?.count == 1)
      #expect((populated["progress"] as? [String: Any])?["doneCount"] as? String == "0")
      let replay = try await fixture.call("planner_execute", arguments: arguments)
      #expect(NSDictionary(dictionary: replay).isEqual(to: created))
      _ = try await fixture.call(
        "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": UUID().uuidString,
          "command": [
            "type": "removeMembership", "listId": list.id.uuidString,
            "membershipId": membershipIdentifier,
          ],
        ])
      let replayAfterRemoval = try await fixture.call("planner_execute", arguments: arguments)
      #expect(NSDictionary(dictionary: replayAfterRemoval).isEqual(to: created))
      let emptied = try await read(fixture, kind: "list", identifier: list.id.uuidString)
      #expect((emptied["references"] as? [Any])?.isEmpty == true)
      for destination in [nil, NSNull()] as [Any?] {
        var globalCommand: [String: Any] = [
          "type": "createItem", "content": ["title": "Global"],
        ]
        globalCommand["listId"] = destination
        let global = try await fixture.call(
          "planner_execute",
          arguments: [
            "formatVersion": 1, "operationId": UUID().uuidString, "command": globalCommand,
          ])
        #expect(global["state"] as? String == "applied")
        let globalGenerated = try #require(
          (global["result"] as? [String: Any])?["generated"] as? [[String: Any]])
        #expect(globalGenerated.count == 1 && globalGenerated.first?["kind"] as? String == "item")
      }
      let tools = try await fixture.request(method: "tools/list", parameters: [:])
      let execution = try #require(
        (tools["tools"] as? [[String: Any]])?.first { $0["name"] as? String == "planner_execute" })
      let properties = try #require(
        (execution["inputSchema"] as? [String: Any])?["properties"] as? [String: Any])
      let variants = try #require(
        (properties["command"] as? [String: Any])?["oneOf"] as? [[String: Any]])
      let creation = try #require(
        variants.compactMap { $0["properties"] as? [String: Any] }.first {
          ($0["type"] as? [String: Any])?["const"] as? String == "createItem"
        })
      #expect((creation["listId"] as? [String: Any])?["type"] as? [String] == ["string", "null"])
      await fixture.stop()
    } catch {
      await fixture.stop()
      throw error
    }
  }

  @Test func destinationCreationReviewBindsTheCommandAndCanBeAppliedOverHTTP() async throws {
    let fixture = try await CaptureHTTPFixture.open(directory: fixtureDirectory())
    do {
      let list = try await fixture.save(.createList(content: .init(name: "Tokyo")))
      let command: [String: Any] = [
        "type": "createItem", "listId": list.id.uuidString,
        "content": [
          "title": "Museum", "notes": "Keep this draft",
          "links": [
            ["originalUrl": "https://example.com/museum", "label": "Tickets"],
            ["originalUrl": "https://example.com/museum", "label": "Guide"],
          ],
        ],
      ]
      guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      let initial = try await fixture.call(
        "planner_prepare_review", arguments: ["formatVersion": 1, "command": command])
      try #require((initial["impact"] as? [String: Any])?["kind"] as? String == "itemCreation")
      guard
        case .exported(let afterReview) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(afterReview == before)
      let original = try await read(fixture, kind: "list", identifier: list.id.uuidString)
      _ = try await fixture.call(
        "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": UUID().uuidString,
          "command": [
            "type": "editList", "sourceId": list.id.uuidString,
            "changes": ["name": "Tokyo revised"],
            "expectedFieldHashes": try #require(original["fieldHashes"]),
          ],
        ])
      let stale = try await fixture.call(
        "planner_execute",
        arguments: [
          "formatVersion": 1, "operationId": UUID().uuidString,
          "command": try #require(initial["command"]),
          "reviewToken": try #require(initial["reviewToken"]),
        ], isError: true)
      #expect((stale["reason"] as? [String: Any])?["code"] as? String == "staleReview")
      let review = try await fixture.call(
        "planner_prepare_review", arguments: ["formatVersion": 1, "command": command])
      let reviewedCommand = try #require(review["command"] as? [String: Any])
      let token = try #require(review["reviewToken"] as? String)
      guard
        case .exported(let renamedData) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      for removesDestination in [false, true] {
        var changed = reviewedCommand
        if removesDestination {
          changed["listId"] = nil
        } else {
          var content = try #require(changed["content"] as? [String: Any])
          content["title"] = "Changed after review"
          changed["content"] = content
        }
        let rejected = try await fixture.call(
          "planner_execute",
          arguments: [
            "formatVersion": 1, "operationId": UUID().uuidString,
            "command": changed, "reviewToken": token,
          ], isError: true)
        #expect((rejected["reason"] as? [String: Any])?["code"] as? String == "staleReview")
      }
      guard
        case .exported(let unchanged) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(unchanged == renamedData)
      let arguments: [String: Any] = [
        "formatVersion": 1, "operationId": UUID().uuidString,
        "command": reviewedCommand, "reviewToken": token,
      ]
      let applied = try await fixture.call("planner_execute", arguments: arguments)
      #expect(applied["state"] as? String == "applied")
      let generated = try #require(
        (applied["result"] as? [String: Any])?["generated"] as? [[String: Any]])
      #expect(generated.count == 2)
      let itemIdentifier = try #require(generated.first?["id"] as? String)
      let saved = try await read(fixture, kind: "item", identifier: itemIdentifier)
      let links = try #require((saved["content"] as? [String: Any])?["links"] as? [[String: Any]])
      #expect(links.map { $0["label"] as? String } == ["Tickets", "Guide"])
      let replay = try await fixture.call("planner_execute", arguments: arguments)
      #expect(NSDictionary(dictionary: replay).isEqual(to: applied))
      await fixture.stop()
    } catch {
      await fixture.stop()
      throw error
    }
  }

  @Test func invalidDestinationsAndNonreviewableCreationLeaveDataUnchanged() async throws {
    let fixture = try await CaptureHTTPFixture.open(directory: fixtureDirectory())
    do {
      let archived = try await fixture.save(.createList(content: .init(name: "Archived")))
      _ = try await fixture.execute(.setArchive(source: archived, archived: true))
      guard case .exported(let before) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      for destination: Any in ["invalid-uuid", "", 42, false, [String]()] {
        let operationIdentifier = UUID()
        let result = try await fixture.call(
          "planner_execute",
          arguments: [
            "formatVersion": 1, "operationId": operationIdentifier.uuidString,
            "command": [
              "type": "createItem", "listId": destination, "content": ["title": "Must not save"],
            ],
          ], isError: true)
        let reason = try #require(result["reason"] as? [String: Any])
        #expect(reason["code"] as? String == "invalidInput")
        #expect(reason["propertyPath"] as? String == "/command/listId")
        guard
          case .noReliableEvidence = await fixture.planner.operationStatus(
            session: fixture.session, operationId: operationIdentifier)
        else { throw CancellationError() }
      }
      for destination in [UUID().uuidString, archived.id.uuidString] {
        let result = try await fixture.call(
          "planner_execute",
          arguments: [
            "formatVersion": 1, "operationId": UUID().uuidString,
            "command": [
              "type": "createItem", "listId": destination, "content": ["title": "Must not save"],
            ],
          ], isError: true)
        let reason = try #require(result["reason"] as? [String: Any])
        #expect(reason["code"] as? String == "missingReference")
        #expect(reason["propertyPath"] as? String == "/command/listId")
      }
      for destination in [nil, NSNull()] as [Any?] {
        var command: [String: Any] = ["type": "createItem", "content": ["title": "Global"]]
        command["listId"] = destination
        let result = try await fixture.call(
          "planner_prepare_review", arguments: ["formatVersion": 1, "command": command],
          isError: true)
        let reason = try #require(result["reason"] as? [String: Any])
        #expect(reason["code"] as? String == "invalidInput")
        #expect(reason["propertyPath"] as? String == "/command/listId")
      }
      guard case .exported(let after) = await fixture.planner.exportData(session: fixture.session)
      else { throw CancellationError() }
      #expect(after == before)
      await fixture.stop()
    } catch {
      await fixture.stop()
      throw error
    }
  }

  private func fixtureDirectory() -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerItemInListHTTPTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    print("Item in List HTTP fixture: \(directory.path)")
    return directory
  }

  private func read(_ fixture: CaptureHTTPFixture, kind: String, identifier: String) async throws
    -> [String: Any]
  {
    let result = try await fixture.call(
      "planner_read",
      arguments: [
        "formatVersion": 1,
        "request": ["kind": "source", "source": ["kind": kind, "id": identifier]],
      ])
    return try #require(result["value"] as? [String: Any])
  }
}
