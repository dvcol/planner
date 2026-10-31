# Grouped link and label Undo in Core

Status: Q111's grouped Item/Itinerary association inverse passes 47 affected Core test functions in 17 suites. Native editor registration and its interaction checks follow this checkpoint. Navigation and physical sync acceptance remain open.

## Context, goal and starting state

The [approved contract](../native-compound-association-undo-contract-review.md) requires one atomic Undo for all links and label associations removed by one editor Save. Before this change, the Save applied those removals without issuing an Undo companion. Move and explicit membership/entry removals already use the current-run snapshot interface.

Restore original association identities and owned fields under fresh lifetimes. Keep current notes, surviving bookmark edits, independent additions, shared-label names, completion and bookings. Reject the whole group when newer relationships, reordered original anchors or changed owner/label lifetimes make restoration unsafe.

## Implementation and readiness

Q110 and Q111 approve this behavior, its concrete interface, literal placement rules and existing public operation/read/export, native UI and Q108 controller test boundaries. No new test seam is introduced.

Item and Itinerary Save capture actual removed records inside the coordinated writer and issue one `ownedAssociationGroup` companion after local commit. Removed bookmarks now receive the same minimal closure metadata as removed label associations. Each restored member gets fresh authorized lineage. Companions remain outside backup/receipt encodings and agent access; existing command payload digests remain unchanged.

The existing restoration transaction validates every predecessor and binding before staging the group. Bookmark insertion uses surviving original anchors and the existing checked rank allocator. Current bookmarks retain their relative order and fields. Label-only restoration does not inspect or rewrite bookmark ordering. The plain bookmark snapshot adopts the existing rank interface; no persistent model, schema, package or target changes.

## Executed observations

The initial Item and Itinerary behavior tests fail because the applied Save supplies no companion. Their first passing runs take 0.157 and 0.188 seconds. They preserve later notes/retained-link changes, duplicate URLs, current shared-label names, independent completion and an existing booking. Exact restoration replay leaves the public export byte-identical.

A label-only test exposes an overbroad bookmark-order guard. Limiting the guard and writes to removed association kinds makes the same test pass in 0.133 seconds. Three anchor-placement cases pass together in 0.154 seconds, covering suffix insertion, no surviving anchors and an independently removed anchor.

Six whole-group rejection cases cover incompatible anchor order, a recreated label pair, deleted owner/label and explicitly restored owner/label identities under new lifetimes. Each preserves the complete current export. Current-run expiry, cross-dataset rejection, superseded history and fresh lineage also pass. Ordinary content edits and additions issue no removal history.

Genuine native save faults first expose retained prepared evidence after rolled-back Item and Itinerary edits. Both catch paths now discard only that known failed preparation, matching Move/restoration handling. The same-operation retries then pass for both owner kinds and their inverses. Applied/incomplete recovery remains applied, blocks new mutations and repairs only its checkpoint; replay does not repeat changes.

The first affected regression run finds an old Itinerary assertion expecting only two label closure markers. The approved inverse also requires its two removed bookmark markers. The updated test checks all four and the exact removed bookmark identities. The final affected invocation passes **47 functions in 17 suites**, zero failures, in **2.995 seconds**.

## Evidence and remaining work

The execution index retains fourteen source epochs, including actual behavior failures and the compiler diagnostic. Validation records exact final package inputs, affected strict Swift/Markdown lint, whitespace and local-link checks. The manifest hashes source snapshots and execution evidence.

Native editor response propagation, specific Undo naming, actual editing journeys and agent admission regressions remain the next slice. No Mac UI, physical CloudKit/account/Share, signing, scale or whole-app polish credit is claimed here.
