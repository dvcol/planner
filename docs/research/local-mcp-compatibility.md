# Local MCP compatibility

Researched on 2026-10-07 for [Local MCP compatibility](https://github.com/dvcol/planner/issues/6), within the [decision map](https://github.com/dvcol/planner/issues/1). This records documentation, pinned source inspection, and installed package metadata. It does not claim a successful client connection, change configuration, start a listener, or select a client or session policy for the user.

## Finding

Temporary authenticated loopback HTTP is a documented possibility for local Codex and Claude Code. Desktop surfaces need separate qualification. The official Swift SDK supplies HTTP request handling, but Planner must supply and stop the actual listener, authenticate every request, and connect tool handlers to PlannerCore. The current client and protocol documentation also makes compatibility with the SDK's older protocol revision an explicit prototype check.

Recommend trying direct Streamable HTTP before considering a bridge. Treat the inspected versions below as initial prototype baselines, not proven supported minimums. [Shared command contracts](https://github.com/dvcol/planner/issues/13) must confirm the supported surfaces and handoff policy; [MCP session prototype](https://github.com/dvcol/planner/issues/16) must demonstrate them.

## Installed variants and evidence

Read-only checks used `command -v`, `--version`, MCP help, symlink inspection, and selected `Info.plist` fields. No user MCP configuration, credentials, account state, or server lists were read.

| Variant | Observed installation | Evidence and limitation |
| --- | --- | --- |
| Codex CLI | `codex-cli 0.160.1`, `/opt/homebrew/bin/codex` | `codex mcp add --help` exposes `--url` for Streamable HTTP and `--bearer-token-env-var`. Help succeeded despite a warning about creating PATH aliases. |
| Codex desktop surface | `/Applications/ChatGPT.app`, bundle identifier `com.openai.codex`, version `26.928.31416`, build `12553` | Package metadata only. Its embedded MCP runtime version and successful HTTP connection were not inspected or tested. |
| Claude Code CLI | `2.1.291 (Claude Code)`, `/opt/homebrew/bin/claude` | `claude mcp add --help` exposes HTTP transport and header configuration. |
| Claude Desktop | `/Applications/Claude.app`, bundle identifier `com.anthropic.claudefordesktop`, version `1.46388.2` | Package metadata only. The Code tab's embedded client version and the Chat surface's local HTTP support remain unproved. |

The separate Claude Code URL Handler package is a launch integration, not evidence of another MCP client. Neither observed CLI version establishes the desktop runtime version.

## Compatibility by surface

| Surface and execution location | Documented route | Status for this planner |
| --- | --- | --- |
| Codex CLI executing locally on the Mac | Configured HTTP URL; environment bearer token, headers, or local header helper | Strong direct HTTP candidate; installed release schema supports these fields. [Pinned configuration schema](https://github.com/openai/codex/blob/rust-v0.160.1/codex-rs/core/config.schema.json) |
| Codex desktop local surface | Current OpenAI documentation names the desktop app ChatGPT, shares configuration with CLI, and provides Streamable HTTP plus Save/Restart | Candidate needing a separate app check. Do not substitute the inspected CLI version for its runtime. [OpenAI MCP documentation](https://developers.openai.com/codex/mcp) |
| Claude Code CLI executing locally | HTTP URL and Authorization header | Direct HTTP candidate. [Claude Code MCP documentation](https://code.claude.com/docs/en/mcp#option-1-add-a-remote-http-server) |
| Claude Desktop, local Code tab | Reads CLI MCP configurations and additionally loads desktop Chat configurations | Direct HTTP candidate through local Code configuration; embedded version and precedence need testing. This does not establish equal Chat support. [Shared configuration](https://code.claude.com/docs/en/desktop#shared-configuration) |
| Claude Desktop, Chat local extension | Official local route packages Node, Python, or binary servers as extensions | Inspected documentation does not establish a direct localhost HTTP URL with custom bearer headers. A local stdio-to-HTTP bridge would add distribution and lifecycle work requiring user acceptance. [Local desktop extensions](https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop) |
| Claude account custom connector, including Desktop/Cowork | Network traffic originates from Anthropic infrastructure and requires public reachability | Excluded by the localhost charter. Desktop installation does not make this connector local. [Remote connector network requirements](https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp#network-requirements) |

An SSH, container, cloud, or remote executor uses its own loopback address. Codex's local header helper is unavailable for HTTP servers on remote executors. Select a local execution surface explicitly. [OpenAI MCP configuration](https://developers.openai.com/codex/mcp)

No supported minimum version has been accepted or proved. Proposed prototype baselines are the observed CLI and desktop versions. Claude documents interactive `/mcp reconnect all` from 2.1.284; that feature floor does not establish a minimum for the complete Planner flow. [Claude reconnect documentation](https://code.claude.com/docs/en/mcp#retry-failed-servers-yourself)

## Token handoff and reconnection

Codex 0.160.1 supports `bearer_token_env_var`, `http_headers`, `env_http_headers`, and `http_headers_helper` alongside a configured `url`. Its pinned helper implementation caches headers per connection, refreshes after same-origin POST 401/403, and retries once only when effective helper headers change. Explicit bearer/OAuth credentials override helper Authorization; an insufficient-scope 403 does not trigger refresh. These are source facts, not an observed Planner connection. [Pinned header implementation](https://github.com/openai/codex/blob/rust-v0.160.1/codex-rs/rmcp-client/src/http_headers.rs)

Claude's helper emits a JSON header object, runs on connection/reconnect, and refreshes after 401/403 before one retry. Project/local helpers require folder trust; repository/plugin helpers lose credential-like environment variables. Mid-session HTTP reconnection has bounded backoff. Its v2 runtime probes the newer protocol, with version/provider/feature-flag differences. [Claude authentication and runtime documentation](https://code.claude.com/docs/en/mcp)

Neither header helper changes the configured URL. A new port requires configuration reload or a fresh client process; a new token cannot update an already running process's inherited environment. OpenAI documents desktop Restart after configuration changes. Silent URL discovery and hot environment refresh are not established by this research.

| Option for the user to choose | Consequence |
| --- | --- |
| Direct HTTP with a chosen stable port and token handoff when starting the client | Simplest first experiment; a stable address does not require a permanent listener. Occupied ports need a clear failure or explicit alternative. Starting/restarting clients remains visible work. |
| OS-assigned port with per-session connection information | Avoids a fixed-port collision, but each enablement may require a new client configuration or launch. No automatic discovery has been proved. |
| Stable URL plus an opt-in local credential helper | Can retrieve renewed tokens without putting them in command arguments or committed settings. Adds helper packaging, secure local exchange, trust, and revocation behavior to prove. It cannot solve a changing URL alone. |
| Bridge for Claude Desktop Chat | Consider only if Chat is selected and direct local HTTP cannot be established. A helper process must cease useful access while Planner is disabled; it must never restart Planner's listener itself. |

Keep temporary token values out of URLs, repository files, shell history, process arguments, and routine logs. For a manual baseline, a client process can receive a token through a protected launch handoff without persisting it in project configuration. Secure storage/helper exchange and clipboard use are options requiring an explicit usability decision, not implementations supplied by this report.

OAuth is not inherently necessary for clients supporting preconfigured bearer headers. MCP's HTTP authorization specification recommends OAuth interoperability when authorization is implemented; a locally paired temporary bearer token is a client-specific route, not a claim of complete OAuth conformance. [MCP authorization requirements](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization#protocol-requirements)

## Swift SDK, listener, and protocol responsibilities

The latest published official Swift SDK release inspected was **0.12.1**, published 2026-05-07. Its pinned README targets protocol **2025-11-25**, despite calling that revision latest in the older release text. [Release metadata](https://github.com/modelcontextprotocol/swift-sdk/releases/tag/0.12.1), [pinned README](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/README.md)

- `StatelessHTTPServerTransport` accepts HTTP request values and returns JSON responses. It has no HTTP session identifier or SSE channel; GET and DELETE return 405, and server notifications are dropped. [Pinned stateless source](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Base/Transports/HTTPServer/StatelessHTTPServerTransport.swift)
- `StatefulHTTPServerTransport` returns streamed responses, assigns a session identifier, and implements GET streams, DELETE termination, and resumability. One instance holds one session and one standalone GET stream. Simultaneous Codex/Claude connections need an explicit routing/transport ownership design. [Pinned stateful source](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Base/Transports/HTTPServer/StatefulHTTPServerTransport.swift)
- Both transports are framework independent request handlers. Neither starts a socket listener. SDK `disconnect()` terminates transport state; it does not unbind a listener owned by the adapter.
- Default pipelines validate Origin/Host, headers, and protocol state, but contain no bearer validator. Supplying a custom pipeline replaces those defaults, so authentication must retain the other protections. The provided bearer validator still delegates credential validation to app code. [Pinned validators](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Base/Transports/HTTPServer/HTTPRequestValidation.swift)

Apple's `NWListener` can use an assigned or chosen local port, but that API alone does not provide an HTTP implementation. A sandboxed macOS listener needs Incoming Connections (`com.apple.security.network.server`). The entitlement permits listening; loopback restriction must still come from socket parameters. Adapter/framework choice and its signing behavior need a focused prototype. [Listener initializer](https://developer.apple.com/documentation/network/nwlistener/init(using:on:)), [server entitlement](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.network.server)

The 2025-11-25 transport requires rejecting a disallowed present Origin and recommends binding loopback. Its disconnect is not a cancellation signal; cancellation is explicit. Revision 2026-07-28 replaces initialization with request metadata and uses closed response streams for HTTP cancellation. Dual-era clients can fall back to older servers, but modern-only clients cannot. Confirm actual fallback before advertising support, and interpret cancellation using the negotiated revision. [Older transport](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports), [current versioning](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning), [current HTTP binding](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http)

The app's authorization lifetime, an MCP session identifier, and a socket lifetime are distinct. Off must revoke authorization, close live connections, and destroy the listener. A reachable server returning 401/403 is not the specified off state. Enablement should create the listener only after authorization and publish connection information only after binding succeeds. The brief requires visible session state, manual Stop, inactivity timeout, and default read/create/edit/archive without permanent delete. Exact durations, window-close behavior, and handling of an already admitted write still require user decisions. [Agent Control requirements](../product-brief.md)

## Precise handoff questions

Resolve these within [Shared command contracts](https://github.com/dvcol/planner/issues/13), without adding another decision ticket:

1. Does “Claude” require Desktop Chat, local Desktop Code, CLI, or more than one? Which inspected desktop and CLI versions become the initial support floor after the prototype?
2. Must clients recover without restarting when Planner is enabled again? Choose stable-port manual handoff, a changing endpoint, or an accepted helper/bridge. Specify what the user sees when the port is occupied or the token has expired.
3. Must Codex and Claude operate simultaneously? Choose isolated stateful sessions or a demonstrated stateless design, with equal JSON-RPC request identifiers from different clients kept separate.
4. On Disable, expiry, or app quit, does an already admitted write finish, or abort before commit where possible? Define response, resulting item state, and retry behavior for each boundary. A lost response must not silently decide whether a write happened.
5. What exactly happens when a client retries an acknowledged or uncertain create/edit/archive? Specify operation identity, duplicate handling, and the expected serialized PlannerCore state before exposing write tools. MCP request identifiers alone do not establish durable domain idempotency.

## Prototype obligations and research completion

These checks belong to [MCP session prototype](https://github.com/dvcol/planner/issues/16), after the user settles the policies above and [Apple test access](https://github.com/dvcol/planner/issues/7) supplies a sandboxed app build and disposable local data. Confirm the public interfaces before coding, then use `/tdd`: one failing behavior test, its minimum passing implementation, and the next scenario. Unit tests cover the agreed credential and command policies; integration tests use real client-to-listener requests and public PlannerCore results. Do not assert internal service calls or claim source inspection tested the application.

Transport fixtures use `POST /mcp`, a bound test loopback port, `Host: 127.0.0.1:<port>`, `Content-Type: application/json`, `Accept: application/json, text/event-stream`, and this legacy request body:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"planner-prototype-check","version":"1"}}}
```

Actual temporary tokens remain in test memory; fixture labels `validToken`, `invalidToken`, `expiredToken`, and `revokedToken` describe credentials, not literal production values.

For a post-initialization protocol check, use `{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}`, with the negotiated protocol header and the returned session identifier when the transport uses one. The initializer itself is exempt from the SDK's header version check.

| Exact variation/action | Required observable outcome |
| --- | --- |
| Send fixture with the active token and no Origin | Successful initialization using a mutually supported version; no domain mutation. Record response and negotiated revision per selected client. |
| At an enabled fixture endpoint, omit Authorization or substitute an invalid, expired, or revoked credential | Each request returns 401 before a domain command runs; disposable data remains unchanged. Record the agreed challenge/error shape. If app timeout has already stopped the listener, expect connection failure instead of an HTTP response. |
| Active token plus `Origin: https://hostile.example` | 403 and unchanged data. Missing Origin for a native client remains acceptable when the other checks pass. |
| Active token plus `Host: hostile.example:<port>` | Reject before domain dispatch; pinned SDK validator returns 421. Confirm the selected adapter preserves this protection. |
| Inspect bound addresses, then attempt the bound port through the Mac's LAN address | Only selected loopback addresses are listening; LAN request cannot connect. Explicitly test IPv4 and the chosen IPv6 policy. |
| Disable, reach the agreed inactivity timeout, or quit; then reconnect to the former endpoint | No Planner-owned listening socket, no usable existing stream, connection failure, and old authorization unavailable. Do not accept a reachable 401 endpoint as passing. |
| Send the post-initialization `tools/list` fixture with `MCP-Protocol-Version: 1900-01-01` | Pinned SDK returns 400; no domain mutation. Separately record each selected client's 2026-07-28 probe and fallback to the supported older revision. |
| Drop a connection; reconnect with the selected session policy; explicitly cancel an in-flight request | Record recovery and cancellation under the negotiated revision. Verify no unauthorized session reuse or implicit write replay. |
| Admit the agreed write fixture, lose its response, repeat it, then disable during another write | Use the exact create/edit/archive inputs and before/after JSON snapshots approved in Shared command contracts. Pass only if outcomes match that decision, including duplicate and in-flight behavior. |
| Connect both clients with JSON-RPC `id: 1` concurrently, if simultaneous clients are selected | Each receives its own result and authorization/session isolation; no cross-client response or state confusion. |

Manual UI checks must show enablement, connection instructions, stale token/endpoint recovery, expiry, and Off. Each selected desktop surface needs its own demonstration; CLI success is insufficient. Verify existing and new connections, app quit separately from window close, and redaction of tokens in generated instructions and captured logs.

Research is complete when these cited facts and explicit remaining checks are accepted in the map. Runtime interoperability, signing, and security checks remain unperformed and belong to the prototype. No Swift code, installation, client configuration, listener, git action, or GitHub mutation was performed for this report.
