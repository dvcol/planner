import Foundation
import PlannerCore
import Testing

struct CapturePreparationTests {
  @Test func linkOnlyTextLanesRemainInNotesWhenTheCaptureAlsoContainsProse() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCapturePreparationTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let draft) = await planner.prepareCapture(
        session: session,
        input: .direct([.text("Title"), .text("https://example.com/menu\r\n")])),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(draft.content.title == "Title")
    #expect(draft.content.notes == "https://example.com/menu\r\n")
    #expect(draft.links.map(\.originalUrl) == ["https://example.com/menu"])
    #expect(draft.saveAllowed && before == after)
  }

  @Test(arguments: CaptureInputExample.allCases)
  func emptyUnsupportedAndLinkOnlyInputsHaveExplicitDraftOutcomes(example: CaptureInputExample)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCapturePreparationTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let response = await planner.prepareCapture(session: session, input: .direct(example.inputs))
    guard case .draft(let draft) = response,
      case .exported(let after) = await planner.exportData(session: session)
    else {
      Issue.record("Capture must report this input in its transient draft: \(response)")
      return
    }
    #expect(draft.content.title == example.title)
    #expect(draft.content.notes == nil)
    #expect(draft.links.map(\.originalUrl) == example.originals)
    #expect(draft.saveAllowed == example.saveAllowed)
    #expect(draft.inputIssues.count == example.issueCount)
    #expect(
      draft.inputIssues.allSatisfy {
        $0.state == .unsupported && !$0.blocksSave && !$0.message.isEmpty
      })
    #expect(before == after)
  }

  @Test(arguments: ["directInputs", "bytes", "links"], [-1, 0, 1])
  func captureAcceptanceBudgetsReportOversizedInputsWithoutWriting(
    budget: String, boundaryOffset: Int
  ) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCapturePreparationTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let inputs: [PlannerCaptureDirectInput]
    let oversizedIndex: Int64
    switch budget {
    case "directInputs":
      inputs = (0..<(32 + boundaryOffset)).map { .url("https://example.com/?input=\($0)") }
      oversizedIndex = 32
    case "bytes":
      var text = String(repeating: "é", count: 524_288)
      if boundaryOffset < 0 { text.removeLast() }
      if boundaryOffset != 0 { text += "a" }
      inputs = [.text(text)]
      oversizedIndex = 0
    default:
      let text = (0..<(128 + boundaryOffset)).map { "https://example.com/?link=\($0)" }.joined(
        separator: "\n")
      inputs = [.text(text)]
      oversizedIndex = 0
    }
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .direct(inputs)),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    if boundaryOffset > 0 && budget != "directInputs" {
      #expect(!draft.saveAllowed)
      #expect(
        draft.inputIssues.contains {
          $0.inputIndex == oversizedIndex && $0.state == .oversized && $0.blocksSave
        })
      #expect(draft.links.count <= 128)
    } else {
      #expect(draft.saveAllowed && draft.inputIssues.isEmpty)
    }
    #expect(before == after)
  }

  @Test func exactOriginalCandidatesRetainIdentitiesAndDoNotOverwriteExistingItems() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCapturePreparationTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let exact = "https://example.com/%2f?x=%41"
    guard case .ready(let session) = await planner.bootstrap() else { throw CancellationError() }
    var identities: [UUID] = []
    for (index, original) in [exact, exact, "https://example.com/%2F?x=A"].enumerated() {
      guard
        case .applied(let result, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session,
            command: .createItem(
              content: .init(title: "Candidate \(index)", links: [.init(originalUrl: original)])))
        ).outcome, let item = result.generated.first
      else { throw CancellationError() }
      identities.append(item.id)
    }
    guard
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setCompletion(scope: .globalItem(itemId: identities[0]), done: true))
      ).outcome,
      case .applied(_, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: .setArchive(source: .init(kind: .item, id: identities[1]), archived: true))
      ).outcome,
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .direct([.url(exact)])),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(Set(draft.reuseCandidates.map(\.itemId)) == Set(identities.prefix(2)))
    #expect(
      draft.reuseCandidates.map(\.itemId)
        == identities.prefix(2).sorted { $0.uuidString < $1.uuidString })
    #expect(
      draft.reuseCandidates.allSatisfy {
        $0.matchingOriginalUrls == [exact] && $0.matchingLinkIds.count == 1
      })
    #expect(draft.reuseCandidates.first { $0.itemId == identities[0] }?.globalDone == true)
    #expect(draft.reuseCandidates.first { $0.itemId == identities[1] }?.archived == true)
    #expect(draft.content.title == "Saved link" && before == after)
    let foreign = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("foreign/store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("foreign/control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("foreign/recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let foreignSession) = await foreign.bootstrap(),
      case .rejected(let staleCancellation) = await planner.cancelCapture(
        session: session, draftId: draft.draftId, generation: UUID()),
      case .rejected(let foreignRead) = await planner.readCapture(
        session: foreignSession, draftId: draft.draftId),
      case .draft(let retained) = await planner.readCapture(
        session: session, draftId: draft.draftId)
    else { throw CancellationError() }
    #expect(staleCancellation.code == "captureDraftUnavailable")
    #expect(foreignRead.code == "staleDatasetSession")
    #expect(retained.generation == draft.generation)
  }

  @Test func independentUnicodeTextPreservesLinesAndDistinctOriginalLinkOrder() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCapturePreparationTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    let maps = "https://maps.apple.com/?q=Nezu%20Museum"
    let website = "https://example.com/%2f?x=%41"
    let text = "\r\n買い物 🛍️\r\n牛乳\r\nパン\r\n\(website)\r\n\(maps)"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .direct([.url(maps), .text(text), .url(website)])),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(draft.content.title == "買い物 🛍️")
    #expect(draft.content.notes == "牛乳\r\nパン\r\n\(website)\r\n\(maps)")
    #expect(draft.links.map(\.originalUrl) == [maps, website])
    #expect(draft.links.map(\.kind) == [.appleMaps, .website])
    #expect(Set(draft.links.map(\.linkId)).count == 2)
    #expect(draft.content.links.allSatisfy { $0.linkId == nil })
    #expect(draft.saveAllowed && draft.inputIssues.isEmpty && after == before)
  }

  @Test func preparingAndCancellingAnOriginalLinkNeverWritesPlannerData() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerCapturePreparationTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    let original = "https://maps.apple.com/?q=Nezu%20Museum&place-id=fixture-nezu"
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)]))
    else { throw CancellationError() }
    #expect(draft.content.title == "Saved link")
    #expect(draft.content.location == nil && draft.content.notes == nil)
    #expect(draft.links.map(\.originalUrl) == [original])
    #expect(draft.content.links.map(\.originalUrl) == [original])
    #expect(draft.content.links.allSatisfy { $0.linkId == nil })
    #expect(draft.saveAllowed && draft.inputIssues.isEmpty && draft.reuseCandidates.isEmpty)
    #expect(
      draft.preview.state == .notRequested && draft.preview.linkId == draft.links.first?.linkId)
    guard
      case .draft(let read) = await planner.readCapture(session: session, draftId: draft.draftId),
      case .exported(let preparedData) = await planner.exportData(session: session),
      case .cancelled = await planner.cancelCapture(
        session: session, draftId: draft.draftId, generation: draft.generation),
      case .rejected(let cancelledFailure) = await planner.readCapture(
        session: session, draftId: draft.draftId),
      case .exported(let cancelledData) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(read.draftId == draft.draftId && read.generation == draft.generation)
    #expect(preparedData == before && cancelledData == before)
    #expect(cancelledFailure.code == "captureDraftUnavailable")
    guard
      case .draft(let pending) = await planner.prepareCapture(
        session: session, input: .direct([.url(original)]))
    else { throw CancellationError() }
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .rejected(let reopenedFailure) = await reopened.readCapture(
        session: reopenedSession, draftId: pending.draftId),
      case .exported(let reopenedData) = await reopened.exportData(session: reopenedSession)
    else { throw CancellationError() }
    #expect(reopenedFailure.code == "captureDraftUnavailable" && reopenedData == before)
  }
}

enum CaptureInputExample: String, CaseIterable, Sendable {
  case empty, whitespace, linkOnly, nonWebText, mixedUnsupportedURL, invalidURLOnly

  var inputs: [PlannerCaptureDirectInput] {
    switch self {
    case .empty: []
    case .whitespace: [.text("\r\n \t\n")]
    case .linkOnly: [.text("https://example.com/%2f?x=%41")]
    case .nonWebText: [.text("file:///private/tmp/map")]
    case .mixedUnsupportedURL:
      [.url("file:///private/tmp/map"), .url("https://example.com/%2f?x=%41")]
    case .invalidURLOnly: [.url("not an absolute URL")]
    }
  }

  var title: String {
    switch self {
    case .empty, .whitespace, .invalidURLOnly: ""
    case .linkOnly, .mixedUnsupportedURL: "Saved link"
    case .nonWebText: "file:///private/tmp/map"
    }
  }

  var originals: [String] {
    switch self {
    case .linkOnly, .mixedUnsupportedURL: ["https://example.com/%2f?x=%41"]
    default: []
    }
  }

  var saveAllowed: Bool {
    switch self {
    case .linkOnly, .mixedUnsupportedURL, .nonWebText: true
    default: false
    }
  }

  var issueCount: Int {
    switch self {
    case .mixedUnsupportedURL, .invalidURLOnly: 1
    default: 0
    }
  }
}
