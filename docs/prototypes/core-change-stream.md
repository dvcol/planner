# Core local change observation

## Approved contract and starting point

Q130 A approves the [public asynchronous stream](../core-change-stream-contract-review.md). The production Planner currently supplies canonical queries/status and refreshes native views only after their own writes. Use the approved real Core/storage/status and existing native fixture boundaries. No extra test injection, agent method, timeout or protocol session is authorized or needed.

Start with another real Planner writing the same configured dataset while a subscribed reader retains its exact source identity. The notification must permit a canonical read of the saved content. Subscription registration precedes initial reads. Use the existing owned-store fixture helper and post-host verifier; do not unlink a live SQLite store.

## Local implementation investigation

The existing `latestHistoryToken` reads one actual SwiftData transaction with a fetch limit of one. `readRecoveryObservation` independently reads the recovery archive and committed receipts, preserving unavailable evidence. `validateSession` checks the issuing session, dataset, ownership and epoch. Existing writers use the same NSFileCoordinator gate. These are available implementation building blocks, not executed stream evidence.

The installed OS-27 SDK also provides Apple's `HistoryObserver`, with an observable `eventCounter`, container binding and optional history tokens. Apple documents remote-history notifications, including changes from app extensions. Prefer this native database observer and qualify it through the accepted independent-writer/process cases before adding custom database-file observation. Its presence and documentation are not runtime proof. Sources: [HistoryObserver](https://developer.apple.com/documentation/swiftdata/historyobserver), [WWDC26 history observation](https://developer.apple.com/videos/play/wwdc2026/274/).

Investigate native filesystem observation only for configured control/recovery I/O not covered by database history. Recovery observation must cover file replacement and recovery-only repair, including a retained namespace file whose content changes without a directory-entry change. Reestablish replaced-file watches and distinguish observation failure from an idle healthy stream. Do not emit changes for SQLite shared-memory reads. The same coordinated validation/status reads remain authoritative.

Retain ordinary Swift stream lifetime rules, independent subscriptions, cancellation cleanup and no synthetic account/cloud observations. Native ownership must release its consumer task and stream references when the store goes away; a retained live stream remains active. The actual lifetime tests must establish cleanup rather than assuming callback ownership is harmless.

## Remaining qualification

After the first failing/passing public behavior, add the approved cross-process writer, separate namespaces, multiple subscriptions/cancellation, stale/foreign bindings, real observation failure/reopen, receipt replay/no-op, recovery failure/repair, registration/read overlap and burst cases one at a time. Integrate canonical native refresh with retained selections and unsaved drafts. Actual account/cloud, installed Share, physical performance and signed gates remain separate. No stream implementation or runtime credit is claimed by this investigation.

## First public-interface cycle

The first approved independent-writer test [fails compilation](evidence/core-change-stream/independent-writer-contract-red/execution.json) because `changes(session:)` does not exist. Add the reviewed declaration and payload types, then use the installed native HistoryObserver to drive coordinated session/history validation. The [first actual behavior](evidence/core-change-stream/independent-writer-native-observer/execution.json) passes: subscribe, perform an initial canonical read, save through a second Planner instance, receive a data invalidation and read the exact saved identity/title/notes. Its 747 package inputs and two executable products reconcile; its owned fixture is disposed of only after host/handle closure. This is one same-process behavior, not cross-process or complete stream acceptance.

The separate-process follow-up first fails in its test helper because a semaphore wait is unavailable in an async function. Replace that blocking wait with Process.terminationHandler and a native asynchronous stream, retaining the child deadline and exact process result. No production stream behavior is changed for this correction. The corrected follow-up executes both top-level tests successfully, including a separately launched child that saves through the public Planner interface. Its 747 package inputs and two products reconcile; both marked stores are disposed of after process/handle closure. This establishes the represented cross-process invalidation, not recovery or native UI refresh.

## Local data checkpoint in progress

Four top-level public Core tests now pass, plus one actual independently launched writer-child invocation. They cover same-process and separate-process writes, an initial canonical read after registration, exact saved content, cancelling one consumer while another receives own-instance writes, and structured rejection of a session issued by a different Planner instance for the same dataset. Actual child identifiers and transcripts are retained. The final represented run has zero failures, skips or SQLite unlink diagnostics; all four owned stores are removed only after host/handle closure.

The production implementation uses Apple's HistoryObserver and native Observation sequence, validates the current session/history under the existing writer gate, and emits unknown affected identities so clients rerun canonical reads. Each subscription has separate cancellation. It adds no agent session, timeout, test parameter, new package or schema change. This is a data-invalidation slice only. Recovery/control-file observation, stale/lost-store delivery, burst/retention qualification, native Store integration and account/cloud acceptance remain unfinished; the stream contract is not complete.
