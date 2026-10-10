import MapKit
import PlannerPreviews
import SwiftUI

struct ItemAddressPreview: View {
  let request: PlannerAddressPreviewRequest
  @Environment(PlannerAddressPreviews.self) private var previews
  @State private var selectedCandidateIdentifier: String?

  var body: some View {
    Group {
      switch previews.addressState(for: request) {
      case .idle, .loading:
        ProgressView("Finding address")
      case .unavailable:
        Label("Address preview unavailable", systemImage: "mappin.slash")
          .foregroundStyle(.secondary)
        retryButton
      case .available(let candidates):
        if candidates.isEmpty {
          Label("No matching places", systemImage: "mappin.slash")
            .foregroundStyle(.secondary)
          retryButton
        } else if candidates.count == 1, let candidate = candidates.first {
          preview(candidate)
        } else {
          Picker("Matching places", selection: $selectedCandidateIdentifier) {
            Text("Choose a place").tag(nil as String?)
            ForEach(candidates) { candidate in
              Text(candidate.address.map { "\(candidate.name), \($0)" } ?? candidate.name)
                .tag(Optional(candidate.id))
            }
          }
          if let candidate = candidates.first(where: { $0.id == selectedCandidateIdentifier }) {
            preview(candidate)
          }
        }
      }
    }
    .task(id: request) { await previews.loadAddress(request) }
  }

  private var retryButton: some View {
    Button("Retry", systemImage: "arrow.clockwise") {
      Task { await previews.retryAddress(request) }
    }
  }

  private func preview(_ candidate: PlannerAddressCandidate) -> some View {
    VStack(alignment: .leading) {
      ItemLocationMap(
        title: candidate.name,
        coordinate: CLLocationCoordinate2D(
          latitude: candidate.latitude, longitude: candidate.longitude),
        accessibilityIdentifier: "saved.item.location.preview.map")
      Text("Address preview").font(.caption).foregroundStyle(.secondary)
    }
  }
}
