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
  @ObservationIgnored var cancelledResponseURL: URL?
  var externalContent: (destination: URL, isDownload: Bool)?

  func decidePolicy(
    for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences
  ) async -> WKNavigationActionPolicy {
    guard let destination = action.request.url,
      ["http", "https"].contains(destination.scheme?.lowercased() ?? "")
    else { return .allow }
    if action.shouldPerformDownload {
      externalContent = (destination, true)
      return .cancel
    }
    let opensNewWindow = action.target == nil
    if opensNewWindow || action.target?.isMainFrame == true {
      requestedURL = destination
      externalContent = nil
    }
    guard opensNewWindow else { return .allow }
    page?.load(action.request)
    return .cancel
  }

  func decidePolicy(for response: WebPage.NavigationResponse) async -> WKNavigationResponsePolicy {
    guard !response.canShowMimeType, let destination = response.response.url,
      ["http", "https"].contains(destination.scheme?.lowercased() ?? "")
    else { return .allow }
    externalContent = (destination, false)
    cancelledResponseURL = destination
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

  var requestedDestination: URL { navigation.requestedURL ?? request.destination }

  func retry() { page.load(requestedDestination) }

  var externalContent: (destination: URL, isDownload: Bool)? { navigation.externalContent }

  func dismissExternalContent() { navigation.externalContent = nil }

  func consumeResponseCancellation(_ error: any Error) -> Bool {
    guard case WebPage.NavigationError.failedProvisionalNavigation(let underlying) = error else {
      return false
    }
    let failure = underlying as NSError
    // WebKit reports a cancelled response policy as its legacy frame-interruption error.
    guard failure.domain == "WebKitErrorDomain", failure.code == 102,
      let destination = failure.userInfo[NSURLErrorFailingURLErrorKey] as? URL,
      destination == navigation.cancelledResponseURL
    else { return false }
    navigation.cancelledResponseURL = nil
    return true
  }

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

  private var contentTitle: String {
    if session.externalContent?.isDownload == true { return "Open download in your browser" }
    return "Open content in your browser"
  }

  var body: some View {
    let externalContent = session.externalContent
    let canKeepReading = session.page.backForwardList.currentItem != nil
    let requestedDestination = session.requestedDestination
    WebView(session.page)
      .webViewContentBackground(canKeepReading ? .automatic : .hidden)
      .background(.background)
      .alert(
        contentTitle,
        isPresented: Binding(
          get: { externalContent != nil },
          set: { if !$0 { session.dismissExternalContent() } })
      ) {
        if let externalContent {
          Button("Open in default browser") { openURL(externalContent.destination) }
            .accessibilityValue(externalContent.destination.absoluteString)
        }
        Button(canKeepReading ? "Keep reading" : returnTitle, role: .cancel) {
          session.dismissExternalContent()
          if !canKeepReading { returnToPlanner() }
        }
      } message: {
        if let externalContent {
          Text(
            "Open this content in your default browser.\n\(externalContent.destination.absoluteString)"
          )
        }
      }
      .overlay {
        if let failure {
          ContentUnavailableView {
            Label("Page unavailable", systemImage: "network.slash")
          } description: {
            VStack(spacing: 8) {
              Text(failure)
              Text(requestedDestination.absoluteString)
                .font(.caption)
                .textSelection(.enabled)
            }
          } actions: {
            Button("Retry", systemImage: "arrow.clockwise") {
              session.retry()
              self.failure = nil
            }
            Button("Open in default browser", systemImage: "arrow.up.right.square") {
              openURL(requestedDestination)
            }
            .accessibilityValue(requestedDestination.absoluteString)
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
            if session.consumeResponseCancellation(error) {
              failure = nil
              continue
            }
            if case WebPage.NavigationError.failedProvisionalNavigation(let underlying) = error {
              failure = underlying.localizedDescription
            } else {
              failure = error.localizedDescription
            }
          }
        }
      }
  }
}
