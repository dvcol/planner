# Native original-association Undo

Status: Q106/Q107 Core and represented mobile outcomes retain their recorded
results. The 27 October checkpoint below additionally qualifies four native
Mac membership, window/text and Move Undo journeys. Retry/in-flight feedback,
other contexts and broader native UI acceptance remain open.

## Context, goal and starting state

Before this slice, removing a List membership or Itinerary entry saves the removal but offers no original-association Undo. The native store reduces the result to Bool. Ordinary re-add correctly creates a different local Todo association.

The goal is to restore the original public association identity, rank and contextual completion under a fresh lifetime. Preserve live source content and independent appearances. Reject newer conflicting relationships, superseded history and invalid bindings. Undo lasts for the current app run and belongs to its originating window. No source Delete recovery, Trash, persistent history, agent administration or association Redo is introduced.

The [approved contract](../native-association-undo-contract-review.md) defines the concrete companion, restore command, recovery handling and native affordance.

## Definition of ready

Q104 A accepts current-run history. Q105 A preserves newer relationships. Q106 A approves the concrete Core interface and existing public-store/native UI test boundaries. Q107 A approves named UndoManager actions, explicit mobile Undo and no association Redo.

Tests use actual disposable-store commands, reads, exports, native save notifications, isolated filesystem faults, real HTTP and native UI journeys. No snapshot fabrication, private database inspection or test-only production parameter is introduced.

## Current implementation

Core returns an optional issued companion after a successful removal save. Its private current-run registry can supply the same companion for exact removal replay. The snapshot stays outside applied receipt values, backup formats and adapter encodings.

The restore command validates issuance, dataset/ownership binding, predecessor closure, surviving source/owner lifetimes and relevant association history. It restores the original public ID, rank and local flags under a fresh restoration family. Captured expanded states retain their independent flags with the restored lifetime remapped. Shared Item content and standalone List completion remain live and unchanged. Receipt replay precedes fresh restoration eligibility checks.

Applied actions with incomplete recovery remain applied. Checkpoint-only retry acknowledges their saved result without repeating the command. Genuine failed saves now discard their own known-failed prepared proposal after rollback. If that cleanup also fails, the result explicitly requires operation-status resolution before retry.

Native membership and Itinerary removal callers retain the truthful applied result and register its companion with per-window history. Each removal has its own retained UndoManager target. Restoration runs serially; retryable failures retain the same restoration operation ID. Ordinary text history is not cleared or replaced. Namespace changes and window disappearance clear owned targets. These mechanisms still need the broader native-history qualification below.

Visual review found that the original mobile bottom inset covered the native tab bar. The geometry regression fails at Undo maxY 832 versus tab-button minY 795. The production correction uses SwiftUI's native tab accessory on compact layouts and a native bottom bar in sidebar layouts. The corrected phone journey passes in 107.792 s, including Calendar/back navigation, original identity/local completion and relaunch. The iPad List journey passes in dark mode with Increase Contrast in 191.521 s.

The iPad recreated-membership journey passes in 204.703 s. A locally Done membership is removed, then ordinarily added again under a different identity with local Todo. Native Undo explains the rejection and retains that newer association through relaunch. Its original screenshot was inspected: the Todo row, semantic secondary text and dark surfaces remain readable. The two-function invocation still fails overall because its itinerary controller uses the wrong accessibility role; that failure supplies no product-red evidence. The final Mac app/UI targets compile using the existing ad hoc setup. The actual Mac window/text-history retry fails before any function starts: XCTest times out while enabling automation mode after 71.511 s. It supplies no Mac interaction credit and is separate from paid signing or physical-device gates. The corrected iPad itinerary journey passes in `association-undo-tablet-retained-itinerary-qualified`, 98.740 s, including an observed Calendar canvas, return to the retained route, Undo of the original completed branch and relaunch.

## Evidence and TDD

The Core packet retains exact source hashes, changed-source archives, commands, product hashes and underlying results. Native and HTTP epochs are in the compatibility packet. Compiler success alone supplies no runtime credit.

| Epoch | Observed result |
| --- | --- |
| `membership-original-state-qualified-red` / `membership-original-state-first-green` | Missing public companion/command fails compilation, then the real-store membership test passes in 0.150 s. Original ID/rank/local Done return under a new lifetime. The earlier unqualified red also contained two corrected test diagnostics. |
| `itinerary-independent-context-red` / `itinerary-independent-context-first-green` | Missing issued entry companion fails both variants; Item and List-entry restoration then pass in 0.171 s, preserving repeated appearances and source List state. |
| `membership-expanded-contexts-red` / `membership-expanded-contexts-first-green` | Expanded membership restoration fails first, then passes in 0.316 s. Three contextual flags across repeated entries and two Itineraries return under the restored membership lifetime. |
| `newer-membership-history-qualification` | Passes in 0.083 s. Ordinary re-add keeps its newer identity and Todo state; old Undo rejects without changing exported data. |
| `issuance-and-replay-qualification` | Passes in 0.132 s. Reopen expires unused issuance; applied receipt replay survives reopen without overwriting later notes. A fresh reuse of consumed history rejects. |
| `superseded-restoration-history-qualification` | Passes in 0.144 s. Two remove/Undo cycles retain one membership and two valid restoration families after reopen; old history cannot revive its predecessor. |
| `deleted-original-bindings-qualification` | Both Item/List deletion variants pass in 0.089 s. Old Undo rejects and preserves surviving data. |
| `foreign-dataset-issuance-qualification` | Passes in 0.170 s. Another dataset remains unchanged and cannot consume the original dataset's capability. |
| `recreated-expanded-counterparts-qualification` | Both membership/entry variants pass in 0.175 s. Ordinary recreation of an expanded counterpart makes the old Undo ineligible; the whole current exported graph remains unchanged. |
| `association-recovery-qualification` | Two functions pass in 0.137 s, including removal/restoration parameter cases. Real didSave obstruction proves applied/incomplete recovery and checkpoint-only repair. Separate pre-save recovery obstruction rejects without changes and permits exact retry. |
| `genuine-restoration-save-failure-red` / `genuine-restoration-save-failure-first-green` | A real isolated SQLite save failure exposes stale prepared evidence. After cleanup is fixed, the test passes in 0.181 s with unchanged reopened data and successful retry. |
| `genuine-removal-save-failure-red` / `genuine-removal-save-failure-first-green` | The same failure affects removal. Both membership and List-entry writers then pass in 0.261 s, issuing no rejected snapshot and allowing unchanged retry. |
| `association-undo-missing-affordance-phone` / `association-undo-membership-phone-first-green` | The iPhone journey fails at missing Undo, then passes in 186.658 s. It restores the original completed membership and shared notes through relaunch, with no old Undo action after relaunch. |
| `association-undo-itinerary-missing-registration-phone` / `association-undo-itinerary-qualified-red-phone` | These runs fail before Undo because of row-refresh timing and a header locator. They supply no missing-Undo qualification. Corrected observations wait for row identities and use the established native header. |
| `association-undo-itinerary-native-header-red-phone` / `association-undo-itinerary-phone-first-green` | The corrected journey fails at missing Undo, then passes in 89.686 s. It restores one repeated List entry and its independent Done state through relaunch. Placement remains defective in its screenshot. |

The observed run index retains successful and failed invocations separately. Production-source comparisons confirm that all 149 recorded production Swift inputs in those passing phone and tablet Undo epochs match the initial `b042022e` checkpoint. Later changes to those UI test files correct native queries and add qualification; they do not change that checkpoint's product.

The final affected Core invocation passes 18 tests across seven suites in 0.910 s, including the original creation save-failure regression. Those are test-run durations, not a performance claim.

Original passing screenshots were reviewed. The final dark iPad before/after frames show the bottom Undo bar, restored completed branch, independent unfinished branch and 1-of-2 progress without covering the content. Completed rows, independent states and dark-mode text are readable. This supplies no final spacing, toolbar or whole-app design acceptance, and no performance claim from test elapsed times.

## Filter and valid-selection follow-up

The current saved application's native UI boundary also qualifies Undo under active completion filters. A new List journey completes Museum locally, selects Hotel, removes Museum, enables Todo, and invokes Undo. Full progress returns to 1 of 2 while Museum stays hidden. Hotel keeps its original appearance identity; on wide iPad its detail and unique notes stay selected. Compact iPhone stays on the List rather than being pushed into the restored Item. Clearing completion filtering reveals the original completed Museum identity. Relaunch preserves both identities/local states and expires the old Undo action.

The repeated-Itinerary journey now enables Todo before its Calendar round-trip and Undo. The restored completed branch remains filtered out, its independent unfinished branch remains visible, and full progress returns to 1 of 2. Clearing completion filtering reveals both original independent appearances, with their Done/Todo states preserved through relaunch.

| Run | Executed result |
| --- | --- |
| `tablet-native-undo-filter-selection` | Passes in 241.651 s with dark mode and Increase Contrast. Both presentation settings are restored. |
| `phone-native-undo-list-filter-selection` | Passes in 233.706 s in dark mode, with compact navigation retained. Appearance is restored. |
| `phone-native-undo-itinerary-filters` | Passes in 120.402 s in dark mode, including Calendar/return and relaunch. Appearance is restored. |
| `native-undo-filter-selection-build` / `native-undo-filter-selection-mac-build` | Both final affected targets compile. Mac compilation supplies no runtime credit. |

This follow-up changes tests and reporting only. No production correction, new interface or direct history-controller test is introduced. Its run index and production comparison retain the exact current production epoch, which includes the subsequent native duration-filter work. Earlier Core/HTTP results retain their original source epochs.

The List journeys each encounter two previously observed 60-second XCTest animation-notification waits around the native context menu. They still complete within their recorded allowance. These waits supply no responsiveness acceptance and are not attributed to a new Undo product defect. Four inspected originals show retained filters/full counts and the wide Hotel selection. Faint composition captions and scrolled content beneath floating bars remain final-polish findings.

## HTTP admission qualification

`association-undo-mcp-admission-red` builds but executes zero functions because the function selectors do not match Swift Testing discovery. It supplies compiler evidence only.

Selecting the two affected suites runs 13 actual functions. `association-undo-mcp-suite-admission-red` exposes the missing native-only exclusion. Execution and review admission now explicitly forbid `restoreAssociation`; it is not advertised as an agent command.

The review suite also exposes an Item-creation expectation mismatch. Its request has no List destination. Current creation review reports `/command/listId`, while the test expects `/command/type`. The exact committed baseline `96bf986`, with no working-tree overlays, also fails that assertion in `association-undo-mcp-committed-baseline`. The expectation is corrected to the accepted List-creation contract's precise error path. Rejection, unchanged data and unchanged recovery remain required. A speculative command-object guard split did not address the mismatch and was removed. `association-undo-mcp-admission-final-green` passes all 13 actual functions in the two affected suites in 1.173 s, including seven native-administration parameter cases. The native Undo exclusion and unchanged-data/recovery assertions pass. This qualifies real HTTP admission, not signed Agent Control credential storage.

## Remaining tests and definition of done

- Core qualification is recorded for restored identity/order/local state, recreated expanded counterparts, stale bindings, issuance/replay, recovery and genuine save failures. Keep its final source hashes and 18-test affected regression result attached.
- HTTP qualification passes all 13 actual functions with native Undo excluded and existing data operations retained. Keep snapshots outside adapter/backup/receipt encodings; App Intents expose no Undo administration.
- Phone tab placement, destination-change/relaunch restoration and the represented phone/iPad filter/valid-selection checks pass. Retain their original appearance identities and exact source epochs; broader scene/layout/accessibility acceptance remains separate.
- Represented mobile and the 27 October Mac journeys qualify stale rejection,
  ordinary text Undo and per-window isolation. Native retry/in-flight feedback
  retains its separate UI gate.
- The initial slice retains strict lint of its 22 affected Swift files and
  mobile/Mac compiler evidence. The later Mac checkpoint below adds actual UI
  execution and its narrowly affected validation.

Q108 is approved. Its [controller checkpoint](native-association-history-controller.md)
qualifies the separate Foundation/storage outcomes without production test
hooks. Those tests alone supply no native window/focus qualification.

The later [native text-Undo journey](native-association-text-undo.md) uses the already approved UI seam independently of Q108. On phone and iPad, actual system text Undo clears an unsaved title while keeping the membership removed; after draft cancellation, the explicit removal action restores its original identity and Done state through relaunch. Four failed controller attempts remain recorded before the two final passes. This adds represented mobile text-editing evidence, not direct history-controller, actual Mac, per-window or asynchronous retry qualification.

The subsequent [whole-Move](native-move-undo.md) and
[grouped link/label](native-owned-association-undo.md) checkpoints implement
their accepted contracts separately from this first removal slice. Association
Redo remains deferred. Physical CloudKit/account/Share and final whole-app UI
acceptance retain their owning-map gates.

## Native Mac keyboard Undo, 27 October 2026

Four existing journeys now run through actual Mac windows and keyboard Undo.
They use disposable local datasets and the existing native UI seam, with no
production history change or new test interface.

| Mac journey | Passing test seconds |
| --- | ---: |
| Original membership, second-window isolation and text Undo | 91.159 |
| Whole Move and original local Done through relaunch | 108.755 |
| Todo filter, full progress and another valid detail selection | 105.615 |
| Reject old Undo without replacing a newer Todo membership | 76.136 |

The initial three-case group retains two passes and one failure. The stale-Undo
case reaches its expected rejection, then its app-wide OK query matches both
the alert button and its Touch Bar mirror. Scoping that test query to the
native window resolves the interaction. Its assertions still require the same
newer identity, Todo state and relaunch persistence. The corrected case passes
on Mac, phone and iPad; mobile test durations are 216.261 and 213.412 seconds.
Their native animation-notification waits remain timing limitations, not app
responsiveness acceptance.

Both changed-test builds pass with 1,168 matching native inputs. Only one UI
test line differs; production sources are unchanged. Earlier three Mac passes
retain their original products. App/runner hashes differ between build epochs
and are recorded separately rather than presented as byte-identical or one
all-green batch. Strict app/Share/runner signatures pass before each Mac run,
executable hashes remain unchanged within runs, and manual automation
authentication remains required before and after.

The packet
retains all seven executions, including the failed alert interaction, input and
product hashes, commands and five inspected original captures. Mobile captures
also show the List title in both navigation and content; title coherence stays
on the UI-polish queue. Other native contexts, retry presentation,
accessibility, installed Share and CloudKit/account/physical acceptance remain
open. No Core/HTTP rerun is claimed for this UI-test-only correction.
