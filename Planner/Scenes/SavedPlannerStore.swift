import Foundation
import Observation
import PlannerCore

struct SavedPlannerList: Identifiable {
  let source: PlannerEntityReference
  let name: String
  var id: UUID { source.id }
}

struct SavedPlannerItem: Identifiable {
  let id: UUID
  let row: PlannerRowRead
}

@MainActor @Observable
final class SavedPlannerStore {
  private let planner: PlannerCore.Planner?
  private var session: PlannerDatasetSession?
  private(set) var lists: [SavedPlannerList] = []
  private(set) var isOpening = false
  private(set) var isSaving = false
  private(set) var recoveryBlocked = false
  private(set) var openingFailure: String?
  var alertMessage: String?
  var isReady: Bool { session != nil && !isOpening }
  var canCreate: Bool { isReady && !isOpening && !isSaving && !recoveryBlocked }

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    let directory: URL
    if let index = arguments.firstIndex(of: "--local-prototype-dataset") {
      guard arguments.indices.contains(index + 1),
        let identifier = UUID(uuidString: arguments[index + 1])
      else {
        planner = nil
        openingFailure = "The local prototype dataset identifier is invalid."
        return
      }
      directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlannerLocalPrototype", isDirectory: true)
        .appendingPathComponent(identifier.uuidString, isDirectory: true)
    } else {
      guard
        let support = FileManager.default.urls(
          for: .applicationSupportDirectory, in: .userDomainMask
        ).first
      else {
        planner = nil
        openingFailure = "Planner's local data directory is unavailable."
        return
      }
      directory = support.appendingPathComponent("Planner/Local", isDirectory: true)
    }
    planner = PlannerCore.Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
  }

  func open() async {
    guard let planner, session == nil, !isOpening else { return }
    isOpening = true
    openingFailure = nil
    defer { isOpening = false }
    switch await planner.bootstrap() {
    case .ready(let ready):
      session = ready
      await refreshLists()
    case .unavailable(let reason): openingFailure = reason.message
    case .mainAppSetupRequired, .mainAppMigrationRequired:
      openingFailure = "Planner could not initialize its local data."
    }
  }

  func refreshLists() async {
    guard let planner, let session else { return }
    switch await planner.query(
      PlannerQuery(session: session, request: .catalog(.init(sourceKind: .list))))
    {
    case .failed(let reason): alertMessage = reason.message
    case .snapshot(let snapshot):
      switch await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: Int64.max))
      {
      case .rows(let window):
        lists = window.rows.compactMap { row in
          guard case .source(let source) = row.identity, source.kind == .list else { return nil }
          return SavedPlannerList(source: source, name: row.title)
        }
      case .failed(let reason): alertMessage = reason.message
      default: alertMessage = "Planner could not read its Lists."
      }
    }
  }

  func readList(_ identifier: UUID) async -> PlannerListSourceRead? {
    guard let planner, let session else { return nil }
    switch await planner.read(
      session: session, request: .source(.init(kind: .list, id: identifier)))
    {
    case .source(.list(let list)): return list
    case .failed(let reason): alertMessage = reason.message
    default: alertMessage = "Planner could not open this List."
    }
    return nil
  }

  func createList(name: String, operationId: UUID) async -> PlannerEntityReference? {
    guard let planner, let session, canCreate else { return nil }
    isSaving = true
    defer { isSaving = false }
    let result = await planner.execute(
      PlannerOperation(
        operationId: operationId, session: session, command: .createList(content: .init(name: name))
      ))
    switch result.outcome {
    case .rejected(let reason):
      alertMessage = reason.message
      return nil
    case .unverified:
      recoveryBlocked = true
      alertMessage = "The List's save could not be verified. Further changes need recovery review."
      return nil
    case .applied(let applied, let recovery):
      if case .incomplete = recovery {
        recoveryBlocked = true
        alertMessage =
          "The List was saved, but its recovery copy is incomplete. Further changes are paused."
      }
      await refreshLists()
      return applied.generated.first { $0.kind == .list }
    }
  }

  func readListItems(_ identifier: UUID) async -> [SavedPlannerItem]? {
    guard let planner, let session else { return nil }
    switch await planner.query(
      PlannerQuery(
        session: session,
        request: .items(
          .init(
            scope: .list(identifier), completion: .all, archive: .all,
            sort: .init(mode: .manual)))))
    {
    case .failed(let reason): alertMessage = reason.message
    case .snapshot(let snapshot):
      switch await planner.read(
        session: session,
        request: .rows(generation: snapshot.generation, offset: 0, limit: Int64.max))
      {
      case .rows(let window):
        var items: [SavedPlannerItem] = []
        for row in window.rows {
          guard case .appearance(_, .listMembership(let listId, let membershipId)) = row.identity,
            listId == identifier
          else {
            alertMessage = "Planner could not resolve this List's Items."
            return nil
          }
          items.append(SavedPlannerItem(id: membershipId, row: row))
        }
        return items
      case .failed(let reason): alertMessage = reason.message
      default: alertMessage = "Planner could not read this List's Items."
      }
    }
    return nil
  }
}
