import Foundation
import Observation
import PlannerCore
import SwiftUI

@MainActor
private final class SavedAssociationUndoAction {
  let snapshot: PlannerAssociationUndoSnapshot
  let name: String
  let operationIdentifier = UUID()
  weak var manager: UndoManager?

  init(snapshot: PlannerAssociationUndoSnapshot, name: String, manager: UndoManager?) {
    self.snapshot = snapshot
    self.name = name
    self.manager = manager
  }
}

@MainActor @Observable
final class SavedAssociationUndoHistory {
  private var available: [SavedAssociationUndoAction] = []
  private var pending: [SavedAssociationUndoAction] = []
  private var retry: SavedAssociationUndoAction?
  private var recordedRemovals: Set<UUID> = []
  private var namespace: String?
  private var lifecycleIdentifier = UUID()
  private(set) var isRestoring = false
  @ObservationIgnored private weak var store: SavedPlannerStore?
  @ObservationIgnored private var worker: Task<Void, Never>?

  var actionTitle: String? {
    if retry != nil { return "Retry Undo" }
    return available.last.map { "Undo \($0.name)" }
  }

  var presentsControl: Bool {
    if isRestoring { return true }
    #if os(iOS)
      return actionTitle != nil
    #else
      return retry != nil
    #endif
  }

  func recordOwnedRemovals(
    _ result: PlannerOperationResult, store: SavedPlannerStore, manager: UndoManager?
  ) {
    guard let snapshot = result.associationUndoSnapshot,
      case .ownedAssociationGroup(let group) = snapshot.originalRecord
    else { return }
    let name: String
    if group.removedLinks.isEmpty {
      name = "Remove Labels"
    } else if group.removedLabels.isEmpty {
      name = "Remove Links"
    } else {
      name = "Remove Links and Labels"
    }
    record(result, name: name, store: store, manager: manager)
  }

  func record(
    _ result: PlannerOperationResult, name: String, store: SavedPlannerStore,
    manager: UndoManager?
  ) {
    guard case .applied = result.outcome, let snapshot = result.associationUndoSnapshot,
      let currentNamespace = store.devicePreferenceNamespace
    else { return }
    if namespace != currentNamespace { clear() }
    namespace = currentNamespace
    self.store = store
    guard recordedRemovals.insert(snapshot.closingOperationId).inserted else { return }
    let action = SavedAssociationUndoAction(snapshot: snapshot, name: name, manager: manager)
    available.append(action)
    manager?.registerUndo(withTarget: action) { [weak self] action in
      self?.enqueue(action)
    }
    manager?.setActionName(name)
  }

  func undo() {
    guard !isRestoring else { return }
    if let retry {
      self.retry = nil
      pending.insert(retry, at: 0)
      startWorker()
      return
    }
    guard let action = available.last else { return }
    action.manager?.removeAllActions(withTarget: action)
    enqueue(action)
  }

  func clear() {
    lifecycleIdentifier = UUID()
    worker?.cancel()
    worker = nil
    for action in available + pending + [retry].compactMap({ $0 }) {
      action.manager?.removeAllActions(withTarget: action)
    }
    available = []
    pending = []
    retry = nil
    recordedRemovals = []
    namespace = nil
    store = nil
    isRestoring = false
  }

  private func enqueue(_ action: SavedAssociationUndoAction) {
    guard available.contains(where: { $0 === action }) else { return }
    available.removeAll { $0 === action }
    pending.append(action)
    startWorker()
  }

  private func startWorker() {
    guard worker == nil, retry == nil, !pending.isEmpty else { return }
    isRestoring = true
    let lifecycle = lifecycleIdentifier
    worker = Task { [weak self] in
      guard let self else { return }
      await restorePending(lifecycle: lifecycle)
    }
  }

  private func restorePending(lifecycle: UUID) async {
    defer {
      if lifecycleIdentifier == lifecycle {
        worker = nil
        isRestoring = false
      }
    }
    while !pending.isEmpty {
      guard let store, namespace == store.devicePreferenceNamespace else {
        clear()
        return
      }
      let action = pending.removeFirst()
      let result = await store.restoreAssociation(
        action.snapshot, operationIdentifier: action.operationIdentifier)
      guard lifecycleIdentifier == lifecycle, !Task.isCancelled else { return }
      guard let result else {
        retry = action
        return
      }
      switch result.outcome {
      case .applied: break
      case .rejected(let failure):
        if failure.code == "persistenceFailure" || failure.code == "mutationBlocked" {
          retry = action
          return
        }
      case .unverified:
        retry = action
        return
      }
    }
  }
}

struct SavedAssociationUndoControl: View {
  let history: SavedAssociationUndoHistory
  let store: SavedPlannerStore

  var body: some View {
    if history.presentsControl {
      HStack {
        if history.isRestoring {
          ProgressView("Undoing removal")
            .controlSize(.small)
        } else if let title = history.actionTitle {
          Button(title, systemImage: "arrow.uturn.backward") { history.undo() }
            .disabled(!store.canCreate)
            .accessibilityIdentifier("saved.association.undo")
        }
        Spacer()
      }
    }
  }
}
