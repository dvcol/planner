# Native recovery inspection

## Context, before and goal

Core can discover local recovery namespaces and issue immutable saved-snapshot or unverified-proposal selections. The native Settings view has no recovery destination. A user cannot inspect the independent copy through the app even while ordinary saved data remains available.

The first end state is a read-only native Recovery Copies destination. It discovers copies through Core, distinguishes saved snapshots from unverified proposals, displays their selected source names and reference counts, and preserves the current dataset. Native export and explicitly reviewed restoration remain subsequent slices of the full recovery workflow.

## Definition of ready

Q33/Q36 and R13/R20 accept native recovery discovery, data-only selections, independent retained copies and explicit restoration. The [portable contract](../portable-data-contract.md#native-import-delete-and-recovery-forms) governs exact identity, ownership and evidence. Reuse the agreed native UI/public Core seam. Local prototype ownership must not be presented as verified iCloud account ownership. Reads must work without a ready active-dataset session; selection never bootstraps an account or applies data.

## Required TDD and definition of done

- Create a real saved Tag through native controls and require the missing Settings recovery destination as the functional red.
- Discover its acknowledged copy through Core, inspect its saved evidence and original Tag identity/name, then verify current content remains unchanged after relaunch.
- Present loading, failure/retry and genuine empty results separately. Keep unavailable or ownership-unverified data explicit; never label a proposal as saved.
- Keep names primary and exact dataset/namespace identities available for manual administration. Do not add agent routes, schema changes or private-store outcome assertions.
- Inspect original phone/tablet captures, lint affected files, compile the Mac app/test host and record exact execution. Keep empty/error/proposal/separate-dataset, export/restore, Mac runtime, account transition and physical sync gates open until separately proved.

## Execution

The tracer first failed at the missing Settings recovery control after creating its real saved Tag. Settings and the startup-failure screen now open a native Recovery Copies form. Its adapters call Core's existing discovery/selection methods without requiring a ready active session. Copy identity and ownership display come from Core metadata; absent owner names use a dataset identifier rather than an invented account name. Saved snapshots and unverified proposals have separate controls and evidence descriptions.

The selected immutable copy displays source names/kinds and reference counts. Exact namespace, dataset, checkpoint and proposal/operation identities remain in expandable administration details. Selecting or closing a copy never executes a domain command. Source rows use kind plus UUID, matching Core identity rather than conflating equal UUIDs from different source kinds.

An initial implementation run reached the selection screen but failed because the test queried a native StaticText as a Button. The captured hierarchy shows the saved evidence and original Tag. Corrected queries use the observed native role. Source review also found a possible lost replacement refresh and stale selection cleanup; request identities now guard publication, errors and loading cleanup. Those corrections are reviewed source behavior, not a claimed runtime race qualification.

The final inspection function passes once on each simulator, with zero failures or skips. It discovers the acknowledged copy, verifies saved evidence and the original Tag identity/name, closes inspection and confirms current content remains unchanged after relaunch. The affected Settings picker-cancellation/relaunch regression also passes once per device against the same frozen products. Original inspection and retained-current-Tag captures were inspected separately on phone and tablet.

Strict lint passes for six affected Swift files and this report. The final Mac app/test-host build passes with zero Mac runtime functions. Core, HTTP, schemas and portable formats are unchanged; no new Core/HTTP test runs are credited. The initial failed runs remain excluded from passing qualification. Both failed bundles also log a later diagnostic simctl lookup error; their recorded XCTest failures are the preceding control assertions.

[Execution evidence](evidence/navigation/native-recovery-inspection/execution.json) records commands, raw summaries/test trees, compressed logs, the failed native query hierarchy, original passing captures and source/product hashes.

## Remaining gates

This qualifies the represented saved-Tag inspection and unchanged-current-data workflow. Proposal selection, unavailable/ownership-invalid copies, actual empty results, separate retained datasets, interrupted/replaced reads, cross-kind equal UUID fixtures, unavailable active-store access, native export/reviewed restoration and known-applied checkpoint retry still need their own native evidence. The startup-failure entry and no-session adapters are implemented but that failure journey is not yet qualified. Full graph, account transition, signed physical sync/Share, Mac runtime, accessibility/adaptive/scale and whole-app polish gates remain open. Q83 Calendar alignment is still pending.
