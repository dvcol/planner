import SwiftUI

@main
struct PlannerApp: App {
  var body: some Scene {
    WindowGroup {
      NavigationPrototypeView()
    }
    #if os(macOS)
      .defaultSize(width: 1200, height: 800)
      .commands { SidebarCommands() }
    #endif
  }
}
