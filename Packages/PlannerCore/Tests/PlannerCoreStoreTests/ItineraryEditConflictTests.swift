import Foundation
import PlannerCore
import Testing

struct ItineraryEditConflictTests {
  @Test func everyStaleItineraryFieldReturnsCurrentTypedValueWithoutMutation() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = Planner(
      configuration: .init(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let session) = await planner.bootstrap() else {
      Issue.record("Open the native dataset for typed conflict checks.")
      return
    }
    func create(_ command: PlannerCommand) async throws -> PlannerEntityReference {
      let outcome = await planner.execute(
        .init(operationId: UUID(), session: session, command: command)
      ).outcome
      guard case .applied(let result, .complete) = outcome, let source = result.generated.first
      else {
        Issue.record("Save each conflict fixture source.")
        throw MissingResult()
      }
      return source
    }
    let food = try await create(.createCategory(content: .init(name: "Food")))
    let culture = try await create(.createCategory(content: .init(name: "Culture")))
    let rain = try await create(.createTag(content: .init(name: "Rain")))
    let sunny = try await create(.createTag(content: .init(name: "Sunny")))
    let itinerary = try await create(
      .createItinerary(
        content: .init(
          title: "Tokyo", notes: "Keep",
          color: .init(red: 0, green: 0, blue: 1, alpha: 1), iconName: "map",
          location: .init(displayName: "Hotel", formattedAddress: "Tokyo", coordinate: nil),
          links: [.init(originalUrl: "https://example.com/route")], categoryIds: [food.id],
          tagIds: [rain.id])))
    guard
      case .source(.itinerary(let original)) = await planner.read(
        session: session, request: .source(itinerary)),
      let originalLink = original.content.links.first
    else {
      Issue.record("Read the exact initial link identity and all field guards.")
      return
    }
    let savedIdentifier = UUID()
    let savedCommand = PlannerCommand.editItinerary(
      sourceId: itinerary.id,
      changes: .init(
        title: .set("Tokyo weekend"), notes: .clear, color: .clear, iconName: .clear,
        location: .clear,
        links: .set([.init(linkId: originalLink.linkId, originalUrl: "https://example.com/friday")]
        ),
        categoryIds: .set([culture.id]), tagIds: .set([sunny.id])),
      expectedFieldHashes: original.fieldHashes)
    let savedOutcome = await planner.execute(
      .init(operationId: savedIdentifier, session: session, command: savedCommand)
    ).outcome
    guard case .applied(let savedResult, .complete(let savedCheckpoint)) = savedOutcome,
      case .source(.itinerary(let current)) = await planner.read(
        session: session, request: .source(itinerary))
    else {
      Issue.record("Save all changed fields before stale guard checks: \(savedOutcome)")
      return
    }
    let attempts: [(PlannerItineraryField, PlannerItineraryChanges, PlannerItineraryFieldValue)] = [
      (.title, .init(title: .set("Must not save")), .string("Tokyo weekend")),
      (.notes, .init(notes: .set("Must not save")), .optionalString(nil)),
      (.color, .init(color: .set(.init(red: 1, green: 0, blue: 0, alpha: 1))), .optionalColor(nil)),
      (.iconName, .init(iconName: .set("tram")), .optionalString(nil)),
      (
        .location,
        .init(location: .set(.init(displayName: "Museum", formattedAddress: nil, coordinate: nil))),
        .optionalLocation(nil)
      ),
      (
        .links,
        .init(
          links: .set([.init(linkId: originalLink.linkId, originalUrl: "https://example.com/stale")]
          )), .links(current.content.links)
      ),
      (.categoryIds, .init(categoryIds: .set([food.id])), .identitySet([culture.id])),
      (.tagIds, .init(tagIds: .set([rain.id])), .identitySet([sunny.id])),
    ]
    for (field, changes, currentValue) in attempts {
      let operationIdentifier = UUID()
      let outcome = await planner.execute(
        .init(
          operationId: operationIdentifier, session: session,
          command: .editItinerary(
            sourceId: itinerary.id, changes: changes, expectedFieldHashes: original.fieldHashes))
      ).outcome
      guard case .rejected(let reason) = outcome,
        case .staleItineraryEdit(let fields, let values, let hashes) = reason.details,
        case .noReliableEvidence = await planner.operationStatus(
          session: session, operationId: operationIdentifier)
      else {
        Issue.record(
          "A stale field must return its typed current value without a receipt: \(outcome)")
        return
      }
      let currentHash = try #require(current.fieldHashes[field])
      #expect(reason.code == "staleEdit")
      #expect(fields == [field])
      #expect(values == [field: currentValue])
      #expect(hashes == [field: currentHash])
    }
    let mismatchOutcome = await planner.execute(
      .init(
        operationId: savedIdentifier, session: session,
        command: .editItinerary(
          sourceId: itinerary.id, changes: .init(notes: .set("Different payload")),
          expectedFieldHashes: current.fieldHashes))
    ).outcome
    guard case .rejected(let mismatch) = mismatchOutcome,
      case .source(.itinerary(let retained)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .listedNamespaces(let beforeNamespaces) = await planner.inspectRecovery(
        request: .namespaces), let beforeNamespace = beforeNamespaces.first,
      case .source(.category(let cultureRead)) = await planner.read(
        session: session, request: .source(culture))
    else {
      Issue.record("A receipt identity cannot be reused for another patch.")
      return
    }
    #expect(mismatch.code == "operationPayloadMismatch")
    #expect(retained.content == current.content && retained.fieldHashes == current.fieldHashes)
    #expect(retained.references == current.references && retained.updatedAt == current.updatedAt)
    #expect(beforeNamespace.acknowledgedSnapshot?.checkpointGeneration == savedCheckpoint)
    #expect(beforeNamespace.preparedProposals.isEmpty)
    let renameOutcome = await planner.execute(
      .init(
        operationId: UUID(), session: session,
        command: .editCategory(
          sourceId: culture.id, changes: .init(name: .set("Museums")),
          expectedFieldHashes: cultureRead.fieldHashes))
    ).outcome
    guard case .applied(_, .complete(let renameCheckpoint)) = renameOutcome,
      case .source(.itinerary(let refreshed)) = await planner.read(
        session: session, request: .source(itinerary)),
      case .applied(let replayResult, .complete(let replayCheckpoint)) = await planner.execute(
        .init(operationId: savedIdentifier, session: session, command: savedCommand)
      ).outcome,
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first
    else {
      Issue.record(
        "Selected labels stay live and an original edit replay preserves their later rename.")
      return
    }
    #expect(refreshed.labels.map(\.name).contains("Museums"))
    #expect(!refreshed.labels.map(\.name).contains("Culture"))
    #expect(refreshed.content == current.content && refreshed.fieldHashes == current.fieldHashes)
    #expect(refreshed.updatedAt == current.updatedAt && refreshed.references == current.references)
    #expect(replayResult == savedResult && replayCheckpoint == savedCheckpoint)
    #expect(renameCheckpoint == savedCheckpoint + 1)
    #expect(namespace.acknowledgedSnapshot?.checkpointGeneration == renameCheckpoint)
    #expect(namespace.preparedProposals.isEmpty)
  }
  private struct MissingResult: Error {}
}
