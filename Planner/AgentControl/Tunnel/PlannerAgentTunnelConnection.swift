#if PLANNER_AGENT_CONTROL
  import Foundation
  import LocalAuthentication
  import PlannerCore
  import Security

  /// The non-secret binding survives removal so an old ChatGPT connection cannot target another owner.
  struct PlannerAgentTunnelConnection: Codable, Equatable {
    struct Binding: Codable, Equatable {
      let tunnelId: String
      let datasetId: UUID
      let ownershipBinding: String

      func matches(_ session: PlannerDatasetSession) -> Bool {
        datasetId == session.datasetId && ownershipBinding == session.ownershipBinding
      }
    }

    let binding: Binding
    let keyId: UUID

    private struct Settings: Codable {
      var formatVersion = 1
      var bindings: [Binding] = []
      var connection: PlannerAgentTunnelConnection?
    }

    static func settingsURL(for controlURL: URL) -> URL {
      controlURL.deletingLastPathComponent().appending(path: "AgentTunnelConnection.plist")
    }

    static func load(from url: URL) throws -> Self? {
      try settings(from: url).connection
    }

    static func save(
      tunnelId: String, runtimeKey: String, context: PlannerAgentAccess.Context
    ) throws -> Self {
      guard validTunnelId(tunnelId), !runtimeKey.isEmpty, runtimeKey.utf8.count <= 4096,
        runtimeKey.utf8.allSatisfy({ (33...126).contains($0) })
      else { throw PlannerAgentTunnelFailure.invalidConnection }
      let url = settingsURL(for: context.controlURL)
      var settings = try settings(from: url)
      if let old = settings.bindings.first(where: { $0.tunnelId == tunnelId }),
        !old.matches(context.session)
      {
        throw PlannerAgentTunnelFailure.differentLibrary
      }
      let connection = Self(
        binding: .init(
          tunnelId: tunnelId, datasetId: context.session.datasetId,
          ownershipBinding: context.session.ownershipBinding), keyId: UUID())
      try PlannerAgentTunnelKey.store(runtimeKey, id: connection.keyId)
      let previous = settings.connection
      settings.connection = connection
      if !settings.bindings.contains(connection.binding) {
        settings.bindings.append(connection.binding)
      }
      do {
        try write(settings, to: url)
      } catch {
        try? PlannerAgentTunnelKey.remove(id: connection.keyId)
        throw error
      }
      if let previous { try PlannerAgentTunnelKey.remove(id: previous.keyId) }
      return connection
    }

    static func remove(from url: URL) throws {
      var settings = try settings(from: url)
      if let connection = settings.connection {
        try PlannerAgentTunnelKey.remove(id: connection.keyId)
      }
      settings.connection = nil
      try write(settings, to: url)
    }

    static func validTunnelId(_ value: String) -> Bool {
      value.hasPrefix("tunnel_") && value.count == 39
        && value.dropFirst(7).allSatisfy { "0123456789abcdef".contains($0) }
    }

    private static func settings(from url: URL) throws -> Settings {
      guard FileManager.default.fileExists(atPath: url.path) else { return Settings() }
      let settings = try PropertyListDecoder().decode(Settings.self, from: Data(contentsOf: url))
      guard settings.formatVersion == 1,
        settings.bindings.allSatisfy({ validTunnelId($0.tunnelId) }),
        settings.connection.map({ settings.bindings.contains($0.binding) }) ?? true
      else { throw PlannerAgentTunnelFailure.invalidConnection }
      return settings
    }

    private static func write(_ settings: Settings, to url: URL) throws {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try PropertyListEncoder().encode(settings).write(to: url, options: .atomic)
    }
  }

  enum PlannerAgentTunnelKey {
    private static func query(id: UUID) throws -> [String: Any] {
      guard let identifier = Bundle.main.bundleIdentifier else {
        throw PlannerAgentFailure.credentialUnavailable(errSecParam)
      }
      return [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: identifier + ".AgentTunnel",
        kSecAttrAccount as String: id.uuidString,
        kSecUseDataProtectionKeychain as String: true,
      ]
    }

    static func store(_ key: String, id: UUID) throws {
      var attributes = try query(id: id)
      attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      attributes[kSecAttrSynchronizable as String] = false
      attributes[kSecValueData as String] = Data(key.utf8)
      let status = SecItemAdd(attributes as CFDictionary, nil)
      guard status == errSecSuccess else { throw PlannerAgentFailure.credentialUnavailable(status) }
    }

    static func read(id: UUID) throws -> String {
      var attributes = try query(id: id)
      let authentication = LAContext()
      authentication.interactionNotAllowed = true
      attributes[kSecUseAuthenticationContext as String] = authentication
      attributes[kSecReturnData as String] = true
      attributes[kSecMatchLimit as String] = kSecMatchLimitOne
      var result: CFTypeRef?
      let status = SecItemCopyMatching(attributes as CFDictionary, &result)
      guard status == errSecSuccess, let data = result as? Data,
        let key = String(data: data, encoding: .utf8), !key.isEmpty
      else {
        throw PlannerAgentFailure.credentialUnavailable(
          status == errSecSuccess ? errSecDecode : status)
      }
      return key
    }

    static func remove(id: UUID) throws {
      let status = SecItemDelete(try query(id: id) as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else {
        throw PlannerAgentFailure.credentialUnavailable(status)
      }
    }
  }
#endif
