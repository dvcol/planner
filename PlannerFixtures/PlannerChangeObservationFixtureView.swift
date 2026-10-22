import Foundation
import Observation
import PlannerCore
import SwiftUI

struct PlannerChangeObservationFixtureView: View {
  let planOpening: SavedPlanOpeningCoordinator
  let windowIdentifier: UUID
  @State private var fixture: PlannerChangeObservationFixture?
  @State private var failure: String?

  var body: some View {
    Group {
      if let fixture {
        VStack(spacing: 0) {
          SavedPlannerMainWindow(
            store: fixture.store, planOpening: planOpening, windowIdentifier: windowIdentifier
          )
          .environment(fixture.store)
          Divider()
          HStack {
            Menu("Fixture writer") {
              Button("Update Hotel") { Task { await fixture.updateHotel() } }
                .accessibilityIdentifier("fixture.writer.update")
              Button("Move Hotel's pin") { Task { await fixture.moveHotel() } }
                .accessibilityIdentifier("fixture.writer.moveHotel")
              Button("Delete Hotel") { Task { await fixture.deleteHotel() } }
                .accessibilityIdentifier("fixture.writer.deleteHotel")
              Button("Remove Hotel from Weekend") { Task { await fixture.removeHotelMembership() } }
                .accessibilityIdentifier("fixture.writer.removeMembership")
              Button("Delete Weekend") { Task { await fixture.deleteWeekend() } }
                .accessibilityIdentifier("fixture.writer.deleteWeekend")
              Button("Damage recovery checkpoint") { Task { await fixture.damageRecovery() } }
                .accessibilityIdentifier("fixture.writer.damageRecovery")
              Button("Repair recovery checkpoint") { Task { await fixture.repairRecovery() } }
                .accessibilityIdentifier("fixture.writer.repairRecovery")
              Button("Change dataset binding") { fixture.changeBinding() }
                .accessibilityIdentifier("fixture.writer.changeBinding")
              Button("Restore dataset binding") { fixture.restoreBinding() }
                .accessibilityIdentifier("fixture.writer.restoreBinding")
            }
            .accessibilityIdentifier("fixture.writer.menu")
            Text(fixture.status).font(.caption)
              .accessibilityIdentifier("fixture.writer.status")
          }
          .padding(8)
          .frame(maxWidth: .infinity)
          .background(.bar)
        }
      } else if let failure {
        ContentUnavailableView(
          "Fixture unavailable", systemImage: "exclamationmark.triangle",
          description: Text(failure))
      } else {
        ProgressView("Preparing independent writer")
      }
    }
    .task {
      guard fixture == nil, failure == nil else { return }
      do { fixture = try await PlannerChangeObservationFixture.make() } catch {
        failure = error.localizedDescription
      }
    }
  }
}

@MainActor @Observable
private final class PlannerChangeObservationFixture {
  let store: SavedPlannerStore
  private let writer: PlannerCore.Planner
  private let configuration: PlannerStorageConfiguration
  private let session: PlannerDatasetSession
  private let source: PlannerEntityReference
  private var damagedCheckpoint: (url: URL, bytes: Data)?
  private var originalControl: Data?
  private(set) var status = "Independent writer ready"

  private init(
    configuration: PlannerStorageConfiguration, writer: PlannerCore.Planner,
    session: PlannerDatasetSession, source: PlannerEntityReference
  ) {
    store = SavedPlannerStore(configuration: configuration)
    self.configuration = configuration
    self.writer = writer
    self.session = session
    self.source = source
  }

  static func make() async throws -> PlannerChangeObservationFixture {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "--fixture-dataset"),
      arguments.indices.contains(index + 1), let identifier = UUID(uuidString: arguments[index + 1])
    else { throw CancellationError() }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PlannerFixtures/change-observation", isDirectory: true)
      .appendingPathComponent(identifier.uuidString, isDirectory: true)
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let writer = PlannerCore.Planner(configuration: configuration)
    guard case .ready(let session) = await writer.bootstrap(),
      case .snapshot(let existing) = await writer.query(
        .init(session: session, request: .items(.init())))
    else { throw CancellationError() }
    func save(_ command: PlannerCommand) async throws -> PlannerAppliedResult {
      guard
        case .applied(let result, .complete) = await writer.execute(
          .init(operationId: UUID(), session: session, command: command)
        ).outcome
      else { throw CancellationError() }
      return result
    }
    let source: PlannerEntityReference
    if case .source(let existingSource)? = existing.rows.first {
      source = existingSource
    } else {
      var links: [PlannerLinkInput] = []
      if let websiteIndex = arguments.firstIndex(of: "--fixture-website-url") {
        guard arguments.indices.contains(websiteIndex + 1),
          let website = URL(string: arguments[websiteIndex + 1]),
          ["http", "https"].contains(website.scheme?.lowercased() ?? "")
        else { throw CancellationError() }
        links = [.init(originalUrl: arguments[websiteIndex + 1], label: "Museum guide")]
      }
      guard
        let created = try await save(
          .createItem(
            content: .init(
              title: "Hotel", notes: "Original notes",
              location: .init(
                displayName: "Hotel", formattedAddress: nil,
                coordinate: .init(latitude: 35.662, longitude: 139.717)), links: links))
        ).generated.first,
        let list = try await save(.createList(content: .init(name: "Weekend"))).generated.first
      else { throw CancellationError() }
      source = created
      _ = try await save(.addMembership(itemId: source.id, listId: list.id, placement: .last))
    }
    return .init(configuration: configuration, writer: writer, session: session, source: source)
  }

  func updateHotel() async {
    guard
      case .source(.item(let current)) = await writer.read(
        session: session, request: .source(source)),
      let titleHash = current.fieldHashes[.title], let notesHash = current.fieldHashes[.notes]
    else {
      status = "Independent writer could not read Hotel"
      return
    }
    let result = await writer.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: source.id,
          changes: .init(title: .set("Hotel updated"), notes: .set("Other writer notes")),
          expectedFieldHashes: [.title: titleHash, .notes: notesHash])))
    switch result.outcome {
    case .applied(_, .complete): status = "Saved another-writer change"
    default: status = "Independent writer did not complete its save"
    }
  }

  func moveHotel() async {
    guard
      case .source(.item(let current)) = await writer.read(
        session: session, request: .source(source)), let hash = current.fieldHashes[.location]
    else {
      status = "Independent writer could not read Hotel's pin"
      return
    }
    let result = await writer.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editItem(
          sourceId: source.id,
          changes: .init(
            location: .set(
              .init(
                displayName: "Hotel", formattedAddress: nil,
                coordinate: .init(latitude: 35.655, longitude: 139.717)))),
          expectedFieldHashes: [.location: hash])))
    switch result.outcome {
    case .applied(_, .complete): status = "Saved another-writer location"
    default: status = "Independent writer did not move Hotel's pin"
    }
  }

  func deleteHotel() async {
    await deleteSource(source, name: "Hotel")
  }

  func deleteWeekend() async {
    guard
      case .source(.item(let current)) = await writer.read(
        session: session, request: .source(source))
    else {
      status = "Independent writer could not read Hotel's List"
      return
    }
    for reference in current.references {
      guard case .membership(_, let list, let item) = reference, item == source else { continue }
      await deleteSource(list, name: "Weekend")
      return
    }
    status = "No Weekend List to delete"
  }

  private func deleteSource(_ target: PlannerEntityReference, name: String) async {
    let command = PlannerCommand.deleteSource(source: target)
    guard
      case .reviewed(let review) = await writer.prepareReview(
        session: session, command: command)
    else {
      status = "Independent writer could not review \(name) deletion"
      return
    }
    let result = await writer.execute(
      .init(
        operationId: UUID(), session: session, command: command,
        reviewToken: review.reviewToken))
    switch result.outcome {
    case .applied(_, .complete): status = "Deleted \(name) from another writer"
    default: status = "Independent writer did not delete \(name)"
    }
  }

  func removeHotelMembership() async {
    guard
      case .source(.item(let current)) = await writer.read(
        session: session, request: .source(source))
    else {
      status = "Independent writer could not read Hotel's membership"
      return
    }
    for reference in current.references {
      guard case .membership(let membershipIdentifier, let list, let item) = reference,
        item == source
      else { continue }
      let result = await writer.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeMembership(listId: list.id, membershipId: membershipIdentifier)))
      if case .applied(_, .complete) = result.outcome {
        status = "Removed Hotel from Weekend"
      } else {
        status = "Independent writer did not remove Hotel's membership"
      }
      return
    }
    status = "No Hotel membership to remove"
  }

  func damageRecovery() async {
    guard damagedCheckpoint == nil,
      case .status(let current) = await writer.read(session: session, request: .status),
      case .known(let generation?, _, _) = current.recovery,
      case .listedNamespaces(let namespaces) = await writer.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first(where: { $0.datasetId == session.datasetId })
    else {
      status = "Recovery fault fixture could not read its checkpoint"
      return
    }
    do {
      let url = configuration.recoveryDirectoryURL
        .appendingPathComponent(namespace.namespaceId.uuidString)
        .appendingPathComponent("checkpoint-\(generation).json")
      let bytes = try Data(contentsOf: url)
      try Data("{ independent recovery damage".utf8).write(to: url, options: .atomic)
      damagedCheckpoint = (url, bytes)
      status = "Recovery checkpoint damaged"
    } catch { status = "Recovery fault fixture failed: \(error.localizedDescription)" }
  }

  func repairRecovery() async {
    guard let damagedCheckpoint else {
      status = "No recovery checkpoint to repair"
      return
    }
    do {
      try damagedCheckpoint.bytes.write(to: damagedCheckpoint.url, options: .atomic)
      guard case .status(let current) = await writer.read(session: session, request: .status),
        case .known(_, let incomplete, false) = current.recovery, incomplete.isEmpty
      else { throw CancellationError() }
      self.damagedCheckpoint = nil
      status = "Recovery checkpoint repaired"
    } catch { status = "Recovery repair fixture failed: \(error.localizedDescription)" }
  }

  func changeBinding() {
    do {
      guard originalControl == nil else { throw CancellationError() }
      let bytes = try Data(contentsOf: configuration.controlURL)
      guard var control = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
        throw CancellationError()
      }
      control["epochId"] = UUID().uuidString
      try JSONSerialization.data(withJSONObject: control).write(
        to: configuration.controlURL, options: .atomic)
      originalControl = bytes
      status = "Dataset binding changed"
    } catch { status = "Binding fault fixture failed: \(error.localizedDescription)" }
  }

  func restoreBinding() {
    do {
      guard let originalControl else { throw CancellationError() }
      try originalControl.write(to: configuration.controlURL, options: .atomic)
      self.originalControl = nil
      status = "Dataset binding restored"
    } catch { status = "Binding repair fixture failed: \(error.localizedDescription)" }
  }
}
