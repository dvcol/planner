# Older-backup live Overwrite contract

Status: concrete review for accepted Q128 A. The policy is settled; this document specifies the transformations and observable results before their tests and implementation. Q129's Skip contract is separate.

## Existing interfaces and scope

Use `decodeImport`, `prepareReview`, `execute`, `exportData`, canonical reads, recovery and receipt replay. The command remains `applyImport(backup:mode:restoreDeletedData:)`. No public type, backup version, persistence schema, target, agent administration action or test boundary is added.

For a represented source with public identity X, incoming lifetime A and current live lifetime B, Overwrite may replace B's values only when the current retained deletion/restoration lineage authorizes A as a closed predecessor of B. Mere public-identity equality, a deletion marker alone, an unrelated live lifetime or an unknown competing candidate does not grant that authority. Preserve the existing gates for unrelated lifetime replacement, candidate consolidation and contradictory provenance.

Keep the decoded input immutable. Review binds the exact original backup, current graph, mode, restoration authorization and dataset. Construct a projected replacement graph rather than editing the decoded backup in place.

## Source and reference transformations

| Record | Reviewed transformation |
| --- | --- |
| Represented source X/A | Write its whole-owner represented values to X/B. Keep B's lifetime and the complete current source-restoration family. Do not create another source lifetime or revive A. |
| Whole-owner values | Apply represented content, global/archive flags, timestamps, content provenance and applicable manual estimate. Use the existing whole-owner field projection for each source kind. |
| Owned membership | Preserve its public reference identity and validate its own lifetime. Bind a selected List owner to its reviewed live lifetime; resolve the Item dependency only through its separately authorized binding. Retain rank and local completion from the represented owner. |
| Owned itinerary entry | Preserve public reference identity and validate its own lifetime. Bind the selected Itinerary owner and Item/List dependency through their reviewed transformations. Retain route rank and local completion. |
| Expanded completion | Rewrite exact entry/membership lifetimes only when the corresponding references are authorized and retained/restored. Preserve the represented contextual flag. Never replace exact context with source identity alone. |
| Owned label association | Validate its own identity/lifetime, transformed selected owner and separately authorized Category/Tag binding. |
| Owned link or Schedule | Bind its owner to B. Preserve original URL, link order/fields or saved schedule form. A closed identity requires separate restoration authorization and a fresh lifetime. |
| Completion aliases and changes | Preserve exact represented context, alias/change identities and observed-change bindings. Transform only the exact authorized contextual lifetimes; reject incompatible retained identity/history instead of silently dropping it. |
| References owned by an omitted current source | Keep every identity, lifetime, position, local flag and history record unchanged. A live content/global-state update can naturally change their displayed content or effective progress. |
| Deletion and source-restoration metadata | Retain current closure records and the complete family for X/B. Old A stays closed. Independently reviewed incoming deletions keep the existing rules. |

This is complete-owner replacement. References currently owned by X/B but absent from the represented owner follow the existing reviewed removal rules. It does not replace reference collections owned by another omitted source. An incoming reference to A is rewritten only within this explicitly selected, authorized replacement graph; an omitted, closed or otherwise unauthorized source does not become a generally valid dependency merely because X/B exists.

A retained live reference with the same public ID but incompatible lifetime/endpoints still rejects the whole action under the existing binding guard. Closed represented reference identities must appear in restoration impact. Without `restoreDeletedData: true`, execute rejects the whole action, including independent additions. Enabling restoration requires a fresh review; it does not bypass other binding/history checks.

## Literal worked graph

The suffixes below denote distinct full UUIDs in the existing disposable fixture. Expectations must be written as literal complete graphs, not computed with the production merge.

| Record | Before Overwrite | Incoming older backup | Expected after authorized apply |
| --- | --- | --- | --- |
| Item X, ID ending `101` | B ending `814`, title `Current museum`, notes `Current notes` | A ending `811`, title `Museum`, notes `Original notes` | Same X/B, title `Museum`, notes `Original notes` |
| Source family F ending `890` | Closed A, current B with its saved candidate operation | Backup made before deletion has no authority to replace F | Complete current F and A closure unchanged |
| Current List `Other`, omitted from backup | Membership M to X/B, rank and local Done already saved | Absent | Same complete List, M and local Done |
| Owned guide L ending `751` | Its original lifetime is closed | Original HTTP URL, label and rank under X/A | No authorization: whole action unapplied. With reviewed restoration: same L ID, fresh link lifetime, owner X/B and represented fields |
| Schedule S ending `701` | Its original lifetime is closed | Original timed/all-day form under X/A | Same authorization requirement; preserve exact represented form and public S ID under a fresh Schedule lifetime |
| Independent new Tag | Absent | `Rainy day` | Added only when the whole action is allowed to apply |

The first tracer uses real Create, Export, Delete, explicit Restore and Edit before importing the old file. A no-owned-reference variant isolates value replacement: it must preserve B without requesting source restoration. Then add the closed guide/Schedule case to establish separate authorization and atomic rejection. Extend through Item, List, Itinerary, Category and Tag owners using the existing complete-graph fixture, including route, labels and local history.

## Observable preview and result

- Report X/B in `replacements`, with B in both before/after summaries, represented changed field names, complete owned association IDs, original property paths and resolved dependencies. It is not a new source `restorations` entry.
- Report separately closed references as `.restore` changes. Preview remains nonmutating and identifies the restoration impact before apply.
- Successful applied summaries report actual saved B and actual fresh restored reference lifetimes. Operation results do not invent a second X or expose a stale A as live.
- Skip keeps its current complete-owner behavior. Equal-value reimport is unchanged/idempotent; it neither duplicates sources/references nor creates another source family.
- Cancellation and stale review change nothing. A validation or precommit failure leaves the complete current graph intact. Existing complete/incomplete recovery and unverified outcomes remain truthful; never relabel an applied-but-incomplete recovery as unapplied.

## Qualification and completion

Use only the already approved public real-storage boundaries. Before implementation, retain the failing real workflow. Prove the literal complete graph, omitted-owner references, each owned association/history form, preserved closure/family metadata, denied and authorized closed-reference restoration, and independently imported data. Verify canonical reads, full export, recovery, reopen, exact receipt replay, repeated import, changed-authorization payload rejection and stale review after an independent save. Preserve all five-source-kind Skip/known-family/incoming-reference regressions. Run affected Swift lint and Mac/iOS compilation; qualify native import preview/application separately.

This contract does not close competing incoming-family consolidation, arbitrary reference/history reconciliation, signed synchronization, physical convergence or whole-app acceptance. Existing safeguards remain for any transformation outside the enumerated authorization.
