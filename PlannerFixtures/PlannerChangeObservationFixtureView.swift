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
              Button("Rename containing plans") { Task { await fixture.renamePlans() } }
                .accessibilityIdentifier("fixture.writer.renamePlans")
              Button("Move Hotel's pin") { Task { await fixture.moveHotel() } }
                .accessibilityIdentifier("fixture.writer.moveHotel")
              Button("Delete Hotel") { Task { await fixture.deleteHotel() } }
                .accessibilityIdentifier("fixture.writer.deleteHotel")
              Button("Delete and restore Hotel") { Task { await fixture.replaceHotelLifetime() } }
                .accessibilityIdentifier("fixture.writer.restoreHotel")
              Button("Remove Hotel from Weekend") { Task { await fixture.removeHotelMembership() } }
                .accessibilityIdentifier("fixture.writer.removeMembership")
              Button("Restore removed Hotel membership") {
                Task { await fixture.restoreHotelMembership() }
              }
              .disabled(!fixture.canRestoreHotelMembership)
              .accessibilityIdentifier("fixture.writer.restoreMembership")
              Button("Delete Weekend") { Task { await fixture.deleteWeekend() } }
                .accessibilityIdentifier("fixture.writer.deleteWeekend")
              Button("Delete and restore Weekend") {
                Task { await fixture.replaceWeekendLifetime() }
              }
              .disabled(!fixture.canRestoreHotelMembership)
              .accessibilityIdentifier("fixture.writer.restoreWeekend")
              Button("Delete City trip") { Task { await fixture.deleteCityTrip() } }
                .accessibilityIdentifier("fixture.writer.deleteCityTrip")
              Button("Remove Hotel from City trip") { Task { await fixture.removeCityTripEntry() } }
                .accessibilityIdentifier("fixture.writer.removeCityTripEntry")
              Button("Remove first Weekend branch") {
                Task { await fixture.removeFirstWeekendBranch() }
              }
              .accessibilityIdentifier("fixture.writer.removeWeekendBranch")
              Button("Restore removed City trip entry") {
                Task { await fixture.restoreCityTripEntry() }
              }
              .disabled(!fixture.canRestoreCityTripEntry)
              .accessibilityIdentifier("fixture.writer.restoreItineraryEntry")
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
              .accessibilityValue(fixture.removedCityTripEntryIdentifier ?? "")
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
  private var removedHotelMembership: PlannerAssociationUndoSnapshot?
  private var removedCityTripEntry: PlannerAssociationUndoSnapshot?
  private(set) var status = "Independent writer ready"

  var canRestoreHotelMembership: Bool { removedHotelMembership != nil }
  var canRestoreCityTripEntry: Bool { removedCityTripEntry != nil }
  var removedCityTripEntryIdentifier: String? { removedCityTripEntry?.identity.id.uuidString }

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
      let locationCoordinate: PlannerCoordinate
      if arguments.contains("--fixture-map-search-coordinate") {
        locationCoordinate = .init(latitude: 35, longitude: 139)
      } else {
        locationCoordinate = .init(latitude: 35.662, longitude: 139.717)
      }
      guard
        let created = try await save(
          .createItem(
            content: .init(
              title: "Hotel", notes: "Original notes",
              location: .init(
                displayName: "Hotel", formattedAddress: nil,
                coordinate: locationCoordinate), links: links))
        ).generated.first,
        let list = try await save(.createList(content: .init(name: "Weekend"))).generated.first
      else { throw CancellationError() }
      source = created
      _ = try await save(.addMembership(itemId: source.id, listId: list.id, placement: .last))
      if arguments.contains("--fixture-itinerary") {
        let itineraryLinks = links.map {
          PlannerLinkInput(originalUrl: $0.originalUrl, label: "Itinerary guide")
        }
        guard
          let itinerary = try await save(
            .createItinerary(content: .init(title: "City trip", links: itineraryLinks))
          ).generated.first
        else { throw CancellationError() }
        _ = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: source, placement: .last))
        _ = try await save(
          .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
        if arguments.contains("--fixture-repeated-itinerary-list") {
          _ = try await save(
            .addItineraryEntry(itineraryId: itinerary.id, source: list, placement: .last))
        }
      }
    }
    return .init(configuration: configuration, writer: writer, session: session, source: source)
  }

  func renamePlans() async {
    guard
      case .source(.item(let item)) = await writer.read(session: session, request: .source(source)),
      let listReference = item.references.compactMap({ reference -> PlannerEntityReference? in
        guard case .membership(_, let list, let owner) = reference, owner == source else {
          return nil
        }
        return list
      }).first,
      case .source(.list(let list)) = await writer.read(
        session: session, request: .source(listReference)),
      let itineraryReference = list.references.compactMap({ reference -> PlannerEntityReference? in
        guard case .itineraryEntry(_, let itinerary, let owner) = reference,
          owner == listReference
        else { return nil }
        return itinerary
      }).first
    else {
      status = "Independent writer could not read the containing plans"
      return
    }
    let listResult = await writer.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editList(
          sourceId: listReference.id, changes: .init(name: .set("Weekend renamed")),
          expectedFieldHashes: list.fieldHashes)))
    guard case .applied(_, .complete) = listResult.outcome else {
      status = "Independent writer did not rename the List"
      return
    }
    guard
      case .source(.itinerary(let itinerary)) = await writer.read(
        session: session, request: .source(itineraryReference))
    else {
      status = "Renamed List; independent writer could not read the Itinerary"
      return
    }
    let itineraryResult = await writer.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editItinerary(
          sourceId: itineraryReference.id, changes: .init(title: .set("City trip renamed")),
          expectedFieldHashes: itinerary.fieldHashes)))
    if case .applied(_, .complete) = itineraryResult.outcome {
      status = "Renamed saved plans"
    } else {
      status = "Renamed List; independent writer did not rename the Itinerary"
    }
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

  func replaceHotelLifetime() async {
    guard
      case .source(.item(let original)) = await writer.read(
        session: session, request: .source(source)),
      case .exported(let data) = await writer.exportData(session: session),
      case .decoded(let backup) = writer.decodeImport(data),
      case .reviewed(let deletion) = await writer.prepareReview(
        session: session, command: .deleteSource(source: source))
    else {
      status = "Independent writer could not prepare Hotel replacement"
      return
    }
    let deleted = await writer.execute(
      .init(
        operationId: UUID(), session: session, command: deletion.command,
        reviewToken: deletion.reviewToken))
    guard case .applied(_, .complete) = deleted.outcome,
      case .reviewed(let restoration) = await writer.prepareReview(
        session: session,
        command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true))
    else {
      status = "Independent writer could not review Hotel restoration"
      return
    }
    let restored = await writer.execute(
      .init(
        operationId: UUID(), session: session, command: restoration.command,
        reviewToken: restoration.reviewToken))
    guard case .applied(_, .complete) = restored.outcome,
      case .source(.item(let current)) = await writer.read(
        session: session, request: .source(source)),
      current.source == original.source, current.sourceLifetimeId != original.sourceLifetimeId
    else {
      status = "Independent writer did not restore a fresh Hotel lifetime"
      return
    }
    status = "Restored Hotel with a new lifetime"
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

  func replaceWeekendLifetime() async {
    guard let snapshot = removedHotelMembership,
      case .membership(let originalMembership) = snapshot.originalRecord,
      case .source(.item(let originalItem)) = await writer.read(
        session: session, request: .source(source)),
      case .exported(let before) = await writer.exportData(session: session),
      case .decoded(let current) = writer.decodeImport(before),
      let originalList = current.backup.lists.first(where: { $0.id == originalMembership.list.id })
    else {
      status = "Independent writer could not prepare Weekend restoration"
      return
    }
    do {
      guard var sourceOnly = try JSONSerialization.jsonObject(with: before) as? [String: Any],
        let sources = sourceOnly["sources"] as? [[String: Any]],
        let listRecord = sources.first(where: {
          $0["id"] as? String == originalMembership.list.id.uuidString
        })
      else { throw CancellationError() }
      for key in sourceOnly.keys where key != "format" && key != "formatVersion" {
        sourceOnly[key] = []
      }
      sourceOnly["sources"] = [listRecord]
      guard
        case .decoded(let backup) = writer.decodeImport(
          try JSONSerialization.data(withJSONObject: sourceOnly)),
        case .reviewed(let deletion) = await writer.prepareReview(
          session: session, command: .deleteSource(source: originalMembership.list)),
        case .applied(_, .complete) = await writer.execute(
          .init(
            operationId: UUID(), session: session, command: deletion.command,
            reviewToken: deletion.reviewToken)
        ).outcome,
        case .reviewed(let restoration) = await writer.prepareReview(
          session: session,
          command: .applyImport(backup: backup, mode: .overwrite, restoreDeletedData: true)),
        case .applied(_, .complete) = await writer.execute(
          .init(
            operationId: UUID(), session: session, command: restoration.command,
            reviewToken: restoration.reviewToken)
        ).outcome,
        case .exported(let after) = await writer.exportData(session: session),
        case .decoded(let restored) = writer.decodeImport(after),
        let restoredList = restored.backup.lists.first(where: { $0.id == originalList.id }),
        restoredList.lifetimeId != originalList.lifetimeId,
        !restored.backup.memberships.contains(where: { $0.list.id == originalList.id }),
        case .source(.item(let retainedItem)) = await writer.read(
          session: session, request: .source(source)),
        retainedItem.sourceLifetimeId == originalItem.sourceLifetimeId,
        retainedItem.fieldHashes == originalItem.fieldHashes,
        retainedItem.updatedAt == originalItem.updatedAt
      else { throw CancellationError() }
      status = "Restored Weekend with a new lifetime"
    } catch {
      status = "Independent writer did not restore Weekend without its omitted membership"
    }
  }

  func deleteCityTrip() async {
    guard
      case .source(.item(let current)) = await writer.read(
        session: session, request: .source(source))
    else {
      status = "Independent writer could not read Hotel's Itinerary"
      return
    }
    for reference in current.references {
      guard case .itineraryEntry(_, let itinerary, let item) = reference, item == source else {
        continue
      }
      await deleteSource(itinerary, name: "City trip")
      return
    }
    status = "No City trip Itinerary to delete"
  }

  func removeCityTripEntry() async {
    removedCityTripEntry = nil
    guard
      case .source(.item(let current)) = await writer.read(
        session: session, request: .source(source))
    else {
      status = "Independent writer could not read Hotel's Itinerary entry"
      return
    }
    for reference in current.references {
      guard case .itineraryEntry(let entryIdentifier, let itinerary, let item) = reference,
        item == source
      else { continue }
      let result = await writer.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeItineraryEntry(itineraryId: itinerary.id, entryId: entryIdentifier)))
      if case .applied(_, .complete) = result.outcome {
        removedCityTripEntry = result.associationUndoSnapshot
        status = "Removed Hotel from City trip"
      } else {
        status = "Independent writer did not remove Hotel's Itinerary entry"
      }
      return
    }
    status = "No Hotel Itinerary entry to remove"
  }

  func removeFirstWeekendBranch() async {
    removedCityTripEntry = nil
    guard
      case .source(.item(let current)) = await writer.read(
        session: session, request: .source(source)),
      let itinerary = current.references.compactMap({ reference -> PlannerEntityReference? in
        guard case .itineraryEntry(_, let owner, let item) = reference, item == source else {
          return nil
        }
        return owner
      }).first,
      case .snapshot(let snapshot) = await writer.query(
        .init(
          session: session,
          request: .items(
            .init(
              scope: .itinerary(itinerary.id), completion: .all, archive: .all,
              sort: .init(mode: .manual)))))
    else {
      status = "Independent writer could not read the ordered Weekend branches"
      return
    }
    for row in snapshot.rows {
      guard case .appearance(_, .expandedListItem(_, let entryIdentifier, _)) = row else {
        continue
      }
      let result = await writer.execute(
        .init(
          operationId: UUID(), session: session,
          command: .removeItineraryEntry(itineraryId: itinerary.id, entryId: entryIdentifier)))
      if case .applied(_, .complete) = result.outcome {
        removedCityTripEntry = result.associationUndoSnapshot
        status = "Removed first Weekend branch from City trip"
      } else {
        status = "Independent writer did not remove the first Weekend branch"
      }
      return
    }
    status = "No Weekend branch to remove"
  }

  func restoreCityTripEntry() async {
    guard let snapshot = removedCityTripEntry,
      case .itineraryEntry(let original) = snapshot.originalRecord,
      case .source(.item(let before)) = await writer.read(
        session: session, request: .source(source))
    else {
      status = "No original City trip entry to restore"
      return
    }
    let result = await writer.execute(
      .init(operationId: UUID(), session: session, command: .restoreAssociation(snapshot: snapshot))
    )
    guard case .applied(_, .complete) = result.outcome,
      case .exported(let data) = await writer.exportData(session: session),
      case .decoded(let restored) = writer.decodeImport(data),
      let entry = restored.backup.itineraryEntries.first(where: { $0.id == original.id }),
      entry.lifetimeId != original.lifetimeId,
      entry.itinerary == original.itinerary,
      entry.itineraryLifetimeId == original.itineraryLifetimeId,
      entry.source == original.source, entry.sourceLifetimeId == original.sourceLifetimeId,
      entry.rank == original.rank, entry.localDone == original.localDone,
      snapshot.originalExpandedStates.allSatisfy({ originalState in
        restored.backup.expandedCompletions.contains { state in
          state.context.listEntryId == entry.id
            && state.context.listEntryLifetimeId == entry.lifetimeId
            && state.context.membershipId == originalState.context.membershipId
            && state.context.membershipLifetimeId == originalState.context.membershipLifetimeId
            && state.localDone == originalState.localDone
        }
      }),
      case .source(.item(let after)) = await writer.read(
        session: session, request: .source(source)),
      after.sourceLifetimeId == before.sourceLifetimeId,
      after.fieldHashes == before.fieldHashes, after.updatedAt == before.updatedAt
    else {
      status = "Independent writer did not restore the original City trip entry safely"
      return
    }
    removedCityTripEntry = nil
    status = "Restored original City trip entry"
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
    removedHotelMembership = nil
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
        removedHotelMembership = result.associationUndoSnapshot
        status = "Removed Hotel from Weekend"
      } else {
        status = "Independent writer did not remove Hotel's membership"
      }
      return
    }
    status = "No Hotel membership to remove"
  }

  func restoreHotelMembership() async {
    guard let snapshot = removedHotelMembership,
      case .membership(let original) = snapshot.originalRecord,
      case .source(.item(let before)) = await writer.read(
        session: session, request: .source(source))
    else {
      status = "No original Hotel membership to restore"
      return
    }
    let result = await writer.execute(
      .init(operationId: UUID(), session: session, command: .restoreAssociation(snapshot: snapshot))
    )
    guard case .applied(_, .complete) = result.outcome,
      case .exported(let data) = await writer.exportData(session: session),
      case .decoded(let restored) = writer.decodeImport(data),
      let membership = restored.backup.memberships.first(where: { $0.id == original.id }),
      membership.lifetimeId != original.lifetimeId,
      membership.list == original.list, membership.listLifetimeId == original.listLifetimeId,
      membership.item == original.item, membership.itemLifetimeId == original.itemLifetimeId,
      membership.rank == original.rank, membership.localDone == original.localDone,
      case .source(.item(let after)) = await writer.read(
        session: session, request: .source(source)),
      after.sourceLifetimeId == before.sourceLifetimeId,
      after.sourceLifetimeId == original.itemLifetimeId,
      after.fieldHashes == before.fieldHashes, after.updatedAt == before.updatedAt
    else {
      status = "Independent writer did not restore the original membership safely"
      return
    }
    removedHotelMembership = nil
    status = "Restored original Hotel membership"
  }

  func damageRecovery() async {
    guard damagedCheckpoint == nil,
      case .status(let current) = await writer.read(session: session, request: .status),
      case .known(let generation?, _, _, _) = current.recovery,
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
        case .known(_, let incomplete, _, false) = current.recovery, incomplete.isEmpty
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
