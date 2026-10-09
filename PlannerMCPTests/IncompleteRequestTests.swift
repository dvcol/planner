import Foundation
import Network
import Testing

@testable import Planner

@Suite
struct IncompleteRequestTests {
  @Test(.timeLimit(.minutes(1)))
  func stopClosesAConnectionWaitingForTheRestOfItsBody() async throws {
    let requestHandler = PlannerMCPRequestHandler(
      credential: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      accessWindowIdentifier: UUID(uuidString: "00000000-0000-4000-8000-000000000701")!
    )
    let listener = PlannerMCPLoopbackListener(requestHandler: requestHandler)
    let endpoint = try await listener.start(port: 0)
    let portNumber = try #require(endpoint.port)
    let portValue = try #require(UInt16(exactly: portNumber))
    let port = try #require(NWEndpoint.Port(rawValue: portValue))
    let connection = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
    defer { connection.cancel() }

    do {
      try await establishConnection(connection)
      let partialRequest =
        "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:\(portNumber)\r\nAuthorization: Bearer AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nContent-Type: application/json\r\nAccept: application/json\r\nContent-Length: 10\r\n\r\n"
      try await send(partialRequest, through: connection)
      async let remoteClosure = receive(from: connection)

      await listener.stop()
      let observation = await remoteClosure

      #expect(observation.content == nil || observation.content?.isEmpty == true)
      #expect(observation.isComplete || observation.error == .posix(.ECONNRESET))
    } catch {
      await listener.stop()
      throw error
    }
  }

  private func establishConnection(_ connection: NWConnection) async throws {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, Error>) in
        connection.stateUpdateHandler = { state in
          switch state {
          case .ready:
            connection.stateUpdateHandler = nil
            continuation.resume()
          case .failed(let error):
            connection.stateUpdateHandler = nil
            continuation.resume(throwing: error)
          case .cancelled:
            connection.stateUpdateHandler = nil
            continuation.resume(throwing: URLError(.cancelled))
          default:
            break
          }
        }
        connection.start(queue: DispatchQueue(label: "Planner incomplete request fixture"))
      }
    } onCancel: {
      connection.cancel()
    }
  }

  private func send(_ request: String, through connection: NWConnection) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      connection.send(
        content: Data(request.utf8),
        completion: .contentProcessed { error in
          if let error {
            continuation.resume(throwing: error)
            return
          }
          continuation.resume()
        })
    }
  }

  private func receive(from connection: NWConnection) async -> ConnectionClosure {
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) {
          content, _, isComplete, error in
          continuation.resume(
            returning: ConnectionClosure(content: content, isComplete: isComplete, error: error))
        }
      }
    } onCancel: {
      connection.cancel()
    }
  }
}

private struct ConnectionClosure: Sendable {
  let content: Data?
  let isComplete: Bool
  let error: NWError?
}
