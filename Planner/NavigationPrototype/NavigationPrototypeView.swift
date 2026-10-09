import SwiftUI

enum NavigationPrototypeLayout: String, CaseIterable {
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
  @State private var showPrototypeInformation = false

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
    .onChange(of: layout) { _, candidate in
      selectSection(candidate == .itinerary ? "itinerary" : "list")
      columnVisibility = .all
    }
    .sheet(isPresented: $showPrototypeInformation) {
      PrototypeInformationView(layout: $layout)
    }
    #if os(macOS)
      .focusedSceneValue(\.navigationPrototypeLayout, $layout)
      .focusedSceneValue(\.navigationPrototypeInformationPresented, $showPrototypeInformation)
    #endif
  }

  #if os(iOS)
    private var prototypeToolbar: some ToolbarContent {
      ToolbarItem(placement: .topBarTrailing) {
        Button("About prototype", systemImage: "info.circle") {
          showPrototypeInformation = true
        }
        .accessibilityIdentifier("prototype.information")
      }
    }
  #endif

  @ViewBuilder
  private func nativeLayout(_ fixture: NavigationPrototypeFixture) -> some View {
    #if os(macOS)
      splitLayout(fixture).frame(minWidth: 820, minHeight: 540)
    #else
      if horizontalSizeClass == .compact {
        phoneLayout(fixture)
      } else {
        tabletLayout(fixture)
      }
    #endif
  }

  #if os(iOS)
    private func tabletLayout(_ fixture: NavigationPrototypeFixture) -> some View {
      TabView(selection: $section) {
        Tab("Lists", systemImage: "list.bullet", value: "list") { splitLayout(fixture) }
        Tab("Items", systemImage: "square.stack", value: "item") { splitLayout(fixture) }
        Tab(
          "Itineraries", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
          value: "itinerary"
        ) { splitLayout(fixture) }
      }
      .onChange(of: section) { _, newSection in
        selectSection(newSection)
        columnVisibility = .all
      }
    }

    private func phoneLayout(_ fixture: NavigationPrototypeFixture) -> some View {
      TabView(selection: $section) {
        Tab("Lists", systemImage: "list.bullet", value: "list") {
          NavigationStack {
            catalog(fixture, kind: "list")
              .navigationTitle("Lists")
              .toolbar { prototypeToolbar }
          }
        }
        Tab("Items", systemImage: "square.stack", value: "item") {
          NavigationStack {
            catalog(fixture, kind: "item")
              .navigationTitle("Items")
              .toolbar { prototypeToolbar }
          }
        }
        Tab(
          "Itineraries", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
          value: "itinerary"
        ) {
          NavigationStack {
            catalog(fixture, kind: "itinerary")
              .navigationTitle("Itineraries")
              .toolbar { prototypeToolbar }
          }
        }
      }
    }
  #endif

  private func splitLayout(_ fixture: NavigationPrototypeFixture) -> some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      sidebar(fixture)
        .navigationTitle("Planner")
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        #if os(iOS)
          .toolbar { prototypeToolbar }
        #endif
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
        PrototypeItemDetail(
          fixture: fixture, source: source, appearance: nil, showMap: layout == .map)
      } else if let selectedAppearance, let source = fixture.source(selectedAppearance.sourceId) {
        PrototypeItemDetail(
          fixture: fixture, source: source, appearance: selectedAppearance, showMap: layout == .map
        ) {
          selectedSourceId = source.id
        }
      } else {
        ContentUnavailableView("Choose an Item", systemImage: "square.stack")
      }
    }
    .navigationSplitViewStyle(.balanced)
  }

  @ViewBuilder
  private func sidebar(_ fixture: NavigationPrototypeFixture) -> some View {
    List(selection: $sidebarSelection) {
      #if os(macOS)
        if layout != .itinerary {
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
        }
      #endif
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
    }
  }
}

private struct PrototypeInformationView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var layout: NavigationPrototypeLayout

  var body: some View {
    NavigationStack {
      Form {
        Section("Navigation prototype") {
          Text("Planner data is read-only. Only local view preferences are saved.")
          Text("This comparison uses the fixed Full graph fixture.")
        }
        Section("Layout comparison") {
          Picker("Layout", selection: $layout) {
            ForEach(NavigationPrototypeLayout.allCases, id: \.self) { candidate in
              Text(candidate.rawValue).tag(candidate)
            }
          }
          .pickerStyle(.inline)
        }
      }
      .formStyle(.grouped)
      .navigationTitle("About prototype")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
            .accessibilityIdentifier("prototype.information.close")
        }
      }
    }
    #if os(macOS)
      .frame(width: 520, height: 440)
    #endif
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
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        PrototypeCompletionProgress(
          fixture: fixture, appearances: fixture.appearances(in: container),
          accessibilityIdentifier: "progress.container")
        #if os(iOS)
          filterMenu
        #endif
      }
      .padding()
      Divider()
      containerList
    }
    .navigationTitle(container.title)
    #if os(macOS)
      .toolbar {
        ToolbarItem { filterMenu }
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

  private var filterMenu: some View {
    Menu {
      Picker("Completion", selection: $completion) {
        Text("Todo").tag("todo")
        Text("Done").tag("done")
        Text("All completion states").tag("all")
      }
      .pickerStyle(.inline)
      Divider()
      Picker("Archive", selection: $archive) {
        Text("Active").tag("active")
        Text("Archived").tag("archived")
        Text("All archive states").tag("all")
      }
      .pickerStyle(.inline)
    } label: {
      Label(filterSummary, systemImage: "line.3.horizontal.decrease")
        .labelStyle(.titleAndIcon)
        .fixedSize(horizontal: true, vertical: false)
    }
    .accessibilityLabel(filterSummary)
    .accessibilityIdentifier("filter.options")
    .help("Filters: \(filterSummary)")
  }

  private var filterSummary: String {
    let selectedFilters = [completion, archive].filter { $0 != "all" }.map { $0.capitalized }
    return selectedFilters.isEmpty ? "All" : selectedFilters.joined(separator: " · ")
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
        PrototypeCompletionProgress(
          fixture: fixture, appearances: fixture.appearances(in: entry),
          accessibilityIdentifier: "progress.group.\(entry.id.uuidString)")
      }
      .accessibilityIdentifier("group.\(entry.id.uuidString)")
    }
  }
}

private struct PrototypeCompletionProgress: View {
  let fixture: NavigationPrototypeFixture
  let appearances: [NavigationPrototypeFixture.Appearance]
  let accessibilityIdentifier: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(fixture.progress(in: appearances)).font(.caption).foregroundStyle(.secondary)
      if !appearances.isEmpty {
        ProgressView(
          value: Double(appearances.filter(fixture.isDone).count), total: Double(appearances.count)
        )
        .progressViewStyle(.linear)
        .accessibilityLabel("Completion")
        .accessibilityIdentifier(accessibilityIdentifier)
      }
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
          PrototypeItemDetail(
            fixture: fixture, source: source, appearance: appearance, showMap: showMap)
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
  var showMap = false
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
      if showMap {
        Section("Location") {
          if let address = source.content.location?.formattedAddress {
            Label(address, systemImage: "mappin.and.ellipse")
          }
          PrototypeMapItemDetail(source: source)
        }
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
