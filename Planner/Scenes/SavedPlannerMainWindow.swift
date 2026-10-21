import SwiftUI

struct SavedPlannerMainWindow: View {
  @Environment(\.openWindow) private var openWindow
  @Environment(\.appearsActive) private var appearsActive
  @Environment(\.scenePhase) private var scenePhase
  let store: SavedPlannerStore
  let planOpening: SavedPlanOpeningCoordinator
  let windowIdentifier: UUID

  var body: some View {
    SavedPlannerView(
      store: store, planOpening: planOpening, windowIdentifier: windowIdentifier
    )
    .onAppear {
      register()
      planOpening.connect(openWindow)
    }
    .onChange(of: appearsActive) { register() }
    .onChange(of: scenePhase) { register() }
    .onChange(of: store.isReady) { register() }
    .onDisappear { planOpening.unregister(windowIdentifier: windowIdentifier) }
  }

  private func register() {
    planOpening.register(
      windowIdentifier: windowIdentifier,
      isActive: appearsActive && scenePhase == .active, isReady: store.isReady)
  }
}
