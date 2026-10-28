import Foundation
import Observation
import PlannerCore
import PlannerPreviews

enum SavedMapCollectionState: Equatable {
  case idle, loading, ready
  case failed(String)
}

enum SavedMapLocationResolution: Equatable {
  case noInput, loading, unavailable
  case located(PlannerCoordinate)
  case addressCandidates(PlannerAddressPreviewRequest, [PlannerAddressCandidate])
}

struct SavedMapCoordinateIdentity: Hashable {
  let latitude: Double
  let longitude: Double
}

struct SavedMapLocationGroup: Identifiable {
  let coordinate: PlannerCoordinate
  var rows: [PlannerMapRowRead]

  var id: SavedMapCoordinateIdentity {
    .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
  }
}

@MainActor @Observable
final class SavedMapCollection {
  private enum LocationInput: Hashable {
    case address(PlannerAddressPreviewRequest)
    case maps(PlannerLinkPreviewRequest)
  }

  private struct PreviewOperation {
    let identifier: UUID
    let epoch: UUID
    let deadline: Task<Void, Never>
    var timedOut = false
  }

  @ObservationIgnored private let addressPreviews: PlannerAddressPreviews
  @ObservationIgnored private let mapsPreviews: PlannerMapsPreviews
  private(set) var state = SavedMapCollectionState.idle
  private(set) var matchingCount: Int64 = 0
  private(set) var rows: [PlannerMapRowRead] = []
  private(set) var collection: PlannerMapCollection?
  private(set) var listBranches: [PlannerMapListBranch] = []
  private(set) var groups: [SavedMapLocationGroup] = []
  private(set) var locatedCount = 0
  private(set) var unresolvedCount = 0
  private(set) var noInputCount = 0
  @ObservationIgnored private var requestIdentifier = UUID()
  private var resolutions: [SavedMapLocationResolution] = []
  private var mapsResults: [PlannerLinkPreviewRequest: PlannerCapturePreviewCandidate] = [:]
  private var addressResults: [PlannerAddressPreviewRequest: [PlannerAddressCandidate]] = [:]
  private var selectedAddressCandidateIdentifiers: [String?] = []
  @ObservationIgnored private var inputs: [LocationInput?] = []
  @ObservationIgnored private var pendingInputs: [LocationInput] = []
  @ObservationIgnored private var nextPendingInput = 0
  @ObservationIgnored private var waitingInputs: Set<LocationInput> = []
  @ObservationIgnored private var activeInputs: [LocationInput: PreviewOperation] = [:]
  @ObservationIgnored private var retryInputs: Set<LocationInput> = []

  /// Keep unresolved rows in route order so directions never bridge an unknown stop.
  var routingLocations: [(row: PlannerMapRowRead, coordinate: PlannerCoordinate?)] {
    guard state == .ready, !resolutions.contains(.loading) else { return [] }
    return zip(rows, resolutions).map { row, resolution in
      if case .located(let coordinate) = resolution { return (row, coordinate) }
      return (row, nil)
    }
  }

  init(addressPreviews: PlannerAddressPreviews, mapsPreviews: PlannerMapsPreviews) {
    self.addressPreviews = addressPreviews
    self.mapsPreviews = mapsPreviews
  }

  func reload(
    planner: PlannerCore.Planner, session: PlannerDatasetSession, query: PlannerItemQuery,
    identity: SavedItemWindowIdentity
  ) async {
    guard !Task.isCancelled else { return }
    let identifier = UUID()
    requestIdentifier = identifier
    clearPublication()
    state = .loading
    reloadSnapshot: while !Task.isCancelled, requestIdentifier == identifier {
      let result = await planner.query(.init(session: session, request: .items(query)))
      guard !Task.isCancelled, requestIdentifier == identifier else { return }
      guard case .snapshot(let snapshot) = result else {
        if case .failed(let reason) = result { state = .failed(reason.message) }
        return
      }
      guard snapshot.matchingCount == Int64(snapshot.rows.count) else {
        state = .failed("Planner could not resolve the complete Map collection.")
        return
      }
      var loadedRows: [PlannerMapRowRead] = []
      var firstWindow: PlannerMapRowWindow?
      repeat {
        let offset = loadedRows.count
        let end = min(offset + 64, snapshot.rows.count)
        let read = await planner.read(
          session: session,
          request: .mapRows(generation: snapshot.generation, offset: Int64(offset), limit: 64))
        guard !Task.isCancelled, requestIdentifier == identifier else { return }
        guard case .mapRows(let window) = read else {
          if case .failed(let reason) = read {
            if reason.code == "staleSnapshot" { continue reloadSnapshot }
            state = .failed(reason.message)
          } else {
            state = .failed("Planner could not read its Map locations.")
          }
          return
        }
        guard window.generation == snapshot.generation, window.offset == Int64(offset),
          window.matchingCount == snapshot.matchingCount,
          window.rows.map(\.identity) == Array(snapshot.rows[offset..<end])
        else {
          state = .failed("Planner could not read its complete Map page.")
          return
        }
        if let firstWindow {
          guard window.collection == firstWindow.collection,
            window.listBranches == firstWindow.listBranches
          else {
            state = .failed("Planner's Map context changed while loading.")
            return
          }
        } else {
          firstWindow = window
        }
        loadedRows.append(contentsOf: window.rows)
      } while loadedRows.count < snapshot.rows.count
      rows = loadedRows
      selectedAddressCandidateIdentifiers = Array(repeating: nil, count: rows.count)
      matchingCount = snapshot.matchingCount
      collection = firstWindow?.collection
      listBranches = firstWindow?.listBranches ?? []
      resolutions = rows.map { row in
        if let coordinate = row.ownedLocation?.coordinate { return .located(coordinate) }
        return .noInput
      }
      publishLocations()
      state = .ready
      prepareInputs(namespace: identity.namespace)
      startLoads()
      return
    }
  }

  private func prepareInputs(namespace: String) {
    var seen: Set<LocationInput> = []
    inputs = rows.map { row in
      guard row.ownedLocation?.coordinate == nil else { return nil }
      let previewSource = PlannerPreviewSource(
        namespace: namespace, sourceId: source(for: row.identity).id,
        sourceLifetimeId: row.sourceLifetimeId)
      if let address = row.ownedLocation?.formattedAddress,
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        return .address(.init(source: previewSource, address: address))
      }
      guard let link = row.mapsLinks.first else { return nil }
      return .maps(.init(source: previewSource, linkId: link.linkId, originalURL: link.originalUrl))
    }
    for index in inputs.indices where inputs[index] != nil { resolutions[index] = .loading }
    for input in inputs.compactMap({ $0 }) where seen.insert(input).inserted {
      enqueue(input)
    }
  }

  private func enqueue(_ input: LocationInput) {
    guard inputs.contains(input) else { return }
    if let operation = activeInputs[input] {
      if operation.epoch != requestIdentifier || operation.timedOut { waitingInputs.insert(input) }
      return
    }
    guard !pendingInputs[nextPendingInput...].contains(input) else { return }
    pendingInputs.append(input)
  }

  private func startLoads() {
    while activeInputs.count < 4, nextPendingInput < pendingInputs.count {
      let input = pendingInputs[nextPendingInput]
      nextPendingInput += 1
      guard inputs.contains(input) else { continue }
      let operationIdentifier = UUID()
      let epoch = requestIdentifier
      let deadline = Task { [weak self] in
        do { try await Task.sleep(for: .seconds(10)) } catch { return }
        self?.expireLoad(input, operationIdentifier: operationIdentifier, epoch: epoch)
      }
      activeInputs[input] = .init(identifier: operationIdentifier, epoch: epoch, deadline: deadline)
      let retry = retryInputs.remove(input) != nil
      Task { [weak self, addressPreviews, mapsPreviews] in
        var resolution = SavedMapLocationResolution.unavailable
        var mapsPreview: PlannerCapturePreviewCandidate?
        switch input {
        case .address(let request):
          if retry {
            await addressPreviews.retryAddress(request)
          } else {
            await addressPreviews.loadAddress(request)
          }
          while addressPreviews.addressState(for: request) == .loading {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
              withObservationTracking {
                _ = addressPreviews.addressState(for: request)
              } onChange: {
                continuation.resume()
              }
            }
          }
          if case .available(let candidates) = addressPreviews.addressState(for: request) {
            if candidates.count == 1, let candidate = candidates.first {
              resolution = .located(
                .init(latitude: candidate.latitude, longitude: candidate.longitude))
            } else if candidates.count > 1 {
              resolution = .addressCandidates(request, candidates)
            }
          }
        case .maps(let request):
          let result: PlannerMapsPreviewResult?
          if retry {
            result = await mapsPreviews.retry(request)
          } else {
            result = await mapsPreviews.load(request)
          }
          if case .available(let candidate) = result {
            mapsPreview = candidate
            if let coordinate = candidate.coordinate { resolution = .located(coordinate) }
          }
        }
        self?.finishLoad(
          input, operationIdentifier: operationIdentifier, epoch: epoch, resolution: resolution,
          mapsPreview: mapsPreview)
      }
    }
  }

  private func finishLoad(
    _ input: LocationInput, operationIdentifier: UUID, epoch: UUID,
    resolution: SavedMapLocationResolution, mapsPreview: PlannerCapturePreviewCandidate?
  ) {
    guard let operation = activeInputs[input], operation.identifier == operationIdentifier else {
      return
    }
    operation.deadline.cancel()
    activeInputs.removeValue(forKey: input)
    if epoch == requestIdentifier, !operation.timedOut {
      if case .maps(let request) = input, let mapsPreview { mapsResults[request] = mapsPreview }
      if case .address(let request) = input {
        if case .addressCandidates(_, let candidates) = resolution {
          addressResults[request] = candidates
        } else {
          addressResults.removeValue(forKey: request)
        }
      }
      updateInput(input, resolution: resolution)
    }
    if waitingInputs.remove(input) != nil { enqueue(input) }
    startLoads()
  }

  private func expireLoad(
    _ request: LocationInput, operationIdentifier: UUID, epoch: UUID
  ) {
    guard activeInputs[request]?.identifier == operationIdentifier else { return }
    activeInputs[request]?.timedOut = true
    guard epoch == requestIdentifier else { return }
    updateInput(request, resolution: .unavailable)
  }

  private func updateInput(
    _ request: LocationInput, resolution: SavedMapLocationResolution
  ) {
    for index in inputs.indices where inputs[index] == request {
      resolutions[index] = resolution
    }
    publishLocations()
  }

  func cancel() {
    requestIdentifier = UUID()
    clearPublication()
    state = .idle
  }

  func resolution(for identity: PlannerRowIdentity) -> SavedMapLocationResolution? {
    guard let index = rows.firstIndex(where: { $0.identity == identity }) else { return nil }
    return resolutions[index]
  }

  func mapsPreview(for identity: PlannerRowIdentity) -> PlannerCapturePreviewCandidate? {
    guard let index = rows.firstIndex(where: { $0.identity == identity }),
      case .maps(let request) = inputs[index]
    else { return nil }
    return mapsResults[request]
  }

  func mapsLinkChoices(for identity: PlannerRowIdentity)
    -> (selected: PlannerLinkPreviewRequest, links: [PlannerOwnedLinkRead])?
  {
    guard let index = rows.firstIndex(where: { $0.identity == identity }),
      case .maps(let request) = inputs[index]
    else { return nil }
    return (request, rows[index].mapsLinks)
  }

  func chooseMapsLink(_ request: PlannerLinkPreviewRequest, for identity: PlannerRowIdentity)
    -> Bool
  {
    guard let index = rows.firstIndex(where: { $0.identity == identity }),
      case .maps(let current) = inputs[index], current.source == request.source,
      rows[index].mapsLinks.contains(where: {
        $0.linkId == request.linkId && Data($0.originalUrl.utf8) == Data(request.originalURL.utf8)
      })
    else { return false }
    if current == request { return true }
    let input = LocationInput.maps(request)
    inputs[index] = input
    resolutions[index] = .loading
    publishLocations()
    enqueue(input)
    startLoads()
    return true
  }

  func retry(for identity: PlannerRowIdentity) {
    guard let index = rows.firstIndex(where: { $0.identity == identity }),
      resolutions[index] == .unavailable, let request = inputs[index]
    else { return }
    retryInputs.insert(request)
    updateInput(request, resolution: .loading)
    enqueue(request)
    startLoads()
  }

  func chooseAddressCandidate(
    _ candidate: PlannerAddressCandidate, request: PlannerAddressPreviewRequest,
    for identity: PlannerRowIdentity
  ) -> Bool {
    guard let index = rows.firstIndex(where: { $0.identity == identity }),
      inputs[index] == .address(request),
      addressResults[request]?.contains(candidate) == true
    else { return false }
    selectedAddressCandidateIdentifiers[index] = candidate.id
    resolutions[index] = .located(
      .init(latitude: candidate.latitude, longitude: candidate.longitude))
    publishLocations()
    return true
  }

  func addressChoices(for identity: PlannerRowIdentity)
    -> (
      request: PlannerAddressPreviewRequest, candidates: [PlannerAddressCandidate],
      selectedCandidateId: String?
    )?
  {
    guard let index = rows.firstIndex(where: { $0.identity == identity }),
      case .address(let request) = inputs[index], let candidates = addressResults[request]
    else { return nil }
    return (request, candidates, selectedAddressCandidateIdentifiers[index])
  }

  private func source(for identity: PlannerRowIdentity) -> PlannerEntityReference {
    switch identity {
    case .source(let source), .appearance(let source, _): return source
    }
  }

  private func clearPublication() {
    selectedAddressCandidateIdentifiers = []
    matchingCount = 0
    rows = []
    collection = nil
    listBranches = []
    groups = []
    locatedCount = 0
    unresolvedCount = 0
    noInputCount = 0
    resolutions = []
    mapsResults = [:]
    addressResults = [:]
    retryInputs = []
    inputs = []
    pendingInputs = []
    nextPendingInput = 0
    waitingInputs = []
  }

  private func publishLocations() {
    locatedCount = 0
    noInputCount = 0
    unresolvedCount = 0
    var groupIndices: [SavedMapCoordinateIdentity: Int] = [:]
    var locationGroups: [SavedMapLocationGroup] = []
    for (index, row) in rows.enumerated() {
      guard case .located(let coordinate) = resolutions[index] else {
        let address = row.ownedLocation?.formattedAddress ?? ""
        if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && row.mapsLinks.isEmpty
        {
          noInputCount += 1
        } else {
          unresolvedCount += 1
        }
        continue
      }
      locatedCount += 1
      let key = SavedMapCoordinateIdentity(
        latitude: coordinate.latitude, longitude: coordinate.longitude)
      if let index = groupIndices[key] {
        locationGroups[index].rows.append(row)
      } else {
        groupIndices[key] = locationGroups.count
        locationGroups.append(.init(coordinate: coordinate, rows: [row]))
      }
    }
    groups = locationGroups
  }
}
