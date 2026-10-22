# Skip of an unknown restoration candidate

Status: concrete review for accepted Q129 A. Keep the current complete owner and family, skip unavailable dependent owners and import independent data. Synchronization/consolidation remains separately required.

## Existing interfaces and scope

Use the unchanged public `decodeImport`, `prepareReview`, `execute`, `exportData`, query/recovery and receipt interfaces. No new public result, schema, backup version, agent administration command, target or test boundary is proposed.

Both incoming and current graphs must first be valid independently. Skip is not permission to accept malformed input, duplicate identities, cycles, invalid deletion bindings or contradictory known restoration provenance. Preserve whole-file validation and existing collision rejection.

The mode-specific selection must happen before admitting incoming family metadata or resolving new-owner dependencies. It must not let the deterministic winner rule change a matching current owner merely because the backup carries an unknown candidate.

## Literal graphs

Use the same public Item X ending `101` and the same retained predecessor closure in both separately valid files.

| Record | Current planner | Incoming backup | After Skip |
| --- | --- | --- | --- |
| Predecessor A | Lifetime ending `811`, closure ending `892`, operation ending `992` | Exactly the same closure/provenance | Unchanged |
| Live Item X | B ending `814`, title `Current museum` | D ending `813`, title `Other museum` | Complete current X/B unchanged |
| Restoration family | F ending `890`, knows B with operation ending `994` | G ending `893`, knows D with operation ending `996` | Complete current F only; D/G are not admitted |
| New List `Tour` | Absent | ID ending `277`, lifetime ending `827`, membership ending `477` bound to X/D | Whole List and all its owned records skipped |
| New Itinerary `Weekend tour` | Absent | References Tour and has its own bookmarks, labels, schedule and local state | Whole Itinerary and its owned records skipped transitively |
| Independent Tag | Absent | `Rainy day`, with no dependency on excluded data | Imported once with its represented identity and fields |
| Omitted current plans | Existing references to X/B and their local history | Absent | Complete graphs unchanged |

Repeat with D ending `816`, so D sorts after B instead of before it. The same Skip result must hold. This tests admission authority, independent of which candidate would win if it were admitted.

## Family selection and provenance

- A matching current source retains every current field, owned reference/history record, live lifetime and complete current family. Do not merge candidate arrays, choose D, remap B to D or create a second family for A.
- Exclude unknown incoming candidates and associated competing family metadata for that retained owner. New owners whose exact required binding is available only through excluded D are unavailable and skipped as complete owners. Propagate that decision through dependent new containers.
- Preserve existing known-candidate normalization when the current graph already authorizes the incoming binding. A known authorized loser is different from an unknown candidate that would require granting authority.
- Cover a distinct competing family ID and a matching family ID containing additional unknown candidates. Retain exact current family metadata in both cases. Shared known candidate/provenance entries must agree; the same known candidate lifetime with a different operation ID, or conflicting known predecessor data, still rejects the whole action.
- Preserve current one-family-per-predecessor, unique-candidate, closure, cycle and canonical-winner validation. Never temporarily persist the invalid union of F and G.
- The literal fixture deliberately shares exact closure metadata. This contract does not decide admission of additional unrelated incoming closure/history authority or authorize any candidate adoption. Existing gates remain for those cases.
- Eligible independent owners and their self-contained authorized families retain existing import behavior. Excluding G must not drop unrelated accepted data.

## Preview, apply and failure

Report X/B as unchanged or a skipped matching-owner conflict according to its represented value differences, using B and complete current before/after summaries. Report Tour and Weekend tour in `skippedDependents`, with their exact unavailable source dependencies and original property paths. No reference owned by a skipped owner is added/restored/removed. Report Rainy day in `imports`. Preview must predict the final selected graph without mutating either planner or decoded input.

Apply persists only the reviewed selected graph. Source X/B, its family F, omitted current owners and their references stay unchanged. Importing again creates no duplicates and does not gradually admit D/G. Exported data must decode into a valid one-family-per-predecessor graph.

Review binds the immutable input, mode, authorization, dataset and complete current graph. Independent changes require a fresh review. Cancellation, malformed input, contradictory known provenance, stale review and precommit failure apply nothing. Existing applied recovery-incomplete/unverified outcomes remain truthful. Reopen, independent recovery and exact receipt replay must preserve the same selected graph and summary.

## Qualification and completion

Through the existing public real-store seams, retain the failing literal B-versus-D tracer first, then prove both candidate sort directions, both family-ID cases, transitive complete-owner skips, full owned data/history retention and independent import. Assert the literal entire exported graph, canonical route/label/completion reads, nonmutating preview, actual summary, recovery, reopen, replay, duplicate-free reimport and stale review. Preserve the existing contradictory-provenance whole-action rejection with independent data present. Extend relevant cases through the five source kinds and run affected restoration/import/receipt regressions, Swift lint and platform compilation. Qualify native review/application separately.

This contract preserves manual Skip. It neither implements nor defers away the accepted synchronization/consolidation requirement, and it gives ordinary Overwrite no new candidate authority. Q128's deliberate predecessor-value replacement is a separate contract.
