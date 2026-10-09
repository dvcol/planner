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

extension PlannerItemChanges {
  func linkBindings(in item: ItemSnapshot) throws -> [PlannerBoundIdentity] {
    guard case .set(let inputs) = links else { return [] }
    return try inputs.enumerated().compactMap { index, input in
      guard let link = try retainedLink(input, index: index, in: item) else { return nil }
      return PlannerBoundIdentity(kind: "ownedLink", id: link.id, lifetimeId: link.lifetimeId)
    }
  }

  func applyingLinks(to item: ItemSnapshot) throws -> [OwnedLinkSnapshot] {
    guard case .set(let inputs) = links else { return item.links }
    return try inputs.enumerated().map { index, input in
      let previous = try retainedLink(input, index: index, in: item)
      return OwnedLinkSnapshot(
        id: previous?.id ?? UUID(), lifetimeId: previous?.lifetimeId ?? UUID(), rank: Int64(index),
        originalUrl: input.originalUrl, label: input.label,
        kind: try input.validatedKind(propertyPath: "/command/changes/links/\(index)"))
    }
  }

  private func retainedLink(_ input: PlannerLinkInput, index: Int, in item: ItemSnapshot) throws
    -> OwnedLinkSnapshot?
  {
    guard let identifier = input.linkId else { return nil }
    guard let existing = item.links.first(where: { $0.id == identifier }) else {
      throw PlannerFailure(
        "invalidInput", "An existing owned link must belong to this Item and its lifetime.",
        propertyPath: "/command/changes/links/\(index)/linkId")
    }
    return existing
  }
}
