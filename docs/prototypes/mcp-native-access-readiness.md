# Native Agent Control readiness

Refreshed on 18 October 2026 against `prototype/navigation`. Subsequent decision: Q100 B defers native Agent Control implementation until signing and native Mac automation are available. The controlled credential-I/O boundary in option A is not approved. Existing HTTP/Core tests establish transport and domain behavior; they do not establish an enabled native product or a selected-client connection.

## Current source and next step

`PlannerApp` starts SwiftUI and owns `SavedPlannerStore`. The store owns its real Core facade/session. Production startup does not construct the existing request handler or loopback listener. There is no native Agent Control owner, menu-bar status/control or non-UI `--mcp-headers` branch. The accepted signed Keychain/App Group reader remains unimplemented.

The [Q100 proposal](../native-agent-control-contract-review.md) describes the missing lifecycle owner and option A's shared production credential I/O interface. The human selected Q100 B, so the alternative interface and its controlled tests are unapproved. Implementation waits for actual signing/storage qualification. Q98 A and Q99 A are approved independent work.

After the user returned to the unlocked Mac, the [Q101 native Capture journey](native-catalog-add-menu.md) starts and passes, 68.643 seconds. It removes the previous pre-test automation blocker for that run. The fresh signing inventory still reports no valid development identities. The user declines paid membership; verify the available free signing/capability route before claiming the actual protected-storage gate. This does not approve option A's controlled credential tests or a plaintext/volatile fallback.

## Refreshed CLI facts

Recorded commands identify Codex CLI 0.162.1 and Claude Code 2.1.295. Version/help commands are not successful MCP calls.

The installed Codex parser recognizes a temporary runtime `http_headers_helper` override. `codex mcp get` returns a streamable-HTTP configuration with that field redacted. The probe uses a dummy `/usr/bin/false` helper, not a credential reader; it invokes no Planner tool and proves no connection. No MCP add/configuration mutation command was used. The command reports a denied PATH-alias cache write, retained in its stderr. Exact probe.

[Official OpenAI documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli) documents local HTTP helper commands that return a JSON header map. [Official Claude documentation](https://code.claude.com/docs/en/mcp) documents `headersHelper`, including connection-time execution, trust and reconnect rules. These support the planned same-executable reader route. Installed-parser recognition and documentation do not prove helper execution, refresh, trust, actual tools or either desktop route.

All four selected routes still need separately recorded results: Codex CLI, local Codex desktop, Claude Code CLI and Claude Desktop's local Code tab. Real concurrent-client/native behavior and credential handling remain required. Do not replace those gates with the existing Swift SDK/URLSession tests or a hand-supplied token.

## Earlier Mac runtime retry

The existing final Mac compiler products were reused after their source/product checks. One bounded ordinary Apple Maps/owned-address UI journey was attempted. Literal packet reports exit 65: XCTest timed out while enabling automation mode. Zero Test Cases started. The readiness record and compressed log retain the failure.

That attempt supplies no native UI, map, interaction or visual credit. No permission or signing-account setting was changed. The later Q101 pass is separately recorded above, with its actual production source/products, failed assertions, correction and window captures. It establishes the selected Capture workflow, not Agent Control or signed storage. Physical and CloudKit qualification remain unmet.

## Remaining gates

| Requirement | Current evidence | Next dependency |
| --- | --- | --- |
| Native manual Enable/Stop and shared lifecycle owner | Absent from production source | Q100 B: actual signing/storage, then real signed/native TDD; selected Mac Capture automation now works |
| Menu-bar On/Off/Stop and last-window behavior | Absent from production source | Same owner and actual native qualification |
| Same-executable protected credential reader | Approved declaration, no implementation | Actual signed storage and reader implementation/runtime proof |
| Four selected client routes | CLI availability and Codex config recognition only | Working native owner/reader and actual client calls |
| Native Mac UI behavior | Earlier pre-test failure; later Q101 Capture journey passes | Qualify remaining native scenes and Agent Control lifecycle |
| App Group, protected Keychain, account/sync/Share and physical gates | No valid development identity; actual capabilities unverified | Free signing setup and required scenarios; CloudKit still requires membership or a reviewed replacement |

Source hashes, factual review and evidence hashes retain the earlier source inspection, configuration recognition and startup failure. The linked Q101 packet supplies the later native result. Q100 B's signed-storage requirement is still unmet. These checks close no map ticket; all remaining acceptance gates stay in place.
