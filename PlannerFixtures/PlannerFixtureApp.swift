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

struct FixturePreviewProvider: PlannerLinkPreviewProvider, PlannerAddressPreviewProvider {
  func linkPreview(for originalURL: String) async throws -> PlannerLinkPreviewContent {
    .init(title: "Fixture link", imageData: nil)
  }

  func addressPreview(for address: String) async throws -> [PlannerAddressCandidate] { [] }
}
