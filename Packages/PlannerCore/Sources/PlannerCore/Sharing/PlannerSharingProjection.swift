import Foundation

/// Select record identities, never copies, for the one scoped sharing hierarchy.
struct PlannerSharingProjection {
  let names: Set<String>

  init(nodes: [PlannerCloudNode], scope: PlannerSharingScope) throws {
    switch scope {
    case .off:
      names = []
      return
    case .wholeLibrary:
      names = Set(nodes.map(\.name))
      return
    case .selectedLists(let lists):
      guard !lists.isEmpty else {
        throw PlannerFailure("invalidInput", "Choose at least one List to share.")
      }
      var included: Set<String> = []
      var identities: [String: Set<UUID>] = ["list": lists]
      let availableLists = try Set(nodes.filter { $0.kind == "list" }.map { try $0.uuid("id") })
      guard lists.isSubset(of: availableLists) else {
        throw PlannerFailure("staleSharingScope", "A selected List is no longer available.")
      }
      for node in nodes where node.kind == "membership" {
        if lists.contains(try node.uuid("listId")) {
          included.insert(node.name)
          identities["membership", default: []].insert(try node.uuid("id"))
          identities["item", default: []].insert(try node.uuid("itemId"))
        }
      }
      func includes(_ kind: String, _ identifier: UUID) -> Bool {
        identities[kind]?.contains(identifier) == true
      }
      for node in nodes
      where node.kind == "ownedLink" || node.kind == "schedule"
        || node.kind == "labelAssociation"
      {
        let ownerKind: String = try node.value(node.kind == "schedule" ? "sourceKind" : "ownerKind")
        let owner = try node.uuid(node.kind == "schedule" ? "sourceId" : "ownerId")
        guard includes(ownerKind, owner) else { continue }
        included.insert(node.name)
        identities[node.kind, default: []].insert(try node.uuid("id"))
        if node.kind == "labelAssociation" {
          let kind: String = try node.value("labelKind")
          identities[kind, default: []].insert(try node.uuid("labelId"))
        }
      }
      for node in nodes where ["list", "item", "category", "tag"].contains(node.kind) {
        if includes(node.kind, try node.uuid("id")) { included.insert(node.name) }
      }
      // Retired memberships preserve strict Remove authority for the selected sources.
      for node in nodes where node.kind == "membershipProvenance" {
        let binding: PlannerPortableMembershipProvenance = try node.payload()
        if lists.contains(binding.list.id), includes("item", binding.item.id) {
          included.insert(node.name)
          identities["membership", default: []].insert(binding.membershipId)
        }
      }
      var deletionIdentifiers: Set<UUID> = []
      for node in nodes where node.kind == "deletionMarker" {
        let kind: String = try node.value("sourceKind")
        if includes(kind, try node.uuid("sourceId")) {
          included.insert(node.name)
          deletionIdentifiers.insert(try node.uuid("deletionId"))
        }
      }
      func includesContext(_ context: PlannerPortableCompletionContext) -> Bool {
        guard case .listMembership(let identifier, _) = context else { return false }
        return includes("membership", identifier)
      }
      for node in nodes where node.kind == "lineageRecord" {
        let kind: String = try node.value("recordKind")
        let keep: Bool
        switch kind {
        case "contextAlias":
          let alias: PlannerPortableContextAlias = try node.payload()
          keep = includesContext(alias.context) && includesContext(alias.canonicalContext)
        case "completionChange":
          let change: PlannerPortableCompletionChange = try node.payload()
          keep = includesContext(change.context)
        case "restorationFamily":
          let family: PlannerPortableRestorationFamily = try node.payload()
          keep = includes(family.predecessor.kind.rawValue, family.predecessor.id)
        case "membershipRemoval":
          let removal: PlannerPortableMembershipRemoval = try node.payload()
          keep = deletionIdentifiers.contains(removal.deletionId)
        case "deletionMarker":
          keep = false  // Expanded itinerary history is never part of a List-only share.
        default:
          throw PlannerFailure("unsupportedVersion", "Update Plan 2Do before sharing this history.")
        }
        if keep { included.insert(node.name) }
      }
      names = included
    }
  }
}

extension PlannerCloudNode {
  func value<Value: Decodable>(_ key: String) throws -> Value {
    guard let data = fields[key] else {
      throw PlannerFailure("cloudRecordInvalid", "A shared record is missing a required field.")
    }
    return try JSONDecoder().decode(Value.self, from: data)
  }

  func uuid(_ key: String) throws -> UUID { try value(key) }

  func payload<Value: Decodable>() throws -> Value {
    let data: Data = try value("recordData")
    return try JSONDecoder().decode(Value.self, from: data)
  }
}
