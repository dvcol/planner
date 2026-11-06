#if PLANNER_AGENT_CONTROL
  import SwiftUI

  struct PlannerAgentAccessSection: View {
    let store: SavedPlannerStore
    @State private var tunnelId = ""
    @State private var runtimeKey = ""

    var body: some View {
      Group {
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
            stopButton
            DisclosureGroup("Local Codex connection") {
              VStack(alignment: .leading, spacing: 8) {
                Text(endpoint.absoluteString)
                Text(store.agentConnectionInstructions)
                  .font(.system(.caption, design: .monospaced))
                  .accessibilityIdentifier("saved.agent.connection")
              }
              .textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("saved.agent.connection.disclosure")
          }
          if let notice = store.agentAccess.notice {
            Text(notice).foregroundStyle(.secondary)
          }
        } header: {
          Text("Agent access")
        } footer: {
          Text(
            "Allows agents to read and edit this library. Enable and Stop control both local access and your configured private ChatGPT connection. Access resumes for the same library and account after relaunch. The Mac must stay awake, online, and running Plan 2Do. Credentials stay in device-only Keychain."
          )
        }
        privateConnection
      }
    }

    private var privateConnection: some View {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text("Tunnel ID")
          TextField("Tunnel ID", text: $tunnelId)
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .accessibilityIdentifier("saved.agent.tunnel.id")
        }
        VStack(alignment: .leading, spacing: 6) {
          Text("Runtime key")
          SecureField("Runtime key", text: $runtimeKey)
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("saved.agent.tunnel.key")
          if store.agentAccess.tunnel.connection != nil {
            Text("A key is saved on this Mac. Enter a key only to replace it.")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        ViewThatFits(in: .horizontal) {
          HStack { connectionButtons }
          VStack(alignment: .leading, spacing: 8) { connectionButtons }
        }
        remoteStatus
      } header: {
        Text("Private ChatGPT connection")
      } footer: {
        Text(
          "Use the Tunnel connection in your private ChatGPT plugin. Each library requires its own tunnel. Removing this connection deletes its runtime key from this Mac."
        )
        .fixedSize(horizontal: false, vertical: true)
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

    @ViewBuilder
    private var connectionButtons: some View {
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

    @ViewBuilder
    private var remoteStatus: some View {
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
      if let notice = store.agentAccess.tunnel.notice {
        Text(notice).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
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
