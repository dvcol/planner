#if PLANNER_AGENT_CONTROL
  import Foundation
  import MCP
  import Observation
  import PlannerCore

  @MainActor @Observable
  final class PlannerAgentAccess {
    enum State: Equatable {
      case off
      case enabling
      case on(URL)
      case stopping
      case unavailable
    }

    struct Context {
      let planner: PlannerCore.Planner
      let session: PlannerDatasetSession
      let controlURL: URL
    }

    private struct Access {
      let connection: PlannerAgentConnection
      let controlURL: URL
      let handler: PlannerMCPRequestHandler
      let listener: PlannerMCPLoopbackListener
    }

    private(set) var state = State.off
    private(set) var notice: String?
    private let mainInstance = UUID()
    private var attempt: UUID?
    private var starting: Task<Void, Never>?
    private var stopping: Task<Void, Never>?
    private var access: Access?

    var isEnabled: Bool {
      if case .on = state { return true }
      return false
    }

    func enable(_ context: Context, port: UInt16 = 44444) async {
      guard state == .off || state == .unavailable else { return }
      guard port != 0 else {
        state = .unavailable
        notice = "Choose a port from 1 to 65535."
        return
      }
      let identifier = UUID()
      attempt = identifier
      state = .enabling
      notice = nil
      let task = Task { await start(context, port: port, attempt: identifier) }
      starting = task
      await task.value
      if attempt == identifier { starting = nil }
    }

    func stop() async {
      if let stopping {
        await stopping.value
        return
      }
      attempt = nil
      state = .stopping
      let task = Task {
        await access?.handler.revokeAccess()
        await starting?.value
        starting = nil
        await clearAccess()
        state = .off
      }
      stopping = task
      await task.value
      stopping = nil
    }

    private func start(_ context: Context, port: UInt16, attempt identifier: UUID) async {
      let window = UUID()
      do {
        let credential = try PlannerAgentCredential.create(window: window)
        let handler = PlannerMCPRequestHandler(
          credential: credential, accessWindowIdentifier: window,
          planner: context.planner, datasetSession: context.session)
        let listener = PlannerMCPLoopbackListener(requestHandler: handler)
        guard let endpoint = URL(string: "http://127.0.0.1:\(port)/mcp") else {
          try PlannerAgentCredential.remove(window: window)
          throw PlannerAgentFailure.agentControlUnavailable
        }
        let connection = PlannerAgentConnection(
          formatVersion: 1, mainInstanceId: mainInstance, accessWindowId: window,
          endpoint: endpoint, protocolVersion: Version.latest, state: "on")
        access = .init(
          connection: connection, controlURL: context.controlURL,
          handler: handler, listener: listener)
        _ = try await listener.start(port: port)
        guard attempt == identifier else {
          await clearAccess()
          return
        }
        try connection.write(to: context.controlURL)
        state = .on(endpoint)
      } catch {
        await clearAccess()
        if attempt == identifier {
          state = .unavailable
          if case .credentialUnavailable(let status) = error as? PlannerAgentFailure {
            notice = "Keychain access is unavailable (\(status)). Try enabling agent access again."
          } else {
            notice = "Agent access could not start. Check that the port is available and try again."
          }
        }
      }
    }

    /// Revoke before cleanup; leftover discovery files never grant access by themselves.
    private func clearAccess() async {
      guard let current = access else { return }
      access = nil
      await current.listener.stop()
      do {
        if FileManager.default.fileExists(atPath: current.controlURL.path),
          try PlannerAgentConnection.read(from: current.controlURL) == current.connection
        {
          try FileManager.default.removeItem(at: current.controlURL)
        }
      } catch {
        notice = "Access stopped. Some old connection metadata could not be removed."
      }
      do { try PlannerAgentCredential.remove(window: current.connection.accessWindowId) } catch {
        notice = "Access stopped. The old Keychain credential could not be removed."
      }
    }
  }
#endif
