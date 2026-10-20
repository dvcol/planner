import AppIntents
import Foundation
import XCTest

@testable import Planner

@MainActor
final class PlannerTimeZoneIntentTests: XCTestCase {
  func testPrecancelledTimeZoneQueriesRejectEvenEmptyIdentityRequests() async throws {
    let query = PlannerTimeZoneEntityQuery()
    let operations: [@MainActor () async throws -> [PlannerTimeZoneEntity]] = [
      { try await query.entities(for: []) },
      { try await query.entities(for: ["Asia/Tokyo"]) },
      { try await query.entities(matching: "Tokyo") },
      { try await query.suggestedEntities() },
    ]
    for operation in operations {
      let task = Task { @MainActor in try await operation() }
      task.cancel()
      do {
        _ = try await task.value
        XCTFail("Every precancelled native timezone query must reject the request.")
      } catch is CancellationError {
      } catch { XCTFail("Expected cancellation, received \(error).") }
    }
  }

  func testIdentityResolutionPreservesValidAliasesAndOmitsInvalidIdentifiers() async throws {
    let query = PlannerTimeZoneEntityQuery()
    let values = try await query.entities(for: [
      "Asia/Tokyo", "UTC", "Etc/UTC", "GMT+0900", "Not/AZone", "Asia/Tokyo",
    ])
    XCTAssertEqual(values.map(\.id), ["Asia/Tokyo", "UTC", "Etc/UTC", "GMT+0900"])
    XCTAssertEqual(values.map(\.identifier), ["Asia/Tokyo", "UTC", "Etc/UTC", "GMT+0900"])
    XCTAssertTrue(values.allSatisfy { !$0.name.isEmpty })
    let custom = try await query.entities(matching: "GMT+0900")
    XCTAssertTrue(custom.contains { $0.id == "GMT+0900" && $0.identifier == "GMT+0900" })
    let matches = try await query.entities(matching: "tokyo")
    XCTAssertTrue(matches.contains { $0.id == "Asia/Tokyo" })
    let missing = try await query.entities(matching: "Not/AZone")
    XCTAssertTrue(missing.isEmpty)
  }
}
