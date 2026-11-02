#if PLANNER_AGENT_CONTROL
  import Foundation
  import LocalAuthentication
  import MCP
  import Security

  enum PlannerAgentFailure: Error {
    case agentControlUnavailable
    case credentialUnavailable(OSStatus)
    case unsupportedStoredState

    var code: String {
      switch self {
      case .agentControlUnavailable: "agentControlUnavailable"
      case .credentialUnavailable: "credentialUnavailable"
      case .unsupportedStoredState: "unsupportedStoredState"
      }
    }
  }

  /// Non-secret discovery state; a live authenticated ping is required before using it.
  struct PlannerAgentConnection: Codable, Equatable, Sendable {
    let formatVersion: Int
    let mainInstanceId: UUID
    let accessWindowId: UUID
    let endpoint: URL
    let protocolVersion: String
    let state: String

    static func controlURL() throws -> URL {
      guard let directory = try PlannerNativeStorage.configuredSharedDirectory() else {
        throw PlannerAgentFailure.agentControlUnavailable
      }
      return directory.appending(path: "AgentControlState.plist")
    }

    func validated() throws {
      guard formatVersion == 1, state == "on", Version.supported.contains(protocolVersion),
        let components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
        components.scheme == "http", components.host == "127.0.0.1",
        let port = components.port, (1...65535).contains(port), components.path == "/mcp",
        components.user == nil, components.password == nil,
        components.query == nil, components.fragment == nil
      else { throw PlannerAgentFailure.unsupportedStoredState }
    }

    static func read(from url: URL) throws -> Self {
      let value = try PropertyListDecoder().decode(Self.self, from: Data(contentsOf: url))
      try value.validated()
      return value
    }

    func write(to url: URL) throws {
      try validated()
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try PropertyListEncoder().encode(self).write(to: url, options: .atomic)
    }

    /// Refuse stale state, redirects and a changed access window without starting the application.
    static func headers() async throws -> [String: String] {
      let url = try controlURL()
      let connection = try read(from: url)
      let credential = try PlannerAgentCredential.read(window: connection.accessWindowId)
      let identifier = UUID().uuidString
      var request = URLRequest(url: connection.endpoint, timeoutInterval: 5)
      request.httpMethod = "POST"
      request.httpBody = try JSONSerialization.data(withJSONObject: [
        "jsonrpc": "2.0", "id": identifier, "method": "ping",
      ])
      request.setValue("Bearer " + credential, forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
      request.setValue(connection.protocolVersion, forHTTPHeaderField: "MCP-Protocol-Version")
      let configuration = URLSessionConfiguration.ephemeral
      configuration.timeoutIntervalForResource = 5
      let session = URLSession(
        configuration: configuration, delegate: PlannerAgentNoRedirects(), delegateQueue: nil)
      defer { session.invalidateAndCancel() }
      let (data, response) = try await session.data(for: request)
      guard let response = response as? HTTPURLResponse, response.statusCode == 200,
        response.value(forHTTPHeaderField: "X-Planner-Access-Window")
          == connection.accessWindowId.uuidString,
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        object["jsonrpc"] as? String == "2.0", object["id"] as? String == identifier,
        object["error"] == nil, let result = object["result"] as? [String: Any], result.isEmpty,
        try read(from: url) == connection
      else { throw PlannerAgentFailure.agentControlUnavailable }
      return ["Authorization": "Bearer " + credential]
    }
  }

  private final class PlannerAgentNoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
      _ session: URLSession, task: URLSessionTask,
      willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
      completionHandler: @escaping (URLRequest?) -> Void
    ) {
      completionHandler(nil)
    }
  }

  /// App and non-UI reader share this executable's private, device-only Keychain identity.
  enum PlannerAgentCredential {
    private static func query(window: UUID) throws -> [String: Any] {
      guard let identifier = Bundle.main.bundleIdentifier, !identifier.isEmpty else {
        throw PlannerAgentFailure.credentialUnavailable(errSecParam)
      }
      return [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: identifier + ".AgentControl",
        kSecAttrAccount as String: window.uuidString,
        kSecUseDataProtectionKeychain as String: true,
      ]
    }

    static func create(window: UUID) throws -> String {
      var bytes = [UInt8](repeating: 0, count: 32)
      let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
      guard randomStatus == errSecSuccess else {
        throw PlannerAgentFailure.credentialUnavailable(randomStatus)
      }
      let credential = Data(bytes).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
      var attributes = try query(window: window)
      attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      attributes[kSecAttrSynchronizable as String] = false
      attributes[kSecValueData as String] = Data(credential.utf8)
      let status = SecItemAdd(attributes as CFDictionary, nil)
      guard status == errSecSuccess else {
        throw PlannerAgentFailure.credentialUnavailable(status)
      }
      return credential
    }

    static func read(window: UUID) throws -> String {
      var attributes = try query(window: window)
      let authentication = LAContext()
      authentication.interactionNotAllowed = true
      attributes[kSecUseAuthenticationContext as String] = authentication
      attributes[kSecReturnData as String] = true
      attributes[kSecMatchLimit as String] = kSecMatchLimitOne
      var result: CFTypeRef?
      let status = SecItemCopyMatching(attributes as CFDictionary, &result)
      guard status == errSecSuccess,
        let data = result as? Data, let credential = String(data: data, encoding: .utf8),
        credential.utf8.count == 43
      else {
        throw PlannerAgentFailure.credentialUnavailable(
          status == errSecSuccess ? errSecDecode : status)
      }
      return credential
    }

    static func remove(window: UUID) throws {
      let status = SecItemDelete(try query(window: window) as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else {
        throw PlannerAgentFailure.credentialUnavailable(status)
      }
    }
  }
#endif
