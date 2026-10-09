import Foundation

extension PlannerLinkInput {
  func validatedKind(propertyPath: String) throws -> PlannerLinkKind {
    guard let url = URL(string: originalUrl, encodingInvalidCharacters: false),
      let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
      let host = url.host?.lowercased(), !host.isEmpty
    else {
      throw PlannerFailure(
        "invalidInput", "A bookmark must be an absolute HTTP or HTTPS URL.",
        propertyPath: propertyPath + "/originalUrl")
    }
    if host == "maps.apple.com" || host == "maps.apple" || host.hasSuffix(".maps.apple") {
      return .appleMaps
    }
    if host == "maps.app.goo.gl" || host == "maps.google.com"
      || host == "www.google.com" && (url.path == "/maps" || url.path.hasPrefix("/maps/"))
    {
      return .googleMaps
    }
    if host == "tabelog.com" || host.hasSuffix(".tabelog.com") { return .tabelog }
    if host == "booking.com" || host.hasSuffix(".booking.com") { return .booking }
    return .website
  }

  var canonicalValue: PlannerCanonicalValue {
    .record([
      "linkId": .optional(linkId.map { .identity($0) }),
      "originalUrl": .string(originalUrl), "label": .optional(label.map { .string($0) }),
    ])
  }
}

extension PlannerOwnedLinkRead {
  var canonicalValue: PlannerCanonicalValue {
    .record([
      "linkId": .identity(linkId), "originalUrl": .string(originalUrl),
      "label": .optional(label.map { .string($0) }), "kind": .string(kind.rawValue),
      "providerReference": .optional(
        providerReference.map {
          .record(["kind": .string($0.kind.rawValue), "value": .string($0.value)])
        }),
    ])
  }
}
