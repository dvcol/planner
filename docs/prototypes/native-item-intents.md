# Native Item Intent prototype

Status: the local Item tracer is implemented and qualified under Q112 A. The complete Intent catalog and actual system qualification remain open.

The separate [Archive follow-up](native-item-archive-intent.md) adds a fourth action after this tracer's recorded nine-test epoch. Mac/mobile compilation passes; its green runtime check remains pending after XCTest startup failures. This report's passing tests and three-action metadata remain evidence for their original source epoch, not a pass of that follow-up.

## Context and readiness

At `274fe33e`, the app has no App Intents implementation. The accepted Core facade supplies ordinary Item creation, source reads, completion and canonical queries. Q33 governs adapter authority; Q6 permits ordinary locked-device access where Apple allows it. Backup/export/recovery administration, permanent source/label deletion and association restoration are not registered Intent actions.

The intended result is app-target Item actions and one stable Item entity/query using the actual app-owned Core store. Query/read values must reflect current data rather than cached shortcut labels. Creation must retain its returned identity/content and independent recovery after reopening. No new package, target, injected production factory or alternate persistence path is introduced.

## Test boundary

The existing UI-test target compiles against the public AppIntentsTesting framework. Actual invocation rejects before Planner runs with AppIntentsServicesSecurityErrorDomain 803, "Unable to run internal tests on a Customer build". That is unavailable infrastructure, not a missing-feature red. Apple requires matching development-team signatures for this test framework; paid membership is not established as a solution to this exact error.

[Q112's approved boundary](../native-app-intent-test-contract-review.md) adds direct production-interface tests in the existing app-hosted target. Apple's public `callAsFunction(donate: false)` resolves parameters and calls the actual Intent. The test registers a real SavedPlannerStore in AppDependencyManager. Direct EntityQuery calls bind the SDK's existing dependency wrapper to that same real owner. Get Item also uses this SDK binding for its nested query. No custom context or test-only production parameter is added. This does not qualify automatic system injection or actual Siri/Shortcuts discovery.

## Implementation

PlannerApp registers the same store retained by SwiftUI. Concurrent initialization callers await one opening task, including its recovery-status read. Intent context acquisition awaits readiness and never invents an empty successful dataset after opening fails. A concurrent-creation test records one successful creation and a second rejected by the native save-busy admission rule. Intent commands now reach the existing serialized Core writer independently of UI save admission, while recovery checks remain enforced. A shared active-save count keeps the native busy state true until every admitted save finishes.

Create Item uses the shared durable Core command. Its value contains the generated identity and submitted Item fields. Complete recovery and applied/incomplete recovery have different dialogs; the latter retains the applied Item instead of throwing an ordinary unapplied error or retrying creation. Unverified outcomes remain explicit and block further mutation. The prototype still uses localOnly storage.

The Item entity exposes title, global Done and Archive independently. Identity resolution reads current sources and omits missing/unresolved identities; other failures throw. Text search and suggestions use Core's canonical all-completion/all-archive query, including notes matching, with generation-bound 64-row reads. The SDK returns an entity array, so this is not a bounded-total-memory or performance claim. Get Item resolves its current source rather than trusting a supplied entity's cached fields.

Global completion uses Core's global Item scope. Completing an Item makes its existing appearances effectively Done without rewriting their local flags. Reopening restores those local differences. Action wording explicitly says the operation applies everywhere; it does not expose backup, export or recovery administration.

## Executed tracer evidence

Creation reaches the explicit missing-implementation failure through the public SDK invocation, then passes real persistence/reopen/recovery qualification. An earlier attempt's nonexistent-directory cleanup obscures that diagnostic and is retained separately. Query preparation first has a wrong Core argument label, corrected before the actual executable unsupported-query failure. The implemented query passes fresh title/state, missing identity, case-insensitive notes search, empty result and suggestions checks. Get Item then reaches its explicit unsupported implementation using an outdated entity.

The initial concurrent runs also contain temporary-fixture cleanup errors. The retained actual outcome attachment independently identifies the save-busy rejection; those failed runs are not credited as passes. The four creation/read/query/completion and concurrent-creation tests pass together after the admission correction. A separate actual post-save recovery-filesystem failure passes: creation returns its applied Item, recovery blocks the next Intent mutation, the original identity remains readable, and explicit native recovery retry preserves it before a subsequent creation succeeds. An already-cancelled invocation initially creates an Item and fails the preflight test. Checking cancellation immediately before command admission corrects that outcome. This covers cancellation before mutation, without claiming that cancellation can roll back a completed save.

The final focused local batch passes nine Intent tests, seven native Undo-controller tests and five actual HTTP capture tests. It includes invalid-title rejection without an Item, missing read rejection, explicit unavailable-bootstrap failure, duplicate requested IDs, canonical query ordering across 65 Items, concurrency, recovery and preflight cancellation. There are no failures. Swift-format strict lint and diff whitespace checks pass. The iOS Simulator app/UI-test build also passes. Apple's extracted metadata contains exactly the three production action identifiers, one Item entity and its query. Native capture/estimate/cancellation/relaunch and untouched-link Save pass on dark iPhone in 82.976 and 22.450 seconds, and light iPad in 87.772 and 22.479 seconds. Four original captures were inspected; the saved Item preserves notes, duration and original link, and the unavailable website preview retains its retry fallback. These are scoped compatibility checks rather than a whole-app appearance audit. Actual system invocation is explicitly skipped in 7.357 seconds for the same observed service-domain error 803, before Planner executes. No system pass is claimed. Actual packets retain each compiler diagnostic and executable failure separately under navigation compatibility evidence.

## Remaining gates

Actual system discovery/invocation, background launch, locked/system-restricted execution, system confirmation, cancellation/termination/retry and full native adapter parity remain open. Protected Agent Control remains under Q100 B. CloudKit/account/shared-container integration and physical-device qualification remain separate work. Signing stays deferred. These local interface tests do not replace the system gates or close the map.
