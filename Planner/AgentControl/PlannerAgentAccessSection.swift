#if PLANNER_AGENT_CONTROL
  import SwiftUI

  struct PlannerAgentAccessSection: View {
    let store: SavedPlannerStore

    var body: some View {
      Section {
        LabeledContent("Library", value: store.libraryTitle)
        switch store.agentAccess.state {
        case .off, .unavailable:
          Button("Enable agent access", systemImage: "power") {
            Task { await store.enableAgentAccess() }
          }
          .disabled(!store.isReady || store.isSaving || store.isManagingSharing)
          .accessibilityIdentifier("saved.agent.enable")
          if store.agentAccess.isConfigured { stopButton }
        case .suspended:
          Label("Agent access will resume for this library", systemImage: "pause.circle")
          stopButton
        case .enabling:
          ProgressView("Starting agent access")
          stopButton
        case .stopping:
          ProgressView("Stopping agent access")
        case .on(let endpoint):
          Label("Agent access is on", systemImage: "checkmark.shield")
            .accessibilityIdentifier("saved.agent.status")
          Text(endpoint.absoluteString).textSelection(.enabled)
          stopButton
          Text("Codex connection")
            .font(.headline)
          Text(store.agentConnectionInstructions)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .accessibilityIdentifier("saved.agent.connection")
        }
        if let notice = store.agentAccess.notice {
          Text(notice).foregroundStyle(.secondary)
        }
      } header: {
        Text("Agent access")
      } footer: {
        Text(
          "Allows local agents on this Mac to read and edit this library. Your choice is saved until Stop. Access resumes after app relaunch or reconnection for the same library and account. Other libraries require their own enablement. Credentials stay in Keychain."
        )
      }
    }

    private var stopButton: some View {
      Button("Stop agent access", systemImage: "stop.fill") {
        Task { await store.agentAccess.stop() }
      }
      .accessibilityIdentifier("saved.agent.stop")
    }
  }
#endif
