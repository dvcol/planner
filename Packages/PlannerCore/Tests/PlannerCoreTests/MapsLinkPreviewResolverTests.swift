import Foundation
import PlannerCore
import Testing

struct MapsLinkPreviewResolverTests {
  @Test func aShortenedMapsLinkUsesTheExistingBoundedRedirectTransport() async throws {
    let transport = RedirectingMapsPreviewHTTPTransport()
    let resolver = PlannerMapsLinkResolver(transport: transport)
    let candidate = try #require(
      await resolver.preview(originalURL: "https://maps.apple/short-preview#retained"))
    #expect(candidate.provider == .appleMaps)
    #expect(candidate.displayName == "Museum")
    #expect(candidate.coordinate?.latitude == 35)
    #expect(candidate.coordinate?.longitude == 139)
    #expect(
      candidate.uncertaintyReasons == [
        "Values supplied by the Maps link; not independently verified."
      ])
    #expect(
      await transport.requestedURLs == [
        "https://maps.apple/short-preview",
        "https://maps.apple.com/place?name=Museum&coordinate=35,139",
      ])
  }

  @Test func textSearchIsNotInventedAsAResolvedPlace() async throws {
    let transport = UnexpectedMapsPreviewHTTPTransport()
    let candidate = try #require(
      await PlannerMapsLinkResolver(transport: transport).preview(
        originalURL: "https://www.google.com/maps/search/?api=1&query=museum+near+Tokyo"))
    #expect(candidate.displayName == "museum near Tokyo")
    #expect(candidate.formattedAddress == nil)
    #expect(candidate.coordinate == nil)
    #expect(candidate.providerReference == nil)
    #expect(await transport.requestedURLs.isEmpty)
  }

  @Test(arguments: ["https://example.com/maps", "http://maps.apple.com/place?coordinate=35,139"])
  func ineligibleURLsDoNotStartHTTP(_ originalURL: String) async {
    let transport = UnexpectedMapsPreviewHTTPTransport()
    let result = await PlannerMapsLinkResolver(transport: transport).preview(
      originalURL: originalURL)
    #expect(result == nil)
    #expect(await transport.requestedURLs.isEmpty)
  }

  @Test func suppliedGoogleCoordinatesProduceATemporarySearchPreviewWithoutHTTP() async throws {
    let transport = UnexpectedMapsPreviewHTTPTransport()
    let resolver = PlannerMapsLinkResolver(transport: transport)
    let originalURL =
      "https://www.google.com/maps/search/?api=1&query=35.6804%2C139.7690#original-fragment"

    let candidate = try #require(await resolver.preview(originalURL: originalURL))

    #expect(candidate.provider == .googleMaps)
    #expect(candidate.displayName == nil)
    #expect(candidate.formattedAddress == nil)
    #expect(candidate.coordinate?.latitude == 35.6804)
    #expect(candidate.coordinate?.longitude == 139.7690)
    #expect(candidate.attributionText == "Google Maps")
    #expect(
      candidate.uncertaintyReasons == [
        "Search intent supplied by the Maps link; not a resolved place."
      ])
    #expect(await transport.requestedURLs.isEmpty)
  }
}

private actor RedirectingMapsPreviewHTTPTransport: PlannerCaptureHTTPTransport {
  private(set) var requestedURLs: [String] = []

  func head(requestURL: URL, timeout: Duration) async throws -> HTTPURLResponse {
    requestedURLs.append(requestURL.absoluteString)
    let isShortLink = requestURL.host == "maps.apple"
    var headers: [String: String] = [:]
    if isShortLink {
      headers["Location"] = "https://maps.apple.com/place?name=Museum&coordinate=35,139"
    }
    return try #require(
      HTTPURLResponse(
        url: requestURL, statusCode: isShortLink ? 302 : 200,
        httpVersion: "HTTP/1.1", headerFields: headers))
  }
}

private actor UnexpectedMapsPreviewHTTPTransport: PlannerCaptureHTTPTransport {
  private(set) var requestedURLs: [URL] = []

  func head(requestURL: URL, timeout: Duration) async throws -> HTTPURLResponse {
    requestedURLs.append(requestURL)
    throw URLError(.cannotConnectToHost)
  }
}
