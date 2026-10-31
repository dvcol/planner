# Native association history controller qualification

Status: Q108 A's five app-hosted controller tests pass together. This checkpoint
changes no production code, targets or configuration. The later
[native Mac checkpoint][mac-undo] separately qualifies represented window/text
interactions; broader native UI acceptance remains open.

## Context, goal and starting state

Q108 A approved the [production controller test interface](../native-association-history-test-contract-review.md) on 19 October 2026. Existing phone/iPad journeys proved represented restoration and system text Undo, but did not exercise queued asynchronous history, real recovery failure/retry or independent controller instances directly.

The goal is to qualify those outcomes through `SavedAssociationUndoHistory`, real Foundation UndoManager instances and disposable `SavedPlannerStore(configuration:)` storage. Public Core operations create the fixtures; public exports verify identities, local flags, fresh lifetimes and whole-action rejection. No fabricated capability, private queue/database assertion, injected manager, new target or production test hook is added.

## Readiness and required outcomes

Q104–Q107's current-run lifetime, preservation of newer relationships, per-window history, native Undo and absent association Redo remain the product requirements. Q108 approves the additional test interface in the existing Mac app-hosted `PlannerMCPTests` target. Every scenario uses actual local persistence and the normally issued removal response.

- Two histories/managers sharing the same store restore only their own original membership. Clearing one removes its registrations while preserving the other manager and ordinary editing targets.
- Two native Undo invocations queue separate removals. The controller exposes in-flight state, restores both original identities/order/local Done under fresh lifetimes, and registers no association Redo. Another explicit Undo during restoration does not duplicate work.
- A real file replacing the recovery directory rejects preparation. Both removed memberships remain absent and the public backup is byte-identical. Retry remains available; repairing the directory and explicitly retrying resumes both queued restorations once.
- Ordinary re-add creates a new Todo membership. Old Undo explains its rejection, retains current data byte-for-byte, and does not offer retry for that stale capability.
- Explicit native history Undo preserves an ordinary UndoManager target. Registering the same issued removal twice does not create a second association action.

## Executed observations

The initial compile rejects the test fixture's missing MainActor annotation and asynchronous expressions inside XCTest autoclosures. No test function executes. Correcting those test declarations makes the isolation case pass in 0.154 seconds. Production is unchanged.

The queue, initial single-action recovery retry and stale-membership cases then pass in 0.175, 0.150 and 0.132 seconds. The retry case is subsequently strengthened to queue both removals before the filesystem failure; that full case passes in 0.167 seconds.

The first explicit/deduplication case fails three assertions in 0.334 seconds. The test opens and closes an empty Foundation Undo group around the intentionally ignored duplicate registration. A standalone real Foundation probe reproduces the result: an empty group has a blank action name and consumes one Undo without invoking the earlier edit. Removing that test-created empty group gives a passing whole explicit/deduplication case in 0.121 seconds. This is a corrected test controller, not a demonstrated production defect.

## Final executed results

The final focused `xcodebuild test` invocation runs all five `SavedAssociationUndoHistoryTests` functions in the existing app-hosted target, using the local ad hoc Mac setup. All five pass with zero failures in 0.660 seconds of test execution. The app and affected test target compile successfully. This does not run XCUITest or require a development team.

| Function | Final result | Duration |
| --- | --- | --- |
| Explicit Undo, duplicate registration and ordinary target preservation | Pass | 0.123 s |
| Queued native Undo, fresh lifetimes and no Redo | Pass | 0.154 s |
| Newer membership rejection and unchanged current data | Pass | 0.112 s |
| Actual recovery failure, retained retry and queue resumption | Pass | 0.148 s |
| Separate histories/managers and ordinary target preservation | Pass | 0.124 s |

The observed-results index retains all nine invocation records, including the compile failure and the failed explicit-action test. The source comparison checks the final source against compiled inputs and verifies that all 149 production Swift inputs remain unchanged. The final compiler/run qualifies the added tests; existing Core/HTTP and phone/iPad results retain their recorded source epochs and are not rerun for this test-only change.

The validation packet records affected strict Swift/Markdown lint, whitespace and local-link checks. Its manifest binds the evidence, including the actual Foundation diagnostic and final product/xcresult summaries. The bounded credential scan has no findings. No rendered captures are claimed by these controller tests.

## Definition of done and remaining gates

The approved direct controller outcomes are now exercised with real Foundation, durable storage and filesystem failure. There is no production behavior change to deploy and no new target or test-only production interface.

These controller tests alone do not qualify window isolation, focus or ordinary
text Undo. The subsequent [native Mac checkpoint][mac-undo] supplies those
represented UI observations separately. Other controls, rendered accessibility,
physical CloudKit/account/Share, scale and final whole-app acceptance remain open.

Q109/Q110 and the [Q111 contract](../native-compound-association-undo-contract-review.md)
have separate [Move](native-move-undo.md) and
[grouped-removal](native-owned-association-undo.md) implementation checkpoints.

[mac-undo]: native-association-undo.md#native-mac-keyboard-undo-27-october-2026
