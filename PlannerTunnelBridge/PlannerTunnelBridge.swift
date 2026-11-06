import Darwin
import Foundation

/// The runtime owns this stdio child and exits if it dies; this child also watches the GUI owner.
@main
struct PlannerTunnelBridge {
  private struct Owner: Codable, Sendable {
    let pid: Int32
    let startSeconds: UInt64
    let startMicroseconds: UInt64

    static var current: Self? {
      var information = proc_bsdinfo()
      guard
        proc_pidinfo(
          getpid(), PROC_PIDTBSDINFO, 0, &information,
          Int32(MemoryLayout.size(ofValue: information)))
          == MemoryLayout.size(ofValue: information)
      else { return nil }
      return Self(
        pid: getpid(), startSeconds: information.pbi_start_tvsec,
        startMicroseconds: information.pbi_start_tvusec)
    }

    var isAlive: Bool {
      var information = proc_bsdinfo()
      guard pid > 1,
        proc_pidinfo(
          pid, PROC_PIDTBSDINFO, 0, &information, Int32(MemoryLayout.size(ofValue: information)))
          == MemoryLayout.size(ofValue: information)
      else { return false }
      return information.pbi_uid == getuid() && information.pbi_status != SZOMB
        && information.pbi_start_tvsec == startSeconds
        && information.pbi_start_tvusec == startMicroseconds
    }
  }

  private struct Configuration: Sendable {
    let owner: Owner
    let endpoint: URL
    let authorization: String
    let protocolVersion: String
    let stateFile: URL

    init?(environment: [String: String]) {
      guard let ownerJSON = environment["PLANNER_AGENT_OWNER"],
        let ownerData = ownerJSON.data(using: .utf8),
        let owner = try? JSONDecoder().decode(Owner.self, from: ownerData), owner.isAlive,
        let endpointText = environment["PLANNER_MCP_ENDPOINT"],
        let components = URLComponents(string: endpointText),
        components.scheme == "http", components.host == "127.0.0.1",
        let port = components.port, (1...65535).contains(port), components.path == "/mcp",
        components.user == nil, components.password == nil, components.query == nil,
        components.fragment == nil, let endpoint = components.url,
        let authorization = environment["PLANNER_MCP_AUTHORIZATION"],
        authorization.hasPrefix("Bearer "), authorization.utf8.count == 50,
        authorization.dropFirst(7).allSatisfy({
          $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_")
        }),
        let version = environment["PLANNER_MCP_PROTOCOL_VERSION"],
        ["2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25"].contains(version),
        let statePath = environment["PLANNER_AGENT_BRIDGE_STATE_FILE"], statePath.hasPrefix("/")
      else { return nil }
      self.owner = owner
      self.endpoint = endpoint
      self.authorization = authorization
      protocolVersion = version
      stateFile = URL(fileURLWithPath: statePath)
    }
  }

  // The official tunnel limits complete envelopes to 10 MiB.
  private static let maximumMessageBytes = 10 * 1024 * 1024

  static func main() {
    guard getppid() > 1,
      let configuration = Configuration(environment: ProcessInfo.processInfo.environment)
    else { exit(64) }
    let runtimePID = getppid()
    guard let identity = Owner.current else { exit(74) }
    do {
      try JSONEncoder().encode(identity).write(to: configuration.stateFile, options: .atomic)
    } catch { exit(74) }
    Thread.detachNewThread {
      while getppid() == runtimePID && configuration.owner.isAlive { usleep(100_000) }
      _exit(0)
    }
    let settings = URLSessionConfiguration.ephemeral
    settings.timeoutIntervalForResource = 115
    let session = URLSession(configuration: settings, delegate: NoRedirects(), delegateQueue: nil)
    let output = DispatchQueue(label: "dvcol.planner.tunnel-bridge.output")
    var pending = Data()
    while true {
      let bytes = FileHandle.standardInput.availableData
      if bytes.isEmpty { exit(0) }
      pending.append(bytes)
      while let newline = pending.firstIndex(of: 10) {
        let message = Data(pending[..<newline])
        pending.removeSubrange(...newline)
        if message.isEmpty { continue }
        guard message.count <= maximumMessageBytes,
          let envelope = try? JSONSerialization.jsonObject(with: message) as? [String: Any],
          envelope["jsonrpc"] as? String == "2.0", envelope["method"] is String
        else { exit(65) }
        var request = URLRequest(url: configuration.endpoint, timeoutInterval: 115)
        request.httpMethod = "POST"
        request.httpBody = message
        request.setValue(configuration.authorization, forHTTPHeaderField: "Authorization")
        request.setValue(configuration.protocolVersion, forHTTPHeaderField: "MCP-Protocol-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        session.dataTask(with: request) { data, response, error in
          guard error == nil, let response = response as? HTTPURLResponse else { _exit(69) }
          if response.statusCode == 202 { return }
          guard response.statusCode == 200, let data, data.count <= maximumMessageBytes,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            object["jsonrpc"] as? String == "2.0",
            let compact = try? JSONSerialization.data(withJSONObject: object)
          else { _exit(69) }
          output.async {
            do {
              try FileHandle.standardOutput.write(contentsOf: compact)
              try FileHandle.standardOutput.write(contentsOf: Data([10]))
            } catch { _exit(74) }
          }
        }.resume()
      }
      guard pending.count <= maximumMessageBytes else { exit(65) }
    }
  }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
