#if PLANNER_AGENT_CONTROL
  import Darwin
  import Foundation
  import Security

  /// PID, start time and signed executable must all match before reconciling a leftover helper.
  struct PlannerAgentTunnelProcess: Codable, Equatable, Sendable {
    enum Helper {
      case runtime
      case bridge

      var executable: URL {
        let name = self == .runtime ? "tunnel-client-runtime" : "PlannerTunnelBridge"
        return Bundle.main.bundleURL.appending(path: "Contents/Helpers/" + name)
          .resolvingSymlinksInPath()
      }

      var identifier: String {
        self == .runtime ? "dvcol.planner.TunnelRuntime" : "dvcol.planner.TunnelBridge"
      }
    }
    struct Record: Codable, Equatable {
      let ownerId: UUID
      let windowId: UUID
      var identity: PlannerAgentTunnelProcess?

      func directory(relativeTo url: URL) -> URL {
        url.deletingLastPathComponent().appending(path: "AgentTunnel-" + windowId.uuidString)
      }
    }
    let pid: Int32
    let startSeconds: UInt64
    let startMicroseconds: UInt64

    static var executable: URL {
      Helper.runtime.executable
    }

    static func identity(pid: Int32) throws -> Self {
      var info = proc_bsdinfo()
      guard pid > 1,
        proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info)))
          == MemoryLayout.size(ofValue: info), info.pbi_uid == getuid()
      else { throw PlannerAgentTunnelFailure.cleanupFailed }
      return Self(
        pid: pid, startSeconds: info.pbi_start_tvsec, startMicroseconds: info.pbi_start_tvusec)
    }

    func isRunning() throws -> Bool {
      var info = proc_bsdinfo()
      guard
        proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info)))
          == MemoryLayout.size(ofValue: info)
      else {
        if errno == ESRCH { return false }
        throw PlannerAgentTunnelFailure.cleanupFailed
      }
      guard info.pbi_uid == getuid(), info.pbi_start_tvsec == startSeconds,
        info.pbi_start_tvusec == startMicroseconds
      else { return false }
      return info.pbi_status != SZOMB
    }

    func signal(_ signal: Int32) throws {
      guard try isRunning() else { return }
      try validate(helper: .runtime)
      let result = kill(pid, signal)
      guard result == 0 || errno == ESRCH else {
        throw PlannerAgentTunnelFailure.cleanupFailed
      }
    }

    func validate(helper: Helper) throws {
      var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
      let pathStatus = proc_pidpath(pid, &path, UInt32(path.count))
      guard pathStatus > 0,
        URL(fileURLWithPath: String(cString: path)).resolvingSymlinksInPath() == helper.executable
      else { throw PlannerAgentTunnelFailure.cleanupFailed }
      var code: SecCode?
      let attributes = [kSecGuestAttributePid as String: NSNumber(value: pid)]
      let guestStatus = SecCodeCopyGuestWithAttributes(nil, attributes as CFDictionary, [], &code)
      guard guestStatus == errSecSuccess, let code else {
        throw PlannerAgentTunnelFailure.cleanupFailed
      }
      let validity = SecCodeCheckValidity(code, [], try Self.requirement(helper: helper))
      guard validity == errSecSuccess
      else { throw PlannerAgentTunnelFailure.cleanupFailed }
    }

    func isOrphaned() throws -> Bool {
      guard try isRunning() else { return false }
      var info = proc_bsdinfo()
      guard
        proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info)))
          == MemoryLayout.size(ofValue: info)
      else { throw PlannerAgentTunnelFailure.cleanupFailed }
      return info.pbi_ppid == 1
    }

    func terminate() async throws {
      try await Task.detached { try self.signal(SIGTERM) }.value
      for _ in 0..<30 {
        if try !isRunning() { return }
        try await Task.sleep(for: .milliseconds(50))
      }
      try await Task.detached { try self.signal(SIGKILL) }.value
      for _ in 0..<30 {
        if try !isRunning() { return }
        try await Task.sleep(for: .milliseconds(50))
      }
      throw PlannerAgentTunnelFailure.cleanupFailed
    }

    static func validateExecutable(helper: Helper = .runtime) throws {
      var code: SecStaticCode?
      guard SecStaticCodeCreateWithPath(helper.executable as CFURL, [], &code) == errSecSuccess,
        let code,
        SecStaticCodeCheckValidity(
          code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), try requirement(helper: helper))
          == errSecSuccess
      else { throw PlannerAgentTunnelFailure.runtimeUnavailable }
      var information: CFDictionary?
      guard
        SecCodeCopySigningInformation(
          code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
        let values = information as? [String: Any],
        let entitlements = values[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
        entitlements.count == 2,
        entitlements["com.apple.security.app-sandbox"] as? Bool == true,
        entitlements["com.apple.security.inherit"] as? Bool == true
      else { throw PlannerAgentTunnelFailure.runtimeUnavailable }
    }

    private static func requirement(helper: Helper) throws -> SecRequirement {
      var ownCode: SecCode?
      var ownStaticCode: SecStaticCode?
      var information: CFDictionary?
      guard SecCodeCopySelf([], &ownCode) == errSecSuccess, let ownCode,
        SecCodeCopyStaticCode(ownCode, [], &ownStaticCode) == errSecSuccess, let ownStaticCode,
        SecCodeCopySigningInformation(
          ownStaticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
          == errSecSuccess,
        let values = information as? [String: Any],
        let team = values[kSecCodeInfoTeamIdentifier as String] as? String,
        team.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) })
      else { throw PlannerAgentTunnelFailure.runtimeUnavailable }
      var requirement: SecRequirement?
      let expression =
        "identifier \"\(helper.identifier)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
      guard
        SecRequirementCreateWithString(expression as CFString, [], &requirement) == errSecSuccess,
        let requirement
      else { throw PlannerAgentTunnelFailure.runtimeUnavailable }
      return requirement
    }
  }
#endif
