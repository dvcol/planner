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
}

struct SavedMapLocationGroup {
  let coordinate: PlannerCoordinate
  var rows: [PlannerMapRowRead]
}

@MainActor @Observable
final class SavedMapCollection {
  private struct AddressOperation {
    let identifier: UUID
    let deadline: Task<Void, Never>
    var timedOut = false
  }

  private struct CoordinateKey: Hashable {
    let latitude: Double
    let longitude: Double
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
  @ObservationIgnored private var addressRequests: [PlannerAddressPreviewRequest?] = []
  @ObservationIgnored private var pendingAddresses: [PlannerAddressPreviewRequest] = []
  @ObservationIgnored private var nextPendingAddress = 0
  @ObservationIgnored private var waitingAddresses: Set<PlannerAddressPreviewRequest> = []
  @ObservationIgnored private var activeAddresses:
    [PlannerAddressPreviewRequest: AddressOperation] = [:]
  @ObservationIgnored private var retryAddresses: Set<PlannerAddressPreviewRequest> = []

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
    matchingCount = snapshot.matchingCount
    collection = firstWindow?.collection
    listBranches = firstWindow?.listBranches ?? []
    resolutions = rows.map { row in
      if let coordinate = row.ownedLocation?.coordinate { return .located(coordinate) }
      return .noInput
    }
    publishLocations()
    state = .ready
    prepareAddresses(namespace: identity.namespace)
    startAddressLoads()
  }

  private func prepareAddresses(namespace: String) {
    var seen: Set<PlannerAddressPreviewRequest> = []
    addressRequests = rows.map { row in
      guard row.ownedLocation?.coordinate == nil,
        let address = row.ownedLocation?.formattedAddress,
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else { return nil }
      return PlannerAddressPreviewRequest(
        source: .init(
          namespace: namespace, sourceId: source(for: row.identity).id,
          sourceLifetimeId: row.sourceLifetimeId), address: address)
    }
    for index in addressRequests.indices where addressRequests[index] != nil {
      resolutions[index] = .loading
    }
    for request in addressRequests.compactMap({ $0 }) where seen.insert(request).inserted {
      if activeAddresses[request] != nil {
        waitingAddresses.insert(request)
      } else {
        pendingAddresses.append(request)
      }
    }
  }

  private func startAddressLoads() {
    while activeAddresses.count < 4, nextPendingAddress < pendingAddresses.count {
      let request = pendingAddresses[nextPendingAddress]
      nextPendingAddress += 1
      let operationIdentifier = UUID()
      let epoch = requestIdentifier
      let deadline = Task { [weak self] in
        do { try await Task.sleep(for: .seconds(10)) } catch { return }
        self?.expireAddress(request, operationIdentifier: operationIdentifier, epoch: epoch)
      }
      activeAddresses[request] = .init(identifier: operationIdentifier, deadline: deadline)
      let retry = retryAddresses.remove(request) != nil
      Task { [weak self, addressPreviews] in
        if retry {
          await addressPreviews.retryAddress(request)
        } else {
          await addressPreviews.loadAddress(request)
        }
        let result = addressPreviews.addressState(for: request)
        self?.finishAddress(
          request, operationIdentifier: operationIdentifier, epoch: epoch, result: result)
      }
    }
  }

  private func finishAddress(
    _ request: PlannerAddressPreviewRequest, operationIdentifier: UUID, epoch: UUID,
    result: PlannerAddressPreviewState
  ) {
    guard let operation = activeAddresses[request], operation.identifier == operationIdentifier
    else {
      return
    }
    operation.deadline.cancel()
    activeAddresses.removeValue(forKey: request)
    if epoch == requestIdentifier, !operation.timedOut {
      var resolution = SavedMapLocationResolution.unavailable
      if case .available(let candidates) = result, candidates.count == 1,
        let candidate = candidates.first
      {
        resolution = .located(.init(latitude: candidate.latitude, longitude: candidate.longitude))
      }
      updateAddress(request, resolution: resolution)
    }
    if waitingAddresses.remove(request) != nil { pendingAddresses.append(request) }
    startAddressLoads()
  }

  private func expireAddress(
    _ request: PlannerAddressPreviewRequest, operationIdentifier: UUID, epoch: UUID
  ) {
    guard activeAddresses[request]?.identifier == operationIdentifier else { return }
    activeAddresses[request]?.timedOut = true
    guard epoch == requestIdentifier else { return }
    updateAddress(request, resolution: .unavailable)
  }

  private func updateAddress(
    _ request: PlannerAddressPreviewRequest, resolution: SavedMapLocationResolution
  ) {
    for index in addressRequests.indices where addressRequests[index] == request {
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

  func retry(for identity: PlannerRowIdentity) {
    guard let index = rows.firstIndex(where: { $0.identity == identity }),
      resolutions[index] == .unavailable, let request = addressRequests[index]
    else { return }
    retryAddresses.insert(request)
    updateAddress(request, resolution: .loading)
    if activeAddresses[request] != nil {
      waitingAddresses.insert(request)
    } else {
      pendingAddresses.append(request)
    }
    startAddressLoads()
  }

  private func source(for identity: PlannerRowIdentity) -> PlannerEntityReference {
    switch identity {
    case .source(let source), .appearance(let source, _): return source
    }
  }

  private func clearPublication() {
    matchingCount = 0
    rows = []
    collection = nil
    listBranches = []
    groups = []
    locatedCount = 0
    unresolvedCount = 0
    noInputCount = 0
    resolutions = []
    retryAddresses = []
    addressRequests = []
    pendingAddresses = []
    nextPendingAddress = 0
    waitingAddresses = []
  }

  private func publishLocations() {
    locatedCount = 0
    noInputCount = 0
    unresolvedCount = 0
    var groupIndices: [CoordinateKey: Int] = [:]
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
      let key = CoordinateKey(latitude: coordinate.latitude, longitude: coordinate.longitude)
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
