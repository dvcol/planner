import Foundation

extension PlannerImportReview {
  func appliedSummary(in backup: PlannerPortableBackup) throws -> PlannerImportReview {
    let projection = try PlannerImportProjection(backup: backup)

    func afterSummary(_ previous: PlannerImportOwnerSummary?) -> PlannerImportOwnerSummary? {
      guard let previous, let source = projection.sources[previous.identity.reference] else {
        return nil
      }
      return projection.summary(source, changedFields: previous.changedFieldNames)
    }

    func entries(_ previous: [PlannerImportEntry]) -> [PlannerImportEntry] {
      previous.map { entry in
        let after = afterSummary(entry.after)
        return .init(
          owner: after?.identity ?? entry.owner, reasonCode: entry.reasonCode,
          dependencies: entry.dependencies.map { dependency in
            projection.sources[dependency.reference]?.importBinding ?? dependency
          }, propertyPaths: entry.propertyPaths, before: entry.before, after: after)
      }
    }

    return .init(
      imports: entries(imports), unchanged: entries(unchanged),
      skippedConflicts: entries(skippedConflicts), skippedDependents: entries(skippedDependents),
      replacements: entries(replacements), restorations: entries(restorations),
      incomingDeletions: incomingDeletions.map { entry in
        .init(
          target: entry.target, owner: entry.owner, propertyPaths: entry.propertyPaths,
          before: entry.before, after: afterSummary(entry.after))
      }, referenceChanges: referenceChanges)
  }
}
