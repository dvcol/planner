# Explicit native capture retry

The existing `Planner.updateCapture` Retry action reloads selected native input through its retained private provider handle. It preserves owned edits and unaffected input, rejects obsolete results and cancels native loading when its draft is superseded, cancelled or saved. No provider state is written into saved Items or portable backups. Storage schema remains 18 and portable format remains 2.

## Context and goal

[Native URL/text loading](core-native-capture-loading.md) could prepare ordered capture drafts, but Retry could only reparse bytes that had already arrived. A failed native provider had no retained value and was rejected on Retry.

Before this step, users had to prepare the capture again after a supported native load failed. After it, explicit Retry can recover that input within the same draft and retain the user's title and other edits. No automatic provider retry is introduced. This implements the accepted C12/Q17 lifecycle through the existing [public capture boundary](../adapter-contract.md#capture-preparation-and-apply).

## Definition of ready

Q33 confirms the async public facade and native I/O boundary. C1/C8-C10 require held provider descriptions, stable order and preserved supplied links. C12/Q17 require explicit retry/removal, obsolete-result rejection and the accepted numeric loading limits. C16 defines cancellation before Add and complete reviewed save. Actual registered `NSItemProvider` fixtures and public draft/read/export/apply observations use the already approved test seams.

## Definition of done for this step

- A temporary draft retains private, main-actor native representation handles. Callers cannot forge classification or turn provider prose into owned content. Retry reloads only the selected native lanes through the same four-load/ten-second engine; direct input retains its existing reparse behavior.
- Retry preserves owned edits, unaffected links and link identities, stable display order, and temporary provider classification. Unchanged accepted input reserves decoded bytes and distinct original links. A too-large retried lane gets the blocking issue; it cannot displace a later accepted lane.
- Validate edit fields, input indices, retained link identities, link limits and native label references before superseding pending work. Invalid edits and already-cancelled callers leave an active valid Retry untouched.
- After loading, revalidate the dataset session, draft generation, request identity and complete edited content/native references. A newer edit/removal/retry cannot be replaced by an older result. Caller cancellation rejects without publishing another draft generation.
- Draft Cancel, successful reviewed apply and valid superseding edits cancel the native retry. Late callbacks cannot recreate a cancelled draft or change edited/saved content. Successful Add retains its existing durable receipt and recovery behavior.
- Loading and editing remain temporary. Public backup observations show zero saved domain changes until explicit reviewed Add. Native handles are released with removed inputs or discarded/applied drafts and completed request tracking is cleared.

## Tests and review

Six added native-boundary functions cover 20 invocations: failure followed by successful explicit reload, owned edits and zero writes; cancellation with a late callback; edit/removal/apply/caller-cancellation races; unchanged-lane byte reservation in both source orders; distinct-link reservation; and rejected/cancelled second requests during an active retry.

The first reload regression failed because Core rejected the unavailable native value. The cancellation regression then showed that draft Cancel left native progress running. Review identified unchanged-lane byte displacement and premature cancellation by an invalid edit; controlled red fixtures reproduced both before their fixes. The analogous 128-link displacement was also reproduced before reserving unchanged originals. A final cancellation review checks the already-cancelled caller before superseding work.

## Qualification

Mac and iPhone Simulator each passed 176 affected Core functions in 70 suites, covering 470 invocations. Native HTTP passed 16 functions in four suites, covering 22 invocations. Failures and skips were zero. Five changed Swift files passed strict lint; the Mac navigation app and test host compiled successfully. Both review rechecks found no remaining confirmed findings. Completed commands, results, source hashes and red/green regressions are recorded in execution evidence. Native UI runtime and physical Share execution remain unqualified.

## Remaining map work

Native `MKMapItem` loading and permitted references, bounded Maps lookup and obsolete network callbacks, transport encoding/advertisement, native capture review and Share/Intents/MCP flows remain open. Retaining a provider handle is a temporary retry mechanism, not physical sender or extension lifetime proof. Peak allocation before native callbacks still requires physical-platform measurement.

Genuine database-save/cleanup failure and termination remain [capture apply gates](core-capture-apply.md#remaining-map-work). Import reconciliation/forms, Calendar, scale/paging, filtered drag/group/duration behavior, physical sync/account recovery and final native UI polish remain required.
