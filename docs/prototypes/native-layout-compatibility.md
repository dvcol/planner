# Native layout and creation compatibility

Status: the represented local layout and compatibility checks pass. Signing and physical-device checks remain deferred. Whole-app UI polish follows feature completion.

## Context and goal

The ordinary Item editor now lives in the detail column on Mac and wide iPad and uses native navigation on compact layouts. The previous creation qualification proves content, destination review and guarded navigation, but does not prove that changing the layout preserves an edited draft. Historical deletion-survivor checks also predate the final ordinary creation integration.

Keep one edited draft and its original List through layout changes. Explicit Save must create exactly one shared Item and one appearance in that List. Another List must stay empty. Existing Add, Capture and deletion actions must retain their identities, completion scopes and current-query selection behavior.

## Definition of ready

Q88–Q93 approve these behaviors and the production native UI test boundary. The current Core commands and local disposable dataset launch path are available. These checks require no new API, persistence schema, signing entitlement or test-only production interface.

## Required tests and definition of done

- Resize the actual Mac Planner window to 860 points and back to 1200 points, verifying that the window reaches each width. Hide and show its native sidebar while the draft remains open. Keep title, subtitle, notes and destination without a navigation prompt.
- Rotate the iPhone and iPad simulators through landscape, portrait and landscape while editing the same fields. Check the visible draft at each step. Rotation alone does not establish iPad split-screen or a change of horizontal size class.
- Save explicitly, observe one contextual appearance in the original List, retain its identity after relaunch, observe exactly one shared Item, and confirm the other List remains empty.
- Requalify affected Add-existing, Capture and deletion-survivor journeys on the current ordinary-creation source. Preserve filtered/sorted survivor selection, cross-window List and appearance scope on Mac, and compact navigation behavior on iPhone.
- Build the affected platform app/UI targets, run strict affected Swift and report Markdown lint, inspect named own-app/window captures, and retain failed attempts separately from passing invocations.

These checks qualify only their represented local paths. Unavailable/restored destinations, other adaptive layouts, physical sync/account/Share, accessibility, performance and final UI polish keep their remaining gates.

## Witnessed navigation regression

The first Mac attempt times out enabling automation before any function starts. Its retry passes the initial layout journey in 99.868 seconds. It resizes the actual window, hides/shows the sidebar, saves the draft into Origin and retains the saved appearance after relaunch. That source epoch predates the later mobile cleanup and navigation correction.

The first iPhone batch passes Item deletion in 71.701 seconds and List deletion in 113.942 seconds. The new layout journey then fails in 87.633 seconds when reopening the saved appearance. Its retained own-app hierarchy shows Origin contents with the saved row selected after its tap, rather than contextual details. Rotation retained the draft values and explicit Save created the appearance, but the selected compact column remained at contents.

An explicit nonnil membership selection now requests the detail column inside the existing draft-navigation guard. This changes navigation only. It does not recreate a source or appearance, change completion, or affect deletion's nil-selection path.

The following Capture journey fails in 77.132 seconds because the failed layout function leaves the simulator in landscape. Its hierarchy shows the correct contextual detail, with Links below the short viewport. Swift `defer` did not restore orientation after the assertion abort. The layout journey now registers orientation and Mac width restoration with XCTest teardown. Named layout captures use the Planner window; the initial application-wide landscape capture is clipped and supplies no visual qualification.

## Mac cross-window deletion crash

The compatibility batch passes Mac List replacement and the layout journey, but the contextual Item deletion path crashes Planner. An isolated reproduction confirms that this is a product crash, rather than merely a missing replacement selection. The main-thread stack reaches SwiftUI's typed environment lookup; the scoped Planner log reports that `SavedPlannerStore` is missing.

Explicitly providing the existing store at the two detail hosts does not fix the crash: the same isolated function fails in 73.346 seconds with Planner no longer running. Those ineffective injections are removed. The next candidate provides the existing store at the native Table cell's `SavedMembershipRow` boundary, whose row content reads that environment value. Its first invocation fails during fixture creation, before deletion, so it provides no result on the candidate. The unchanged retry reaches deletion but still crashes. Its scoped log now identifies the missing `PlannerPreviews` service rather than the store. This locates both required dependencies in `SavedItemRowContent` at the hosted Table cell boundary.

The final production correction supplies that row with the same existing store and preview service. No new service, cache, dataset or selection policy is introduced. The next run reaches the expected original-window contextual details without crashing, then fails because its application-wide row query resolves Birch in the second window's global Item catalog. The final oracle looks up the appearance in the original window and compares its exact pre-deletion membership identity. Its explicit hierarchy attachment is taken after the contextual details become ready.

The six-function Mac compatibility batch passes on the corrected source, including the originally crashing function in 72.958 seconds. Simulator compatibility results combine individually passing functions from the recorded batches and focused retries below.

## Current qualification

The evidence packet retains literal results, frozen sources, compiler links, product hashes and named Planner-window captures. Its run index separates individual outcomes, incomplete runner exits, whole batches and compiler-only attempts.

| Platform | Qualified functions | Layout journey | Invocation results |
| --- | --- | --- | --- |
| macOS 27.0.1, local ad hoc signing | 6 passed | 88.969 s | Pass, 548.231 s |
| iPhone 18 Pro Simulator, iOS 27.0 | 5 passed | 107.901 s | Three appearance passes from the failed batch; focused Add and Capture pass |
| iPad Air 11-inch (M4) Simulator, iOS 27.0 | 5 passed | 117.635 s | Four appearance passes from the failed batch; focused Capture passes, 92.929 s |

All targets use Xcode 27.1. The passing Mac batch has zero failures or skipped functions. It covers the measured layout changes, two-window Item/List deletion, sorted global Item deletion, Add-to-List from detail/row menus and originating-List Capture. Add-existing is also exercised during fixture setup. The layout journey retains the saved membership identity after relaunch, exactly one shared Item, and the untouched Other List.

Both final app/UI-target builds and strict lint for all four affected Swift files pass. Each final build's 945 archived/overlaid inputs match the repository. Runtime checks freeze 469 source/configuration inputs and verify six product hashes before and after each invocation. Historical products were subsequently replaced by compiler checks; their original hashes and source epochs remain recorded. Source reviewers report no remaining Standards or Spec findings; runtime evidence remains independent of those reviews.

All 40 retained named captures were individually inspected. Twenty-two belong to the selected passing functions: eight Mac, seven phone and seven tablet images. Two phone Add captures belong to the timed-out invocation and supply no pass credit; two further Add captures come from its passing focused rerun. The earlier phone Capture image retains its historical pass but is superseded by the focused run using the corrected mobile controller. The images show readable draft fields at both widths/orientations, contextual survivor details, retained completion/order and Capture's saved bookmark. Capture's live previews use the native unavailable/Retry fallback; this is no provider-success claim. Sidebar estimate summaries truncate at the recorded Mac widths. These observations do not complete the whole-app visual review.

## Native toolbar compatibility

The first iPad batch passes Add (322.632 s), Item deletion (79.054 s), List deletion (141.021 s) and draft rotation/relaunch (117.635 s). Capture fails during fixture creation, before capture begins: the portrait toolbar places New List inside its native overflow. The retained own-app hierarchy identifies that overflow and no directly visible New List button. The Capture controller now follows the same native overflow path already used by the other List-creation tests. Its destination review, cancellation, exact bookmark, membership scope and relaunch assertions are unchanged. The focused iPad Capture retry passes in 92.929 seconds; the focused iPhone retry passes in 70.591 seconds. The original iPad batch remains failed.

The source comparison verifies that this iOS-only test-controller adjustment is the sole changed input among the 945 final build inputs. Production, the appearance test class and shared helpers are identical to the preceding compatibility runs. The active macOS Capture source is identical as well. Earlier passing Mac functions and simulator appearance functions retain their actual epochs; the two focused Capture runs qualify the changed mobile controller. No extra runtime credit comes from this source comparison.

## Phone context-menu timing investigation

The first current-source phone compatibility batch passes Item deletion (66.342 s), List deletion (113.009 s), draft rotation/relaunch (107.901 s) and originating-List Capture (68.797 s). Its combined detail/row-menu Add journey reaches the final source-detail assertions but exceeds the 300-second function allowance. The runner logs two 60-second waits for missing animation-complete notifications, following the row long-press and the Add menu action. The whole batch remains failed; the Add function receives no pass credit.

An isolated control build removes only the new compact membership-selection column request. Production source outside that line, test functions and helpers remain identical. It has separate source/product hashes and a distinct build directory, and never mutates the repository or the active final products. Its one-function diagnostic run allows 360 seconds so a repeated animation-notification delay can finish and be compared. This allowance does not establish UI latency or resolve the original timeout.

The one-line comparison verifies all 945 build inputs, with exactly one production-source difference and identical test source. The control passes in 298.406 seconds and reproduces both 60-second notification waits at the same interactions. The new compact-selection line does not sufficiently explain the waits. No speculative navigation/gesture rewrite follows. The corrected-source focused Add retry passes in 299.612 seconds with a 360-second allowance, zero failures/skips and both identical notification waits. Its source and products match the preceding phone batch at that qualification epoch. The earlier five-function batch remains failed. Both notification waits remain recorded without a responsiveness or performance claim.

## Remaining scope

Only the represented layout and compatibility paths receive qualification here. Other adaptive layouts, iPad split-screen/Stage Manager, restored/unavailable originating destinations, duration/label creation qualification, wider Maps/provider cases, keyboard/accessibility, memory/hitches and physical latency retain their gates. This slice changes native navigation and Table dependency delivery; it supplies no new Core, HTTP, account, CloudKit or Share qualification.

Signing and physical-device work remain deferred. Whole-app UI polish with native SwiftUI components follows the remaining feature work. No overall Navigation, feature or map gate is closed by these results.
