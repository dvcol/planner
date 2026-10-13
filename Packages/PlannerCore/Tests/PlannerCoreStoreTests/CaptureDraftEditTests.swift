import Foundation
import PlannerCore
import Testing

struct CaptureDraftEditTests {
  @Test(arguments: [false, true])
  func linkReplacementRecalculatesFallbackAndPreservesAnExplicitTitle(startsEmpty: Bool)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureDraftEditTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: captureEditConfiguration(directory))
    var inputs: [PlannerCaptureDirectInput] = []
    if !startsEmpty { inputs = [.url("https://example.com/original")] }
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct(inputs)),
      case .draft(let empty) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        edit: .init(changes: .init(links: .set([]))))
    else { throw CancellationError() }
    #expect(empty.content.title.isEmpty && empty.links.isEmpty && !empty.saveAllowed)
    guard
      case .draft(let linked) = await planner.updateCapture(
        session: session, draftId: empty.draftId, generation: empty.generation,
        edit: .init(changes: .init(links: .set([.init(originalUrl: "https://example.com/new")])))),
      case .draft(let titled) = await planner.updateCapture(
        session: session, draftId: linked.draftId, generation: linked.generation,
        edit: .init(changes: .init(title: .set("Saved link")))),
      case .draft(let explicitlyTitled) = await planner.updateCapture(
        session: session, draftId: titled.draftId, generation: titled.generation,
        edit: .init(changes: .init(links: .set([])))),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(linked.content.title == "Saved link" && linked.links.count == 1 && linked.saveAllowed)
    #expect(
      explicitlyTitled.content.title == "Saved link" && explicitlyTitled.links.isEmpty
        && explicitlyTitled.saveAllowed)
    #expect(after == before)
  }

  @Test(arguments: [127, 128, 129])
  func editedLinksRespectTheDistinctLinkBudgetWithoutPartialChanges(count: Int) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureDraftEditTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: captureEditConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url("https://example.com/original")]))
    else { throw CancellationError() }
    let response = await planner.updateCapture(
      session: session, draftId: prepared.draftId, generation: prepared.generation,
      edit: .init(
        changes: .init(
          links: .set((0..<count).map { .init(originalUrl: "https://example.com/\($0)") }))))
    if count <= 128 {
      guard case .draft(let edited) = response else {
        Issue.record("The accepted link budget must remain usable: \(response)")
        return
      }
      #expect(edited.links.count == count && edited.saveAllowed)
    } else {
      guard case .rejected(let failure) = response,
        case .draft(let unchanged) = await planner.readCapture(
          session: session, draftId: prepared.draftId)
      else {
        Issue.record("An over-budget edit must not partially alter the draft: \(response)")
        return
      }
      #expect(failure.code == "captureInputFailure" && failure.propertyPath == "/changes/links")
      #expect(unchanged.generation == prepared.generation && unchanged.links == prepared.links)
    }
  }

  @Test func retryingRetainedDirectInputKeepsOwnEditsAndCurrentLinkIdentities() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureDraftEditTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: captureEditConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url("https://example.com/visit")])),
      case .draft(let edited) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        edit: .init(changes: .init(title: .set("My title"), notes: .set("My note"))))
    else { throw CancellationError() }
    let response = await planner.updateCapture(
      session: session, draftId: edited.draftId, generation: edited.generation,
      edit: .init(retryInputIndexes: [0]))
    guard case .draft(let retried) = response,
      case .exported(let after) = await planner.exportData(session: session)
    else {
      Issue.record(
        "A retained direct input must be re-evaluated without replacing own fields: \(response)")
      return
    }
    #expect(retried.generation != edited.generation && retried.content == edited.content)
    #expect(retried.links == edited.links && retried.saveAllowed && after == before)
  }

  @Test(arguments: [
    "blankTitle", "coordinate", "category", "tag", "removeUnknown", "retryUnknown", "bothActions",
    "unavailableRetry", "empty",
  ])
  func rejectedCaptureEditsLeaveTheCompleteDraftUnchanged(scenario: String) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureDraftEditTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: captureEditConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session,
        input: .direct([
          .url("https://example.com/visit"), .text(String(repeating: "a", count: 1_048_577)),
        ]))
    else { throw CancellationError() }
    let edit: PlannerCaptureEdit
    let expectedCode: String
    let expectedPath: String
    switch scenario {
    case "blankTitle":
      edit = .init(changes: .init(title: .set(" ")))
      expectedCode = "invalidInput"
      expectedPath = "/changes/title"
    case "coordinate":
      edit = .init(
        changes: .init(
          title: .set("Must not apply"),
          location: .set(
            .init(
              displayName: nil, formattedAddress: nil, coordinate: .init(latitude: 91, longitude: 0)
            ))))
      expectedCode = "invalidInput"
      expectedPath = "/changes/location/coordinate"
    case "category":
      edit = .init(changes: .init(title: .set("Must not apply"), categoryIds: .set([UUID()])))
      expectedCode = "missingReference"
      expectedPath = "/changes/categoryIds"
    case "tag":
      edit = .init(changes: .init(title: .set("Must not apply"), tagIds: .set([UUID()])))
      expectedCode = "missingReference"
      expectedPath = "/changes/tagIds"
    case "removeUnknown":
      edit = .init(removeInputIndexes: [-1])
      expectedCode = "invalidInput"
      expectedPath = "/removeInputIndexes"
    case "retryUnknown":
      edit = .init(retryInputIndexes: [99])
      expectedCode = "invalidInput"
      expectedPath = "/retryInputIndexes"
    case "bothActions":
      edit = .init(removeInputIndexes: [0], retryInputIndexes: [0])
      expectedCode = "invalidInput"
      expectedPath = "/retryInputIndexes"
    case "unavailableRetry":
      edit = .init(changes: .init(title: .set("Must not apply")), retryInputIndexes: [1])
      expectedCode = "captureInputFailure"
      expectedPath = "/retryInputIndexes"
    default:
      edit = .init()
      expectedCode = "invalidInput"
      expectedPath = "/changes"
    }
    let response = await planner.updateCapture(
      session: session, draftId: prepared.draftId, generation: prepared.generation, edit: edit)
    guard case .rejected(let failure) = response,
      case .draft(let read) = await planner.readCapture(session: session, draftId: prepared.draftId)
    else {
      Issue.record("Invalid \(scenario) edit must reject together: \(response)")
      return
    }
    #expect(failure.code == expectedCode && failure.propertyPath == expectedPath)
    #expect(read.generation == prepared.generation && read.content == prepared.content)
    #expect(read.links == prepared.links && read.inputIssues == prepared.inputIssues)
    #expect(read.saveAllowed == prepared.saveAllowed)
  }

  @Test func linkEditsRetainDraftBindingsAndNewIdentitiesAcrossLaterOwnEdits() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureDraftEditTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: captureEditConfiguration(directory))
    let maps = "https://maps.apple.com/?q=Museum"
    let website = "https://example.com/%2f?x=%41"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(maps), .url(website)]))
    else { throw CancellationError() }
    let mapIdentifier = try #require(prepared.links.first?.linkId)
    let websiteIdentifier = try #require(prepared.links.last?.linkId)
    let response = await planner.updateCapture(
      session: session, draftId: prepared.draftId, generation: prepared.generation,
      edit: .init(
        changes: .init(
          links: .set([
            .init(linkId: websiteIdentifier, originalUrl: website, label: "Menu"),
            .init(linkId: mapIdentifier, originalUrl: maps, label: "Museum"),
            .init(originalUrl: "https://example.com/extra", label: "Extra"),
          ]))))
    guard case .draft(let edited) = response,
      case .draft(let noted) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: edited.generation,
        edit: .init(changes: .init(notes: .set("My note")))),
      case .rejected(let foreignLink) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: noted.generation,
        edit: .init(changes: .init(links: .set([.init(linkId: UUID(), originalUrl: website)])))),
      case .draft(let read) = await planner.readCapture(session: session, draftId: prepared.draftId),
      case .exported(let after) = await planner.exportData(session: session)
    else {
      Issue.record("Link edits must preserve bindings through subsequent draft edits: \(response)")
      return
    }
    #expect(edited.links.map(\.originalUrl) == [website, maps, "https://example.com/extra"])
    #expect(edited.links.prefix(2).map(\.linkId) == [websiteIdentifier, mapIdentifier])
    #expect(Set(edited.links.map(\.linkId)).count == 3)
    #expect(noted.links == edited.links && noted.content.notes == "My note")
    #expect(noted.content.links.allSatisfy { $0.linkId == nil })
    #expect(
      foreignLink.code == "invalidInput" && foreignLink.propertyPath == "/changes/links/0/linkId")
    #expect(read.generation == noted.generation && read.links == noted.links && after == before)
  }

  @Test func removingInputPathsPreservesSurvivingLinkIdentitiesAndExplicitClear() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureDraftEditTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: captureEditConfiguration(directory))
    let maps = "https://maps.apple.com/?q=Museum"
    let website = "https://example.com/menu"
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session,
        input: .direct([.text("Title\nOriginal notes"), .url(maps), .text("\(website)\n\(maps)")])),
      case .draft(let cleared) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        edit: .init(changes: .init(notes: .clear))),
      case .draft(let onePathRemoved) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: cleared.generation,
        edit: .init(removeInputIndexes: [1])),
      case .draft(let allLinkPathsRemoved) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: onePathRemoved.generation,
        edit: .init(removeInputIndexes: [2])),
      case .draft(let empty) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: allLinkPathsRemoved.generation,
        edit: .init(removeInputIndexes: [0])),
      case .rejected(let alreadyRemoved) = await planner.updateCapture(
        session: session, draftId: empty.draftId, generation: empty.generation,
        edit: .init(removeInputIndexes: [1])),
      case .draft(let retained) = await planner.readCapture(
        session: session, draftId: empty.draftId)
    else { throw CancellationError() }
    #expect(onePathRemoved.links.map(\.originalUrl) == [website, maps])
    #expect(Set(onePathRemoved.links.map(\.linkId)) == Set(prepared.links.map(\.linkId)))
    #expect(onePathRemoved.content.notes == nil && allLinkPathsRemoved.content.notes == nil)
    #expect(allLinkPathsRemoved.links.isEmpty && allLinkPathsRemoved.saveAllowed)
    #expect(empty.links.isEmpty && empty.content.title.isEmpty && !empty.saveAllowed)
    #expect(
      alreadyRemoved.code == "invalidInput" && alreadyRemoved.propertyPath == "/removeInputIndexes")
    #expect(retained.generation == empty.generation)
  }

  @Test func removingOversizedInputUnblocksDraftAndPreservesExplicitEdits() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureDraftEditTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: captureEditConfiguration(directory))
    let original = "https://example.com/visit"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session,
        input: .direct([.url(original), .text(String(repeating: "a", count: 1_048_577))])),
      case .draft(let edited) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        edit: .init(changes: .init(title: .set("My visit"), notes: .set("Keep my own note"))))
    else { throw CancellationError() }
    #expect(!prepared.saveAllowed && prepared.inputIssues.first?.inputIndex == 1)
    #expect(!edited.saveAllowed)
    let response = await planner.updateCapture(
      session: session, draftId: edited.draftId, generation: edited.generation,
      edit: .init(removeInputIndexes: [1]))
    guard case .draft(let removed) = response,
      case .exported(let after) = await planner.exportData(session: session)
    else {
      Issue.record("Explicit input removal must unblock the reviewed draft: \(response)")
      return
    }
    #expect(removed.generation != edited.generation && removed.draftId == edited.draftId)
    #expect(removed.content.title == "My visit" && removed.content.notes == "Keep my own note")
    #expect(removed.links == prepared.links && removed.inputIssues.isEmpty && removed.saveAllowed)
    #expect(after == before)
  }

  @Test func ownEditsRotateGenerationPreserveOriginalLinksAndNeverWriteSavedData() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCaptureDraftEditTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: captureEditConfiguration(directory))
    let original = "https://maps.apple.com/?q=Nezu%20Museum"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)])),
      case .draft(let edited) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        edit: .init(changes: .init(title: .set("Museum visit"), notes: .set("My own note\r\n")))),
      case .rejected(let oldEdit) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        edit: .init(changes: .init(title: .set("Obsolete title")))),
      case .rejected(let oldCancel) = await planner.cancelCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation),
      case .draft(let read) = await planner.readCapture(session: session, draftId: prepared.draftId),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(edited.draftId == prepared.draftId && edited.generation != prepared.generation)
    #expect(edited.content.title == "Museum visit" && edited.content.notes == "My own note\r\n")
    #expect(edited.links == prepared.links)
    #expect(edited.content.links.map(\.originalUrl) == [original])
    #expect(edited.content.links.allSatisfy { $0.linkId == nil })
    #expect(edited.saveAllowed && edited.preview.state == .notRequested)
    #expect(
      oldEdit.code == "captureDraftUnavailable" && oldCancel.code == "captureDraftUnavailable")
    #expect(read.generation == edited.generation && read.content == edited.content)
    #expect(after == before)
  }
}

private func captureEditConfiguration(_ directory: URL) -> PlannerStorageConfiguration {
  .init(
    storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
    controlURL: directory.appendingPathComponent("control/writer"),
    recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
    processRole: .mainApplication, storageMode: .localOnly)
}
