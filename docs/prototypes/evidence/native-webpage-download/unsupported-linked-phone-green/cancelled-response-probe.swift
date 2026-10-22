import AppKit
import Foundation
import WebKit

@MainActor final class ProbeNavigation: WebPage.NavigationDeciding {
  func decidePolicy(for response: WebPage.NavigationResponse) async -> WKNavigationResponsePolicy {
    print("response", response.response.url!.absoluteString, response.canShowMimeType)
    return response.canShowMimeType ? .allow : .cancel
  }
}

@main struct PlannerUnsupportedResponseProbe {
  @MainActor static func main() async {
    _ = NSApplication.shared
    let page = WebPage(navigationDecider: ProbeNavigation())
    let events = page.navigations
    page.load(URLRequest(url: URL(string: CommandLine.arguments[1])!))
    do {
      for try await event in events { print("event", event) }
    } catch {
      print("error", String(reflecting: error))
      if case let WebPage.NavigationError.failedProvisionalNavigation(underlying) = error {
        let native = underlying as NSError
        print("underlying",native.domain,native.code,native.userInfo)
      }
    }
  }
}
