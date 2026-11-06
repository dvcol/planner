#if PLANNER_AGENT_CONTROL
  enum PlannerAgentTunnelFailure: Error {
    case invalidConnection
    case differentLibrary
    case runtimeUnavailable
    case cleanupFailed

    var message: String {
      switch self {
      case .invalidConnection:
        "Enter a valid Tunnel ID and runtime key."
      case .differentLibrary:
        "This tunnel belongs to a different library or account. Create a separate tunnel connection."
      case .runtimeUnavailable:
        "The signed tunnel helper is unavailable. Local agent access still works."
      case .cleanupFailed:
        "The previous tunnel helper could not be stopped safely. Retry before starting another connection."
      }
    }
  }
#endif
