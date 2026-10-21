#if !PLANNER_FIXTURES
  import AppIntents

  struct PlannerAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
      AppShortcut(
        intent: CreatePlannerItemIntent(),
        phrases: ["Create an item in \(.applicationName)"],
        shortTitle: "Create item", systemImageName: "plus")
      AppShortcut(
        intent: FindPlannerItemsIntent(),
        phrases: ["Find items in \(.applicationName)"],
        shortTitle: "Find items", systemImageName: "checklist")
      AppShortcut(
        intent: FindPlannerListsIntent(),
        phrases: ["Find lists in \(.applicationName)"],
        shortTitle: "Find lists", systemImageName: "list.bullet")
      AppShortcut(
        intent: FindPlannerItinerariesIntent(),
        phrases: ["Find itineraries in \(.applicationName)"],
        shortTitle: "Find itineraries",
        systemImageName: "point.topleft.down.to.point.bottomright.curvepath")
    }
  }
#endif
