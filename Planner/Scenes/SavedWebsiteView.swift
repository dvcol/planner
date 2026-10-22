import Observation
import PlannerCore
import SwiftUI
import WebKit

struct SavedWebsiteRequest {
  let destination: URL
  let linkIdentifier: UUID
  let source: PlannerEntityReference
  let sourceLifetimeIdentifier: UUID
  let appearance: PlannerAppearance?
  let namespace: String
}

extension EnvironmentValues {
  @Entry var savedWebsiteOpening: (@MainActor (SavedWebsiteRequest) -> Void)? = nil
}

@MainActor @Observable
private final class SavedWebsiteNavigation: WebPage.NavigationDeciding {
  @ObservationIgnored var requestedURL: URL?
  @ObservationIgnored weak var page: WebPage?
  var downloadURL: URL?

  func decidePolicy(
    for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences
  ) async -> WKNavigationActionPolicy {
    guard let destination = action.request.url,
      ["http", "https"].contains(destination.scheme?.lowercased() ?? "")
    else { return .allow }
    if action.shouldPerformDownload {
      downloadURL = destination
      return .cancel
    }
    let opensNewWindow = action.target == nil
    if opensNewWindow || action.target?.isMainFrame == true {
      requestedURL = destination
      downloadURL = nil
    }
    guard opensNewWindow else { return .allow }
    page?.load(action.request)
    return .cancel
  }
}

@MainActor
final class SavedWebsiteSession: Identifiable, Hashable {
  let request: SavedWebsiteRequest
  let page: WebPage
  private let navigation: SavedWebsiteNavigation
  var hasStarted = false
  nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }

  init(request: SavedWebsiteRequest) {
    self.request = request
    let navigation = SavedWebsiteNavigation()
    self.navigation = navigation
    var configuration = WebPage.Configuration()
    configuration.websiteDataStore = .default()
    page = WebPage(configuration: configuration, navigationDecider: navigation)
    navigation.page = page
  }

  func retry() { page.load(navigation.requestedURL ?? request.destination) }

  var requestedDownloadURL: URL? { navigation.downloadURL }

  func dismissRequestedDownload() { navigation.downloadURL = nil }

  nonisolated static func == (first: SavedWebsiteSession, second: SavedWebsiteSession) -> Bool {
    first === second
  }

  nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

struct SavedWebsiteView: View {
  let session: SavedWebsiteSession
  let returnToPlanner: () -> Void
  @Environment(\.openURL) private var openURL
  @State private var failure: String?

  private var returnTitle: String {
    session.request.source.kind == .itinerary ? "Return to itinerary" : "Return to item"
  }

  var body: some View {
    let downloadURL = session.requestedDownloadURL
    WebView(session.page)
      .alert(
        "Open download in your browser",
        isPresented: Binding(
          get: { downloadURL != nil },
          set: { if !$0 { session.dismissRequestedDownload() } })
      ) {
        if let downloadURL {
          Button("Open in default browser") { openURL(downloadURL) }
            .accessibilityValue(downloadURL.absoluteString)
        }
        Button("Keep reading", role: .cancel) { session.dismissRequestedDownload() }
      } message: {
        if let downloadURL {
          Text("Open this download in your default browser.\n\(downloadURL.absoluteString)")
        }
      }
      .overlay {
        if let failure {
          ContentUnavailableView {
            Label("Page unavailable", systemImage: "network.slash")
          } description: {
            Text(failure)
          } actions: {
            Button("Retry", systemImage: "arrow.clockwise") {
              session.retry()
              self.failure = nil
            }
            Button("Open in default browser", systemImage: "arrow.up.right.square") {
              openURL(session.page.url ?? session.request.destination)
            }
          }
          .background(.background)
        }
      }
      .safeAreaInset(edge: .top, spacing: 0) {
        if session.page.isLoading {
          ProgressView(value: session.page.estimatedProgress)
            .progressViewStyle(.linear)
            .accessibilityLabel("Loading webpage")
        }
      }
      .toolbar {
        ToolbarItemGroup(placement: .primaryAction) {
          Button("Back", systemImage: "chevron.backward") {
            if let previous = session.page.backForwardList[-1] { session.page.load(previous) }
          }
          .disabled(session.page.backForwardList.backList.isEmpty)
          .help("Back")
          .accessibilityIdentifier("saved.browser.back")
          Button("Forward", systemImage: "chevron.forward") {
            if let next = session.page.backForwardList[1] { session.page.load(next) }
          }
          .disabled(session.page.backForwardList.forwardList.isEmpty)
          .help("Forward")
          .accessibilityIdentifier("saved.browser.forward")
          Button("Reload", systemImage: "arrow.clockwise") {
            if failure != nil {
              session.retry()
              failure = nil
            } else {
              session.page.reload()
            }
          }
          .help("Reload")
          .accessibilityIdentifier("saved.browser.reload")
        }
        ToolbarItem(placement: .navigation) {
          Button(returnTitle, systemImage: "chevron.backward", action: returnToPlanner)
            .labelStyle(.iconOnly)
            .help("Return to Planner")
            .accessibilityIdentifier("saved.browser.return")
        }
      }
      .labelStyle(.iconOnly)
      #if os(iOS)
        .navigationBarBackButtonHidden()
        .navigationTitle(session.page.title)
        .toolbarTitleDisplayMode(.inline)
      #endif
      .task(id: session.id) {
        while !Task.isCancelled {
          let navigations = session.page.navigations
          if !session.hasStarted {
            session.hasStarted = true
            session.page.load(session.request.destination)
          }
          do {
            for try await _ in navigations {
              guard !Task.isCancelled else { return }
              failure = nil
            }
            return
          } catch {
            guard !Task.isCancelled else { return }
            failure = error.localizedDescription
          }
        }
      }
  }
}
