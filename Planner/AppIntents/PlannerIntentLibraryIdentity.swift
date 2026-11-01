import Foundation

#if !PLANNER_FIXTURES
  import AppIntents

  /// Saved choices carry their source identity and an explicit originating library.
  protocol PlannerLibraryBoundEntity: AppEntity where ID == String {
    var recordIdentifier: UUID { get }
    var libraryBinding: String { get }
  }

  extension PlannerLibraryBoundEntity {
    var id: String {
      plannerEncodeIntentIdentifier(recordIdentifier.uuidString, binding: libraryBinding)
    }

    @MainActor func sourceIdentifier(in store: SavedPlannerStore) throws -> UUID {
      _ = try plannerResolveIntentIdentifier(id, store: store)
      return recordIdentifier
    }
  }

  func plannerEncodeIntentIdentifier(_ identifier: String, binding: String) -> String {
    if identifier.hasPrefix("library2|") || binding.isEmpty { return identifier }
    return "library2|" + binding + "|" + identifier
  }

  /// Legacy manually supplied choices remain personal-only; shared choices must be bound.
  @MainActor func plannerResolveIntentIdentifier(_ identifier: String, store: SavedPlannerStore)
    throws -> String
  {
    let fields = identifier.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
    if fields.count == 3, fields[0] == "library2",
      String(fields[1]) == store.appIntentLibraryBinding, !fields[2].isEmpty
    {
      return String(fields[2])
    }
    if !identifier.contains("|"), store.activeLibrary == nil { return identifier }
    throw PlannerIntentLibraryFailure()
  }

  private struct PlannerIntentLibraryFailure: LocalizedError {
    var errorDescription: String? {
      "This choice belongs to another library. Choose it again from the current library."
    }
  }
#endif
