# Restored-source target references and membership authority

Status: Q160 A approved on 25 October 2026. Q159 A is accepted. It extends strict Remove authority across the authorized candidates of one proven Item restoration family. Q158's direct-entry rule is implemented. This declaration joins the next independent target-reference cases under one portable and maintenance upgrade. Implementation must follow the user's MVP-first preference, reusing the existing storage/maintenance paths and retaining the bounded exclusions.

## Scope and unchanged ownership

Admit these references to the actual existing winner of a fully proven open restoration family:

| Reference | Binding changed | Preserved data |
| --- | --- | --- |
| Direct Item entry | Item source lifetime and native Item relationship | Q158 entry identity/lifetime, owner, rank, local Done and history |
| Referenced List entry | List source lifetime and native List relationship | Entry identity/lifetime, owner, rank and separate repeated branches |
| Membership in an independent surviving List | Item lifetime and native Item relationship | Original membership identity/lifetime, rank, local Done, original provenance and completion history, subject to existing Q155 consolidation |
| Category/Tag association on an independent surviving Item/Itinerary | Label lifetime and native Category/Tag relationship | Association identity/lifetime, owner binding and owner timestamps |

The owner must be uniquely resolved and survive. Source kind, public source identity and all unchanged scalar/native bindings must agree. Preserve winning content, global/archive state, timestamps, declared families, source closures and unrelated graph exactly. Derived views refresh without rewriting user-edit timestamps.

Do not transfer candidate-owned collections. Losing List memberships, losing Itinerary entries, bookmark ownership, Schedule ownership and label-association ownership remain outside this rule. Do not select an association identity when label rebinding would produce two owner/label pairs with different association identities; reject the complete maintenance projection and retain data for later reconciliation. These exclusions remain required work on the map.

## Portable version 5 and truthful membership history

Declare portable5 with the existing portable4 fields. Retain each provenance record's original List/Item endpoint lifetimes and actual observed removal IDs. Retain membershipRemoval records as deletion IDs. Do not rewrite an old observation, add a removal to an old Add, create a new membership lifetime merely to normalize a target, or add a per-record temporal witness.

Portable5 introduces two distinct Item comparisons:

- Historical sibling comparison requires the same public Item and membership of the same uniquely declared restoration family. It can validate retained records after that family closes. This preserves historical observations across the family's candidates.
- Live binding and removal admission require the actual present winner of the same proven open family. No predecessor traversal, closed-family redirection, unknown candidate or unresolved authority is allowed.

The List endpoint of a membership pair remains exact, including its lifetime. This contract does not extend removal authority across restored List ownership. A family predecessor is not one of its candidates. A later family descended from an old winner therefore does not join the old membership generation.

For a live pair, applicable strict removals include removals attested against its authorized Item siblings in that same open family. An unaware Add is suppressed. New deliberate Add, Move destination creation and original-association restoration record the applicable removals they actually observe, through their existing interfaces. An existing destination membership retains its state. Same-generation aliases, suppressed roots, detached expanded completion and retained partial-history checks must use the same declared authority rule.

Graph version5 applies this authority to existing immutable records too. Native historical JSON records have no old/new interpretation flag, and none is added. Portable1–4 decode and validate under their original exact-pair semantics; a new current combined graph explicitly uses version5. Old canonical bytes and exact original operation replay remain unchanged.

## Canonical memberships and repeated contexts

Resolve target bindings and strict-removal eligibility before applying Q155's existing duplicate-membership rules. Eligible copies of the same logical pair/generation retain the established deterministic membership identity/rank, initial completion combination and explicit-change precedence. Do not combine unrelated generations or invent completion observations. Unknown or conflicting history blocks the whole projection.

List-entry rebinding preserves expanded entry/membership identity keys and their completion flags, aliases, changes and Q156 removal observations. Validate the projected context against the winning List and the final canonical membership graph before native staging. Raw snapshot extraction must not reject an otherwise authorized candidate binding merely because the pre-projection entry List lifetime differs from its surviving membership's List lifetime. Scalar/native endpoint mismatches remain invalid.

Each repeated List entry keeps its independent expanded context. A direct Item entry remains independent from the same Item inside a List. The winner's global Done and archive state determine the resulting effective presentation; a losing source's flags are never copied into local completion.

## Literal outcomes

**Unaware offline Add.** Open family F declares Item X101/814 and X101/815. List L201/821 survives. Removal M targets a membership attested against814/821. An independently delivered membership against815/821 with no observation of M is suppressed after resolution to814. Its retained original provenance and completion history are not rewritten. Museum stays absent from the List.

**Deliberate re-add.** After M is known, a new Add to the same List creates a new local Todo membership against the current winner and records M. The Add is eligible. Old unaware copies do not revive or contribute completion to that new generation.

**Informed sibling.** A membership originally attested against815/821 already records M. Rebinding to814 preserves that exact record and its eligible state. Duplicate eligible memberships use Q155, while another itinerary's direct stop stays independent.

**Later source deletion and restoration.** F later closes. The retained815-to-M814 observation remains historically valid within F. A new family G has predecessor814 and a fresh candidate816. Neither814 nor815 is a candidate of G. Old F removals/observations do not silently become a new816 generation or redirect closed references.

**Repeated List branches.** Two independent itinerary entries target an authorized losing List candidate. They follow the winning List while keeping each entry identity/rank and every valid expanded context. Completing one branch does not complete the other or the standalone List. Candidate-owned memberships on the losing List remain excluded.

**Label target and collision.** One independent Item's Tag association targets an authorized losing Tag. It follows the winner with its original association identity and owner timestamps. If another distinct association already selects that winning logical Tag, normalization rejects the complete action. It neither drops an association nor borrows membership completion-merging rules.

## Imports, replay and declarations

Manual import remains explicit administration. Old valid backups retain their decoded format and fingerprint algorithms. When evaluating or applying them to current data, the proposed current graph uses portable5 and the new authority. An import proposing an unaware membership after an applicable strict Remove must prove admission or use an already accepted explicitly authorized restoration path. Otherwise reject the whole import, as Q155 requires; do not silently drop part of the reviewed payload. Preserve Skip/Overwrite's accepted owner/value behavior.

Use distinct import canonical version5 and payload fingerprint5 for incoming portable5. Preserve every v1–v4 canonical algorithm and dispatch, including the legacy empty replay graph, saved source bindings, membership evidence and expanded-completion evidence. Replaying an original receipt/preparation uses its frozen evidence before resolving current sources or new authority. Existing ordinary operation evidence fields still mean the exact resolved bindings and observations that were saved; no additional operation-evidence encoding is proposed solely for graph comparison.

Declare sourceRestorationConsolidation rule3 with a complete portable5 proposal for aggregate source selection, target rebinding and any required canonical membership work. Newly emitted unreferenced/direct-entry source maintenance also uses rule3/portable5. Ordinary membership-only maintenance declares membershipConsolidation rule3/portable5. Historical member rule1/portable3, member rule2/portable4 and source rules1–2/portable4 keep their original meanings and exact preparation-byte digests. Recovery acknowledgements validate the minimum portable version by maintenance kind/rule; a later v5 checkpoint can carry forward truthful earlier acknowledgements.

Advance the logical writer gate from22 to23. Keep physical model19, its migration plan, native raw history fields and recovery envelope2. No new public command, target, package or test hook is introduced.

## Atomic activation, maintenance and failure

For control22 and older inputs, main derives one nonmutating, complete portable5 projection of source selection, independent target rebinding, membership eligibility/consolidation and expanded contexts. Validate it before publishing a coherent v5 recovery baseline and metadata23, then activate control23 last. Share waits for main activation. An invalid projection preserves native data, control and prior recovery. Baseline publication records no native maintenance commit.

After activation, revalidate the actual source/history/ownership/control state. Durably prepare the exact complete proposed graph before one native transaction that rebinds all admitted scalar/relationship targets, applies required canonical membership/history changes, retires losing sources and records matching rule3 commit evidence. Stage the whole graph before validation and save; do not expose an intermediate rebound-but-unconsolidated state. Preserve original receipts and all unrelated bytes.

A native failure rolls back every binding, retirement and history change. Preparation alone does not authorize Retry. A committed native save followed by recovery publication failure blocks new commands until explicit Retry publishes that coherent committed graph. Retry cannot manufacture a user command or repeat consolidation under another source identity. Cancellation, interruption and redelivery retain the existing truthful outcomes.

## Readiness and completion gates

Before implementation, this concrete declaration and Q159's accepted policy must both be reviewed. Retain one failing unaware-sibling membership tracer through the existing public Core/native-input boundary, then implement vertical slices. Use the existing approved real-store, recovery-filesystem, process, native UI and authenticated HTTP seams. No additional direct test seam is requested.

Qualify the literal cases, all target kinds, complete graph/history preservation, Q155 collisions/generations, Q156 partial histories, repeated branch independence, invalid object/scalar/owner authority, unknown/missing/closed families, label collisions, old-format import admission, unchanged exact replay and stale reads/actions. Include projection/activation failures, genuine gate22 active and cold main/Share rejection after23, interruption/native-save/publication/Retry and independent-reader refresh. Run affected lint/compiler/native/HTTP checks and reconcile actual inputs/products. Retain failed/interrupted data and use verified post-host-exit fixture cleanup.

Installed Share, signed storage, CloudKit/account convergence, actual Mac interaction, physical devices and whole-app acceptance remain separate gates. Signing stays deferred. Candidate-owned collection transfer and unresolved label-identity collisions remain on the map after this bounded rule.
