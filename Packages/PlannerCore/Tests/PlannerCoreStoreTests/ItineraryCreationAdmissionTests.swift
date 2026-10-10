import Foundation
import PlannerCore
import Testing

struct ItineraryCreationAdmissionTests {
  @Test func invalidItineraryCreationLeavesNoMutationAndDuplicateNamesRetainSeparateSources()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Initialize the real store before invalid creation attempts.")
      return
    }
    let invalidInputs: [(PlannerItineraryContentInput, String, String)] = [
      (.init(title: " \n "), "invalidInput", "/command/content/title"),
      (
        .init(title: "Tokyo", color: .init(red: .nan, green: 0, blue: 0, alpha: 1)), "invalidInput",
        "/command/content/color/red"
      ),
      (
        .init(
          title: "Tokyo",
          location: .init(
            displayName: nil, formattedAddress: nil, coordinate: .init(latitude: 91, longitude: 139)
          )), "invalidInput", "/command/content/location/coordinate"
      ),
      (
        .init(title: "Tokyo", links: [.init(linkId: UUID(), originalUrl: "https://example.com")]),
        "invalidInput", "/command/content/links/0/linkId"
      ),
      (
        .init(title: "Tokyo", links: [.init(originalUrl: "file:///private/tmp/route")]),
        "invalidInput", "/command/content/links/0/originalUrl"
      ),
      (
        .init(title: "Tokyo", categoryIds: [UUID()]), "missingReference",
        "/command/content/categoryIds"
      ),
      (.init(title: "Tokyo", tagIds: [UUID()]), "missingReference", "/command/content/tagIds"),
    ]
    for (input, code, path) in invalidInputs {
      guard
        case .rejected(let reason) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session, command: .createItinerary(content: input))
        ).outcome
      else {
        Issue.record("Invalid Itinerary input must reject before saving or preparing recovery.")
        continue
      }
      #expect(reason.code == code)
      #expect(reason.propertyPath == path)
    }
    guard
      case .listedNamespaces(let emptyNamespaces) = await planner.inspectRecovery(
        request: .namespaces)
    else {
      Issue.record("Inspect recovery without creating a source.")
      return
    }
    #expect(emptyNamespaces.first?.acknowledgedSnapshot == nil)
    #expect(emptyNamespaces.first?.preparedProposals.isEmpty == true)
    var sources: [PlannerEntityReference] = []
    for _ in 0..<2 {
      guard
        case .applied(let created, .complete) = await planner.execute(
          PlannerOperation(
            operationId: UUID(), session: session,
            command: .createItinerary(content: .init(title: "Tokyo", notes: nil, iconName: "")))
        ).outcome,
        let source = created.generated.first,
        case .source(.itinerary(let read)) = await planner.read(
          session: session, request: .source(source))
      else {
        Issue.record("Equal Itinerary titles remain separate sources with ordinary empty defaults.")
        return
      }
      sources.append(source)
      #expect(read.content.notes == nil)
      #expect(read.content.iconName == "")
      #expect(read.content.color == nil)
      #expect(read.content.location == nil)
      #expect(read.content.links.isEmpty)
      #expect(read.content.categoryIds.isEmpty)
      #expect(read.content.tagIds.isEmpty)
      #expect(read.labels.isEmpty)
      #expect(read.references.isEmpty)
      #expect(read.progress.state == .empty)
    }
    #expect(sources[0] != sources[1])
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 2))
    else {
      Issue.record("Recover both independently created sources without invalid-attempt evidence.")
      return
    }
    #expect(
      Set(recovery.decodedBackup.backup.sources.filter { $0.kind == .itinerary }.map(\.id))
        == Set(sources.map(\.id)))
    #expect(namespace.preparedProposals.isEmpty)
    #expect(recovery.checkpointGeneration == 2)
  }
}
