import CoreTransferable
import Foundation
import LinkPresentation
import UniformTypeIdentifiers

@MainActor
public struct AppleLinkPreviewProvider: PlannerLinkPreviewProvider {
  public init() {}

  public func linkPreview(for originalURL: String) async throws -> PlannerLinkPreviewContent {
    guard let destination = URL(string: originalURL),
      let scheme = destination.scheme?.lowercased(),
      scheme == "https" || scheme == "http", destination.host() != nil
    else {
      throw URLError(.badURL)
    }
    let metadata = try await LinkMetadata(fetching: destination)
    let image = try? await metadata.media(.image, as: PreviewImageData.self)
    let imageData = image?.data
    return PlannerLinkPreviewContent(title: metadata.title, imageData: imageData)
  }
}

private struct PreviewImageData: Transferable {
  let data: Data

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(importedContentType: .image) { PreviewImageData(data: $0) }
  }
}
