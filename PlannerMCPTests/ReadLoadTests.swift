import Darwin
import Foundation
import PlannerCore
import Testing

@testable import Planner

struct ReadLoadTests {
  @Test(.timeLimit(.minutes(2)))
  func sixtyFourHotelReadsAtEachConcurrencyRetainSourceAndRecovery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let planner = PlannerCore.Planner(
      configuration: PlannerStorageConfiguration(
        storeURL: directory.appendingPathComponent("store/Planner.sqlite"),
        controlURL: directory.appendingPathComponent("control/writer"),
        recoveryDirectoryURL: directory.appendingPathComponent("recovery"),
        processRole: .mainApplication, storageMode: .localOnly))
    guard case .ready(let datasetSession) = await planner.bootstrap() else {
      Issue.record("The real dataset must initialize.")
      return
    }
    let created = await planner.execute(
      PlannerOperation(
        operationId: UUID(), session: datasetSession,
        command: .createItem(
          content: PlannerItemContentInput(title: "Hotel", notes: "Original notes"))))
    guard case .applied(let result, .complete(let checkpoint)) = created.outcome else {
      Issue.record("Hotel must be independently saved before load measurement.")
      return
    }
    let source = try #require(result.generated.first)
    guard
      case .source(let original) = await planner.read(
        session: datasetSession, request: .source(source))
    else {
      Issue.record("The source must be readable before measurement.")
      return
    }
    let accessWindowIdentifier = UUID()
    let handler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      accessWindowIdentifier: accessWindowIdentifier,
      planner: planner, datasetSession: datasetSession)
    let listener = PlannerMCPLoopbackListener(requestHandler: handler)
    let endpoint = try await listener.start(port: 0)
    let request = try readRequest(endpoint: endpoint, sourceIdentifier: source.id)
    do {
      for concurrency in [1, 2, 4, 8, 16, 32] {
        let measurement = try await measure(
          request: request, concurrency: concurrency,
          sourceIdentifier: source.id, accessWindowIdentifier: accessWindowIdentifier)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        print(
          "PLANNER_MCP_READ_LOAD "
            + String(decoding: try encoder.encode(measurement), as: UTF8.self))
        #expect(measurement.completed == 64)
        #expect(measurement.rejected == 0)
        #expect(measurement.cancelled == 0)
        #expect(measurement.failed == 0)
      }
      await listener.stop()
      guard
        case .source(let current) = await planner.read(
          session: datasetSession, request: .source(source))
      else {
        Issue.record("Read-only load must retain Hotel.")
        return
      }
      #expect(current.content.title == "Hotel")
      #expect(current.content.notes == "Original notes")
      #expect(current.state.globalDone == false)
      #expect(current.state.archived == false)
      #expect(current.updatedAt == original.updatedAt)
      #expect(current.fieldHashes == original.fieldHashes)
      guard
        case .snapshot(let snapshot) = await planner.query(
          PlannerQuery(
            session: datasetSession,
            request: .items(PlannerItemQuery())))
      else {
        Issue.record("Read-only load must retain the complete public query.")
        return
      }
      #expect(snapshot.matchingCount == 1)
      #expect(snapshot.rows == [.source(source)])
      guard
        case .listedNamespaces(let namespaces) = await planner.inspectRecovery(request: .namespaces)
      else {
        Issue.record("Read-only load must retain independent recovery.")
        return
      }
      #expect(namespaces.first?.acknowledgedSnapshot?.checkpointGeneration == checkpoint)
      #expect(namespaces.first?.preparedProposals.isEmpty == true)
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func measure(
    request: URLRequest, concurrency: Int, sourceIdentifier: UUID,
    accessWindowIdentifier: UUID
  ) async throws -> Measurement {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpMaximumConnectionsPerHost = concurrency
    let httpSession = URLSession(configuration: configuration)
    defer { httpSession.invalidateAndCancel() }
    let baseline = try memory()
    var observations: [Observation] = []
    var sampledPeakFootprintBytes = baseline.footprintBytes
    let clock = ContinuousClock()
    let started = clock.now
    try await withThrowingTaskGroup(of: Observation.self) { group in
      for _ in 0..<concurrency {
        group.addTask {
          await observe(
            request: request, httpSession: httpSession,
            sourceIdentifier: sourceIdentifier, accessWindowIdentifier: accessWindowIdentifier)
        }
      }
      var submitted = concurrency
      while let observation = try await group.next() {
        observations.append(observation)
        sampledPeakFootprintBytes = max(sampledPeakFootprintBytes, try memory().footprintBytes)
        if submitted < 64 {
          submitted += 1
          group.addTask {
            await observe(
              request: request, httpSession: httpSession,
              sourceIdentifier: sourceIdentifier, accessWindowIdentifier: accessWindowIdentifier)
          }
        }
      }
    }
    let elapsedMilliseconds = milliseconds(clock.now - started)
    httpSession.invalidateAndCancel()
    try await Task.sleep(for: .milliseconds(250))
    let settled = try memory()
    let latencies = observations.filter { $0.state == .completed }.map(\.latencyMilliseconds)
      .sorted()
    return Measurement(
      concurrency: concurrency, submitted: 64,
      completed: observations.filter { $0.state == .completed }.count,
      rejected: observations.filter { $0.state == .rejected }.count,
      cancelled: observations.filter { $0.state == .cancelled }.count,
      failed: observations.filter { $0.state == .failed }.count,
      elapsedMilliseconds: elapsedMilliseconds,
      completedLatencyMilliseconds: Latencies(
        minimum: latencies.first, median: percentile(latencies, fraction: 0.5),
        percentile95: percentile(latencies, fraction: 0.95),
        percentile99: percentile(latencies, fraction: 0.99), maximum: latencies.last),
      baselineMemory: baseline, sampledPeakFootprintBytes: sampledPeakFootprintBytes,
      settledAfterMilliseconds: 250, settledMemory: settled,
      failures: observations.compactMap(\.failure))
  }

  private func observe(
    request: URLRequest, httpSession: URLSession, sourceIdentifier: UUID,
    accessWindowIdentifier: UUID
  ) async -> Observation {
    let clock = ContinuousClock()
    let started = clock.now
    do {
      let exchange = try await httpSession.data(for: request)
      let elapsed = milliseconds(clock.now - started)
      guard let response = exchange.1 as? HTTPURLResponse, response.statusCode == 200 else {
        return Observation(
          state: .rejected, latencyMilliseconds: elapsed, failure: "HTTP response was not 200.")
      }
      guard response.value(forHTTPHeaderField: "MCP-Session-Id") == nil,
        response.value(forHTTPHeaderField: "X-Planner-Access-Window")
          == accessWindowIdentifier.uuidString,
        let envelope = try JSONSerialization.jsonObject(with: exchange.0) as? [String: Any],
        envelope["id"] as? Int == 7, envelope["error"] == nil,
        let tool = envelope["result"] as? [String: Any], tool["isError"] as? Bool == false,
        let structured = tool["structuredContent"] as? [String: Any],
        structured["formatVersion"] as? Int == 1,
        structured["kind"] as? String == "source",
        let value = structured["value"] as? [String: Any],
        let source = value["source"] as? [String: Any], source["kind"] as? String == "item",
        source["id"] as? String == sourceIdentifier.uuidString,
        let content = value["content"] as? [String: Any], content["title"] as? String == "Hotel",
        content["notes"] as? String == "Original notes",
        let state = value["state"] as? [String: Any],
        state["globalDone"] as? Bool == false, state["archived"] as? Bool == false
      else {
        return Observation(
          state: .rejected, latencyMilliseconds: elapsed,
          failure: "Response did not retain the requested Hotel/window/protocol values.")
      }
      return Observation(state: .completed, latencyMilliseconds: elapsed, failure: nil)
    } catch let error as URLError where error.code == .cancelled {
      return Observation(
        state: .cancelled, latencyMilliseconds: milliseconds(clock.now - started),
        failure: "URLSession cancelled the request.")
    } catch {
      return Observation(
        state: .failed, latencyMilliseconds: milliseconds(clock.now - started),
        failure: error.localizedDescription)
    }
  }

  private func readRequest(endpoint: URL, sourceIdentifier: UUID) throws -> URLRequest {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "jsonrpc": "2.0", "id": 7, "method": "tools/call",
      "params": [
        "name": "planner_read",
        "arguments": [
          "formatVersion": 1,
          "request": [
            "kind": "source", "source": ["kind": "item", "id": sourceIdentifier.uuidString],
          ],
        ],
      ],
    ])
    request.setValue(
      "Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("2025-11-25", forHTTPHeaderField: "MCP-Protocol-Version")
    request.timeoutInterval = 10
    return request
  }

  private func memory() throws -> Memory {
    var information = task_vm_info_data_t()
    let requiredCount = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    var count = requiredCount
    let capacity = Int(count)
    let result = withUnsafeMutablePointer(to: &information) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) { rebound in
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
      }
    }
    guard result == KERN_SUCCESS, count == requiredCount,
      information.ledger_phys_footprint_peak >= 0
    else {
      throw NSError(
        domain: "PlannerMCPReadLoadMemory", code: Int(result),
        userInfo: [NSLocalizedDescriptionKey: "Native process memory counters were unavailable."])
    }
    return Memory(
      footprintBytes: information.phys_footprint, residentBytes: information.resident_size,
      processLifetimePeakFootprintBytes: information.ledger_phys_footprint_peak,
      processLifetimePeakResidentBytes: information.resident_size_peak)
  }

  private func milliseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds)
      / 1_000_000_000_000_000
  }

  private func percentile(_ values: [Double], fraction: Double) -> Double? {
    guard !values.isEmpty else { return nil }
    return values[Int(ceil(Double(values.count) * fraction)) - 1]
  }

  private struct Observation: Sendable {
    enum State { case completed, rejected, cancelled, failed }
    let state: State
    let latencyMilliseconds: Double
    let failure: String?
  }

  private struct Memory: Codable {
    let footprintBytes: UInt64
    let residentBytes: UInt64
    let processLifetimePeakFootprintBytes: Int64
    let processLifetimePeakResidentBytes: UInt64
  }

  private struct Latencies: Codable {
    let minimum: Double?
    let median: Double?
    let percentile95: Double?
    let percentile99: Double?
    let maximum: Double?
  }

  private struct Measurement: Codable {
    let concurrency: Int
    let submitted: Int
    let completed: Int
    let rejected: Int
    let cancelled: Int
    let failed: Int
    let elapsedMilliseconds: Double
    let completedLatencyMilliseconds: Latencies
    let baselineMemory: Memory
    let sampledPeakFootprintBytes: UInt64
    let settledAfterMilliseconds: Int
    let settledMemory: Memory
    let failures: [String]
  }
}
