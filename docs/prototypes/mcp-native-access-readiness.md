# Native Agent Control readiness

Refreshed on 18 October 2026 against `prototype/navigation`. Subsequent decision: Q100 B defers native Agent Control implementation until signing and native Mac automation are available. The controlled credential-I/O boundary in option A is not approved. Existing HTTP/Core tests establish transport and domain behavior; they do not establish an enabled native product or a selected-client connection.

## Current source and next step

`PlannerApp` starts SwiftUI and owns `SavedPlannerStore`. The store owns its real Core facade/session. Production startup does not construct the existing request handler or loopback listener. There is no native Agent Control owner, menu-bar status/control or non-UI `--mcp-headers` branch. The accepted signed Keychain/App Group reader remains unimplemented.

The [Q100 proposal](../native-agent-control-contract-review.md) declares the missing lifecycle owner and shared production credential I/O interface before tests. It reuses the current authorized Core context, handler/listener and accepted reader/security policy. The human selected Q100 B, so this implementation waits for signing and working native Mac automation. Q98 A and Q99 A are approved independent work.

Local app-hosted controller tests can use controlled results at the actual credential I/O boundary while exercising real Core and loopback HTTP. Actual signed storage/reader behavior remains required separately. This is the proposed staging, not a claim that the controller exists or signed access works. No plaintext or volatile production fallback is proposed.

## Refreshed CLI facts

[Recorded commands](evidence/mcp/native-access-readiness/installed-cli.json) identify Codex CLI 0.162.1 and Claude Code 2.1.295. Version/help commands are not successful MCP calls.

The installed Codex parser recognizes a temporary runtime `http_headers_helper` override. `codex mcp get` returns a streamable-HTTP configuration with that field redacted. The probe uses a dummy `/usr/bin/false` helper, not a credential reader; it invokes no Planner tool and proves no connection. No MCP add/configuration mutation command was used. The command reports a denied PATH-alias cache write, retained in its stderr. [Exact probe](evidence/mcp/native-access-readiness/codex-header-configuration-probe.json).

[Official OpenAI documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli) documents local HTTP helper commands that return a JSON header map. [Official Claude documentation](https://code.claude.com/docs/en/mcp) documents `headersHelper`, including connection-time execution, trust and reconnect rules. These support the planned same-executable reader route. Installed-parser recognition and documentation do not prove helper execution, refresh, trust, actual tools or either desktop route.

All four selected routes still need separately recorded results: Codex CLI, local Codex desktop, Claude Code CLI and Claude Desktop's local Code tab. Real concurrent-client/native behavior and credential handling remain required. Do not replace those gates with the existing Swift SDK/URLSession tests or a hand-supplied token.

## Current Mac runtime retry

The existing final Mac compiler products were reused after their source/product checks. One bounded ordinary Apple Maps/owned-address UI journey was attempted. [Literal packet](evidence/navigation/native-scene-appearance/mac-maps-current-runtime/exit.json) reports exit 65: XCTest timed out while enabling automation mode. Zero Test Cases started. The [readiness record](evidence/mcp/native-access-readiness/mac-runtime.json) and compressed log retain the failure.

This is no native UI, map, interaction or visual credit. No permission or signing-account setting was changed. Repeating the same startup failure is not another feature test. Signing and physical-device work remain deferred.

## Remaining gates

| Requirement | Current evidence | Next dependency |
| --- | --- | --- |
| Native manual Enable/Stop and shared lifecycle owner | Absent from production source | Q100 B: signing and working native Mac automation, then real signed/native TDD |
| Menu-bar On/Off/Stop and last-window behavior | Absent from production source | Same owner and actual native qualification |
| Same-executable protected credential reader | Approved declaration, no implementation | Shared credential boundary, then signed/runtime proof |
| Four selected client routes | CLI availability and Codex config recognition only | Working native owner/reader and actual client calls |
| Native Mac UI behavior | Current attempt starts zero Test Cases | Working XCTest automation environment |
| App Group, protected Keychain, account/sync/Share and physical gates | Not established by this check | User-deferred signing/device setup and their required scenarios |

[Source hashes, factual review and evidence hashes](evidence/mcp/native-access-readiness/) distinguish source inspection, configuration recognition and runtime failure. Q100 B leaves this implementation deferred until signing and native Mac automation are available. This check closes no map ticket; all remaining acceptance gates stay in place.
