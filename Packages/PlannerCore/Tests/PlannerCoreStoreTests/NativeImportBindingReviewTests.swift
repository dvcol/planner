import Foundation
import PlannerCore
import Testing

struct NativeImportBindingReviewTests {
  enum BindingCase: CaseIterable { case live, missing, wrongLifetime }

  @Test(arguments: BindingCase.allCases)
  func declaredNewOwnerResolvesItsExternalItemOrRejectsTheWholeReview(bindingCase: BindingCase)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .createItem(content: .init(title: "Current museum")))
      ).outcome,
      let item = created.generated.first,
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    var object = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
    let currentItem = try #require((object["sources"] as? [[String: Any]])?.first)
    let itemId =
      bindingCase == .missing ? "00000000-0000-4000-8000-000000000199" : item.id.uuidString
    let itemLifetime =
      bindingCase == .wrongLifetime
      ? "00000000-0000-4000-8000-000000000999" : try #require(currentItem["lifetimeId"] as? String)
    object["sources"] = [
      [
        "kind": "list", "id": "00000000-0000-4000-8000-000000000277",
        "lifetimeId": "00000000-0000-4000-8000-000000000827",
        "createdAt": 10.25, "updatedAt": 20.125,
        "content": [
          "name": "New plan", "notes": NSNull(), "color": NSNull(), "iconName": NSNull(),
        ],
        "globalDone": NSNull(), "archived": false, "contentOrigins": ["name": "independent"],
      ]
    ]
    object["memberships"] = [
      [
        "id": "00000000-0000-4000-8000-000000000477",
        "lifetimeId": "00000000-0000-4000-8000-000000000477",
        "list": [
          "kind": "list", "id": "00000000-0000-4000-8000-000000000277",
          "lifetimeId": "00000000-0000-4000-8000-000000000827",
        ],
        "item": ["kind": "item", "id": itemId, "lifetimeId": itemLifetime],
        "rank": "1024", "localDone": false,
      ]
    ]
    guard
      case .decoded(let decoded) = planner.decodeImport(
        try JSONSerialization.data(withJSONObject: object))
    else { throw CancellationError() }
    #expect(decoded.externalBindings.count == 1)
    let response = await planner.prepareReview(
      session: session, command: .applyImport(backup: decoded))
    if bindingCase == .live {
      guard case .reviewed(let review) = response else {
        Issue.record("Use the current live external Item for a complete new List: \(response)")
        return
      }
      let details = try #require(review.impact.importDetails)
      #expect(details.imports.count == 1 && details.imports.first?.after?.title == "New plan")
      #expect(details.imports.first?.dependencies.first?.id == item.id)
      #expect(details.skippedConflicts.isEmpty && details.skippedDependents.isEmpty)
      #expect(
        details.unchanged.isEmpty && details.replacements.isEmpty && details.restorations.isEmpty)
      #expect(details.referenceChanges.count == 1 && details.referenceChanges.first?.change == .add)
    } else {
      guard case .failed(let failure) = response else {
        Issue.record("Reject every unresolved binding before issuing an import review.")
        return
      }
      #expect(failure.code == "missingReference")
      #expect(
        failure.propertyPath
          == (bindingCase == .missing ? "/memberships/0/item/id" : "/memberships/0/item/lifetimeId")
      )
    }
    guard case .exported(let after) = await planner.exportData(session: session) else {
      throw CancellationError()
    }
    #expect(before == after)
  }
}
