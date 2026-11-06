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
          #if PLANNER_AGENT_CONTROL
            sharingDelegate.agentAccess = savedPlanner.agentAccess
          #endif
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
        CommandGroup(replacing: .appSettings) {
          Button("Settings…") { planOpening.navigate(to: .settings) }
          .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(after: .newItem) {
          Button("New Item") { planOpening.navigate(to: .newItem) }
          .keyboardShortcut("n", modifiers: [.command, .option])
          .disabled(!savedPlanner.canCreate || !savedPlanner.librarySwitchBlockedWindows.isEmpty)
          Button("New List") { planOpening.navigate(to: .newList) }
          .keyboardShortcut("n", modifiers: [.command, .shift])
          .disabled(!savedPlanner.canCreate || !savedPlanner.librarySwitchBlockedWindows.isEmpty)
        }
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
      MenuBarExtra {
        Button("Open Plan 2Do") { planOpening.navigate(to: .planner) }
        Menu("Go to") {
          Button("Lists") { planOpening.navigate(to: .lists) }
          Button("Items") { planOpening.navigate(to: .items) }
          Button("Inbox") { planOpening.navigate(to: .inbox) }
          Button("Itineraries") { planOpening.navigate(to: .itineraries) }
          Button("Calendar") { planOpening.navigate(to: .calendar) }
        }
        Divider()
        Button("New Item") { planOpening.navigate(to: .newItem) }
          .disabled(!savedPlanner.canCreate || !savedPlanner.librarySwitchBlockedWindows.isEmpty)
        Button("New List") { planOpening.navigate(to: .newList) }
          .disabled(!savedPlanner.canCreate || !savedPlanner.librarySwitchBlockedWindows.isEmpty)
        if savedPlanner.hasPrivateSynchronization {
          Button(savedPlanner.isSynchronizing ? "Syncing…" : "Sync now") {
            Task { await savedPlanner.synchronize() }
          }
          .disabled(
            !savedPlanner.isReady || savedPlanner.isSaving || savedPlanner.isSynchronizing
              || savedPlanner.isCheckingRecovery || savedPlanner.isReconnectingChanges)
        }
        Divider()
        Text(savedPlanner.libraryTitle)
        if savedPlanner.agentAccess.isEnabled {
          Text("Local agent access: On")
        } else if savedPlanner.agentAccess.isConfigured {
          Text("Local agent access: Paused")
        } else {
          Text("Local agent access: Off")
        }
        if savedPlanner.agentAccess.tunnel.connection != nil {
          switch savedPlanner.agentAccess.tunnel.state {
          case .off: Text("Private ChatGPT: Off")
          case .starting: Text("Private ChatGPT: Starting")
          case .ready: Text("Private ChatGPT: Ready")
          case .unavailable:
            Text("Private ChatGPT: Unavailable")
            if savedPlanner.agentAccess.isEnabled && savedPlanner.agentAccess.tunnel.matchesLibrary
            {
              Button("Retry private connection") {
                Task { await savedPlanner.agentAccess.retryTunnel() }
              }
              .disabled(savedPlanner.agentAccess.isUpdatingTunnel)
            }
          }
        }
        if savedPlanner.agentAccess.isConfigured || savedPlanner.agentAccess.state == .enabling {
          Button("Stop agent access") { Task { await savedPlanner.agentAccess.stop() } }
        } else {
          Button("Enable agent access") { Task { await savedPlanner.enableAgentAccess() } }
            .disabled(
              !savedPlanner.isReady || savedPlanner.isSaving || savedPlanner.isManagingSharing
                || savedPlanner.agentAccess.state == .stopping)
        }
        Divider()
        Button("Settings…") { planOpening.navigate(to: .settings) }
        Divider()
        Button("Quit Plan 2Do") { NSApplication.shared.terminate(nil) }
      } label: {
        Label(
          "Plan 2Do", systemImage: savedPlanner.agentAccess.isEnabled ? "network" : "network.slash"
        )
        .labelStyle(.iconOnly)
        .accessibilityLabel("Plan 2Do")
        .help("Plan 2Do")
      }
    #endif
    #if os(macOS)
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
