import Foundation
import ImageIO
import PlannerPreviews
import Testing

@MainActor
struct AppleLinkPreviewTests {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["PLANNER_PREVIEW_FIXTURE_URL"] != nil))
  func appleMetadataLoadsTheControlledImageAndPlainPage() async throws {
    let base = try #require(ProcessInfo.processInfo.environment["PLANNER_PREVIEW_FIXTURE_URL"])
    let provider = AppleLinkPreviewProvider()
    let image = try await provider.linkPreview(for: base + "/image")
    #expect(image.title == "Planner image preview")
    let imageData = try #require(image.imageData)
    let decoded = try #require(CGImageSourceCreateWithData(imageData as CFData, nil))
    #expect(CGImageSourceGetCount(decoded) > 0)
    let plain = try await provider.linkPreview(for: base + "/plain")
    #expect(plain.title == "Planner plain preview")
    #expect(plain.imageData == nil)
  }
}
