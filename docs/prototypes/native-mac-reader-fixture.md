# Native Mac reader fixture, 28 October 2026

The existing saved-guide journey starts on the signed Mac runner, but its
loopback HTTP fixture fails with `Operation not permitted` before Planner opens.
The runner is sandboxed and permits outgoing connections; its generated
entitlements do not permit listening. Apple's
[server-entitlement reference](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.server)
documents that requirement.

The navigation test configuration now supplies that entitlement on macOS only.
The existing fixture already binds `127.0.0.1` on an ephemeral port. Actual
runner inspection confirms sandbox, client and server entitlements. Production
app/Share permissions and manual UI Automation authentication are unchanged.

The same journey then passes in 38.066 seconds with zero failures. It opens the
real local page through the saved bookmark and rich card, returns to the exact
bookmark, and preserves the single Item. The inspected original capture shows
the page in Planner's detail pane beside its Items catalog. The failed run
remains a fixture-startup failure, without product UI credit.

The [execution record](evidence/native-reader-mac-fixture-2026-10-28/result.json)
retains both outcomes, separate input/product epochs, strict signature checks
and the original capture. Corrected Mac and Simulator builds match 1,169 inputs.
Separate mobile List presentation edits were present in those snapshots; this
checkpoint supplies no mobile runtime credit. Reader resizing/history/lifecycle,
installed Share discovery and full accessibility/physical acceptance remain
open. Production CloudKit stays disabled.
