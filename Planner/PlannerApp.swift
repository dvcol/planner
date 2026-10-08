import PlannerCore
import SwiftUI

@main
struct PlannerApp: App {
  var body: some Scene {
    WindowGroup {
      ContentUnavailableView(
        "Planner MCP prototype",
        systemImage: "hammer",
        description: Text("Native build setup. Agent Control is not implemented yet.")
      )
      .frame(minWidth: 320, minHeight: 240)
    }
  }
}
