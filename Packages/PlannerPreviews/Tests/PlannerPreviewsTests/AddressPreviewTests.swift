import Foundation
import PlannerPreviews
import Testing

@MainActor
struct AddressPreviewTests {
  @Test func byteDistinctUnicodeAddressesKeepSeparatePreviewResults() async {
    let source = PlannerPreviewSource(
      namespace: "local-dataset", sourceId: UUID(), sourceLifetimeId: UUID())
    let composed = PlannerAddressPreviewRequest(source: source, address: "Caf\u{00E9} Road")
    let decomposed = PlannerAddressPreviewRequest(source: source, address: "Cafe\u{0301} Road")
    let first = PlannerAddressCandidate(
      id: "first-place", name: "First place", address: "First address",
      latitude: 35, longitude: 139)
    let second = PlannerAddressCandidate(
      id: "second-place", name: "Second place", address: "Second address",
      latitude: 36, longitude: 140)
    let provider = RecordingAddressProvider(candidates: [first])
    let previews = PlannerAddressPreviews(provider: provider)

    await previews.loadAddress(composed)
    provider.candidates = [second]
    #expect(previews.addressState(for: decomposed) == .idle)
    await previews.loadAddress(decomposed)
    #expect(previews.addressState(for: composed) == .available([first]))
    #expect(previews.addressState(for: decomposed) == .available([second]))
    #expect(provider.requestedAddresses.count == 2)
    #expect(provider.requestedAddresses.last?.utf8.elementsEqual("Cafe\u{0301} Road".utf8) == true)
  }

  @Test func aRequestedAddressLoadsOneCandidateAndReusesOnlyItsExactCacheKey() async {
    let request = PlannerAddressPreviewRequest(
      source: .init(namespace: "local-dataset", sourceId: UUID(), sourceLifetimeId: UUID()),
      address: "1 Apple Park Way, Cupertino, CA")
    let candidate = PlannerAddressCandidate(
      id: "apple-park", name: "Apple Park", address: "Cupertino, California",
      latitude: 37.334859, longitude: -122.0090403)
    let provider = RecordingAddressProvider(candidates: [candidate])
    let previews = PlannerAddressPreviews(provider: provider)

    #expect(previews.addressState(for: request) == .idle)
    #expect(provider.requestedAddresses.isEmpty)
    await previews.loadAddress(request)
    #expect(previews.addressState(for: request) == .available([candidate]))
    #expect(provider.requestedAddresses == ["1 Apple Park Way, Cupertino, CA"])
    #expect(request.address == "1 Apple Park Way, Cupertino, CA")
    await previews.loadAddress(request)
    #expect(provider.requestedAddresses.count == 1)
    let differentAddress = PlannerAddressPreviewRequest(
      source: request.source, address: "1 Infinite Loop, Cupertino, CA")
    #expect(previews.addressState(for: differentAddress) == .idle)
  }

  @Test func providerFailureCanBeRetriedToZeroOrMultipleMatchesWithoutChangingTheAddress() async {
    let request = PlannerAddressPreviewRequest(
      source: .init(namespace: "local-dataset", sourceId: UUID(), sourceLifetimeId: UUID()),
      address: "Museum Road")
    let first = PlannerAddressCandidate(
      id: "east-museum", name: "Museum", address: "East Museum Road",
      latitude: 35.0, longitude: 139.0)
    let second = PlannerAddressCandidate(
      id: "west-museum", name: "Museum", address: "West Museum Road",
      latitude: 36.0, longitude: 140.0)
    let provider = RecoveringAddressProvider(candidates: [first, second])
    let previews = PlannerAddressPreviews(provider: provider)

    await previews.loadAddress(request)
    #expect(previews.addressState(for: request) == .unavailable)
    await previews.loadAddress(request)
    #expect(provider.requestCount == 1)
    await previews.retryAddress(request)
    #expect(previews.addressState(for: request) == .available([]))
    await previews.retryAddress(request)
    #expect(previews.addressState(for: request) == .available([first, second]))
    #expect(provider.requestCount == 3)
    #expect(request.address == "Museum Road")
  }

  @Test(arguments: ["address", "namespace", "lifetime", "source"])
  func aLateAddressResponseCannotReplaceADifferentRequest(_ changedValue: String) async {
    let originalSource = PlannerPreviewSource(
      namespace: "old-dataset", sourceId: UUID(), sourceLifetimeId: UUID())
    let original = PlannerAddressPreviewRequest(source: originalSource, address: "Original Road")
    var currentSource = originalSource
    var currentAddress = original.address
    switch changedValue {
    case "address": currentAddress = "Current Road"
    case "namespace":
      currentSource = .init(
        namespace: "current-dataset", sourceId: originalSource.sourceId,
        sourceLifetimeId: originalSource.sourceLifetimeId)
    case "lifetime":
      currentSource = .init(
        namespace: originalSource.namespace, sourceId: originalSource.sourceId,
        sourceLifetimeId: UUID())
    default:
      currentSource = .init(
        namespace: originalSource.namespace, sourceId: UUID(),
        sourceLifetimeId: originalSource.sourceLifetimeId)
    }
    let current = PlannerAddressPreviewRequest(source: currentSource, address: currentAddress)
    let provider = DelayedAddressProvider()
    let previews = PlannerAddressPreviews(provider: provider)
    let oldLoad = Task { await previews.loadAddress(original) }
    await provider.waitForRequests(1)
    #expect(previews.addressState(for: original) == .loading)
    #expect(previews.addressState(for: current) == .idle)
    let newLoad = Task { await previews.loadAddress(current) }
    await provider.waitForRequests(2)
    await previews.loadAddress(current)
    await previews.retryAddress(current)
    #expect(provider.requestCount == 2)
    let candidate = PlannerAddressCandidate(
      id: "current-museum", name: "Current Museum", address: "Current Road",
      latitude: 35.0, longitude: 139.0)
    provider.completeRequest(1, with: [candidate])
    await newLoad.value
    #expect(previews.addressState(for: current) == .available([candidate]))
    provider.completeRequest(0, with: [])
    await oldLoad.value
    #expect(previews.addressState(for: current) == .available([candidate]))
    #expect(previews.addressState(for: original) == .available([]))
  }

  @Test func aDisappearingDetailDoesNotCancelTheSharedAddressRequest() async {
    let request = PlannerAddressPreviewRequest(
      source: .init(namespace: "local-dataset", sourceId: UUID(), sourceLifetimeId: UUID()),
      address: "Museum Road")
    let provider = DelayedAddressProvider()
    let previews = PlannerAddressPreviews(provider: provider)
    let disappearingDetail = Task { await previews.loadAddress(request) }
    await provider.waitForRequests(1)
    disappearingDetail.cancel()
    await previews.loadAddress(request)
    #expect(provider.requestCount == 1)
    #expect(previews.addressState(for: request) == .loading)
    provider.completeRequest(0, with: [])
    await disappearingDetail.value
    #expect(previews.addressState(for: request) == .available([]))
  }
}

@MainActor
private final class RecordingAddressProvider: PlannerAddressPreviewProvider {
  var candidates: [PlannerAddressCandidate]
  private(set) var requestedAddresses: [String] = []

  init(candidates: [PlannerAddressCandidate]) { self.candidates = candidates }

  func addressPreview(for address: String) async throws -> [PlannerAddressCandidate] {
    requestedAddresses.append(address)
    return candidates
  }
}

@MainActor
private final class RecoveringAddressProvider: PlannerAddressPreviewProvider {
  enum Failure: Error { case offline }
  let candidates: [PlannerAddressCandidate]
  private(set) var requestCount = 0

  init(candidates: [PlannerAddressCandidate]) { self.candidates = candidates }

  func addressPreview(for address: String) async throws -> [PlannerAddressCandidate] {
    requestCount += 1
    if requestCount == 1 { throw Failure.offline }
    if requestCount == 2 { return [] }
    return candidates
  }
}

@MainActor
private final class DelayedAddressProvider: PlannerAddressPreviewProvider {
  private var responses: [CheckedContinuation<[PlannerAddressCandidate], any Error>] = []
  private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
  var requestCount: Int { responses.count }

  func addressPreview(for address: String) async throws -> [PlannerAddressCandidate] {
    let candidates: [PlannerAddressCandidate] = try await withCheckedThrowingContinuation {
      continuation in
      responses.append(continuation)
      let ready = waiters.filter { $0.count <= responses.count }
      waiters.removeAll { $0.count <= responses.count }
      for waiter in ready { waiter.continuation.resume() }
    }
    try Task.checkCancellation()
    return candidates
  }

  func waitForRequests(_ count: Int) async {
    guard responses.count < count else { return }
    await withCheckedContinuation { waiters.append((count, $0)) }
  }

  func completeRequest(_ index: Int, with candidates: [PlannerAddressCandidate]) {
    responses[index].resume(returning: candidates)
  }
}
