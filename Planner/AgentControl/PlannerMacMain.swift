#if PLANNER_AGENT_CONTROL && !PLANNER_FIXTURES
  import Foundation

  @main
  enum PlannerMacMain {
    @MainActor
    static func main() async {
      guard CommandLine.arguments.contains("--mcp-headers") else {
        PlannerApp.main()
        return
      }
      do {
        guard Array(CommandLine.arguments.dropFirst()) == ["--mcp-headers"] else {
          throw PlannerAgentFailure.agentControlUnavailable
        }
        let headers = try await PlannerAgentConnection.headers()
        var data = try JSONSerialization.data(withJSONObject: headers, options: .sortedKeys)
        data.append(0x0A)
        FileHandle.standardOutput.write(data)
      } catch {
        let reason = (error as? PlannerAgentFailure)?.code ?? "agentControlUnavailable"
        FileHandle.standardError.write(Data((reason + "\n").utf8))
        exit(1)
      }
    }
  }
#endif
