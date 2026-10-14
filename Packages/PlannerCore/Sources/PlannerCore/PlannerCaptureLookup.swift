import Foundation

func plannerLookupCapturePlace(_ originalURL: String, transport: any PlannerCaptureHTTPTransport)
  async -> PlannerCapturePreviewCandidate?
{
  guard var requestURL = plannerCaptureRequestURL(originalURL) else { return nil }
  let clock = ContinuousClock()
  let deadline = clock.now.advanced(by: .seconds(8))
  var visited: Set<URL> = []
  for _ in 0..<6 {
    let remaining = clock.now.duration(to: deadline)
    guard remaining > .zero, !Task.isCancelled, visited.insert(requestURL).inserted else {
      return nil
    }
    do {
      let response = try await transport.head(
        requestURL: requestURL, timeout: min(.seconds(4), remaining))
      guard clock.now < deadline, !Task.isCancelled, response.url == requestURL else { return nil }
      if (200..<300).contains(response.statusCode) {
        return plannerCapturePlaceCandidate(requestURL)
      }
      guard [301, 302, 303, 307, 308].contains(response.statusCode),
        let location = response.value(forHTTPHeaderField: "Location"),
        let relativeLocation = URL(string: location, encodingInvalidCharacters: false),
        let destination = URL(
          string: relativeLocation.relativeString, relativeTo: requestURL)?.absoluteURL,
        let validated = plannerCaptureRequestURL(destination.absoluteString)
      else { return nil }
      requestURL = validated
    } catch {
      return nil
    }
  }
  return nil
}

func plannerCaptureRequestURL(_ original: String) -> URL? {
  guard var components = URLComponents(string: original),
    components.scheme?.lowercased() == "https", let host = components.host?.lowercased()
  else { return nil }
  let allowed =
    host == "maps.apple.com" || host == "maps.apple" || host.hasSuffix(".maps.apple")
    || host == "maps.app.goo.gl" || host == "maps.google.com"
    || host == "www.google.com" && components.path.hasPrefix("/maps/")
  guard allowed else { return nil }
  components.fragment = nil
  return components.url
}

func plannerCapturePlaceCandidate(_ requestURL: URL) -> PlannerCapturePreviewCandidate? {
  if requestURL.host?.lowercased() == "www.google.com" {
    return plannerCaptureGoogleSearchCandidate(requestURL)
  }
  guard requestURL.host?.lowercased() == "maps.apple.com", requestURL.path == "/place",
    let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)
  else { return nil }
  let queryItems = components.queryItems ?? []
  let displayName = plannerCaptureQueryValue("name", in: queryItems)
  let formattedAddress = plannerCaptureQueryValue("address", in: queryItems)
  let coordinate = plannerCaptureQueryValue("coordinate", in: queryItems)
    .flatMap(plannerCaptureCoordinate)
  guard displayName != nil || formattedAddress != nil || coordinate != nil else { return nil }
  return .init(
    provider: .appleMaps, displayName: displayName, formattedAddress: formattedAddress,
    coordinate: coordinate, providerReference: nil,
    uncertaintyReasons: ["Values supplied by the Maps link; not independently verified."],
    attributionText: "Apple Maps")
}

private func plannerCaptureGoogleSearchCandidate(_ requestURL: URL)
  -> PlannerCapturePreviewCandidate?
{
  guard requestURL.path == "/maps/search/" || requestURL.path == "/maps/search",
    var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)
  else { return nil }
  components.percentEncodedQuery = components.percentEncodedQuery?
    .replacingOccurrences(of: "+", with: "%20")
  let queryItems = components.queryItems ?? []
  guard plannerCaptureQueryValue("api", in: queryItems) == "1",
    let query = plannerCaptureQueryValue("query", in: queryItems)
  else { return nil }
  let coordinate = plannerCaptureCoordinate(query)
  return .init(
    provider: .googleMaps, displayName: coordinate == nil ? query : nil, formattedAddress: nil,
    coordinate: coordinate, providerReference: nil,
    uncertaintyReasons: ["Search intent supplied by the Maps link; not a resolved place."],
    attributionText: "Google Maps")
}

private func plannerCaptureCoordinate(_ rawCoordinate: String) -> PlannerCoordinate? {
  let components = rawCoordinate.split(separator: ",", omittingEmptySubsequences: false)
  guard components.count == 2, let latitude = Double(components[0]),
    let longitude = Double(components[1]), latitude.isFinite, longitude.isFinite,
    (-90...90).contains(latitude), (-180...180).contains(longitude)
  else { return nil }
  return .init(latitude: latitude, longitude: longitude)
}

private func plannerCaptureQueryValue(_ name: String, in queryItems: [URLQueryItem]) -> String? {
  let matches = queryItems.filter { $0.name == name }
  guard matches.count == 1, let value = matches.first?.value, !value.isEmpty else { return nil }
  return value
}

extension PlannerPreparedCapture {
  func replacingPreview(_ preview: PlannerCapturePreview) -> PlannerPreparedCapture {
    let observed = PlannerCaptureDraftRead(
      draftId: read.draftId, generation: read.generation, content: read.content,
      links: read.links, inputIssues: read.inputIssues, preview: preview,
      reuseCandidates: read.reuseCandidates, saveAllowed: read.saveAllowed)
    return .init(
      session: session, read: observed, contentOrigins: contentOrigins,
      retainedInputs: retainedInputs, overrides: overrides)
  }
}
