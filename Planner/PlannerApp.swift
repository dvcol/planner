import PlannerPreviews
import SwiftUI

#if !PLANNER_FIXTURES
  import AppIntents
#endif

#if !PLANNER_FIXTURES && !os(macOS)
  @main
#endif
struct PlannerApp: App {
  #if os(iOS)
    @UIApplicationDelegateAdaptor(PlannerSharingApplicationDelegate.self) private
      var sharingDelegate
  #else
    @NSApplicationDelegateAdaptor(PlannerSharingApplicationDelegate.self) private
      var sharingDelegate
  #endif
  @State private var savedPlanner: SavedPlannerStore
  @State private var planOpening: SavedPlanOpeningCoordinator
  @State private var previews = PlannerPreviews(provider: AppleLinkPreviewProvider())
  @State private var addressPreviews = PlannerAddressPreviews(
    provider: AppleAddressPreviewProvider())
  @State private var mapsPreviews = PlannerMapsPreviews(provider: NativeMapsPreviewProvider())
  #if os(macOS) && DEBUG
    @Environment(\.openWindow) private var openWindow
    @FocusedBinding(\.navigationPrototypeLayout) private var prototypeLayout:
      NavigationPrototypeLayout?
    @FocusedBinding(\.navigationPrototypeInformationPresented) private var showPrototypeInformation:
      Bool?
  #endif

  init() {
    let plannerStore = SavedPlannerStore()
    let opening = SavedPlanOpeningCoordinator()
    _savedPlanner = State(initialValue: plannerStore)
    _planOpening = State(initialValue: opening)
    #if !PLANNER_FIXTURES
      AppDependencyManager.shared.add(dependency: plannerStore)
      AppDependencyManager.shared.add(dependency: opening)
    #endif
  }

  var body: some Scene {
    WindowGroup(id: SavedPlanOpeningCoordinator.mainWindowSceneIdentifier, for: UUID.self) {
      $windowIdentifier in
      #if DEBUG
        let navigationPrototypeRequested = ProcessInfo.processInfo.arguments.contains(
          "--navigation-prototype")
      #else
        let navigationPrototypeRequested = false
      #endif
      if navigationPrototypeRequested {
        NavigationPrototypeView()
      } else {
        SavedPlannerMainWindow(
          store: savedPlanner, planOpening: planOpening, windowIdentifier: windowIdentifier
        )
        .environment(savedPlanner)
        .environment(previews)
        .environment(addressPreviews)
        .environment(mapsPreviews)
        .task(id: PlannerSharingInvitations.shared.revision) {
          await savedPlanner.open()
          while let metadata = PlannerSharingInvitations.shared.consume() {
            await savedPlanner.acceptSharingInvitation(metadata)
          }
        }
      }
    } defaultValue: {
      UUID()
    }
    #if os(macOS)
      .defaultSize(width: 1200, height: 800)
      .windowToolbarStyle(.unified)
      .commands {
        SidebarCommands()
        InspectorCommands()
        #if DEBUG
          CommandMenu("Prototype") {
            Button("Open navigation comparison") { openWindow(id: "navigation-prototype") }
            Divider()
            if let layout = Binding($prototypeLayout) {
              Picker("Layout comparison", selection: layout) {
                ForEach(NavigationPrototypeLayout.allCases, id: \.self) { candidate in
                  Text(candidate.rawValue).tag(candidate)
                }
              }
              .pickerStyle(.inline)
            }
            Divider()
            Button("About navigation prototype") { showPrototypeInformation = true }
            .disabled(showPrototypeInformation == nil)
          }
        #endif
      }
    #endif
    #if PLANNER_AGENT_CONTROL
      MenuBarExtra(
        "Plan 2Do agent access",
        systemImage: savedPlanner.agentAccess.isEnabled ? "network" : "network.slash"
      ) {
        if savedPlanner.agentAccess.isEnabled {
          Text("Agent access on")
        } else if savedPlanner.agentAccess.isConfigured {
          Text("Agent access paused")
        } else {
          Text("Agent access off")
        }
        Text(savedPlanner.libraryTitle)
        if savedPlanner.agentAccess.isConfigured || savedPlanner.agentAccess.state == .enabling {
          Button("Stop agent access") { Task { await savedPlanner.agentAccess.stop() } }
        } else {
          Button("Enable agent access") { Task { await savedPlanner.enableAgentAccess() } }
            .disabled(
              !savedPlanner.isReady || savedPlanner.isSaving || savedPlanner.isManagingSharing
                || savedPlanner.agentAccess.state == .stopping)
        }
        Divider()
        SettingsLink { Label("Settings", systemImage: "gear") }
      }
    #endif
    #if os(macOS)
      Settings {
        SavedPlannerSettingsView(store: savedPlanner)
      }
      #if DEBUG
        Window("Navigation comparison", id: "navigation-prototype") {
          NavigationPrototypeView()
        }
        .defaultSize(width: 1200, height: 800)
      #endif
    #endif
  }
}

#if os(macOS)
  private struct NavigationPrototypeLayoutKey: FocusedValueKey {
    typealias Value = Binding<NavigationPrototypeLayout>
  }

  private struct NavigationPrototypeInformationKey: FocusedValueKey {
    typealias Value = Binding<Bool>
  }

  extension FocusedValues {
    var navigationPrototypeLayout: Binding<NavigationPrototypeLayout>? {
      get { self[NavigationPrototypeLayoutKey.self] }
      set { self[NavigationPrototypeLayoutKey.self] = newValue }
    }

    var navigationPrototypeInformationPresented: Binding<Bool>? {
      get { self[NavigationPrototypeInformationKey.self] }
      set { self[NavigationPrototypeInformationKey.self] = newValue }
    }
  }
#endif
