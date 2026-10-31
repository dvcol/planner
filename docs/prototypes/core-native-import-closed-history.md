# Import completion history after its reference is removed

## Context and goal

At `56617e0`, importing explicit history and then removing its membership or direct itinerary entry produces a valid exported backup that cannot be reviewed again. Graph validation accepts the declared closure, but import projection requires a current context owner and fails with `missingReference`. Expanded history can still resolve a parent entry, so it exposes a different attribution path for the same closed-state requirement.

Closed history must remain recoverable data. Review should show its paths against the actual closure target without fabricating a live source owner. Reimport and faithful empty restoration must preserve its identities and values. Matching closed history follows the accepted Skip/Overwrite policy; source content and live contextual state stay unchanged.

## Definition of ready

- Complete data-only backups, minimal deletion markers and explicit completion history are accepted.
- Native removal/recovery, empty restore, additive Skip and retained-record Overwrite have qualified evidence.
- Use actual native persistence and public decode/review/execute/export/recovery/reopen boundaries.
- Removing references during Overwrite remains a following reconciliation requirement; this fix makes their existing closure history usable.

## Definition of done and required /tdd

- Import an independent full graph with each of the three explicit completion-context shapes.
- Remove the corresponding membership or direct itinerary entry using ordinary native commands, retaining its one alias and explicit change.
- Review and freshly reimport the exported closed graph, generating no new source and preserving all exported data.
- Review matching closed-history conflicts with alias/change property paths and no fabricated owner/content summary. Skip preserves current values; Overwrite takes incoming values while retaining their bindings.
- Reused alias/change identities bound to a different closed context reject before Skip's value-preservation filter, leaving export and operation evidence unchanged, including after reopen.
- Restore the original closed backup into an empty dataset. Verify full export, acknowledged recovery and reopen without resurrecting removed references.
- Requalify affected import/closure/deletion review, native recovery/migration, HTTP checks, strict lint and native app/test-host compilation.

## Proof and limits

The first tracer also compared recovery and export JSON bytes despite their different formatting. That assertion was corrected to compare data. The qualified red isolates two real review failures: removed membership and direct-entry history. Expanded history passes that initial review through its still-live parent entry; it is now treated consistently as closed history.

Spec review found a matching-ID collision that Skip could hide before checking the history bindings. A separate admitted public tracer reproduced both alias and change collisions returning applied with incoming history discarded. Binding validation now precedes value selection; the collision tests require rejection without a partial closure import or receipt.

The final candidate passes 57 Core functions in 26 suites on both Mac and iOS Simulator (132 invocations each), and 16 Mac HTTP functions in four suites (22 invocations). Strict Swift lint passes for all seven changed Swift files; the Mac app and navigation test host compile. Standards review has no confirmed findings; spec review rechecked the binding fix without a remaining confirmed defect. Commands, source hashes, result summaries and logs retain the qualified red, collision red and final evidence. This extends the [retained-record Overwrite proof](core-native-import-retained-owned-overwrite.md).

Reference additions/removals during Overwrite, deleted-ID restoration, origin/provider persistence, import summaries, native forms and direct local-save failure proof remain open. Closure metadata and local native tests do not prove physical synchronization's deletion precedence.
