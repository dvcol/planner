# Native Item finding

Status: first text/state/scope/sort slice qualified at the production Intent boundary. Mac, Simulator and unsigned device products compile. Signing remains deferred. The [cumulative identity/presence/scheduling follow-up](native-item-find-criteria-intent.md) is subsequently qualified separately; the counts below retain this first slice's original evidence epoch.

## Context and goal

Before this slice, Shortcuts can resolve Item identities and search text, but cannot express the native app's cumulative query criteria or select a sort. Find Planner Items uses the existing Core Item query and generation-bound row pages. It returns the existing shared Item entity, with global completion rather than a List or Itinerary appearance's local state.

This first slice combines text, All Items or Inbox scope, completion and archive. Sort choices use Core's Title, Created, Last updated and Estimate semantics, with ascending/descending direction. Manual order remains a container-content operation. Defaults retain all completion/archive states and alphabetical order, matching the existing native Item choices. This action does not save presentation preferences or alter Item data. Shared Category/Tag/List identity criteria, address/link presence and scheduled state remain subsequent local slices.

Duration-range input remains dependent on Q115's native quantity/unit choice; this slice does not select that pending presentation or claim the full query interface is complete. Q117's deferred property boundary and Q118/Q119 scheduling workflows remain separate and unimplemented on assumed answers.

## Test boundary and required evidence

Use Q112's production callAsFunction interface, real AppDependencyManager registration and disposable SavedPlannerStore/Core data in the existing app-hosted target. Reuse the production Item query loader. No new package, target, test-only factory, injected query environment or private-helper tests are proposed.

Qualify cumulative criteria, exact shared identities despite duplicate/renamed labels, independent local/global completion, Inbox membership changes, sorting and missing estimates, direct/inherited/past schedules, large result paging, live external edits, cancellation, unavailable storage and reads during actual incomplete recovery. Compare portable data before/after reads and verify preserved identities/content after reopening. Dispose marked fixtures only after their test hosts and SQLite handles close.

The required cases span the complete planned interface. This first slice qualifies its implemented text/state/scope/sort fields and leaves label, presence and scheduling criteria explicitly open.

## Executed development checks

The first test attempt included an incorrect fixture argument label. After correction, its feature red identifies the missing action and resulting unresolved filter types. The initial implementation passes cumulative text/completion/archive filtering and byte-identical portable data before/after reads.

The scope/sort test initially used the wrong List field and treated a membership as a source identity. Those test-construction failures are retained. The corrected test has a separate missing-parameter red, then passes both original tests with both directions of all four sorts. Inbox excludes current List members. A locally Done but globally Todo Item remains in global Todo results. Archived/Done filters stay independent, unknown estimates sort last in either direction, and sorted reads preserve saved manual order and local states.

The empty-result precancellation test produces three actual runtime failures: Find, text choices and empty identity choices all return success because their checks occur only inside result loops. The fix checks cancellation before acquiring the store context and, for row queries, after Core returns the snapshot. This adds no injected cancellation mechanism. It proves precancellation behavior, not every in-flight cancellation interleaving.

## Local qualification

| Check | Actual result |
| --- | --- |
| [Combined Mac run](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-final-clean/test-results-summary.json) | 31 pass, no failures/skips: 29 XCTest cases in 16.628 seconds plus two real Calendar HTTP compatibility tests |
| Find-specific cases | Six pass in 9.607 seconds: cumulative text/state criteria, both scopes/all sort directions, precancelled empty reads, unavailable bootstrap, multi-page/live-writer refresh and reads during incomplete recovery |
| [Fixture lifecycle](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-final-clean/fixture-lifecycle-report.json) | All 29 marked XCTest stores safely disposed after host/database closure. No SQLite lifetime diagnostics in the original combined log |
| [Native contracts](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-final-clean/extracted-intent-identifiers.json) | 67 actions, unchanged ten entities/queries, nine enums. Find has six required parameters with defaults and an existing Item-entity array result; five enums add only the supported criteria/sort cases |
| [Source comparison](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-final-clean/baseline-source-comparison.json) | 1038 frozen inputs. The existing Item query changes, with one Find action file and one test file added; other prior inputs remain unchanged |
| [Simulator compilation](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-mobile-compile/exit.json) | App and existing native UI target compile with matching inputs and native contracts; no system runtime credit |
| [Unsigned device product](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-device-compile/embedded-products-verification.json) | arm64 app and exactly one mobile Share extension, with matching inputs and native contracts; no installation or launch |
| [Strict Swift lint](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-final-clean/strict-lint.json) | All three affected Swift files pass |

The paged fixture contains 73 saved Items. Two matching visits already have List memberships, leaving 67 Inbox matches across two pages in descending title order, with every identity present once. Completing one through a second real Planner writer leaves 66 Todo matches. Selecting all completion states restores 67 results with the changed global state. Portable data remains byte-identical around each read phase; these are separate fresh queries, not a forced write between page reads or a physical-performance result.

Find reads applied searchable notes during a real recovery-directory obstruction. It keeps the original incomplete operation and blocked-mutation state. Once archive access returns, the original receipt is still incomplete until explicit recovery. Successful reads do not acknowledge the saved edit's recovery.

The [collector correction](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-final-clean/collector-count-correction.json) preserves an incorrect initial fixture-count assumption. All 31 tests passed; 29 native cases used the marked fixture factory, and the two HTTP cases did not. No production/test source or test outcome changed when correcting this evidence check. All three current platform builds have zero compiler diagnostics; known clean-base warnings remain recorded separately rather than claimed fixed.

Inspect actual native parameters, enum cases and array output. Preserve previous action/entity/query/enum contracts and compare Mac, Simulator and unsigned device source hashes. Run affected existing Item query/action and real HTTP regressions, strict affected-source lint and platform compilation. Full result arrays and Core's captured identities remain retained; 64-row paging does not prove bounded total memory or physical-device performance.

Actual Shortcuts discovery, parameter rendering, system invocation, background/locked access and system dependency injection remain separate open gates. This local slice does not authorize signing or installation, or complete Agent Control, CloudKit/account/shared storage, installed Share, physical qualification or final whole-app polish.
