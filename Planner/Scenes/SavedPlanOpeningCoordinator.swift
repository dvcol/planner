import Foundation
import Observation
import PlannerCore
import SwiftUI

struct SavedPlanOpeningRequest: Equatable {
  let identifier: UUID
  let source: PlannerEntityReference
  let sourceLifetimeIdentifier: UUID
  let namespace: String
  var windowIdentifier: UUID?
  var isClaimed = false
}

@MainActor @Observable
final class SavedPlanOpeningCoordinator {
  static let mainWindowSceneIdentifier = "planner-main"
  private struct WindowRegistration {
    var isActive: Bool
    var isReady: Bool
    var activityOrder: UInt64
  }

  private var windows: [UUID: WindowRegistration] = [:]
  private var activityOrder: UInt64 = 0
  private var isSubmitting = false
  @ObservationIgnored private var openWindow: OpenWindowAction?
  private(set) var pending: SavedPlanOpeningRequest?

  func connect(_ action: OpenWindowAction) {
    openWindow = action
    activateRecipient()
  }

  func readyRequestIdentifier(for windowIdentifier: UUID) -> UUID? {
    guard windows[windowIdentifier]?.isReady == true,
      pending?.windowIdentifier == windowIdentifier
    else { return nil }
    return pending?.identifier
  }

  func register(windowIdentifier: UUID, isActive: Bool, isReady: Bool) {
    let previous = windows[windowIdentifier]
    if isActive && previous?.isActive != true { activityOrder += 1 }
    let retainedOrder = previous?.activityOrder ?? 0
    windows[windowIdentifier] = .init(
      isActive: isActive, isReady: isReady,
      activityOrder: isActive && previous?.isActive != true ? activityOrder : retainedOrder)
    if pending?.windowIdentifier == nil, isReady {
      pending?.windowIdentifier = windowIdentifier
    }
  }

  func unregister(windowIdentifier: UUID) {
    windows[windowIdentifier] = nil
    if pending?.windowIdentifier == windowIdentifier { pending = nil }
  }

  func cancel(requestIdentifier: UUID, windowIdentifier: UUID) {
    guard pending?.identifier == requestIdentifier,
      pending?.windowIdentifier == windowIdentifier
    else { return }
    pending = nil
  }

  func submit(source: PlannerEntityReference, store: SavedPlannerStore) async throws
    -> SavedPlanOpeningRequest
  {
    guard pending == nil, !isSubmitting else {
      throw failure("Planner is already opening a plan. Finish or cancel that request first.")
    }
    isSubmitting = true
    defer { isSubmitting = false }
    let binding = try await readBinding(source: source, store: store)
    let recipient = windows.keys.sorted { first, second in
      let firstWindow = windows[first]!
      let secondWindow = windows[second]!
      if firstWindow.isActive != secondWindow.isActive { return firstWindow.isActive }
      if firstWindow.activityOrder != secondWindow.activityOrder {
        return firstWindow.activityOrder > secondWindow.activityOrder
      }
      return first.uuidString < second.uuidString
    }.first
    let request = SavedPlanOpeningRequest(
      identifier: UUID(), source: source, sourceLifetimeIdentifier: binding.lifetime,
      namespace: binding.namespace, windowIdentifier: recipient)
    pending = request
    activateRecipient()
    return request
  }

  private func activateRecipient() {
    guard let openWindow, pending != nil else { return }
    if pending?.windowIdentifier == nil { pending?.windowIdentifier = UUID() }
    guard let recipient = pending?.windowIdentifier, windows[recipient]?.isActive != true else {
      return
    }
    openWindow(id: Self.mainWindowSceneIdentifier, value: recipient)
  }

  func claim(windowIdentifier: UUID, store: SavedPlannerStore) async throws
    -> SavedPlanOpeningRequest?
  {
    guard var request = pending, request.windowIdentifier == windowIdentifier,
      !request.isClaimed, windows[windowIdentifier]?.isReady == true
    else { return nil }
    request.isClaimed = true
    pending = request
    try await validate(request, store: store)
    return request
  }

  func resolveNavigation(
    requestIdentifier: UUID, windowIdentifier: UUID, store: SavedPlannerStore
  ) async throws -> PlannerEntityReference {
    guard let request = pending, request.identifier == requestIdentifier,
      request.windowIdentifier == windowIdentifier, request.isClaimed
    else { throw failure("This opening request is no longer available.") }
    try await validate(request, store: store)
    pending = nil
    return request.source
  }

  private func validate(_ request: SavedPlanOpeningRequest, store: SavedPlannerStore) async throws {
    do {
      guard store.devicePreferenceNamespace == request.namespace else {
        throw failure("Planner's data changed. Request opening the plan again.")
      }
      let binding = try await readBinding(source: request.source, store: store)
      guard binding.namespace == request.namespace,
        binding.lifetime == request.sourceLifetimeIdentifier,
        pending?.identifier == request.identifier,
        pending?.windowIdentifier == request.windowIdentifier,
        request.windowIdentifier.flatMap({ windows[$0] }) != nil
      else { throw failure("This plan or its receiving window is no longer available.") }
    } catch {
      if pending?.identifier == request.identifier { pending = nil }
      throw error
    }
  }

  private func readBinding(source: PlannerEntityReference, store: SavedPlannerStore) async throws
    -> (namespace: String, lifetime: UUID)
  {
    guard source.kind == .list || source.kind == .itinerary else {
      throw failure("Choose a saved List or Itinerary to open.")
    }
    let (planner, session) = try await store.appIntentContext()
    guard let namespace = store.devicePreferenceNamespace else {
      throw failure("Planner could not identify its current data.")
    }
    let snapshot: PlannerQuerySnapshot
    switch await planner.query(
      .init(session: session, request: .catalog(.init(sourceKind: source.kind, archive: .all))))
    {
    case .snapshot(let value): snapshot = value
    case .failed(let reason): throw failure(reason.message)
    }
    guard let index = snapshot.rows.firstIndex(of: .source(source)) else {
      throw failure("This plan is no longer available.")
    }
    let lifetime: UUID
    switch await planner.read(
      session: session,
      request: .rows(generation: snapshot.generation, offset: Int64(index), limit: 1))
    {
    case .rows(let page):
      guard page.rows.count == 1, let row = page.rows.first, row.identity == .source(source) else {
        throw failure("Planner could not validate this exact plan.")
      }
      lifetime = row.sourceLifetimeId
    case .failed(let reason): throw failure(reason.message)
    default: throw failure("Planner could not validate this plan.")
    }
    try Task.checkCancellation()
    guard namespace == store.devicePreferenceNamespace else {
      throw failure("Planner's data changed. Request opening the plan again.")
    }
    return (namespace, lifetime)
  }

  private func failure(_ message: String) -> SavedPlanOpeningFailure {
    SavedPlanOpeningFailure(message: message)
  }
}

private struct SavedPlanOpeningFailure: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}
