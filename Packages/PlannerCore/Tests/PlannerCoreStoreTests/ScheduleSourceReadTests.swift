import CryptoKit
import Foundation
import PlannerCore
import Testing

struct ScheduleSourceReadTests {
  @Test func savedScheduleHasItsOwnReadableIdentityAndSingleFormHashAfterReopen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let configuration = PlannerStorageConfiguration(
      storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
      controlURL: directory.appendingPathComponent("control/writer"),
      recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
      processRole: .mainApplication, storageMode: .localOnly)
    let planner = Planner(configuration: configuration)
    guard case .ready(let session) = await planner.bootstrap(),
      case .applied(let created, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createItem(content: PlannerItemContentInput(title: "Hotel", notes: "Keep")))
      )
      .outcome,
      let item = created.generated.first,
      case .applied(let scheduled, .complete) = await planner.execute(
        PlannerOperation(
          operationId: UUID(), session: session,
          command: .createSchedule(
            source: item,
            form: .timed(
              start: Date(timeIntervalSinceReferenceDate: 813_200_400),
              end: Date(timeIntervalSinceReferenceDate: 813_204_000), planningTimeZone: "Asia/Tokyo"
            )))
      )
      .outcome,
      let schedule = scheduled.generated.first
    else {
      Issue.record("The real Item and independent Tokyo appointment must be saved first.")
      return
    }
    guard
      case .source(.schedule(let read)) = await planner.read(
        session: session, request: .source(schedule))
    else {
      Issue.record("The saved Schedule must have a source read under its own identity.")
      return
    }
    #expect(read.source == schedule)
    #expect(read.fieldHashes.count == 1)
    #expect(read.content.source == item)
    #expect(
      read.content.form
        == .timed(
          start: Date(timeIntervalSinceReferenceDate: 813_200_400),
          end: Date(timeIntervalSinceReferenceDate: 813_204_000), planningTimeZone: "Asia/Tokyo"))
    #expect(Set(read.fieldHashes.keys) == [.form])
    guard
      case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces),
      let namespace = namespaces.first,
      case .selected(let recovery) = await planner.inspectRecovery(
        request: .acknowledgedSnapshot(
          namespaceId: namespace.namespaceId, checkpointGeneration: 2)),
      let savedSchedule = recovery.decodedBackup.backup.schedules.first
    else {
      Issue.record("Independent recovery must retain the Schedule's lifetime for its hash binding.")
      return
    }
    // The form bytes are literal accepted fixture bytes; only native-generated context UUIDs vary.
    let fixtureInput =
      "506c616e6e65724669656c64486173680000000001000000000000400080000000000008010600000000000040008000000000000701000000000000400080000000000008710000000000000004666f726d1800000000000000040000000000000003656e6415011941c83c411000000000000000000000046b696e6410000000000000000574696d65640000000000000010706c616e6e696e6754696d655a6f6e6510000000000000000a417369612f546f6b796f000000000000000573746172741941c83c3a08000000"
    let boundInput =
      fixtureInput
      .replacingOccurrences(
        of: "00000000000040008000000000000801",
        with: session.datasetId.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
      )
      .replacingOccurrences(
        of: "00000000000040008000000000000701",
        with: schedule.id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
      )
      .replacingOccurrences(
        of: "00000000000040008000000000000871",
        with: savedSchedule.lifetimeId.uuidString.replacingOccurrences(of: "-", with: "")
          .lowercased())
    let characters = Array(boundInput)
    let input = try Data(
      stride(from: 0, to: characters.count, by: 2).map { index in
        try #require(UInt8(String(characters[index...index + 1]), radix: 16))
      })
    let expectedHash = SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    #expect(read.fieldHashes[.form]?.value == "sha256-v1:" + expectedHash)
    let reopened = Planner(configuration: configuration)
    guard case .ready(let reopenedSession) = await reopened.bootstrap(),
      case .source(.schedule(let retained)) = await reopened.read(
        session: reopenedSession, request: .source(schedule))
    else {
      Issue.record("Reopening must retain the same Schedule read and guarded form hash.")
      return
    }
    #expect(retained.source == schedule)
    #expect(retained.fieldHashes == read.fieldHashes)
  }
}
