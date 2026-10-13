import Foundation
import PlannerCore
import Testing
import UniformTypeIdentifiers

@Suite(.serialized)
struct NativeCaptureLoadingTests {
  @Test @MainActor
  func mixedFileAndWebRepresentationsKeepTheUsableWebLinkWithoutLoadingFileContent()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: UTType.fileURL.identifier, visibility: .all
    ) { completion in
      Issue.record("The file representation must never be loaded.")
      completion(Data("file:///private/tmp/attachment".utf8), nil)
      return nil
    }
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      completion(Data("https://example.com/visit".utf8), nil)
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    #expect(draft.links.map(\.originalUrl) == ["https://example.com/visit"] && draft.saveAllowed)
    #expect(draft.inputIssues.contains { $0.state == .unsupported && !$0.blocksSave })
  }

  @Test(arguments: [String.Encoding.utf8, .utf16, .utf32]) @MainActor
  func genericPlainTextUsesNativeEncodingDetectionWithoutPromotingDescriptions(
    encoding: String.Encoding
  ) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let provider = NSItemProvider()
    let data = try #require("食事 🥢 https://example.com/visit".data(using: encoding))
    provider.registerDataRepresentation(
      forTypeIdentifier: UTType.plainText.identifier, visibility: .all
    ) { completion in
      completion(data, nil)
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    #expect(draft.links.map(\.originalUrl) == ["https://example.com/visit"])
    #expect(draft.saveAllowed && draft.content.title == "Saved link" && draft.content.notes == nil)
    #expect(draft.inputIssues.contains { $0.state == .held && $0.message.contains("食事 🥢") })
  }

  @Test(arguments: [127, 128, 129]) @MainActor
  func nativeTextLinksShareTheDistinctLinkLimit(count: Int) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let text = (0..<count).map { "https://example.com/\($0)" }.joined(separator: "\n")
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all
    ) { completion in
      completion(Data(text.utf8), nil)
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    if count <= 128 {
      #expect(draft.links.count == count && draft.saveAllowed)
    } else {
      #expect(
        draft.links.isEmpty && !draft.saveAllowed
          && draft.inputIssues.contains { $0.state == .oversized && $0.blocksSave })
    }
  }

  @Test @MainActor
  func loadedDescriptionsStayTemporaryAcrossRetryOwnEditsAndReviewedSave() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      completion(Data("https://example.com/visit".utf8), nil)
      return nil
    }
    provider.registerDataRepresentation(
      forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all
    ) { completion in
      completion(Data("Provider title\nProvider address\nhttps://example.com/visit".utf8), nil)
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .loaded(loaded)),
      case .draft(let edited) = await planner.updateCapture(
        session: session, draftId: prepared.draftId,
        generation: prepared.generation, edit: .init(changes: .init(title: .set("My museum")))),
      case .draft(let retried) = await planner.updateCapture(
        session: session, draftId: edited.draftId,
        generation: edited.generation, edit: .init(retryInputIndexes: [1])),
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyCapture(
          draftId: retried.draftId, draftGeneration: retried.generation,
          choice: .createNew, listIds: [])),
      case .applied(let result, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session,
          command: review.command, reviewToken: review.reviewToken)
      ).outcome,
      let item = result.generated.first,
      case .source(.item(let saved)) = await planner.read(session: session, request: .source(item)),
      case .exported(let data) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(
      retried.content.title == "My museum" && retried.content.notes == nil
        && retried.links == edited.links)
    #expect(
      saved.content.title == "My museum" && saved.content.notes == nil
        && saved.content.location == nil)
    #expect(saved.content.links.map(\.originalUrl) == ["https://example.com/visit"])
    let backupText = String(decoding: data, as: UTF8.self)
    #expect(!backupText.contains("Provider title") && !backupText.contains("Provider address"))
  }

  @Test(arguments: ["utf8", "utf16"], [-1, 0, 1]) @MainActor
  func decodedByteBudgetIncludesAllRepresentationsAndHeldText(encodingName: String, offset: Int)
    async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = "https://example.com/visit"
    let text = String(repeating: "x", count: 1_048_576 + offset - original.utf8.count)
    var textType = UTType.utf8PlainText
    var encoding = String.Encoding.utf8
    if encodingName == "utf16" {
      textType = .utf16PlainText
      encoding = .utf16
    }
    let data = try #require(text.data(using: encoding))
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      completion(Data(original.utf8), nil)
      return nil
    }
    provider.registerDataRepresentation(forTypeIdentifier: textType.identifier, visibility: .all) {
      completion in
      completion(data, nil)
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    #expect(
      draft.content.title == "Saved link" && draft.content.notes == nil
        && draft.links.map(\.originalUrl) == [original])
    if offset <= 0 {
      #expect(draft.saveAllowed)
    } else {
      #expect(
        !draft.saveAllowed
          && draft.inputIssues.contains { $0.lane == .text && $0.state == .oversized })
      let oversize = try #require(draft.inputIssues.first { $0.state == .oversized })
      guard
        case .draft(let removed) = await planner.updateCapture(
          session: session, draftId: draft.draftId,
          generation: draft.generation, edit: .init(removeInputIndexes: [oversize.inputIndex]))
      else { throw CancellationError() }
      #expect(removed.saveAllowed && removed.links == draft.links)
    }
  }

  @Test(arguments: ["failure", "badEncoding", "unsupported", "file", "textOnly", "empty"])
  @MainActor
  func nativeFailuresAndUnsupportedDataKeepTheReviewHonest(scenario: String) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let provider = NSItemProvider()
    var providers = [provider]
    switch scenario {
    case "failure":
      provider.registerDataRepresentation(
        forTypeIdentifier: UTType.url.identifier, visibility: .all
      ) { completion in
        completion(nil, CocoaError(.fileReadUnknown))
        return nil
      }
    case "badEncoding":
      provider.registerDataRepresentation(
        forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all
      ) { completion in
        completion(Data([0xff, 0xfe, 0xff]), nil)
        return nil
      }
    case "unsupported":
      provider.registerDataRepresentation(
        forTypeIdentifier: UTType.image.identifier, visibility: .all
      ) { completion in
        Issue.record("Unsupported binary representations must never be loaded.")
        completion(Data([0]), nil)
        return nil
      }
    case "file":
      provider.registerDataRepresentation(
        forTypeIdentifier: UTType.fileURL.identifier, visibility: .all
      ) { completion in
        Issue.record("The file representation must never be loaded.")
        completion(Data("file:///private/tmp/attachment".utf8), nil)
        return nil
      }
      provider.registerDataRepresentation(
        forTypeIdentifier: UTType.url.identifier, visibility: .all
      ) { completion in
        completion(Data("file:///private/tmp/attachment".utf8), nil)
        return nil
      }
    case "textOnly":
      provider.registerDataRepresentation(
        forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all
      ) { completion in
        completion(Data("Received description".utf8), nil)
        return nil
      }
    default: providers = []
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: providers)
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    #expect(
      !draft.saveAllowed && draft.links.isEmpty && draft.content.title.isEmpty
        && draft.content.notes == nil)
    if scenario == "failure" || scenario == "badEncoding" {
      #expect(draft.inputIssues.contains { $0.state == .failed && $0.blocksSave })
    } else if scenario == "textOnly" {
      #expect(draft.inputIssues.contains { $0.state == .held && !$0.blocksSave })
    } else {
      #expect(draft.inputIssues.allSatisfy { !$0.blocksSave })
    }
  }

  @Test(arguments: [31, 32, 33]) @MainActor
  func providerBudgetLoadsAtMostThirtyTwoAndReportsOverflowBeforeAdd(count: Int) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let tracker = NativeCaptureLoadTracker()
    let providers = (0..<count).map { index in
      let provider = NSItemProvider()
      provider.registerDataRepresentation(
        forTypeIdentifier: UTType.url.identifier, visibility: .all
      ) { completion in
        tracker.started()
        tracker.finished()
        completion(Data("https://example.com/\(index)".utf8), nil)
        return nil
      }
      return provider
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: providers)
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    #expect(tracker.totalStarted == min(count, 32) && draft.links.count == min(count, 32))
    if count <= 32 {
      #expect(draft.saveAllowed && draft.inputIssues.isEmpty)
    } else {
      #expect(
        !draft.saveAllowed && draft.inputIssues.contains { $0.state == .oversized && $0.blocksSave }
      )
      let overflow = try #require(draft.inputIssues.first { $0.state == .oversized })
      guard
        case .draft(let removed) = await planner.updateCapture(
          session: session, draftId: draft.draftId,
          generation: draft.generation, edit: .init(removeInputIndexes: [overflow.inputIndex]))
      else { throw CancellationError() }
      #expect(removed.saveAllowed && removed.links == draft.links)
    }
  }

  @Test @MainActor
  func overallTenSecondDeadlineCancelsSlowNativeInputAndKeepsLateDataOutOfTheDraft() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let progress = Progress(totalUnitCount: 1)
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      Task {
        try? await Task.sleep(for: .seconds(11))
        completion(Data("https://example.com/late".utf8), nil)
      }
      return progress
    }
    let clock = ContinuousClock()
    let beginning = clock.now
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let elapsed = beginning.duration(to: clock.now)
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    #expect(
      elapsed >= .seconds(9.7) && elapsed < .seconds(10.6),
      "Observed deadline return after \(elapsed)")
    #expect(progress.isCancelled && draft.links.isEmpty && !draft.saveAllowed)
    #expect(draft.inputIssues.contains { $0.state == .failed && $0.blocksSave })
    try await Task.sleep(for: .milliseconds(1200))
    guard
      case .draft(let unchanged) = await planner.readCapture(
        session: session, draftId: draft.draftId)
    else { throw CancellationError() }
    #expect(unchanged.links.isEmpty && unchanged.generation == draft.generation)
  }

  @Test @MainActor
  func cancellationCancelsNativeProgressAndLateDataCannotChangeTheLoadedResult() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let progress = Progress(totalUnitCount: 1)
    let controlled = NativeCaptureControlledCompletion()
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      controlled.retain(completion)
      return progress
    }
    let loading = Task { await PlannerNativeCaptureLoader.load(providers: [provider]) }
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !controlled.started && ContinuousClock.now < deadline { await Task.yield() }
    #expect(controlled.started)
    loading.cancel()
    let loaded = await loading.value
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let canceled) = await planner.prepareCapture(
        session: session, input: .loaded(loaded)),
      case .draft(let current) = await planner.prepareCapture(
        session: session,
        input: .direct([.url("https://example.com/current")]))
    else { throw CancellationError() }
    #expect(progress.isCancelled && canceled.links.isEmpty && !canceled.saveAllowed)
    #expect(canceled.inputIssues.contains { $0.state == .failed && $0.blocksSave })
    controlled.deliver(Data("https://example.com/old".utf8))
    await Task.yield()
    guard
      case .draft(let stillCurrent) = await planner.readCapture(
        session: session, draftId: current.draftId)
    else { throw CancellationError() }
    #expect(stillCurrent.generation == current.generation && stillCurrent.links == current.links)
  }

  @Test @MainActor
  func outOfOrderNativeCallbacksKeepSourceAndRepresentationOrderWithFourConcurrentLoads()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let tracker = NativeCaptureLoadTracker()
    var providers: [NSItemProvider] = []
    for providerIndex in 0..<4 {
      let provider = NSItemProvider()
      for (type, suffix) in [(UTType.url, "url"), (.utf8PlainText, "text")] {
        let text = "https://example.com/\(providerIndex)/\(suffix)"
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) {
          completion in
          let progress = Progress(totalUnitCount: 1)
          tracker.started()
          Task {
            if suffix == "url" {
              try? await Task.sleep(for: .milliseconds(50))
            } else {
              try? await Task.sleep(for: .milliseconds(10))
            }
            tracker.finished()
            completion(Data(text.utf8), nil)
          }
          return progress
        }
      }
      providers.append(provider)
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: providers)
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    #expect(tracker.maximumActive == 4)
    #expect(
      draft.links.map(\.originalUrl) == [
        "https://example.com/0/url", "https://example.com/0/text",
        "https://example.com/1/url", "https://example.com/1/text",
        "https://example.com/2/url", "https://example.com/2/text",
        "https://example.com/3/url", "https://example.com/3/text",
      ])
  }

  @Test @MainActor
  func registeredUrlAndTextRepresentationsProduceOneDraftWithoutPromotingProviderProse()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    let provider = NSItemProvider()
    let original = "https://example.com/%2f?x=%41"
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      completion(Data(original.utf8), nil)
      return nil
    }
    provider.registerDataRepresentation(
      forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all
    ) { completion in
      completion(
        Data("Provider title\nProvider address\n\(original)\nhttps://example.com/extra".utf8), nil)
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded)),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(
      draft.content.title == "Saved link" && draft.content.notes == nil
        && draft.content.location == nil)
    #expect(draft.links.map(\.originalUrl) == [original, "https://example.com/extra"])
    #expect(draft.inputIssues.contains { $0.lane == .text && $0.state == .held && !$0.blocksSave })
    #expect(draft.saveAllowed && before == after)
  }
}

private final class NativeCaptureControlledCompletion: @unchecked Sendable {
  private let lock = NSLock()
  private var completion: (@Sendable (Data?, (any Error)?) -> Void)?
  private var didStart = false
  func retain(_ completion: @escaping @Sendable (Data?, (any Error)?) -> Void) {
    lock.withLock {
      self.completion = completion
      didStart = true
    }
  }
  var started: Bool { lock.withLock { didStart } }
  func deliver(_ data: Data) {
    let retained = lock.withLock {
      let retained = completion
      completion = nil
      return retained
    }
    retained?(data, nil)
  }
}

private final class NativeCaptureLoadTracker: @unchecked Sendable {
  private let lock = NSLock()
  private var activeCount = 0
  private var maximumCount = 0
  private var startedCount = 0
  func started() {
    lock.withLock {
      activeCount += 1
      startedCount += 1
      maximumCount = max(maximumCount, activeCount)
    }
  }
  func finished() { lock.withLock { activeCount -= 1 } }
  var maximumActive: Int { lock.withLock { maximumCount } }
  var totalStarted: Int { lock.withLock { startedCount } }
}

private func nativeCaptureLoadingConfiguration(_ directory: URL) -> PlannerStorageConfiguration {
  .init(
    storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
    controlURL: directory.appendingPathComponent("control/writer"),
    recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
    processRole: .mainApplication, storageMode: .localOnly)
}
