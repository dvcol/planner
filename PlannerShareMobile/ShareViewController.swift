import SwiftUI
import UIKit

final class ShareViewController: UIViewController {
  private var hasFinished = false

  override func viewDidLoad() {
    super.viewDidLoad()
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
    let content = PlannerShareRootView(
      providers: providers,
      didCancel: { [weak self] in self?.finish(cancelled: true) },
      didSave: { [weak self] _ in self?.finish(cancelled: false) })
    let hostingController = UIHostingController(rootView: content)
    addChild(hostingController)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hostingController.view)
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    hostingController.didMove(toParent: self)
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
