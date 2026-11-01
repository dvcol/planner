import Foundation

enum PlannerSharingPermissions {
  static func validate(_ command: PlannerCommand, library: PlannerSharedLibrary) throws {
    guard library.canEdit else {
      throw PlannerFailure("sharingReadOnly", "This shared library is read only.")
    }
    guard case .selectedLists(let lists) = library.scope else { return }
    switch command {
    case .deleteSource, .createList, .createItinerary, .addItineraryEntry,
      .removeItineraryEntry, .reorderItineraryEntry, .editItinerary,
      .applyImport, .restoreRecovery:
      throw PlannerFailure(
        "sharingOwnerRequired", "The owner manages shared Lists and global deletion.")
    case .createItem(_, let list):
      guard let list, lists.contains(list) else { throw destinationRequired() }
    case .applyCapture(_, _, _, let destinations):
      guard !destinations.isEmpty, destinations.isSubset(of: lists) else {
        throw destinationRequired()
      }
    case .addMembership(_, let list, _), .removeMembership(let list, _),
      .reorderMembership(let list, _, _), .editList(let list, _, _):
      guard lists.contains(list) else { throw destinationRequired() }
    case .moveMembership(let source, _, let destination, _):
      guard lists.contains(source), lists.contains(destination) else {
        throw destinationRequired()
      }
    default: break
    }
  }

  private static func destinationRequired() -> PlannerFailure {
    .init("sharedDestinationRequired", "Choose a List included in this shared library.")
  }
}
