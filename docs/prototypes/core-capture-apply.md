# Core reviewed capture apply

Core saves a reviewed capture through `PlannerCommand.applyCapture`. Create saves one new Item with every selected List membership; reuse adds only missing exact-original links and memberships to the explicitly chosen Item. Both use one native save, a durable receipt and independent recovery publication. Storage schema remains 18 and portable format remains 2.

## Context and goal

[Preparation](core-capture-preparation.md) and [draft editing](core-capture-draft-edits.md) created no saved data. They could not complete Add, preserve its operation result across reopening or distinguish a committed capture from a cancelled draft.

This step implements the confirmed [capture apply contract](../adapter-contract.md#capture-preparation-and-apply) at the public Core/native storage boundary. Review returns proposed new content or exact missing additions. A completed operation retains its generated identities after the transient draft is discarded; replay returns the stored outcome rather than creating new data.

## Definition of ready

Q33 accepted the facade, C14-C16 define create/reuse and save behavior, and A15/A18/A19 define recovery acknowledgement, mutation blocking and unverified proposals. Tests use the confirmed public Core/native seam and the existing real native-save notification boundary for recovery publication faults. No test-only production dependency or new package was added.

## Definition of done for this step

- Review names current selected Lists, the reused Item and existing selected memberships. Native `captureDetails` describes new content, missing original links and missing destination memberships without fabricating saved identities. Preparing review writes no domain data.
- Create keeps permitted owned fields, shared label references and internal content origins. New saved link identities are distinct from draft identities. An empty destination set saves to Inbox. New memberships start locally Todo.
- Reuse requires an explicitly chosen exact-original candidate. It retains owned content, labels, global completion, archive state, schedules, existing link identities/labels and existing local membership state. Missing links append in draft order after saved links, including imported nonconsecutive ranks. Missing memberships append to saved List order. An already Done/Archived candidate remains Done/Archived.
- Changed draft generation, selected identities, link additions or membership target sets require another review. Deleted/archived destinations cannot silently become another List. A source archive transition or changed matching links invalidates reuse review. Cancellation before apply creates nothing.
- One native save commits the Item, labels, selected memberships and receipt together. Independent publication failure returns an applied/recovery-incomplete outcome and blocks later mutation. Recovery retry publishes that complete action without applying it again.
- Once committed, the current facade reports `notCancellable` with the operation identity. The draft is unavailable for further editing or another Add. After reopening, exact receipt replay works without a live draft or review token. A changed capture command under the same operation identity rejects without changing its prior status.

## Tests and review

Six public-boundary functions cover 18 invocations: create with automatic/explicit title origin, exact reuse and imported order, post-commit cancellation and modified replay, eleven stale/invalid review cases, create/reuse recovery publication faults and retry, and owned fields/labels plus a no-addition reuse. Exported data proves draft review/rejection and empty reuse do not change saved content. Reopening and replay preserve result identities and complete data.

The missing apply and cancellation APIs were established before implementation. A reuse regression first reported the unavailable behavior. An imported-rank regression then showed a new link sorting before the existing one; the fix preserves existing link identities and order. The first publication-fault test queried status while the recovery directory was obstructed; its diagnostic is retained, and the test now restores the obstruction before verifying the established status/retry boundary.

Spec review also found that a caught native save failure retained its prepared proposal and prevented the same operation from retrying. The handler now rolls back and clears only that issued proposal. If cleanup fails, it retains evidence and directs operation-status resolution. This conditional fix was reviewed from the code path; genuine database-save failure and cleanup-failure injection remain unqualified.

## Qualification

Mac and iPhone Simulator each passed 159 affected Core functions in 69 suites, covering 423 invocations. Native HTTP passed 16 functions in four suites, covering 22 invocations. Failures and skips were zero. Seven affected Swift files passed strict lint; the Mac app and navigation test host compiled successfully. Standards and Spec rechecks found no remaining confirmed findings.

Execution evidence records final source hashes, exact narrow commands, completed result summaries and red/green traces. Native capture UI runtime and physical extension execution remain unqualified.

## Remaining map work

This step does not prove a genuine native database-save failure or termination at commit checkpoints. Those remain explicit gates; recovery publication failure is a different tested boundary. A surviving prepared proposal alone remains unverified and requires operation-status/recovery inspection rather than automatic replay.

Core-owned native provider loading/classification, provider references supplied by that loader, Maps lookup and obsolete callbacks, capture transport advertisement/encoding, native Add/Cancel review, Share/Intents/MCP flows and physical sender/extension evidence remain required. Import reconciliation/forms, Calendar, scale/paging, physical sync/account recovery and final native UI polish remain open.
