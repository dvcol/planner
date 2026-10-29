import CoreLocation
import Foundation
import MapKit
import PlannerCore
import Testing
import UniformTypeIdentifiers

@Suite(.serialized)
struct NativeCaptureLoadingTests {
  @Test @MainActor
  func opaqueURLRepresentationUsesTheNativeURLValueWithoutChangingTheOriginal() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = "https://example.com/%2f?x=%41"
    let provider = NativeCaptureURLValueProvider(original: original)
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    #expect(draft.links.map(\.originalUrl) == [original] && draft.saveAllowed)
    #expect(draft.content.title == "Saved link" && draft.content.notes == nil)
    #expect(draft.inputIssues.isEmpty)
  }

  @Test @MainActor
  func nativeURLObjectFallbackKeepsTheDecodedByteLimit() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = "https://example.com/" + String(repeating: "a", count: 1_048_576)
    let provider = NativeCaptureURLValueProvider(original: original)
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    #expect(draft.links.isEmpty && !draft.saveAllowed)
    #expect(draft.inputIssues.contains { $0.state == .oversized && $0.blocksSave })
  }

  @Test @MainActor
  func nativeURLObjectFallbackCancelsProgressAndIgnoresLateValues() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let controlled = NativeCaptureControlledCompletion()
    let provider = NativeCaptureURLValueProvider(
      original: "https://example.com/old", controlled: controlled)
    let loading = Task { await PlannerNativeCaptureLoader.load(providers: [provider]) }
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !controlled.started && ContinuousClock.now < deadline { await Task.yield() }
    #expect(controlled.started)
    loading.cancel()
    let loaded = await loading.value
    #expect(provider.objectProgress.isCancelled)
    controlled.deliver(Data("https://example.com/old".utf8))
    await Task.yield()
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    #expect(draft.links.isEmpty && !draft.saveAllowed)
    #expect(draft.inputIssues.contains { $0.state == .failed && $0.blocksSave })
  }

  @Test(arguments: [-1, 0, 1]) @MainActor
  func nativeMapArchiveBudgetIsEightMiBBeforeSecureDecode(offset: Int) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = Data(repeating: 0, count: 8_388_608 + offset)
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: MKMapItemTypeIdentifier, visibility: .all
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
    let issue = try #require(draft.inputIssues.first { $0.lane == .mapItem })
    if offset <= 0 {
      #expect(issue.state == .failed)
    } else {
      #expect(issue.state == .oversized)
    }
    #expect(issue.blocksSave && !draft.saveAllowed && draft.preview.candidate == nil)
  }

  #if os(macOS)
    @Test @MainActor
    func nativeMapArchiveSizeIsIndependentFromDecodedMetadataSize() async throws {
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
      defer { try? FileManager.default.removeItem(at: directory) }
      let mapItem = MKMapItem(
        location: CLLocation(latitude: 35.66, longitude: 139.7), address: nil)
      mapItem.name = "Provider museum"
      let archiver = NSKeyedArchiver(requiringSecureCoding: true)
      archiver.encode(mapItem, forKey: NSKeyedArchiveRootObjectKey)
      archiver.encode(Data(repeating: 0, count: 1_048_576), forKey: "unrelatedFixtureData")
      archiver.finishEncoding()
      let data = archiver.encodedData
      #expect(data.count > 1_048_576 && data.count < 8_388_608)
      let provider = NSItemProvider()
      provider.registerDataRepresentation(
        forTypeIdentifier: MKMapItemTypeIdentifier, visibility: .all
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
      #expect(draft.preview.candidate?.displayName == "Provider museum")
      #expect(draft.preview.candidate?.coordinate == .init(latitude: 35.66, longitude: 139.7))
      #expect(draft.inputIssues.allSatisfy { !$0.blocksSave })
      #expect(draft.content.title.isEmpty && draft.content.location == nil && draft.links.isEmpty)
    }
  #endif

  @Test(arguments: ["retry", "remove"]) @MainActor
  func failedNativeMapInputRequiresExplicitRetryOrRemoval(action: String) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let mapItem = MKMapItem(
      location: CLLocation(latitude: 35.66, longitude: 139.7),
      address: MKAddress(fullAddress: "Provider address", shortAddress: nil))
    mapItem.name = "Provider museum"
    let data = try await nativeCaptureMapRepresentation(mapItem)
    let tracker = NativeCaptureLoadTracker()
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: MKMapItemTypeIdentifier, visibility: .all
    ) { completion in
      tracker.started()
      if tracker.totalStarted == 1 {
        completion(nil, CocoaError(.fileReadUnknown))
      } else {
        completion(data, nil)
      }
      tracker.finished()
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded)),
      case .draft(let edited) = await planner.updateCapture(
        session: session, draftId: draft.draftId, generation: draft.generation,
        edit: .init(changes: .init(title: .set("My museum"))))
    else { throw CancellationError() }
    #expect(draft.preview.candidate == nil)
    #expect(
      !edited.saveAllowed
        && edited.inputIssues.contains {
          $0.inputIndex == 0 && $0.lane == .mapItem && $0.state == .failed && $0.blocksSave
        })
    let edit: PlannerCaptureEdit
    if action == "retry" {
      edit = .init(retryInputIndexes: [0])
    } else {
      edit = .init(removeInputIndexes: [0])
    }
    guard
      case .draft(let recovered) = await planner.updateCapture(
        session: session, draftId: edited.draftId, generation: edited.generation, edit: edit),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(recovered.saveAllowed && recovered.content.title == "My museum")
    #expect(recovered.content.location == nil && recovered.links.isEmpty && before == after)
    if action == "retry" {
      #expect(
        tracker.totalStarted == 2 && recovered.preview.candidate?.displayName == "Provider museum")
      #expect(recovered.inputIssues.allSatisfy { !$0.blocksSave })
    } else {
      #expect(tracker.totalStarted == 1 && recovered.preview.candidate == nil)
      #expect(recovered.inputIssues.isEmpty)
    }
  }

  @Test @MainActor
  func nativeCurrentLocationDoesNotBecomeAFixedPlace() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let data = try await nativeCaptureMapRepresentation(MKMapItem.forCurrentLocation())
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: MKMapItemTypeIdentifier, visibility: .all
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
    let candidate = try #require(draft.preview.candidate)
    #expect(candidate.coordinate == nil && candidate.providerReference == nil)
    #expect(candidate.uncertaintyReasons.contains { $0.contains("changing current location") })
    #expect(draft.content.location == nil && draft.links.isEmpty && !draft.saveAllowed)
  }

  @Test(arguments: [-1, 0, 1]) @MainActor
  func nativeMapDescriptionsShareTheWholeCaptureByteBudget(offset: Int) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let mapItem = MKMapItem(
      location: CLLocation(latitude: 35.66, longitude: 139.7),
      address: MKAddress(fullAddress: "Provider address", shortAddress: nil))
    mapItem.name = "Provider museum"
    let data = try await nativeCaptureMapRepresentation(mapItem)
    let mapProvider = NSItemProvider()
    mapProvider.registerDataRepresentation(
      forTypeIdentifier: MKMapItemTypeIdentifier, visibility: .all
    ) { completion in
      completion(data, nil)
      return nil
    }
    let text = String(repeating: "x", count: 1_048_576 - 31 + offset)
    let textProvider = NSItemProvider()
    textProvider.registerDataRepresentation(
      forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all
    ) { completion in
      completion(Data(text.utf8), nil)
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [mapProvider, textProvider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    #expect(draft.preview.candidate?.displayName == "Provider museum")
    if offset <= 0 {
      #expect(draft.inputIssues.allSatisfy { !$0.blocksSave })
    } else {
      #expect(
        draft.inputIssues.contains {
          $0.inputIndex == 1 && $0.lane == .text && $0.state == .oversized && $0.blocksSave
        })
    }
  }

  @Test @MainActor
  func ownCaptureEditsKeepNativeMapPreviewTemporaryThroughReviewedSave() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let mapItem = MKMapItem(
      location: CLLocation(latitude: 35.66, longitude: 139.7),
      address: MKAddress(fullAddress: "Provider address", shortAddress: nil))
    mapItem.name = "Provider museum"
    let data = try await nativeCaptureMapRepresentation(mapItem)
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: MKMapItemTypeIdentifier, visibility: .all
    ) { completion in
      completion(data, nil)
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded)),
      case .draft(let edited) = await planner.updateCapture(
        session: session, draftId: draft.draftId, generation: draft.generation,
        edit: .init(changes: .init(title: .set("My museum"), notes: .set("My note"))))
    else { throw CancellationError() }
    #expect(edited.preview.candidate?.displayName == "Provider museum")
    #expect(
      edited.saveAllowed && edited.content.location == nil && edited.content.notes == "My note")
    guard
      case .reviewed(let review) = await planner.prepareReview(
        session: session,
        command: .applyCapture(
          draftId: edited.draftId, draftGeneration: edited.generation,
          choice: .createNew, listIds: [])),
      case .applied(let result, .complete) = await planner.execute(
        .init(
          operationId: UUID(), session: session, command: review.command,
          reviewToken: review.reviewToken)
      ).outcome,
      let item = result.generated.first,
      case .source(.item(let saved)) = await planner.read(session: session, request: .source(item)),
      case .exported(let backup) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(saved.content.title == "My museum" && saved.content.notes == "My note")
    #expect(saved.content.location == nil && saved.content.links.isEmpty)
    let text = String(decoding: backup, as: UTF8.self)
    #expect(!text.contains("Provider museum") && !text.contains("Provider address"))
  }

  @Test @MainActor
  func nativeMapObjectProducesHeldPreviewWithoutOwnedContentOrInventedBookmark() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let mapItem = MKMapItem(
      location: CLLocation(latitude: 35.66, longitude: 139.7),
      address: MKAddress(fullAddress: "Provider address", shortAddress: "Provider short"))
    mapItem.name = "Provider museum"
    mapItem.url = URL(string: "https://example.com/business")
    let data = try await nativeCaptureMapRepresentation(mapItem)
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: MKMapItemTypeIdentifier, visibility: .all
    ) { completion in
      completion(data, nil)
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded)),
      case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    let candidate = try #require(draft.preview.candidate)
    #expect(draft.preview.state == .available && draft.preview.linkId == nil)
    #expect(
      candidate.displayName == "Provider museum" && candidate.formattedAddress == "Provider address"
    )
    #expect(candidate.coordinate?.latitude == 35.66 && candidate.coordinate?.longitude == 139.7)
    #expect(candidate.provider == .appleMaps && candidate.providerReference == nil)
    #expect(
      draft.content.title.isEmpty && draft.content.notes == nil && draft.content.location == nil)
    #expect(draft.links.isEmpty && !draft.saveAllowed && before == after)
    #expect(
      draft.inputIssues.contains { $0.lane == .mapItem && $0.state == .held && !$0.blocksSave })
  }

  @Test(arguments: [127, 128, 129]) @MainActor
  func nativeRetryReservesAcceptedLinksBeforeAdmittingEarlierText(count: Int) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let tracker = NativeCaptureLoadTracker()
    let textProvider = NSItemProvider()
    let received = (0..<count).map { "https://example.com/new/\($0)" }.joined(separator: "\n")
    textProvider.registerDataRepresentation(
      forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all
    ) { completion in
      tracker.started()
      if tracker.totalStarted == 1 {
        completion(nil, CocoaError(.fileReadUnknown))
      } else {
        completion(Data(received.utf8), nil)
      }
      tracker.finished()
      return nil
    }
    let urlProvider = NSItemProvider()
    urlProvider.registerDataRepresentation(
      forTypeIdentifier: UTType.url.identifier, visibility: .all
    ) { completion in
      completion(Data("https://example.com/original".utf8), nil)
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [textProvider, urlProvider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded)),
      case .draft(let retried) = await planner.updateCapture(
        session: session, draftId: draft.draftId, generation: draft.generation,
        edit: .init(retryInputIndexes: [0]))
    else { throw CancellationError() }
    #expect(retried.links.contains { $0.originalUrl == "https://example.com/original" })
    if count == 127 {
      #expect(retried.saveAllowed && retried.links.count == 128)
      #expect(retried.links.first?.originalUrl == "https://example.com/new/0")
    } else {
      #expect(
        !retried.saveAllowed && retried.links.map(\.originalUrl) == ["https://example.com/original"]
      )
      #expect(retried.inputIssues.contains { $0.inputIndex == 0 && $0.state == .oversized })
    }
  }

  @Test(arguments: ["category", "tag", "foreignLink", "linkLimit", "cancelledCaller"]) @MainActor
  func rejectedEditLeavesThePendingNativeRetryActive(scenario: String) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let tracker = NativeCaptureLoadTracker()
    let pending = NativeCaptureControlledCompletion()
    let progress = Progress(totalUnitCount: 1)
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      tracker.started()
      if tracker.totalStarted == 1 {
        completion(Data("https://example.com/original".utf8), nil)
        tracker.finished()
        return nil
      }
      pending.retain(completion)
      return progress
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    let retry = Task {
      await planner.updateCapture(
        session: session, draftId: draft.draftId, generation: draft.generation,
        edit: .init(retryInputIndexes: [0]))
    }
    let deadline = ContinuousClock().now.advanced(by: .seconds(2))
    while !pending.started && ContinuousClock().now < deadline { await Task.yield() }
    #expect(pending.started)
    let changes: PlannerItemChanges
    switch scenario {
    case "category": changes = .init(categoryIds: .set([UUID()]))
    case "tag": changes = .init(tagIds: .set([UUID()]))
    case "cancelledCaller": changes = .init(title: .set("Cancelled title"))
    case "foreignLink":
      changes = .init(
        links: .set([.init(linkId: UUID(), originalUrl: "https://example.com/foreign")]))
    default:
      changes = .init(
        links: .set((0..<129).map { .init(originalUrl: "https://example.com/\($0)") }))
    }
    let secondEdit = Task {
      await planner.updateCapture(
        session: session, draftId: draft.draftId, generation: draft.generation,
        edit: .init(changes: changes))
    }
    if scenario == "cancelledCaller" { secondEdit.cancel() }
    guard case .rejected = await secondEdit.value,
      case .draft(let unchanged) = await planner.readCapture(
        session: session, draftId: draft.draftId)
    else { throw CancellationError() }
    #expect(!progress.isCancelled && unchanged.generation == draft.generation)
    pending.deliver(Data("https://example.com/retried".utf8))
    let outcome = await retry.value
    guard case .draft(let retried) = outcome else {
      Issue.record("A rejected edit must preserve the active Retry, observed \(outcome)")
      return
    }
    #expect(
      retried.saveAllowed && retried.links.map(\.originalUrl) == ["https://example.com/retried"])
  }

  @Test(arguments: [-1, 0, 1], [true, false]) @MainActor
  func nativeRetryKeepsOtherLanesAndEnforcesTheWholeDraftByteBudget(
    offset: Int, urlFirst: Bool
  ) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let urlLoads = NativeCaptureLoadTracker()
    let textLoads = NativeCaptureLoadTracker()
    let original = "https://example.com/original"
    let received = String(repeating: "x", count: 1_048_576 + offset - original.utf8.count)
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      urlLoads.started()
      completion(Data(original.utf8), nil)
      urlLoads.finished()
      return nil
    }
    let textProvider = NSItemProvider()
    textProvider.registerDataRepresentation(
      forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all
    ) { completion in
      textLoads.started()
      if textLoads.totalStarted == 1 {
        completion(nil, CocoaError(.fileReadUnknown))
      } else {
        completion(Data(received.utf8), nil)
      }
      textLoads.finished()
      return nil
    }
    var providers = [provider, textProvider]
    var textIndex: Int64 = 1
    if !urlFirst {
      providers = [textProvider, provider]
      textIndex = 0
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: providers)
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded)),
      case .draft(let retried) = await planner.updateCapture(
        session: session, draftId: draft.draftId, generation: draft.generation,
        edit: .init(retryInputIndexes: [textIndex]))
    else { throw CancellationError() }
    #expect(urlLoads.totalStarted == 1 && textLoads.totalStarted == 2)
    #expect(retried.links.map(\.originalUrl) == [original] && retried.content.notes == nil)
    if offset <= 0 {
      #expect(retried.saveAllowed && retried.inputIssues.contains { $0.state == .held })
    } else {
      #expect(!retried.saveAllowed && retried.inputIssues.contains { $0.state == .oversized })
    }
  }

  @Test(arguments: ["edit", "remove", "apply", "cancelCaller"]) @MainActor
  func obsoleteNativeRetryCannotReplaceEditedRemovedOrSavedCapture(scenario: String) async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let tracker = NativeCaptureLoadTracker()
    let pending = NativeCaptureControlledCompletion()
    let progress = Progress(totalUnitCount: 1)
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      tracker.started()
      if tracker.totalStarted == 1 {
        completion(Data("https://example.com/original".utf8), nil)
        tracker.finished()
        return nil
      }
      pending.retain(completion)
      return progress
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    let retry = Task {
      await planner.updateCapture(
        session: session, draftId: draft.draftId, generation: draft.generation,
        edit: .init(retryInputIndexes: [0]))
    }
    let deadline = ContinuousClock().now.advanced(by: .seconds(2))
    while !pending.started && ContinuousClock().now < deadline { await Task.yield() }
    #expect(pending.started)
    var savedItem: PlannerEntityReference?
    switch scenario {
    case "edit":
      guard
        case .draft = await planner.updateCapture(
          session: session, draftId: draft.draftId, generation: draft.generation,
          edit: .init(changes: .init(title: .set("Current title"))))
      else { throw CancellationError() }
    case "remove":
      guard
        case .draft = await planner.updateCapture(
          session: session, draftId: draft.draftId, generation: draft.generation,
          edit: .init(removeInputIndexes: [0]))
      else { throw CancellationError() }
    case "apply":
      guard
        case .reviewed(let review) = await planner.prepareReview(
          session: session,
          command: .applyCapture(
            draftId: draft.draftId, draftGeneration: draft.generation,
            choice: .createNew, listIds: [])),
        case .applied(let result, .complete) = await planner.execute(
          .init(
            operationId: UUID(), session: session, command: review.command,
            reviewToken: review.reviewToken)
        ).outcome
      else { throw CancellationError() }
      savedItem = try #require(result.generated.first)
    default: retry.cancel()
    }
    guard case .rejected(let failure) = await retry.value else { throw CancellationError() }
    #expect(progress.isCancelled && failure.code == "captureDraftUnavailable")
    pending.deliver(Data("https://example.com/obsolete".utf8))
    if let savedItem {
      guard
        case .source(.item(let item)) = await planner.read(
          session: session, request: .source(savedItem)),
        case .rejected = await planner.readCapture(session: session, draftId: draft.draftId)
      else { throw CancellationError() }
      #expect(item.content.links.map(\.originalUrl) == ["https://example.com/original"])
    } else {
      guard
        case .draft(let current) = await planner.readCapture(
          session: session, draftId: draft.draftId)
      else { throw CancellationError() }
      if scenario == "remove" {
        #expect(current.links.isEmpty && !current.saveAllowed)
      } else {
        #expect(current.links.map(\.originalUrl) == ["https://example.com/original"])
        if scenario == "edit" {
          #expect(current.content.title == "Current title")
        } else {
          #expect(current.generation == draft.generation)
        }
      }
    }
  }

  @Test @MainActor
  func cancellingDraftCancelsItsNativeRetryAndRejectsLateInput() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let tracker = NativeCaptureLoadTracker()
    let pending = NativeCaptureControlledCompletion()
    let progress = Progress(totalUnitCount: 1)
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      tracker.started()
      if tracker.totalStarted == 1 {
        completion(nil, CocoaError(.fileReadUnknown))
        tracker.finished()
        return nil
      }
      pending.retain(completion)
      return progress
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .draft(let draft) = await planner.prepareCapture(
        session: session, input: .loaded(loaded))
    else { throw CancellationError() }
    let retry = Task {
      await planner.updateCapture(
        session: session, draftId: draft.draftId, generation: draft.generation,
        edit: .init(retryInputIndexes: [0]))
    }
    let deadline = ContinuousClock().now.advanced(by: .seconds(2))
    while !pending.started && ContinuousClock().now < deadline { await Task.yield() }
    #expect(pending.started)
    guard
      case .cancelled = await planner.cancelCapture(
        session: session, draftId: draft.draftId, generation: draft.generation)
    else { throw CancellationError() }
    #expect(progress.isCancelled)
    pending.deliver(Data("https://example.com/obsolete".utf8))
    guard case .rejected(let failure) = await retry.value,
      case .rejected = await planner.readCapture(session: session, draftId: draft.draftId)
    else { throw CancellationError() }
    #expect(failure.code == "captureDraftUnavailable")
  }

  @Test @MainActor
  func explicitRetryReloadsFailedNativeInputAndPreservesOwnedEdits() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerNativeCaptureLoadingTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let tracker = NativeCaptureLoadTracker()
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all)
    { completion in
      tracker.started()
      if tracker.totalStarted == 1 {
        completion(nil, CocoaError(.fileReadUnknown))
      } else {
        completion(Data("https://example.com/retried".utf8), nil)
      }
      tracker.finished()
      return nil
    }
    let loaded = await PlannerNativeCaptureLoader.load(providers: [provider])
    let planner = Planner(configuration: nativeCaptureLoadingConfiguration(directory))
    guard case .ready(let session) = await planner.bootstrap(),
      case .exported(let before) = await planner.exportData(session: session),
      case .draft(let prepared) = await planner.prepareCapture(
        session: session, input: .loaded(loaded)),
      case .draft(let edited) = await planner.updateCapture(
        session: session, draftId: prepared.draftId, generation: prepared.generation,
        edit: .init(changes: .init(title: .set("My museum"))))
    else { throw CancellationError() }
    #expect(!prepared.saveAllowed && prepared.inputIssues.contains { $0.state == .failed })
    let outcome = await planner.updateCapture(
      session: session, draftId: edited.draftId, generation: edited.generation,
      edit: .init(retryInputIndexes: [0]))
    guard case .draft(let retried) = outcome else {
      Issue.record("Explicit Retry must reload the native provider, observed \(outcome)")
      return
    }
    #expect(tracker.totalStarted == 2)
    #expect(retried.links.map(\.originalUrl) == ["https://example.com/retried"])
    #expect(
      retried.content.title == "My museum" && retried.saveAllowed && retried.inputIssues.isEmpty)
    guard case .exported(let after) = await planner.exportData(session: session)
    else { throw CancellationError() }
    #expect(before == after)
  }

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

private final class NativeCaptureURLValueProvider: NSItemProvider, @unchecked Sendable {
  let original: String
  let controlled: NativeCaptureControlledCompletion?
  let objectProgress = Progress(totalUnitCount: 1)

  init(original: String, controlled: NativeCaptureControlledCompletion? = nil) {
    self.original = original
    self.controlled = controlled
    super.init()
  }

  override var registeredTypeIdentifiers: [String] { [UTType.url.identifier] }

  override func loadDataRepresentation(
    forTypeIdentifier typeIdentifier: String,
    completionHandler: @escaping @Sendable (Data?, (any Error)?) -> Void
  ) -> Progress {
    completionHandler(Data([0xff, 0xfe, 0x00]), nil)
    return Progress(totalUnitCount: 1)
  }

  override func loadObject(
    ofClass aClass: any NSItemProviderReading.Type,
    completionHandler: @escaping @Sendable ((any NSItemProviderReading)?, (any Error)?) -> Void
  ) -> Progress {
    guard aClass == NSURL.self else {
      completionHandler(nil, CocoaError(.coderReadCorrupt))
      return objectProgress
    }
    if let controlled {
      controlled.retain { data, error in
        let url = data.flatMap { String(data: $0, encoding: .utf8) }.flatMap(URL.init(string:))
        completionHandler(url.map { $0 as NSURL }, error)
      }
    } else {
      completionHandler(URL(string: original).map { $0 as NSURL }, nil)
    }
    return objectProgress
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

@MainActor private func nativeCaptureMapRepresentation(_ mapItem: MKMapItem) async throws -> Data {
  #if os(iOS)
    return try await withCheckedThrowingContinuation { continuation in
      _ = mapItem.loadData(withTypeIdentifier: MKMapItemTypeIdentifier) { data, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let data else {
          continuation.resume(throwing: CocoaError(.fileReadUnknown))
          return
        }
        continuation.resume(returning: data)
      }
    }
  #else
    return try NSKeyedArchiver.archivedData(withRootObject: mapItem, requiringSecureCoding: true)
  #endif
}
