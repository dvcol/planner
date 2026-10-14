import PlannerCore
import SwiftUI

struct SavedBackupImportSummary: View {
  let details: PlannerImportReview

  var body: some View {
    let sourceNames = reviewedSourceNames
    recordSection("Additions", identifier: "additions", entries: details.imports)
    recordSection("Unchanged", identifier: "unchanged", entries: details.unchanged)
    recordSection("Skipped conflicts", identifier: "conflicts", entries: details.skippedConflicts)
    recordSection(
      "Skipped dependents", identifier: "dependents", entries: details.skippedDependents)
    recordSection("Replacements", identifier: "replacements", entries: details.replacements)
    recordSection("Restorations", identifier: "restorations", entries: details.restorations)
    Section {
      LabeledContent("Deletions", value: String(details.incomingDeletions.count))
        .accessibilityIdentifier("saved.import.summary.deletions")
      ForEach(details.incomingDeletions.indices, id: \.self) { index in
        let entry = details.incomingDeletions[index]
        DisclosureGroup(entry.before?.title ?? entry.after?.title ?? deletionTitle(entry.target)) {
          if let before = entry.before { ownerSummary("Before", summary: before) }
          if let after = entry.after {
            ownerSummary("After", summary: after)
          } else {
            Text("The selected data will be unavailable after import.").foregroundStyle(.secondary)
          }
          DisclosureGroup("Backup details") {
            identityRows(deletionIdentities(entry.target))
            backupPaths(entry.propertyPaths)
          }
        }
      }
    }
    Section {
      LabeledContent("Reference changes", value: String(details.referenceChanges.count))
        .accessibilityIdentifier("saved.import.summary.references")
      ForEach(details.referenceChanges.indices, id: \.self) { index in
        let change = details.referenceChanges[index]
        DisclosureGroup {
          identityRows(referenceIdentities(change.reference))
        } label: {
          VStack(alignment: .leading) {
            LabeledContent(
              referenceTitle(change.reference), value: change.change.rawValue.capitalized)
            Text(referenceContext(change.reference, sourceNames: sourceNames))
              .font(.caption).foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func recordSection(
    _ title: String, identifier: String, entries: [PlannerImportEntry]
  ) -> some View {
    Section {
      LabeledContent(title, value: String(entries.count))
        .accessibilityIdentifier("saved.import.summary.\(identifier)")
      ForEach(entries.indices, id: \.self) { index in
        let entry = entries[index]
        DisclosureGroup {
          if let before = entry.before { ownerSummary("Before", summary: before) }
          if let after = entry.after { ownerSummary("After", summary: after) }
          if let reason = reasonDescription(entry.reasonCode) {
            Text(reason).foregroundStyle(.secondary)
          }
          DisclosureGroup("Backup details") {
            identityRows([
              ("Record ID", entry.owner.id), ("Record version", entry.owner.lifetimeId),
            ])
            if !entry.dependencies.isEmpty {
              DisclosureGroup("Required records") {
                ForEach(entry.dependencies.indices, id: \.self) { index in
                  let dependency = entry.dependencies[index]
                  Text(dependency.kind.rawValue.capitalized).font(.subheadline.bold())
                  identityRows([
                    ("Record ID", dependency.id), ("Record version", dependency.lifetimeId),
                  ])
                }
              }
            }
            backupPaths(entry.propertyPaths)
          }
        } label: {
          VStack(alignment: .leading) {
            Text(entry.after?.title ?? entry.before?.title ?? entry.owner.kind.rawValue.capitalized)
            Text(entry.owner.kind.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func ownerSummary(_ title: String, summary: PlannerImportOwnerSummary) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.subheadline.bold())
      if let name = summary.title { LabeledContent("Name", value: name) }
      LabeledContent("References", value: String(summary.associationIds.count))
      DisclosureGroup("Record details") {
        identityRows([
          ("Record ID", summary.identity.id), ("Record version", summary.identity.lifetimeId),
        ])
        ForEach(summary.associationIds, id: \.self) { identifier in
          LabeledContent("Reference ID", value: identifier.uuidString)
            .font(.caption.monospaced()).textSelection(.enabled)
        }
      }
      if !summary.changedFieldNames.isEmpty {
        Text("Changed: " + summary.changedFieldNames.map(fieldTitle).joined(separator: ", "))
          .foregroundStyle(.secondary)
      }
    }
  }

  private func fieldTitle(_ name: String) -> String {
    switch name {
    case "lifetimeId": return "Restoration"
    case "contextAliases", "completionChanges": return "Completion history"
    case "expandedCompletions": return "Item completion in Itineraries"
    case "memberships": return "List contents"
    case "itineraryEntries": return "Route entries"
    case "labelAssociations": return "Categories and Tags"
    case "ownedLinks": return "Bookmarks"
    default: break
    }
    return name.replacingOccurrences(
      of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression
    )
    .capitalized
  }

  private func identityRows(_ identities: [(String, UUID)]) -> some View {
    ForEach(identities.indices, id: \.self) { index in
      LabeledContent(identities[index].0, value: identities[index].1.uuidString)
        .font(.caption.monospaced()).textSelection(.enabled)
    }
  }

  private func backupPaths(_ paths: [String]) -> some View {
    DisclosureGroup("Backup fields") {
      ForEach(paths, id: \.self) { path in
        Text(path).font(.caption.monospaced()).textSelection(.enabled)
      }
    }
  }

  private func referenceIdentities(_ reference: PlannerReferenceRead) -> [(String, UUID)] {
    switch reference {
    case .expandedCompletion(
      let itineraryIdentifier, let listEntryIdentifier, let membershipIdentifier):
      [
        ("Itinerary ID", itineraryIdentifier), ("List entry ID", listEntryIdentifier),
        ("Membership ID", membershipIdentifier),
      ]
    case .itineraryEntry(let identifier, let itinerary, let source):
      [("Entry ID", identifier), ("Itinerary ID", itinerary.id), ("Source ID", source.id)]
    case .membership(let identifier, let list, let item):
      [("Membership ID", identifier), ("List ID", list.id), ("Item ID", item.id)]
    case .ownedLink(let identifier, let owner):
      [("Bookmark ID", identifier), ("Owner ID", owner.id)]
    case .schedule(let identifier, let source):
      [("Schedule ID", identifier), ("Source ID", source.id)]
    case .labelAssociation(let identifier, let owner, let label):
      [("Association ID", identifier), ("Owner ID", owner.id), ("Label ID", label.id)]
    }
  }

  private func deletionIdentities(_ target: PlannerPortableDeletionTarget) -> [(String, UUID)] {
    switch target {
    case .source(let source, let lifetimeIdentifier):
      [("Record ID", source.id), ("Record version", lifetimeIdentifier)]
    case .membership(let identifier, let lifetimeIdentifier),
      .itineraryEntry(let identifier, let lifetimeIdentifier),
      .labelAssociation(let identifier, let lifetimeIdentifier),
      .ownedLink(let identifier, let lifetimeIdentifier):
      [("Reference ID", identifier), ("Reference version", lifetimeIdentifier)]
    case .expandedCompletion(let context):
      [
        ("List entry ID", context.listEntryId), ("List entry version", context.listEntryLifetimeId),
        ("Membership ID", context.membershipId),
        ("Membership version", context.membershipLifetimeId),
      ]
    }
  }

  private var reviewedSourceNames: [PlannerEntityReference: String] {
    var names = [PlannerEntityReference: String]()
    let entries =
      details.imports + details.unchanged + details.skippedConflicts
      + details.skippedDependents + details.replacements + details.restorations
    let summaries =
      entries.flatMap { [$0.before, $0.after].compactMap { $0 } }
      + details.incomingDeletions.flatMap { [$0.before, $0.after].compactMap { $0 } }
    for summary in summaries {
      guard let title = summary.title else { continue }
      names[.init(kind: summary.identity.kind, id: summary.identity.id)] = title
    }
    return names
  }

  private func referenceContext(
    _ reference: PlannerReferenceRead, sourceNames: [PlannerEntityReference: String]
  ) -> String {
    func name(_ source: PlannerEntityReference) -> String {
      sourceNames[source] ?? source.kind.rawValue.capitalized
    }
    switch reference {
    case .expandedCompletion(let itineraryIdentifier, _, _):
      return name(.init(kind: .itinerary, id: itineraryIdentifier))
    case .itineraryEntry(_, let itinerary, let source):
      return name(itinerary) + " · " + name(source)
    case .membership(_, let list, let item): return name(list) + " · " + name(item)
    case .ownedLink(_, let owner), .schedule(_, let owner): return name(owner)
    case .labelAssociation(_, let owner, let label): return name(owner) + " · " + name(label)
    }
  }

  private func deletionTitle(_ target: PlannerPortableDeletionTarget) -> String {
    switch target {
    case .source(let source, _): "Previously deleted " + source.kind.rawValue.capitalized
    case .membership: "Deleted List membership"
    case .itineraryEntry: "Deleted Itinerary entry"
    case .labelAssociation: "Deleted label association"
    case .ownedLink: "Deleted bookmark"
    case .expandedCompletion: "Deleted contextual completion"
    }
  }

  private func reasonDescription(_ reason: String?) -> String? {
    switch reason {
    case "matchingRecordConflict": "Keep the current record and its complete contents."
    case "deletedDependency": "A required record was deleted, so this dependent record is skipped."
    case "deletedSource": "Previously deleted data is not restored by this import."
    case "omittedOwner": "The backup omits the owner, so its partial contents are skipped."
    case "unchanged": "The represented record matches the current data."
    default: nil
    }
  }

  private func referenceTitle(_ reference: PlannerReferenceRead) -> String {
    switch reference {
    case .expandedCompletion: "Contextual completion"
    case .itineraryEntry: "Itinerary entry"
    case .membership: "List membership"
    case .ownedLink: "Bookmark"
    case .schedule: "Appointment"
    case .labelAssociation: "Shared label association"
    }
  }
}
