#if PLANNER_AGENT_CONTROL
  import Darwin
  import Foundation
  import Observation

  @MainActor @Observable
  final class PlannerAgentTunnel {
    enum State: Equatable {
      case off
      case starting
      case ready
      case unavailable
    }

    private(set) var state = State.off
    private(set) var notice: String?
    private(set) var connection: PlannerAgentTunnelConnection?
    private var context: PlannerAgentAccess.Context?
    private var process: Process?
    private var identity: PlannerAgentTunnelProcess?
    private var directory: URL?
    private var recordURL: URL?
    private let ownerId = UUID()
    private var record: PlannerAgentTunnelProcess.Record?
    private var monitor: Task<Void, Never>?
    private var stopping: Task<Bool, Never>?
    private var attempt = UUID()

    var configuredTunnelId: String { connection?.binding.tunnelId ?? "" }
    var contextIdentifier: UUID? { context?.session.sessionId }
    var matchesLibrary: Bool {
      guard let context, let connection else { return false }
      return connection.binding.matches(context.session)
    }

    func showFailure(_ error: Error) {
      state = .unavailable
      notice =
        (error as? PlannerAgentTunnelFailure)?.message
        ?? "The private connection could not be saved or read. Check Keychain access and try again."
    }

    func configure(_ context: PlannerAgentAccess.Context) {
      self.context = context
      recordURL = context.controlURL.deletingLastPathComponent().appending(
        path: "AgentTunnelProcess.plist")
      do {
        connection = try PlannerAgentTunnelConnection.load(
          from: PlannerAgentTunnelConnection.settingsURL(for: context.controlURL))
        notice = nil
        if connection != nil && !matchesLibrary {
          state = .unavailable
          notice = PlannerAgentTunnelFailure.differentLibrary.message
        }
      } catch {
        connection = nil
        state = .unavailable
        notice = "The saved private connection could not be read. Remove it and configure it again."
      }
    }

    func save(tunnelId: String, runtimeKey: String) throws {
      guard let context else { throw PlannerAgentTunnelFailure.invalidConnection }
      connection = try PlannerAgentTunnelConnection.save(
        tunnelId: tunnelId.trimmingCharacters(in: .whitespacesAndNewlines),
        runtimeKey: runtimeKey.trimmingCharacters(in: .whitespacesAndNewlines), context: context)
      notice = nil
    }

    func remove() throws {
      guard let context else { return }
      try PlannerAgentTunnelConnection.remove(
        from: PlannerAgentTunnelConnection.settingsURL(for: context.controlURL))
      connection = nil
      notice = nil
      state = .off
    }

    /// The parent supplies only the fresh credential for its already-ready local access window.
    func start(local: PlannerAgentConnection, credential: String) async {
      let identifier = UUID()
      attempt = identifier
      guard await stopRuntime(), attempt == identifier else { return }
      guard let context, let connection else {
        if notice != nil { state = .unavailable }
        return
      }
      guard matchesLibrary else {
        showFailure(PlannerAgentTunnelFailure.differentLibrary)
        return
      }
      state = .starting
      notice = nil
      do {
        guard await reconcileRuntime(), attempt == identifier else { return }
        try local.validated()
        try await Task.detached {
          try PlannerAgentTunnelProcess.validateExecutable()
          try PlannerAgentTunnelProcess.validateExecutable(helper: .bridge)
        }.value
        guard attempt == identifier else { return }
        let runtimeKey = try PlannerAgentTunnelKey.read(id: connection.keyId)
        let directory = context.controlURL.deletingLastPathComponent()
          .appending(
            path: "AgentTunnel-" + local.accessWindowId.uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
          at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        self.directory = directory
        var record = PlannerAgentTunnelProcess.Record(
          ownerId: ownerId, windowId: local.accessWindowId)
        self.record = record
        guard let recordURL else { throw PlannerAgentTunnelFailure.runtimeUnavailable }
        try PropertyListEncoder().encode(record).write(to: recordURL, options: .atomic)
        let healthURLFile = directory.appending(path: "health.url")
        let owner = try PlannerAgentTunnelProcess.identity(pid: getpid())
        let bridgeCommand =
          "'"
          + PlannerAgentTunnelProcess.Helper.bridge.executable.path
          .replacingOccurrences(of: "'", with: "'\\''") + "'"
        let child = Process()
        child.executableURL = PlannerAgentTunnelProcess.executable
        child.arguments = [
          "run", "--control-plane.tunnel-id", connection.binding.tunnelId,
          "--mcp.command", bridgeCommand, "--mcp.stdio-failure-policy", "exit",
          "--health.listen-addr", "127.0.0.1:0", "--health.url-file", healthURLFile.path,
          "--pid.file", directory.appending(path: "runtime.pid").path,
          "--log.level", "warn", "--log.format", "json",
        ]
        child.environment = [
          "CONTROL_PLANE_API_KEY": runtimeKey,
          "PLANNER_MCP_AUTHORIZATION": "Bearer " + credential,
          "PLANNER_MCP_ENDPOINT": local.endpoint.absoluteString,
          "PLANNER_MCP_PROTOCOL_VERSION": local.protocolVersion,
          "PLANNER_AGENT_OWNER": String(decoding: try JSONEncoder().encode(owner), as: UTF8.self),
          "PLANNER_AGENT_BRIDGE_STATE_FILE": directory.appending(path: "bridge.json").path,
          "HOME": NSHomeDirectory(), "TMPDIR": FileManager.default.temporaryDirectory.path,
          "PATH": "/usr/bin:/bin",
        ]
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        try child.run()
        process = child
        let identity = try PlannerAgentTunnelProcess.identity(pid: child.processIdentifier)
        self.identity = identity
        record.identity = identity
        self.record = record
        try PropertyListEncoder().encode(record).write(to: recordURL, options: .atomic)
        monitor = Task { await watch(child, healthURLFile: healthURLFile, attempt: identifier) }
      } catch {
        _ = await stopRuntime()
        guard attempt == identifier else { return }
        state = .unavailable
        notice =
          (error as? PlannerAgentTunnelFailure)?.message
          ?? "The private connection could not start. Check the saved runtime key and retry."
      }
    }

    /// Admission must be revoked by the parent before this is called for an access-window change.
    @discardableResult
    func stop(reconcile: Bool = false) async -> Bool {
      attempt = UUID()
      guard await stopRuntime() else { return false }
      if reconcile { return await reconcileRuntime() }
      return true
    }

    private func stopRuntime() async -> Bool {
      if let stopping { return await stopping.value }
      monitor?.cancel()
      monitor = nil
      let task = Task { await terminateRuntime() }
      stopping = task
      let stopped = await task.value
      stopping = nil
      if stopped {
        state = .off
      } else {
        state = .unavailable
        notice = PlannerAgentTunnelFailure.cleanupFailed.message
      }
      return stopped
    }

    private func terminateRuntime() async -> Bool {
      do {
        if let process {
          if process.isRunning { process.terminate() }
          for _ in 0..<30 {
            if !process.isRunning { break }
            try await Task.sleep(for: .milliseconds(50))
          }
          if process.isRunning {
            guard let identity else { return false }
            try await Task.detached { try identity.signal(SIGKILL) }.value
            for _ in 0..<30 {
              if !process.isRunning { break }
              try await Task.sleep(for: .milliseconds(50))
            }
          }
        } else if let identity {
          try await identity.terminate()
        }
        if process?.isRunning == true { return false }
        if let directory { try await waitForBridgeExit(in: directory) }
        if let child = process { child.waitUntilExit() }
        process = nil
        identity = nil
        if let record, let recordURL { try removeRecord(record, at: recordURL) }
        record = nil
        if let directory { try FileManager.default.removeItem(at: directory) }
        directory = nil
        return true
      } catch { return false }
    }

    /// A different live controller owns its grant; only a verified orphan can be reclaimed.
    private func reconcileRuntime() async -> Bool {
      guard let recordURL, FileManager.default.fileExists(atPath: recordURL.path) else {
        return true
      }
      do {
        let record = try PropertyListDecoder().decode(
          PlannerAgentTunnelProcess.Record.self, from: Data(contentsOf: recordURL))
        var previous = record.identity
        if previous == nil {
          var foundPID = false
          let pidFile = record.directory(relativeTo: recordURL).appending(path: "runtime.pid")
          for _ in 0..<30 {
            if let value = try? String(contentsOf: pidFile, encoding: .utf8),
              let pid = Int32(value.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 1
            {
              foundPID = true
              if kill(pid, 0) != 0 && errno == ESRCH { break }
              previous = try PlannerAgentTunnelProcess.identity(pid: pid)
              break
            }
            try await Task.sleep(for: .milliseconds(50))
          }
          guard previous != nil || foundPID else {
            throw PlannerAgentTunnelFailure.cleanupFailed
          }
        }
        if let previous, try previous.isRunning() {
          try await Task.detached { try previous.validate(helper: .runtime) }.value
          guard try previous.isOrphaned() else { throw PlannerAgentTunnelFailure.cleanupFailed }
          let deadline = Date().addingTimeInterval(10)
          while try previous.isRunning(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
          }
          guard try !previous.isRunning() else { throw PlannerAgentTunnelFailure.cleanupFailed }
        }
        try await waitForBridgeExit(in: record.directory(relativeTo: recordURL))
        try removeRecord(record, at: recordURL)
        let directory = record.directory(relativeTo: recordURL)
        if FileManager.default.fileExists(atPath: directory.path) {
          try FileManager.default.removeItem(at: directory)
        }
        return true
      } catch {
        state = .unavailable
        notice = PlannerAgentTunnelFailure.cleanupFailed.message
        return false
      }
    }

    private func removeRecord(_ expected: PlannerAgentTunnelProcess.Record, at url: URL) throws {
      guard FileManager.default.fileExists(atPath: url.path) else { return }
      let current = try PropertyListDecoder().decode(
        PlannerAgentTunnelProcess.Record.self, from: Data(contentsOf: url))
      if current == expected { try FileManager.default.removeItem(at: url) }
    }

    /// The stdio child exits when the runtime or original GUI owner disappears; never signal an orphan.
    private func waitForBridgeExit(in directory: URL) async throws {
      let stateFile = directory.appending(path: "bridge.json")
      guard FileManager.default.fileExists(atPath: stateFile.path) else { return }
      let bridge = try JSONDecoder().decode(
        PlannerAgentTunnelProcess.self, from: Data(contentsOf: stateFile))
      if try !bridge.isRunning() { return }
      try await Task.detached { try bridge.validate(helper: .bridge) }.value
      let deadline = Date().addingTimeInterval(3)
      while try bridge.isRunning(), Date() < deadline {
        try await Task.sleep(for: .milliseconds(50))
      }
      guard try !bridge.isRunning() else { throw PlannerAgentTunnelFailure.cleanupFailed }
    }

    private func watch(_ child: Process, healthURLFile: URL, attempt identifier: UUID) async {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.timeoutIntervalForResource = 2
      let session = URLSession(
        configuration: configuration, delegate: PlannerTunnelNoRedirects(), delegateQueue: nil)
      defer { session.invalidateAndCancel() }
      let deadline = Date().addingTimeInterval(30)
      while !Task.isCancelled && attempt == identifier {
        guard child.isRunning else {
          state = .unavailable
          notice =
            "The private tunnel stopped (exit \(child.terminationStatus)). Check the runtime key and retry."
          return
        }
        if let endpoint = try? String(contentsOf: healthURLFile, encoding: .utf8),
          let components = URLComponents(
            string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
          components.scheme == "http", components.host == "127.0.0.1",
          let port = components.port, (1...65535).contains(port),
          components.user == nil, components.password == nil,
          components.query == nil, components.fragment == nil,
          components.path.isEmpty || components.path == "/",
          let url = URL(string: "http://127.0.0.1:\(port)/readyz"),
          let (data, response) = try? await session.data(from: url),
          !Task.isCancelled, attempt == identifier,
          (response as? HTTPURLResponse)?.statusCode == 200,
          String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            == "ready"
        {
          state = .ready
          notice = nil
        } else if !Task.isCancelled && attempt == identifier {
          if Date() < deadline {
            state = .starting
          } else {
            state = .unavailable
            notice = "The private tunnel is reconnecting. Check the Mac's network or retry."
          }
        }
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
      }
    }
  }

  private final class PlannerTunnelNoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
      _ session: URLSession, task: URLSessionTask,
      willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
      completionHandler: @escaping (URLRequest?) -> Void
    ) {
      completionHandler(nil)
    }
  }
#endif
