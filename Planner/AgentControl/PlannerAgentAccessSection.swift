#if PLANNER_AGENT_CONTROL
  import SwiftUI

  struct PlannerAgentAccessSection: View {
    let store: SavedPlannerStore
    @State private var tunnelId = ""
    @State private var runtimeKey = ""

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
        privateConnection
      } header: {
        Text("Agent access")
      } footer: {
        Text(
          "Allows agents to read and edit this library. Enable and Stop control both local access and your configured private ChatGPT connection. Access resumes for the same library and account after relaunch. The Mac must stay awake, online, and running Plan 2Do. Credentials stay in device-only Keychain."
        )
      }
    }

    private var privateConnection: some View {
      Group {
        Text("Private ChatGPT connection").font(.headline)
        TextField("Tunnel ID", text: $tunnelId)
          .autocorrectionDisabled()
          .accessibilityIdentifier("saved.agent.tunnel.id")
        SecureField("Runtime key", text: $runtimeKey)
          .accessibilityIdentifier("saved.agent.tunnel.key")
        HStack {
          Button("Save connection") {
            let key = runtimeKey
            runtimeKey = ""
            Task { await store.agentAccess.saveTunnel(tunnelId: tunnelId, runtimeKey: key) }
          }
          .disabled(
            !store.isReady || runtimeKey.isEmpty
              || !PlannerAgentTunnelConnection.validTunnelId(tunnelId)
              || store.agentAccess.isUpdatingTunnel || store.agentAccess.state == .stopping
          )
          .accessibilityIdentifier("saved.agent.tunnel.save")
          if store.agentAccess.tunnel.connection != nil {
            Button("Remove connection") {
              runtimeKey = ""
              Task {
                await store.agentAccess.removeTunnel()
                tunnelId = store.agentAccess.tunnel.configuredTunnelId
              }
            }
            .disabled(store.agentAccess.isUpdatingTunnel || store.agentAccess.state == .stopping)
          }
        }
        switch store.agentAccess.tunnel.state {
        case .off:
          Text(
            store.agentAccess.tunnel.connection == nil
              ? "Remote access is not configured" : "Remote access is off"
          )
          .foregroundStyle(.secondary)
        case .starting:
          ProgressView("Remote access: Starting")
        case .ready:
          Label("Remote access: Ready", systemImage: "checkmark.shield")
        case .unavailable:
          LabeledContent("Remote access", value: "Unavailable")
          if store.agentAccess.isEnabled && store.agentAccess.tunnel.matchesLibrary {
            Button("Retry private connection") { Task { await store.agentAccess.retryTunnel() } }
              .disabled(store.agentAccess.isUpdatingTunnel)
          }
        }
        if let notice = store.agentAccess.tunnel.notice { Text(notice).foregroundStyle(.secondary) }
        Text(
          "Use the Tunnel connection in your private ChatGPT plugin. Each library requires its own tunnel. Removing this connection deletes its runtime key from this Mac."
        )
        .font(.caption).foregroundStyle(.secondary)
      }
      .onChange(of: store.agentAccess.tunnel.configuredTunnelId, initial: true) {
        tunnelId = store.agentAccess.tunnel.configuredTunnelId
        runtimeKey = ""
      }
      .onChange(of: store.agentAccess.tunnel.contextIdentifier) {
        tunnelId = store.agentAccess.tunnel.configuredTunnelId
        runtimeKey = ""
      }
      .onDisappear { runtimeKey = "" }
    }

    private var stopButton: some View {
      Button("Stop agent access", systemImage: "stop.fill") {
        Task { await store.agentAccess.stop() }
      }
      .accessibilityIdentifier("saved.agent.stop")
    }
  }
#endif
