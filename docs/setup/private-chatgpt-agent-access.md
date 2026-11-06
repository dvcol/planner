# Private ChatGPT access

Plan 2Do can run an outbound OpenAI Secure MCP Tunnel alongside its local MCP
listener. A private ChatGPT plugin then reads and edits the selected Mac library
from ChatGPT on the web, iPhone and iPad. The Mac must remain awake, online and
running Plan 2Do.

## Build the Mac app

Run `bash scripts/prepare-tunnel-runtime.sh` before building or archiving the
Mac target. This downloads official `tunnel-client-runtime` v0.0.19 artifacts,
checks pinned SHA-256 values and assembles a universal arm64/x86_64 runtime.
It also compiles the small lifetime bridge for both architectures. Run preparation
again whenever the bridge source changes; the Mac build checks its source hash.
Generated binaries and licenses stay under ignored `.build/tunnel-runtime`.
The Xcode target copies both helpers and required licenses into the Mac app.
CodeSignOnCopy signs the helpers with the app's team and preserves their sandbox
inheritance entitlements. The iOS build excludes these artifacts.

Keep the identifiers `dvcol.planner.TunnelRuntime` and `dvcol.planner.TunnelBridge` when signing. Their only
entitlements are `com.apple.security.app-sandbox` and `com.apple.security.inherit`.
The app checks both helpers' identities, signing team and entitlements before launch.
The build requires normal Apple development signing for the app's capabilities.

## Connect your account

1. Create a tunnel in your personal Platform organization and associate your personal ChatGPT workspace.
2. Create a restricted runtime API key with Tunnels Use permission.
3. Open Plan 2Do on the Mac and select the intended library.
4. Open Settings → Agent access and enter the Tunnel ID and runtime key.
5. Click Save connection, then Enable agent access.
6. Wait for local access to turn on and Remote access to show Ready.
7. In ChatGPT Plugins, add a custom MCP server with Connection set to Tunnel.
8. Select this tunnel and use No authentication for the approved private, single-user connection.
9. Create and connect the private plugin under Personal → Created by you.
10. Select that plugin in ChatGPT on each device and test a disposable Item.

Do not publish, submit for review or share the plugin. Tunnel permissions control
which OpenAI organization/workspace can reach it. Plan 2Do's local bearer
credential separately controls database admission. No public inbound endpoint or
separate OAuth login is configured.

## Stop, retry and replace

Stop agent access saves Off and revokes local MCP admission before terminating
and awaiting both child processes. It controls local and remote access together.
Quit and library/account replacement use the same revocation order. Relaunch
restores access only for the same authorized library and account, with a new local
credential. An unrelated library requires explicit local enablement and a separate
tunnel. Stored tunnel bindings survive connection removal to prevent an old
ChatGPT connection from silently targeting a different library or owner.

Remote failure leaves local access usable. Retry private connection restarts the
helper with the current Mac credential. The runtime handles transient network
reconnection. Remove connection stops remote access and deletes its runtime key
from device-only Keychain. It does not delete the remote plugin or tunnel.

The runtime and bridge receive credentials through their environment, never command arguments.
The app discards child output. The non-secret connection file records the tunnel,
library and owner binding; it contains no credentials. Relaunch reconciles a stale
helper only after its PID, start time, executable path and signing identity match.
An unverified process blocks another tunnel launch and leaves local access usable.

Plan 2Do directly owns the official runtime. The runtime owns the bundled bridge
as its stdio MCP child, with `--mcp.stdio-failure-policy exit`. The bridge forwards
requests to the existing authenticated loopback listener and watches the original
app's PID and start time. App death closes the bridge; bridge death stops the
runtime; runtime death stops the bridge. This avoids macOS sandbox restrictions
on signalling an orphan after its original app has died. Relaunch waits for any
previous pair to exit before starting another poller.

The bridge has no separate preference, login item or service. Enable agent access
and Stop agent access control it through the same saved library/account choice.

All reads and writes retain PlannerCore permissions, field hashes, review tokens
and operation IDs. After an uncertain write, check `planner_operation_status`
before retrying the exact payload. The server ignores unsupported object-valued
experimental initialization advertisements that SDK 0.12.1 cannot decode; ordinary
tool requests and supported protocol-version checks stay intact.

See the official [tunnel documentation](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
and [private ChatGPT connection instructions](https://developers.openai.com/plugins/deploy/connect-chatgpt).
