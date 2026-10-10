import Foundation
import PlannerPreviews
import Testing

@MainActor
struct AppleAddressPreviewTests {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["PLANNER_ADDRESS_FIXTURE"] != nil))
  func appleGeocodingProvidesNativeCandidatesForTheKnownAddress() async throws {
    let address = ProcessInfo.processInfo.environment["PLANNER_ADDRESS_FIXTURE"]!
    let provider = AppleAddressPreviewProvider()
    let candidates = try await provider.addressPreview(for: address)

    #expect(!candidates.isEmpty)
    #expect(candidates.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty })
    #expect(
      candidates.contains {
        $0.latitude > 37.3 && $0.latitude < 37.4
          && $0.longitude > -122.1 && $0.longitude < -122.0
      })
    #expect(candidates.contains { $0.address?.contains("Cupertino") == true })
  }
}
