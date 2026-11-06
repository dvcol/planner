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
      case suspended
      case unavailable
    }

    struct Context {
      let planner: PlannerCore.Planner
      let session: PlannerDatasetSession
      let controlURL: URL

      var preferenceURL: URL {
        controlURL.deletingLastPathComponent().appending(path: "AgentControlPreference.plist")
      }
    }

    private struct Preference: Codable {
      let formatVersion: Int
      let datasetId: UUID
      let ownershipBinding: String
      let port: UInt16
      var enabled: Bool

      func matches(_ session: PlannerDatasetSession) -> Bool {
        formatVersion == 1 && port != 0 && datasetId == session.datasetId
          && ownershipBinding == session.ownershipBinding
      }
    }

    private struct Access {
      let connection: PlannerAgentConnection
      let controlURL: URL
      let handler: PlannerMCPRequestHandler
      let listener: PlannerMCPLoopbackListener
      let session: PlannerDatasetSession
    }

    private(set) var state = State.off
    private(set) var notice: String?
    private let mainInstance = UUID()
    private var attempt: UUID?
    private var starting: Task<Void, Never>?
    private var stopping: Task<Void, Never>?
    private var access: Access?
    private var context: Context?
    private var preference: Preference?

    var isEnabled: Bool {
      if case .on = state { return true }
      return false
    }

    var isConfigured: Bool {
      guard let context, let preference else { return false }
      return preference.enabled && preference.matches(context.session)
    }

    func enable(_ context: Context, port: UInt16 = 44444) async {
      guard state == .off || state == .suspended || state == .unavailable else { return }
      guard port != 0 else {
        state = .unavailable
        notice = "Choose a port from 1 to 65535."
        return
      }
      self.context = context
      let choice = Preference(
        formatVersion: 1, datasetId: context.session.datasetId,
        ownershipBinding: context.session.ownershipBinding, port: port, enabled: true)
      do {
        try save(choice, to: context.preferenceURL)
        preference = choice
      } catch {
        state = .unavailable
        notice = "The agent access setting could not be saved. Try again."
        return
      }
      await startEnabledContext(context, port: port)
    }

    /// Reuse consent only for the exact dataset and owner; every replacement gets fresh credentials.
    func resume(_ context: Context) async {
      if let access, access.session == context.session, access.controlURL == context.controlURL {
        return
      }
      let identifier = UUID()
      attempt = identifier
      self.context = context
      await stopRuntime()
      guard attempt == identifier else { return }
      do {
        preference = nil
        if FileManager.default.fileExists(atPath: context.preferenceURL.path) {
          preference = try PropertyListDecoder().decode(
            Preference.self, from: Data(contentsOf: context.preferenceURL))
        }
        guard isConfigured, let preference else { return }
        await startEnabledContext(context, port: preference.port)
      } catch {
        state = .unavailable
        notice = "The saved agent access setting could not be read. Enable access again to retry."
      }
    }

    /// Lifecycle interruption revokes the live window without changing the saved choice.
    func suspend() async {
      let identifier = UUID()
      attempt = identifier
      await stopRuntime()
      guard attempt == identifier else { return }
      if isConfigured { state = .suspended }
    }

    private func startEnabledContext(_ context: Context, port: UInt16) async {
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
      attempt = nil
      if let context {
        do {
          var current: Preference?
          if FileManager.default.fileExists(atPath: context.preferenceURL.path) {
            current = try PropertyListDecoder().decode(
              Preference.self, from: Data(contentsOf: context.preferenceURL))
          }
          preference = current
          if var choice = current, choice.matches(context.session) {
            choice.enabled = false
            try save(choice, to: context.preferenceURL)
            preference = choice
          }
        } catch {
          notice = "Access stopped, but the saved setting could not be updated. Try Stop again."
        }
      }
      await stopRuntime()
    }

    private func stopRuntime() async {
      if let stopping {
        await stopping.value
        return
      }
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
      guard attempt == identifier else { return }
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
          handler: handler, listener: listener, session: context.session)
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

    private func save(_ preference: Preference, to url: URL) throws {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try PropertyListEncoder().encode(preference).write(to: url, options: .atomic)
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
