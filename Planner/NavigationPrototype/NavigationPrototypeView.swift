import SwiftUI

private enum NavigationPrototypeLayout: String, CaseIterable {
  case library = "Library first"
  case itinerary = "Itinerary first"
  case map = "Map alongside list"
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
              selectedAppearance = nil
              selectedSourceId = nil
              selectedContainerId = source.id
              if source.kind == "item" { selectedSourceId = source.id }
              #if os(iOS)
                columnVisibility = .doubleColumn
              #endif
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
      .navigationTitle("Planner")
      .navigationSplitViewColumnWidth(min: 190, ideal: 230)
    } content: {
      if let selectedContainerId, let container = fixture.source(selectedContainerId),
        container.kind != "item"
      {
        PrototypeContainerView(fixture: fixture, container: container) { appearance in
          selectedAppearance = appearance
          selectedSourceId = nil
        }
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

  private var sectionTitle: String {
    switch section {
    case "item": "Items"
    case "itinerary": "Itineraries"
    default: "Lists"
    }
  }

  private func selectSection(_ newSection: String) {
    section = newSection
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
      Text("Read-only layout review. No changes are saved or synced.")
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

  var body: some View {
    List {
      Section {
        Text(fixture.progress(in: container))
          .font(.headline)
        HStack {
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
      Section("Items") {
        ForEach(visibleAppearances) { appearance in
          if let source = fixture.source(appearance.sourceId) {
            if let selectAppearance {
              Button {
                selectAppearance(appearance)
              } label: {
                row(source, appearance: appearance)
              }
              .accessibilityIdentifier("appearance.\(appearance.id)")
            } else {
              NavigationLink {
                if showMap {
                  PrototypeMapItemDetail(fixture: fixture, source: source, appearance: appearance)
                } else {
                  PrototypeItemDetail(fixture: fixture, source: source, appearance: appearance)
                }
              } label: {
                row(source, appearance: appearance)
              }
              .accessibilityIdentifier("appearance.\(appearance.id)")
            }
          }
        }
        if visibleAppearances.isEmpty {
          Text("No matching items").foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle(container.title)
    .id(container.id)
  }

  private var visibleAppearances: [NavigationPrototypeFixture.Appearance] {
    fixture.appearances(in: container).filter { appearance in
      guard let source = fixture.source(appearance.sourceId) else { return false }
      let done = fixture.isDone(appearance)
      let matchesCompletion = completion == "all" || (completion == "done") == done
      let matchesArchive = archive == "all" || (archive == "archived") == (source.archived == true)
      return matchesCompletion && matchesArchive
    }
  }

  private func row(
    _ source: NavigationPrototypeFixture.Source, appearance: NavigationPrototypeFixture.Appearance
  ) -> some View {
    HStack {
      Image(systemName: fixture.isDone(appearance) ? "checkmark.circle.fill" : "circle")
      Text(source.title)
      if source.archived == true {
        Image(systemName: "archivebox").accessibilityLabel("Archived")
      }
    }
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
        if let notes = source.content.notes { Text(notes) }
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
    .navigationTitle(source.title)
  }

  private func identityValue(_ label: String, identifier: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label).font(.caption).foregroundStyle(.secondary)
      Text(identifier).font(.caption.monospaced()).textSelection(.enabled)
    }
  }
}
