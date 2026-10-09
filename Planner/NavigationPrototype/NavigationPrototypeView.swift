import SwiftUI

private enum NavigationPrototypeLayout: String, CaseIterable {
  case library = "Library first"
  case itinerary = "Itinerary first"
  case map = "Map alongside list"
}

private enum PrototypeSidebarSelection: Hashable {
  case section(String)
  case source(UUID)
}

/// Native layout experiment. All displayed data comes from the fixed, read-only fixture.
struct NavigationPrototypeView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var fixture: NavigationPrototypeFixture?
  @State private var loadError: String?
  @State private var section = "list"
  @State private var layout: NavigationPrototypeLayout = .library
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @State private var selectedContainerId: UUID?
  @State private var selectedAppearance: NavigationPrototypeFixture.Appearance?
  @State private var selectedSourceId: UUID?
  @State private var sidebarSelection: PrototypeSidebarSelection? = .section("list")

  var body: some View {
    Group {
      if let fixture {
        nativeLayout(fixture)
      } else if let loadError {
        ContentUnavailableView(
          "Fixture unavailable", systemImage: "exclamationmark.triangle",
          description: Text(loadError))
      } else {
        ProgressView("Opening prototype fixture")
      }
    }
    .task {
      do {
        fixture = try NavigationPrototypeFixture.load()
      } catch {
        loadError = error.localizedDescription
      }
    }
  }

  private var prototypeToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) { prototypeLayoutMenu }
  }

  private var prototypeLayoutMenu: some View {
    Menu {
      ForEach(NavigationPrototypeLayout.allCases, id: \.self) { candidate in
        Button(candidate.rawValue) { chooseLayout(candidate) }
      }
    } label: {
      Label(layout.rawValue, systemImage: "rectangle.3.group")
    }
    .accessibilityLabel("Prototype layouts")
    .accessibilityIdentifier("prototype.layouts")
    .help("Navigation prototype layout comparison")
  }

  @ViewBuilder
  private var tabletPrototypeControls: some View {
    #if os(iOS)
      if horizontalSizeClass == .regular {
        Section("Prototype layout") { prototypeLayoutMenu }
      }
    #endif
  }

  @ViewBuilder
  private func nativeLayout(_ fixture: NavigationPrototypeFixture) -> some View {
    #if os(macOS)
      if layout == .itinerary {
        planningLayout(fixture).frame(minWidth: 820, minHeight: 540)
      } else {
        splitLayout(fixture).frame(minWidth: 820, minHeight: 540)
      }
    #else
      if horizontalSizeClass == .compact {
        phoneLayout(fixture)
      } else if layout == .itinerary {
        planningLayout(fixture)
      } else {
        splitLayout(fixture)
      }
    #endif
  }

  private func chooseLayout(_ candidate: NavigationPrototypeLayout) {
    layout = candidate
    selectSection(candidate == .itinerary ? "itinerary" : "list")
    columnVisibility = .all
  }

  private func planningLayout(_ fixture: NavigationPrototypeFixture) -> some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      catalog(fixture, kind: "itinerary")
        .navigationTitle("Itineraries")
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
    } detail: {
      ContentUnavailableView(
        "Choose an Itinerary", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
    }
    .navigationSplitViewStyle(.balanced)
    .toolbar { prototypeToolbar }
  }

  private func phoneLayout(_ fixture: NavigationPrototypeFixture) -> some View {
    TabView(selection: $section) {
      NavigationStack {
        catalog(fixture, kind: "list")
          .navigationTitle("Lists")
          .toolbar { prototypeToolbar }
      }
      .tabItem { Label("Lists", systemImage: "list.bullet") }
      .accessibilityIdentifier("nav.lists")
      .tag("list")
      NavigationStack {
        catalog(fixture, kind: "item")
          .navigationTitle("Items")
          .toolbar { prototypeToolbar }
      }
      .tabItem { Label("Items", systemImage: "square.stack") }
      .accessibilityIdentifier("nav.items")
      .tag("item")
      NavigationStack {
        catalog(fixture, kind: "itinerary")
          .navigationTitle("Itineraries")
          .toolbar { prototypeToolbar }
      }
      .tabItem {
        Label("Itineraries", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
      }
      .accessibilityIdentifier("nav.itineraries")
      .tag("itinerary")
    }
  }

  private func splitLayout(_ fixture: NavigationPrototypeFixture) -> some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      sidebar(fixture)
        .navigationTitle("Planner")
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    } content: {
      if let selectedContainerId, let container = fixture.source(selectedContainerId),
        container.kind != "item"
      {
        PrototypeContainerView(fixture: fixture, container: container) { appearance in
          selectedAppearance = appearance
          selectedSourceId = nil
        }
        .id(container.id)
        .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 480)
      } else {
        ContentUnavailableView("Choose a List or Itinerary", systemImage: "list.bullet.rectangle")
      }
    } detail: {
      if let selectedSourceId, let source = fixture.source(selectedSourceId) {
        PrototypeItemDetail(fixture: fixture, source: source, appearance: nil)
      } else if let selectedAppearance, let source = fixture.source(selectedAppearance.sourceId) {
        if layout == .map {
          PrototypeMapItemDetail(fixture: fixture, source: source, appearance: selectedAppearance)
        } else {
          PrototypeItemDetail(fixture: fixture, source: source, appearance: selectedAppearance) {
            selectedSourceId = source.id
          }
        }
      } else {
        ContentUnavailableView("Choose an Item", systemImage: "square.stack")
      }
    }
    .navigationSplitViewStyle(.balanced)
    .toolbar { prototypeToolbar }
  }

  @ViewBuilder
  private func sidebar(_ fixture: NavigationPrototypeFixture) -> some View {
    #if os(macOS)
      List(selection: $sidebarSelection) {
        Section("Planner") {
          NavigationLink(value: PrototypeSidebarSelection.section("list")) {
            Label("Lists", systemImage: "list.bullet")
          }
          .accessibilityIdentifier("nav.lists")
          NavigationLink(value: PrototypeSidebarSelection.section("item")) {
            Label("Items", systemImage: "square.stack")
          }
          .accessibilityIdentifier("nav.items")
          NavigationLink(value: PrototypeSidebarSelection.section("itinerary")) {
            Label("Itineraries", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
          }
          .accessibilityIdentifier("nav.itineraries")
        }
        Section(sectionTitle) {
          ForEach(fixture.sources.filter { $0.kind == section }) { source in
            NavigationLink(value: PrototypeSidebarSelection.source(source.id)) {
              Label(
                source.title,
                systemImage: source.kind == "item" ? "circle" : "list.bullet.rectangle")
            }
            .accessibilityIdentifier("\(source.kind).\(source.id.uuidString)")
          }
        }
      }
      .listStyle(.sidebar)
      .onChange(of: sidebarSelection) { _, selection in
        switch selection {
        case .section(let kind): selectSection(kind)
        case .source(let sourceId):
          if let source = fixture.source(sourceId) { selectContainer(source) }
        case nil: break
        }
      }
      .safeAreaInset(edge: .bottom) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Navigation prototype").font(.caption)
          Text("Read-only Planner data").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
      }
    #else
      List {
        Section("Planner") {
          Button("Lists", systemImage: "list.bullet") { selectSection("list") }
            .accessibilityIdentifier("nav.lists")
          Button("Items", systemImage: "square.stack") { selectSection("item") }
            .accessibilityIdentifier("nav.items")
          Button("Itineraries", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
            selectSection("itinerary")
          }
          .accessibilityIdentifier("nav.itineraries")
        }
        Section(sectionTitle) {
          ForEach(fixture.sources.filter { $0.kind == section }) { source in
            Button {
              selectContainer(source)
            } label: {
              Label(
                source.title,
                systemImage: source.kind == "item" ? "circle" : "list.bullet.rectangle")
            }
            .accessibilityIdentifier("\(source.kind).\(source.id.uuidString)")
          }
        }
        fixtureNotice
        tabletPrototypeControls
      }
    #endif
  }

  private func selectContainer(_ source: NavigationPrototypeFixture.Source) {
    selectedAppearance = nil
    selectedSourceId = source.kind == "item" ? source.id : nil
    selectedContainerId = source.id
    #if os(iOS)
      columnVisibility = .doubleColumn
    #endif
  }

  private var sectionTitle: String {
    switch section {
    case "item": "Items"
    case "itinerary": "Itineraries"
    default: "Lists"
    }
  }

  private func selectSection(_ newSection: String) {
    section = newSection
    sidebarSelection = .section(newSection)
    selectedContainerId = nil
    selectedAppearance = nil
    selectedSourceId = nil
  }

  private func catalog(_ fixture: NavigationPrototypeFixture, kind: String) -> some View {
    List {
      ForEach(fixture.sources.filter { $0.kind == kind }) { source in
        NavigationLink {
          if source.kind == "item" {
            PrototypeItemDetail(fixture: fixture, source: source, appearance: nil)
          } else {
            PrototypeContainerView(fixture: fixture, container: source, showMap: layout == .map)
          }
        } label: {
          VStack(alignment: .leading) {
            Text(source.title)
            if source.kind != "item" {
              Text(fixture.progress(in: source)).font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        .accessibilityIdentifier("\(source.kind).\(source.id.uuidString)")
      }
      fixtureNotice
      tabletPrototypeControls
    }
  }

  private var fixtureNotice: some View {
    Section {
      Text("Navigation prototype · Full graph fixture")
        .font(.caption).foregroundStyle(.secondary)
      Text("Planner data is read-only. Only local view preferences are saved.")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
}

private struct PrototypeContainerView: View {
  let fixture: NavigationPrototypeFixture
  let container: NavigationPrototypeFixture.Source
  var showMap = false
  var selectAppearance: ((NavigationPrototypeFixture.Appearance) -> Void)?
  @State private var completion = "todo"
  @State private var archive = "active"
  @State private var selectedAppearanceIdentifier: String?
  @FocusState private var isItemListFocused: Bool

  var body: some View {
    containerList
      .navigationTitle(container.title)
      #if os(macOS)
        .toolbar {
          ToolbarItemGroup { filterMenus }
        }
      #endif
  }

  @ViewBuilder
  private var containerList: some View {
    #if os(macOS)
      List(selection: $selectedAppearanceIdentifier) { containerContents }
        .listStyle(.inset)
        .focused($isItemListFocused)
        .onChange(of: selectedAppearanceIdentifier) { _, identifier in
          if let appearance = fixture.appearances(in: container).first(where: {
            $0.id == identifier
          }) {
            selectAppearance?(appearance)
            isItemListFocused = true
          }
        }
    #else
      List { containerContents }
    #endif
  }

  private var containerContents: some View {
    Group {
      Section {
        Text(fixture.progress(in: container)).font(.headline)
        #if os(iOS)
          HStack { filterMenus }
        #endif
      }
      Section("Items") {
        if container.kind == "itinerary" {
          ForEach(fixture.itineraryEntries.filter { $0.itinerary.id == container.id }, id: \.id) {
            entry in
            if fixture.source(entry.source.id)?.kind == "list" {
              PrototypeItineraryListGroup(
                fixture: fixture, itinerary: container, entry: entry,
                visibleAppearances: fixture.appearances(in: entry).filter(matchesFilters),
                showMap: showMap, selectAppearance: selectAppearance)
            } else {
              appearanceRows(fixture.appearances(in: entry).filter(matchesFilters))
            }
          }
        } else {
          appearanceRows(visibleAppearances)
        }
        if visibleAppearances.isEmpty {
          Text("No matching items").foregroundStyle(.secondary)
        }
      }
    }
  }

  private var filterMenus: some View {
    Group {
      Menu {
        Button("Todo") { completion = "todo" }
        Button("Done") { completion = "done" }
        Button("All completion states") { completion = "all" }
      } label: {
        Label(
          completion == "all" ? "All completion" : completion.capitalized,
          systemImage: "checkmark.circle")
      }
      .accessibilityIdentifier("filter.completion")
      Menu {
        Button("Active") { archive = "active" }
        Button("Archived") { archive = "archived" }
        Button("All archive states") { archive = "all" }
      } label: {
        Label(archive == "all" ? "All archive" : archive.capitalized, systemImage: "archivebox")
      }
      .accessibilityIdentifier("filter.archive")
    }
  }

  private var visibleAppearances: [NavigationPrototypeFixture.Appearance] {
    fixture.appearances(in: container).filter(matchesFilters)
  }

  private func matchesFilters(_ appearance: NavigationPrototypeFixture.Appearance) -> Bool {
    guard let source = fixture.source(appearance.sourceId) else { return false }
    let done = fixture.isDone(appearance)
    let matchesCompletion = completion == "all" || (completion == "done") == done
    let matchesArchive = archive == "all" || (archive == "archived") == (source.archived == true)
    return matchesCompletion && matchesArchive
  }

  private func appearanceRows(_ appearances: [NavigationPrototypeFixture.Appearance]) -> some View {
    ForEach(appearances) { appearance in
      PrototypeAppearanceRow(
        fixture: fixture, appearance: appearance, showMap: showMap,
        selectAppearance: selectAppearance
      )
      .tag(appearance.id)
    }
  }
}

private struct PrototypeItineraryListGroup: View {
  let fixture: NavigationPrototypeFixture
  let entry: NavigationPrototypeFixture.Entry
  let visibleAppearances: [NavigationPrototypeFixture.Appearance]
  let showMap: Bool
  let selectAppearance: ((NavigationPrototypeFixture.Appearance) -> Void)?
  @AppStorage private var isExpanded: Bool

  init(
    fixture: NavigationPrototypeFixture, itinerary: NavigationPrototypeFixture.Source,
    entry: NavigationPrototypeFixture.Entry,
    visibleAppearances: [NavigationPrototypeFixture.Appearance], showMap: Bool,
    selectAppearance: ((NavigationPrototypeFixture.Appearance) -> Void)?
  ) {
    self.fixture = fixture
    self.entry = entry
    self.visibleAppearances = visibleAppearances
    self.showMap = showMap
    self.selectAppearance = selectAppearance
    _isExpanded = AppStorage(
      wrappedValue: true,
      "prototype.navigation.expanded.\(itinerary.id.uuidString).\(entry.id.uuidString)")
  }

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      ForEach(visibleAppearances) { appearance in
        PrototypeAppearanceRow(
          fixture: fixture, appearance: appearance, showMap: showMap,
          selectAppearance: selectAppearance
        )
        .tag(appearance.id)
      }
      if visibleAppearances.isEmpty {
        Text("No matching items").foregroundStyle(.secondary)
      }
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        Label(
          fixture.source(entry.source.id)?.title ?? "List", systemImage: "list.bullet.rectangle"
        )
        .font(.headline)
        Text(fixture.progress(in: fixture.appearances(in: entry)))
          .font(.caption).foregroundStyle(.secondary)
      }
      .accessibilityIdentifier("group.\(entry.id.uuidString)")
    }
  }
}

private struct PrototypeAppearanceRow: View {
  let fixture: NavigationPrototypeFixture
  let appearance: NavigationPrototypeFixture.Appearance
  let showMap: Bool
  let selectAppearance: ((NavigationPrototypeFixture.Appearance) -> Void)?

  var body: some View {
    if let source = fixture.source(appearance.sourceId) {
      if let selectAppearance {
        #if os(macOS)
          row(source)
            .accessibilityIdentifier("appearance.\(appearance.id)")
        #else
          Button {
            selectAppearance(appearance)
          } label: {
            row(source)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("appearance.\(appearance.id)")
        #endif
      } else {
        NavigationLink {
          if showMap {
            PrototypeMapItemDetail(fixture: fixture, source: source, appearance: appearance)
          } else {
            PrototypeItemDetail(fixture: fixture, source: source, appearance: appearance)
          }
        } label: {
          row(source)
        }
        .accessibilityIdentifier("appearance.\(appearance.id)")
      }
    }
  }

  private func row(_ source: NavigationPrototypeFixture.Source) -> some View {
    HStack {
      Image(systemName: fixture.isDone(appearance) ? "checkmark.circle.fill" : "circle")
      Text(source.title)
      if source.archived == true {
        Image(systemName: "archivebox").accessibilityLabel("Archived")
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }
}

struct PrototypeItemDetail: View {
  let fixture: NavigationPrototypeFixture
  let source: NavigationPrototypeFixture.Source
  let appearance: NavigationPrototypeFixture.Appearance?
  var openSource: (() -> Void)?

  var body: some View {
    Form {
      Section(appearance?.contextName ?? "Source Item") {
        Text(source.title).font(.title2)
        Text("Global: \(source.globalDone == true ? "Done" : "Todo")")
        if let appearance {
          Text("Local: \(appearance.localDone ? "Done" : "Todo")")
          Text("Effective: \(fixture.isDone(appearance) ? "Done" : "Todo")")
        }
      }
      if let notes = source.content.notes {
        Section("Notes") { Text(notes).textSelection(.enabled) }
      }
      if appearance != nil {
        Section {
          if let openSource {
            Button("Open source Item", action: openSource)
          } else {
            NavigationLink("Open source Item") {
              PrototypeItemDetail(fixture: fixture, source: source, appearance: nil)
            }
          }
        }
      }
      Section("Prototype identity inspection") {
        identityValue("Source identity", identifier: source.id.uuidString)
        if let appearance {
          identityValue("Appearance identity", identifier: appearance.id)
        }
      }
    }
    .formStyle(.grouped)
    .frame(maxWidth: 760)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .navigationTitle(source.title)
  }

  private func identityValue(_ label: String, identifier: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label).font(.caption).foregroundStyle(.secondary)
      Text(identifier).font(.caption.monospaced()).textSelection(.enabled)
    }
  }
}
