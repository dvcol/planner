import PlannerPreviews
import SwiftUI

@main
struct PlannerApp: App {
  @State private var savedPlanner = SavedPlannerStore()
  @State private var previews = PlannerPreviews(provider: AppleLinkPreviewProvider())
  #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @FocusedBinding(\.navigationPrototypeLayout) private var prototypeLayout:
      NavigationPrototypeLayout?
    @FocusedBinding(\.navigationPrototypeInformationPresented) private var showPrototypeInformation:
      Bool?
  #endif

  var body: some Scene {
    WindowGroup {
      if ProcessInfo.processInfo.arguments.contains("--navigation-prototype") {
        NavigationPrototypeView()
      } else {
        SavedPlannerView(store: savedPlanner)
          .environment(savedPlanner)
          .environment(previews)
      }
    }
    #if os(macOS)
      .defaultSize(width: 1200, height: 800)
      .commands {
        SidebarCommands()
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
      }
    #endif
    #if os(macOS)
      Window("Navigation comparison", id: "navigation-prototype") {
        NavigationPrototypeView()
      }
      .defaultSize(width: 1200, height: 800)
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
