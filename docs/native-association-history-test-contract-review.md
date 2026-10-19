# Native association history qualification

Status: Q108 A approved by the human on 19 October 2026. Q106/Q107 product behavior and the existing Core/native UI boundaries remain accepted. Execution evidence follows implementation; approval alone does not qualify the controller.

## Context, goal and starting state

Original-association restoration passes the affected public Core tests and represented phone/iPad journeys. Actual Mac UI testing still times out while enabling automation, before any function starts. Native asynchronous retry, queue handling and independent history instances need direct qualification. A successful build does not establish those outcomes.

The goal is to exercise the production native history controller with real Foundation UndoManager instances and disposable Planner storage through the existing app-hosted test target. This supplements actual native UI journeys; it cannot establish Mac window focus, text-field integration, layout or accessibility.

## Proposed boundary

Use the existing `SavedAssociationUndoHistory` production interface: `record`, `undo`, `clear`, `actionTitle`, `presentsControl` and `isRestoring`. Construct `SavedPlannerStore(configuration:)` with disposable local storage, call its ordinary `open` and removal methods, and retain the actual issued removal result. Use actual Foundation UndoManager registration and invocation.

Observe saved state through public Core reads/exports or ordinary native store reads. Inject filesystem failures only at the real recovery directory boundary. Do not fabricate snapshots, inspect private queue/registry/database state, add production test callbacks or change method signatures. No package, target, schema, backup or agent contract changes are proposed.

## Definition of ready and required checks

Q108 approves this additional native controller test boundary. Q104–Q107 already define current-run history, newer-relationship preservation, truthful outcomes, serial asynchronous restoration, retry and no association Redo.

- Two controller/UndoManager instances share real storage. Undo in one restores only its issued association. Clearing one history removes only its own registered targets.
- Actual UndoManager invocation starts restoration, exposes in-flight state, serializes pending removals and restores original identities/local flags without registering association Redo.
- A real recovery preparation obstruction rejects restoration without changing data. The controller retains Retry Undo. Repairing the directory and retrying restores once through the ordinary operation/recovery path.
- Ordinary non-association UndoManager targets remain registered after explicit mobile Undo or clearing association history. This checks target preservation, not actual text-field focus.
- A newer recreated relationship rejects old Undo, retains current state and exposes the ordinary native failure explanation.

Use bounded asynchronous waits against observable results. Keep real Mac window/text-field journeys and native Simulator presentation tests separate. Record any discovered failure before changing production behavior, then rerun the affected tests and native callers.

## Definition of done

The additional app-hosted tests execute against actual production history, Foundation and durable storage. They preserve independent data and ordinary Undo targets, qualify retry/serial handling and pass affected lint/build checks. Publish exact results and source hashes. Mac UI startup, real window/text-field behavior, signing and physical-device gates remain explicit until their own journeys pass.

The [Q108 execution report](prototypes/native-association-history-controller.md) records the five passing controller functions, their failed diagnostic attempts and exact evidence. Production behavior is unchanged; actual native window/text-field checks remain separate.
