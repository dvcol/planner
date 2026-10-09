import Foundation

/// Read-only fixture projection for native layout review.
struct NavigationPrototypeFixture: Decodable {
  struct Source: Decodable, Identifiable {
    struct Content: Decodable {
      let title: String?
      let name: String?
      let notes: String?
    }

    let kind: String
    let id: UUID
    let content: Content
    let globalDone: Bool?
    let archived: Bool?

    var title: String { content.title ?? content.name ?? "Untitled" }
  }

  struct Reference: Decodable {
    let id: UUID
  }

  struct Membership: Decodable {
    let id: UUID
    let list: Reference
    let item: Reference
    let localDone: Bool
  }

  struct Entry: Decodable {
    let id: UUID
    let itinerary: Reference
    let source: Reference
    let localDone: Bool?
  }

  struct ExpandedCompletion: Decodable {
    struct Context: Decodable {
      let listEntryId: UUID
      let membershipId: UUID
    }

    let context: Context
    let localDone: Bool
  }

  struct Appearance: Identifiable, Hashable {
    let id: String
    let sourceId: UUID
    let associationId: UUID
    let localDone: Bool
    let contextName: String
  }

  let sources: [Source]
  let memberships: [Membership]
  let itineraryEntries: [Entry]
  let expandedCompletions: [ExpandedCompletion]

  static func load() throws -> Self {
    guard let url = Bundle.main.url(forResource: "portable-backup-v1", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
  }

  func source(_ sourceId: UUID) -> Source? {
    sources.first { $0.id == sourceId }
  }

  func appearances(in container: Source) -> [Appearance] {
    if container.kind == "list" {
      return memberships.filter { $0.list.id == container.id }.map {
        Appearance(
          id: $0.id.uuidString, sourceId: $0.item.id, associationId: $0.id,
          localDone: $0.localDone, contextName: "List appearance")
      }
    }
    return itineraryEntries.filter { $0.itinerary.id == container.id }.flatMap { entry in
      guard let referencedSource = source(entry.source.id) else { return [Appearance]() }
      if referencedSource.kind == "item" {
        return [
          Appearance(
            id: entry.id.uuidString, sourceId: referencedSource.id, associationId: entry.id,
            localDone: entry.localDone ?? false, contextName: "Itinerary appearance")
        ]
      }
      return memberships.filter { $0.list.id == referencedSource.id }.map { membership in
        let completion = expandedCompletions.first {
          $0.context.listEntryId == entry.id && $0.context.membershipId == membership.id
        }
        return Appearance(
          id: "\(entry.id.uuidString)/\(membership.id.uuidString)",
          sourceId: membership.item.id, associationId: membership.id,
          localDone: completion?.localDone ?? false, contextName: "Itinerary list appearance")
      }
    }
  }

  func isDone(_ appearance: Appearance) -> Bool {
    source(appearance.sourceId)?.globalDone == true || appearance.localDone
  }

  func progress(in container: Source) -> String {
    let children = appearances(in: container)
    guard !children.isEmpty else { return "No items" }
    return "\(children.filter(isDone).count) of \(children.count) done"
  }
}
