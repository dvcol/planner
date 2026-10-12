import PlannerPreviews
import SwiftUI

@main
struct PlannerFixtureApp: App {
  @State private var store: SavedPlannerStore?
  @State private var failure: String?
  @State private var previews = PlannerPreviews(provider: FixturePreviewProvider())
  @State private var addressPreviews = PlannerAddressPreviews(provider: FixturePreviewProvider())

  var body: some Scene {
    WindowGroup {
      Group {
        if let store {
          SavedPlannerView(store: store)
            .environment(store)
            .environment(previews)
            .environment(addressPreviews)
        } else if let failure {
          ContentUnavailableView(
            "Fixture unavailable", systemImage: "exclamationmark.triangle",
            description: Text(failure))
        } else {
          ProgressView("Preparing fixture")
        }
      }
      .task {
        guard store == nil, failure == nil else { return }
        do { store = try await PlannerFixtureDataset.makeStore() } catch {
          failure = error.localizedDescription
        }
      }
    }
  }
}

@MainActor
final class FixturePreviewProvider: PlannerLinkPreviewProvider, PlannerAddressPreviewProvider {
  private var hasFailedRetryLink = false
  func linkPreview(for originalURL: String) async throws -> PlannerLinkPreviewContent {
    if originalURL == "https://fixtures.invalid/retry", !hasFailedRetryLink {
      hasFailedRetryLink = true
      throw URLError(.cannotConnectToHost)
    }
    guard originalURL == "https://fixtures.invalid/image" else {
      return .init(title: "Fixture link", imageData: nil)
    }
    guard let imageURL = Bundle.main.url(forResource: "website-image", withExtension: "png") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return .init(title: "Fixture image preview", imageData: try Data(contentsOf: imageURL))
  }

  func addressPreview(for address: String) async throws -> [PlannerAddressCandidate] { [] }
}
