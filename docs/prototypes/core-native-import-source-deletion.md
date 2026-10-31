# Delete sources during Overwrite

## Context and goal

At `a137c3b`, Overwrite can reconcile removed owned references, but rejects incoming deletion markers for current Items, Lists, Itineraries, Categories and Tags. The review describes the deletion's impact without being able to apply it.

Overwrite must apply that reviewed source deletion and its dependent references in one local action. Deleting a container preserves its shared sources. Skip keeps the current graph. Neither mode restores deleted content merely because an older backup contains it.

## Definition of ready

- Confirmed source deletion, minimal deletion metadata, whole-owner import modes and independent recovery are accepted.
- Owned-reference removal and closed completion history already have public native proof.
- Reuse the existing deletion impact resolver, portable closure records and persistence transaction.

## Definition of done and required /tdd

- Reproduce the public execution rejection for each of the five source kinds.
- Verify each with surviving owners declared and omitted. Skip preserves the graph; Overwrite removes exactly the source, dependent references and expanded contexts described by native Delete review.
- Preserve surviving identities, content, archive/global completion, owned data and closed completion history, including history omitted from the incoming file.
- Preserve supplied minimal marker identity and metadata. Report deleted source identities and removed references in the applied result.
- Compare full native export with independent recovery; verify reopen, original-operation replay, repeated import and faithful restore into an empty planner.
- Reject an obsolete backup without resurrecting the source, writing a receipt or changing the graph.
- Apply an independent new Tag alongside a deletion. Reject the entire mixed import when a new membership depends on the deleted Item or a marker identity conflicts with retained history.
- Requalify affected import, recovery, native deletion and migration tests on Mac and iOS Simulator, native HTTP checks, strict Swift lint and native compilation.

## Proof and limits

The initial tracer reproduces all ten Overwrite gate rejections. The final source-deletion matrix covers five kinds with surviving owners declared or omitted, each in Skip and Overwrite. Expected surviving graphs are independently specified. The three mixed cases cover a valid addition plus deletion, a deleted dependency and conflicting marker identity. Successful mixed import also passes recovery, reopen, replay and repeated import checks.

Spec review found no confirmed defect. Standards review found a misleading helper name; it now describes removal of unretained records, including sources. Compilation checks also caught an incorrect decoding-result case and recursive test-macro use; both were corrected before runtime qualification.

Final qualification passes 110 Core functions in 50 suites on both Mac and iOS Simulator, with 290 invocations on each. Native HTTP passes 16 functions in four suites, with 22 invocations. Strict lint passes for four changed Swift files, and the Mac app/navigation test-host build passes. Commands, source hashes, native summaries, logs and post-process fixture cleanup retain the evidence.

Restoration families/rebinding, origin/provider persistence, complete import summaries/forms and direct local-save failure proof remain open. These local tests do not prove physical deletion convergence, account transitions or Share behavior. No new native UI runtime is claimed.
