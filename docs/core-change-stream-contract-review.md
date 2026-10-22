# Core change stream contract review

Status: Q130 A accepted on 22 October 2026. The declaration and existing test boundaries are approved; implementation and qualification remain pending.

## Context, before and after

A21 accepts `changes(dataset session)` and Q33 declares four `PlannerChange` payload categories. Production Core has no stream yet. `SavedPlannerStore.changeRevision` refreshes native views after that store receives its own applied result; it does not establish observation of another writer or a recovery-only checkpoint change.

The end state is a cancellable, dataset-bound public invalidation stream. Native clients subscribe before their initial reads, then rerun canonical queries/status when notified. Independent local writes become visible without changing identities, draft contents, completion scope or query-generation rules. An event never means that every device is synchronized.

The [adapter contract](adapter-contract.md#definition-of-ready-and-done) requires review of changed concrete declarations before their tests. This proposal makes the accepted capability executable. It adds no MCP method, administration access, protocol session or timeout.

## Proposed declaration

```swift
public func changes(session: PlannerDatasetSession)
  -> AsyncThrowingStream<PlannerChange, any Error>
```

The actor method returns a stream with registration and initial session validation established. `PlannerChange` has a generated `notificationId: UUID` and one typed payload:

- `dataChanged(affected: [PlannerChangeIdentity]?)`.
- `recoveryStatusChanged(value: PlannerRecoveryObservation)`.
- `accountStatusChanged(value: PlannerAccountObservation)`.
- `cloudActivityChanged(value: PlannerCloudObservation)`.

`PlannerChangeIdentity` wraps an existing source reference or existing reference-read value. Reuse the declared native status types. `nil` affected identities means unknown records, requiring relevant canonical reads rather than invented identities. The return type introduces no observer, notification-center, clock or polling argument.

## Delivery, failure and lifetime

1. The stream supplies future invalidations, not an initial data/status snapshot or an operation log. Subscribe first, then perform canonical initial reads. Changes occurring after registration must remain observable across those reads.
2. Repeated invalidations may coalesce. No exact event count, one-event-per-command mapping, or delivery deadline is promised. Coalescing cannot discard a data invalidation because a status event arrived. Unknown affected identities are valid. A replay/read alone must not be presented as a new domain change; a real receipt/history change may still invalidate reads without implying changed Item content.
3. Validate the issuing instance, dataset, ownership and epoch before registration and before publishing observed values. An invalid/stale binding finishes by throwing the existing structured `PlannerFailure`. Observation failure must be distinguishable from an empty, healthy stream. Never silently switch a subscription to another dataset or account.
4. Use ordinary Swift asynchronous-stream lifetime rules. Cancellation while awaiting the next element terminates that subscription; breaking a loop alone does not terminate a stream whose references remain retained. Native teardown cancels its consumer task and releases its stream/iterator references. Observation-resource cleanup is asynchronous, not guaranteed complete before iteration returns. Separate `changes` calls are independent subscriptions; copies/iterators of one stream share its lifetime. There is no time-based or idle expiry. Observation must not retain a discarded native store/app indefinitely; an intentionally retained live stream remains an active subscription.
5. Observe the actual configured store and independent recovery I/O. `ModelContext.didSave` alone cannot establish cross-process delivery, and database-only observation misses recovery publication without a model save. Choose and prove the implementation at those real I/O boundaries. Unrelated stores/recovery namespaces cannot publish into this dataset.
6. Existing applied/complete, applied/incomplete and rejected command outcomes remain authoritative. Notifications do not acknowledge saves, repeat commands, mint review authority or replace operation-status checks.

The first implementation qualifies local data and recovery observation. Account/cloud payloads retain their declared form, but remain unknown unless actual matching observations establish another value. Their signed/physical integration gates remain open. Do not emit guessed account changes or cloud freshness to make the stream appear complete.

## Native integration

Let `SavedPlannerStore` own one subscription for its ready Core/session. Route data invalidations through the existing canonical refresh path and recovery changes through the native status projection. Preserve request cancellation/generation checks, selected source/appearance identities and unsaved editor drafts. A failed subscription exposes a useful failure and requires a fresh validated opening; it must not leave a false all-current indication.

No exact native refresh call count is part of the interface. Qualify visible current data and truthful status instead of private observer or callback counts.

## Definition of ready

- Q130 A accepts this declaration, future-only/coalescing behavior and failure/cancellation contract.
- Existing public Core operation/read/status seams and real temporary storage remain the test boundaries. No test-only production injection is proposed.
- Existing writer/history and recovery-fault fixtures supply independent expected outcomes. The native UI uses its existing explicit-configuration fixture boundary.
- Keep account/cloud integration and Q100 signed Agent Control separate from this local slice.

## Required tests and definition of done

Use real configured stores, public stream iteration and canonical reads. Start with one failing independent-writer invalidation behavior, implement the minimum, then extend one behavior at a time under `/tdd`.

- Subscribe, write through another real `Planner`, observe an invalidation and read the exact saved content. Include writes from another process so same-process notifications cannot falsely qualify cross-process delivery.
- Qualify another dataset's writes, multiple subscribers, cancellation of one subscriber, stale/foreign bindings, observer failure and re-opening. Use public outcomes rather than private subscription collections or injected notifications.
- Exercise own writes, reviewed bulk changes, receipt replay/no-op cases, independent recovery failure and recovery-only repair. Verify saved data/checkpoints and unchanged unrelated contexts. Do not impose a synthetic notification count or time-only freshness claim.
- Cover registration/read overlap and burst changes. A consumer must eventually obtain the final canonical data without a dropped invalidation or fabricated query generation. Record actual retention/performance limits rather than promising bounded total memory.
- Through existing native UI fixtures, prove an independent writer refreshes rows/details and recovery status while a valid selection and an edited draft survive. Mobile qualification can proceed independently of the unresolved Mac UI runner.
- Compile affected platform targets, strictly lint changed Swift/docs, and retain exact command/result/source evidence. Physical account/cloud observation, installed Share and actual system invocation retain separate acceptance gates.

No tests or implementation are credited by publication of this proposal.

## Standard-library lifetime evidence

Swift's [stream implementation](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/AsyncThrowingStream.swift) shares storage between a stream and its iterators. Its [buffer cancellation handler](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/AsyncStreamBuffer.swift) handles cancellation during `next()`. The installed Apple Swift 6.4 interface exposes continuation termination, but no consumer-side `cancel()` method. This proposal follows those native rules and does not promise that plain `break` or cancellation of an unrelated task synchronously frees retained stream resources.
