import AppKit
import SwiftUI

final class ShareViewController: NSViewController {
  private var hasFinished = false

  override func loadView() {
    view = NSView()
    preferredContentSize = NSSize(width: 560, height: 620)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
    let content = PlannerShareRootView(
      providers: providers,
      didCancel: { [weak self] in self?.finish(cancelled: true) },
      didSave: { [weak self] _ in self?.finish(cancelled: false) })
    let hostingController = NSHostingController(rootView: content)
    addChild(hostingController)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hostingController.view)
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }

  private func finish(cancelled: Bool) {
    guard !hasFinished, let extensionContext else { return }
    hasFinished = true
    if cancelled {
      extensionContext.cancelRequest(withError: CocoaError(.userCancelled))
    } else {
      extensionContext.completeRequest(returningItems: nil)
    }
  }
}
