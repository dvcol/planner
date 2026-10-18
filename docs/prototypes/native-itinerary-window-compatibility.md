# Native itinerary window compatibility

Status: local qualification continuation of [Q98](native-itinerary-windows.md). The map remains open. No Apple account, team, entitlement or provisioning setup changes are part of this work.

## Context and goal

The shared loader already windows Item, Inbox, standalone List and Itinerary presentations. The first itinerary checkpoint qualifies repeated appearances on phone and an earlier tablet source. Its remaining acceptance work includes migrated callers, collapse/reopen, rotation, actual Mac resizing, filtered drag anchors and live route/membership changes.

Before: those interactions lack current-source qualification. After: the represented native and real-Core journeys preserve complete identities, independent local completion, full progress, saved order and selected details while releasing offscreen presentations. Compilation and a failed automation preflight cannot establish runtime behavior.

## Definition of ready and test boundaries

Q95, Q97 and Q98 approve the shared app-internal loader and existing app-hosted real-Core/native UI boundaries. Use disposable local data and public Core commands. Native tests operate the production views and standard controls. No test-only production parameter, persistence field, package or target is introduced.

Keep repository Swift/configuration inputs and compiled products frozen throughout each native runtime. Build and execute Xcode jobs serially. Record exact source/product hashes, command, result and original captures for each epoch.

## Required checks and definition of done

- Requalify the repeated 132-appearance route and both offscreen Item pickers against the final parent-navigation correction.
- Collapse and reopen one repeated List, retaining selected details on wide layouts and independent local completion. Exercise real mobile rotation and measured narrow/wide Mac windows.
- Drag a visible itinerary entry under a Todo filter. Clearing that filter must retain the hidden completed entry, its original identity and full saved order after relaunch.
- Change route order, List membership/order, live source names and a repeated branch through real Core commands. Refresh must retain surviving identities and contextual state.
- Requalify affected Item/Inbox/List and itinerary filtering/entry journeys. Close the separate List-origin New Item label-selection gap through the already accepted native UI boundary.
- Run affected strict Swift lint, mobile/Mac compilation and the narrow loader class. Inspect actual original captures, record unavailable checks, and keep physical performance, sync and final whole-app acceptance separate.

## Results recorded so far

| Epoch | Represented result |
| --- | --- |
| `tablet-repeated-pages-and-both-pickers` | Three pass: repeated route 155.613 s, Add-existing picker 262.753 s, Itinerary picker 188.599 s. Uses the final parent-context correction. |
| `itinerary-order-membership-source-refresh` | New real-Core route/membership/source mutation function passes in 2.561 s. |
| `tablet-collapse-rotation` | Controller failure: a positional element query retargets the second repeated appearance after the first disappears. No product correction or pass credit. |
| `tablet-collapse-rotation-identity-qualified` | Exact-identity collapse, selected detail, rotation and reopen pass in 53.269 s. |
| `tablet-filtered-entry-drag` | Native drag does not produce the expected order. Retained as failed; the cause is not established. |
| `itinerary-drag-diagnostic-build` | Sandbox prevents compiler-cache and Simulator access. No runtime credit. |
| `itinerary-drag-diagnostic-build-retry` | Mobile compiler check passes with required Xcode access. |
| `tablet-filtered-drag-diagnostic` | Drag, filter clearing and exact saved order/state after relaunch pass in 66.796 s with before/after captures. No production change separates this from the earlier failed gesture. |
| `phone-collapse-and-filtered-drag` | Collapse/rotation/reopen passes in 55.593 s; filtered drag/relaunch passes in 66.450 s. |
| `itinerary-native-mac-compatibility-build` | Local ad hoc Mac compiler check passes. |
| `mac-itinerary-pages-collapse-resize-drag` | UI automation times out before any function starts. No paging, resize or drag runtime credit. |
| `mac-current-itinerary-and-catalog-retry` | A second current-source attempt times out enabling automation before either selected function starts. Mac compilation passes separately; runtime remains unavailable. |
| `phone-list-origin-labels` | New controller looks for a List row while compact navigation still shows the saved Item detail. Fails in 105.421 s. The controller now uses the existing rich-creation journey's native Back step. |
| `phone-list-origin-labels-context-qualified` | Discard, labels, rotation, Save, exact shared-label identities and original local Todo appearance after relaunch pass in 139.900 s. |

The [evidence packet](evidence/navigation/native-itinerary-window-compatibility/) retains each epoch separately. Successful gestures do not erase failed attempts or prove their cause. The native results above precede the subsequent Q103 shared-loader extension and catalog migration. Their exact source epochs remain separate; affected current-source native qualification continues with Q103.

## Visual review and limitations

The primary agent inspected two original dark iPad drag captures. Both show readable full progress and estimates. The filtered view shows two matching rows; the relaunched view shows 001, 003, 002 with only 001 checked. Two further phone label-journey originals show a correctly framed landscape draft and the saved labeled Todo row after relaunch. The portrait toolbar contains a clipped partial navigation-title glyph behind its controls; keep this finding for native polish.

A read-only sub-agent inspected four original phone captures. Portrait captures show readable List headers, differing branch progress and the saved drag order. Scrolled rows extend behind native floating controls at the viewport edges; this does not establish whether any content is unreachable. The app-wide landscape screenshot is misframed and supplies no whole-layout visual credit. A corrected window capture remains to inspect.

The later `phone-main-catalogs-and-corrected-collapse` epoch uses the established native screen-capture method on mobile. The primary agent inspected its original landscape image: it is fully framed and shows readable route controls, a direct Item, the collapsed List's estimates and independent 1-of-65 progress. Scrolled content still extends beneath native top/bottom controls. This corrects the capture limitation rather than qualifying every landscape scene.

Exact inspected paths, hashes, reviewer attribution and limitations are in `visual-review-primary.json` and `visual-review-delegated.json` in the packet. Pixel inspection is separate from interaction assertions and formal accessibility testing.

The later current-source `tablet-catalog-refresh-and-collapse-current` reruns wide detail/collapse/rotation successfully after Q103, in 52.994 s. Its dark portrait and landscape originals show retained Completed details and full progress beside the collapsed branch. Both platform targets compile with the final catalog lifecycle corrections.

## Remaining local and external gates

Q98 remains open for the unavailable Mac runtime and listed caller regressions. The corrected phone landscape original now has scoped visual evidence above. Broader native accessibility, keyboard operation, scale measurements and feature-complete whole-app polish retain their map gates.

Q103 A approves windowing the remaining List/Itinerary catalogs and choice pickers in [the concrete contract](../native-container-window-contract-review.md). Its shared overload and all eager native catalog/picker callers are migrated; affected native qualification continues. Q104 A settles current-app-run Undo history; Q105 A preserves newer relationships and rejects conflicting old Undo. Q106 A and Q107 A approve [the concrete Core issuance and native-affordance contract](../native-association-undo-contract-review.md).

Q100 B still requires actual signing and protected Agent Control storage qualification. Physical iPhone/iPad, CloudKit/account transitions and cross-process Share checks need their own signing/capability setup and actual device evidence. Local work continues independently; this report does not claim signing is the only remaining task.
