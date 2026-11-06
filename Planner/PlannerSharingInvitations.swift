import CloudKit
import Observation
import SwiftUI

/// Invitation acceptance adds a library without replacing any window's draft or selection.
@MainActor @Observable
final class PlannerSharingInvitations {
  static let shared = PlannerSharingInvitations()
  private(set) var pending: [CKShare.Metadata] = []
  private(set) var revision = UUID()

  func receive(_ metadata: CKShare.Metadata) {
    guard !pending.contains(where: { $0.share.recordID == metadata.share.recordID }) else { return }
    pending.append(metadata)
    revision = UUID()
  }

  func consume() -> CKShare.Metadata? {
    guard !pending.isEmpty else { return nil }
    return pending.removeFirst()
  }
}

#if os(iOS)
  import UIKit

  final class PlannerSharingApplicationDelegate: UIResponder, UIApplicationDelegate {
    func application(
      _ application: UIApplication, configurationForConnecting session: UISceneSession,
      options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
      let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
      if session.role == .windowApplication {
        configuration.delegateClass = PlannerSharingSceneDelegate.self
      }
      return configuration
    }
  }

  final class PlannerSharingSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(
      _ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions
    ) {
      if let metadata = options.cloudKitShareMetadata {
        PlannerSharingInvitations.shared.receive(metadata)
      }
    }

    func windowScene(
      _ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
      PlannerSharingInvitations.shared.receive(metadata)
    }
  }
#else
  import AppKit

  final class PlannerSharingApplicationDelegate: NSObject, NSApplicationDelegate {
    #if PLANNER_AGENT_CONTROL
      weak var agentAccess: PlannerAgentAccess?
      private var terminationPending = false

      func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let agentAccess else { return .terminateNow }
        if !terminationPending {
          terminationPending = true
          Task {
            await agentAccess.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
          }
        }
        return .terminateLater
      }
    #endif

    func application(
      _ application: NSApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
      PlannerSharingInvitations.shared.receive(metadata)
    }
  }
#endif
