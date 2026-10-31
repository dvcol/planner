# Remove owned references during Overwrite

## Context and goal

At `30e712a`, native Overwrite applies source fields, retained records and additions, but rejects removal of current owned references. Explicit incoming closures can be reviewed yet cannot execute against live data. This prevents a backup that removes a route stop, List membership, label, bookmark, schedule or expanded completion from replacing that owner's data.

Overwrite must apply the reviewed removal and its dependent contexts together, preserving shared source objects and minimal closure/history data. Skip preserves the complete current owner. Omitted owners stay unchanged except for contexts whose underlying membership or route entry has been removed. A reviewed explicit closure can remove its target without replacing the omitted source owner's content.

## Definition of ready

- Whole-owner import modes, confirmed deletion, minimal markers, closed completion history and all-or-nothing local actions are accepted.
- Additive and retained-record Overwrite already have qualified native proof.
- Use public native persistence, review, execution, export, independent recovery, reopen, replay and reimport boundaries.

## Definition of done and required /tdd

- Reproduce the execution gate for seven removal kinds, with explicit and implicit closure metadata.
- Test each with all owners declared and with unchanged owners omitted; Skip preserves the original graph, while Overwrite removes exactly the selected reference and dependent expanded contexts.
- Preserve Item/List/Itinerary/Category/Tag identities, content, archive/global completion, other owned records and prior markers. Retain aliases and explicit changes for the closed context, including history omitted from the incoming file.
- Generate one minimal closure for an implicit removal, using the import operation identity. Preserve a supplied closure's identity and metadata. Parent membership/entry closures cover their dependent contexts without redundant child markers.
- Persist scalar bookmark closures in the existing marker shape and composite expanded closures in the existing durable lineage store; change no stored model fields.
- Prove explicit closure of a logical Todo context with retained history and no persisted completion flag.
- Verify full export/recovery, reopen, replay, repeat import, faithful empty restoration and rejection of obsolete backups without writes or receipts.
- Verify a later ordinary save retains the new scalar/composite closure and history in independent recovery.
- Requalify affected import, recovery, native deletion and migration suites, HTTP checks, strict lint and native compilation.

## Proof and limits

The initial public tracer reproduces 14 removal rejections. Native deletion must process pending changes before full graph readback; otherwise stale inverse relationships make the graph appear unresolved. The expanded matrix covers 28 removal cases across both modes. A later ordinary-save tracer covers new bookmark/composite markers.

Spec review found an unstored Todo edge: deriving closure only from persisted flags missed valid retained history. The public tracer reproduced it, then passed after deriving composite targets from reviewed logical references and live entry/membership lifetimes. Standards review's multiline conditional finding was corrected. Rechecks found no remaining confirmed defects.

Broader qualification exposed a membership-removal assertion still expecting the older nested marker encoding. An isolated build of committed base `30e712a` reproduces both failures. The assertion now checks the accepted flat marker fields and exact identity/lifetime, while legacy decode fixtures remain unchanged.

The combined iOS run also reproduced SQLite failures after repeated native container creation, while the isolated removal suite passed. Deferring disposable-store deletion and an autorelease-pool experiment did not fix the combined failure; the unsuccessful pool change was reverted. Core now retains one container per facade while its volume/inode identity matches, uses fresh contexts for operations, and invalidates the container when storage disappears or is replaced. The same 90-function iOS run then passes. Public checks also verify another facade's title/global completion edits and same-facade reads after missing/restored storage. These observations qualify local container reuse; they are not a general memory or physical-sync benchmark. New heavy-suite stores are retained until the test process exits and cleaned afterward.

Final qualification passes 108 Core functions in 49 suites on both Mac and iOS Simulator (277 invocations each), plus 16 Mac HTTP functions in four suites (22 invocations). Strict lint passes for all 13 changed Swift files; Mac app/navigation test-host compilation passes. Commands, source hashes, native summaries, failed experiments, final logs and post-process cleanup retain the complete evidence. A separate runtime test of arbitrary backing-file replacement did not run.

Source deletion, restoration families/rebinding, origin/provider persistence, summaries/forms and direct local-save failure proof remain open. Local closure tests do not prove physical deletion convergence, account recovery or Share behavior. [Additive Overwrite](core-native-import-owned-additions.md) retains prior scope evidence.
