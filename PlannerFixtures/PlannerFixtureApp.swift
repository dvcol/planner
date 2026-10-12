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
  private var hasFailedRetryAddress = false
  private var pendingAddressPreviewContinuation:
    CheckedContinuation<[PlannerAddressCandidate], any Error>?
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

  func addressPreview(for address: String) async throws -> [PlannerAddressCandidate] {
    if address == "Fixture delayed address" {
      return try await withCheckedThrowingContinuation { continuation in
        guard pendingAddressPreviewContinuation == nil else {
          continuation.resume(throwing: CancellationError())
          return
        }
        pendingAddressPreviewContinuation = continuation
      }
    }
    if address == "Fixture current address" {
      let candidateName: String
      if let continuation = pendingAddressPreviewContinuation {
        pendingAddressPreviewContinuation = nil
        continuation.resume(returning: [
          .init(
            id: "outdated", name: "Outdated entrance", address: "4 Fixture Way",
            latitude: 35.662, longitude: 139.717)
        ])
        candidateName = "Current entrance"
      } else {
        candidateName = "Reopened entrance"
      }
      return [
        .init(
          id: "current", name: candidateName, address: "5 Fixture Way",
          latitude: 35.655, longitude: 139.717)
      ]
    }
    if address == "Fixture retry address" {
      guard hasFailedRetryAddress else {
        hasFailedRetryAddress = true
        throw URLError(.cannotFindHost)
      }
      return [
        .init(
          id: "recovered", name: "Recovered entrance", address: "3 Fixture Way",
          latitude: 35.662, longitude: 139.717)
      ]
    }
    guard address == "Fixture multiple matches" else { return [] }
    return [
      .init(
        id: "north", name: "North entrance", address: "1 Fixture Way",
        latitude: 35.662, longitude: 139.717),
      .init(
        id: "south", name: "South entrance", address: "2 Fixture Way",
        latitude: 35.655, longitude: 139.717),
    ]
  }
}
