# Q129: Skip when a new restoration candidate arrives

Status: Q129 A is accepted on 23 October 2026. Skip preserves the current complete owner and family, excludes the unknown incoming candidate, skips dependent owners and imports independent data. Review of the concrete family/provenance contract precedes implementation; existing safeguards remain until it is qualified.

## Context and starting state

Manual Skip retains a complete current owner under A12/A13. A20 separately requires concurrent restorations to converge to a deterministic candidate, with authorized references following that family. Consolidation is already required in principle. The unresolved intersection is whether manual Skip adopts a previously unknown restoration candidate at all.

Use this concrete case, with the same public Item identity throughout:

| Value | Current planner | Incoming backup |
| --- | --- | --- |
| Closed predecessor | A, lifetime ending `811` | The same A |
| Live Item | B, lifetime ending `814`, title `Current museum` | D, lifetime ending `813`, title `Other museum` |
| Restoration family | F, knows B | G, knows D |
| New dependent plan | Absent | New List `Tour`, referencing X/D |
| Independent data | Absent | New Tag `Rainy day` |

Each backup can be valid by itself. D is unknown to the current planner and sorts before B under the accepted stable candidate rule. Adopting D into a consolidated family therefore differs from the completed known-candidate normalization: current data already authorizes both candidates in that completed case. Old predecessor A must still never redirect.

Current code deliberately gates changed known-family candidate sets and unsupported source-lifetime replacements. It does not settle the final mode-specific policy merely by rejecting a request. The [current source decision](native-import-live-overwrite-decision.md) is Q128, which concerns an old closed predecessor rather than this newly delivered candidate.

## Choices and effects

A. Keep the complete current X/B and family under Skip. Do not adopt D/G. Skip the complete new List and its dependents because their D binding is unavailable, while importing the independent Tag. This preserves manual Skip's current-owner promise; adopting the additional restoration requires a separately settled explicit workflow.

B. Consolidate restoration candidates during Skip and select the deterministic winner. In this example D and its represented content win, and the new List follows D. This revises manual Skip: a matching current Item can change even when the user selects Skip. Exact conflict presentation and consolidation/provenance rules would need a concrete contract before implementation.

C. Reject the whole import until the user chooses an explicit replacement/consolidation workflow. Current data remains unchanged, but the independent Tag is not imported either. This provides a simple failure boundary at the expense of useful partial eligibility.

Recommendation: A, preserving the accepted meaning of manual Skip. A20's synchronization/consolidation requirement remains on the map; choosing A would not remove it or decide Q128's Overwrite behavior.

## Definition of ready

- The human chooses the manual Skip result above.
- Review the concrete candidate/family binding and provenance rules before enabling any consolidation. Portable data currently permits arbitrary family UUIDs while native restoration derives an ID from the predecessor. Two families for one predecessor cannot simply coexist in a valid complete graph.
- Continue using the approved public decode/review/execute/export/query/recovery/replay seams with disposable real storage. No new test hook, target or public query interface is proposed here.

## Required proof after the choice

For A, a literal valid B-versus-D fixture must show current X/B and its complete family/reference state retained, D/G excluded, complete dependent-owner skips and the independently imported Tag. Exercise D sorting both before and after B. Preview must remain nonmutating and accurately predict apply. Verify acknowledged recovery, reopen, replay, duplicate-free reimport and stale-review rejection.

For B, first approve the concrete winner/content, family-identity, provenance and reference-remapping contract. Then prove both candidate orders, complete reference/state preservation, independent imports, idempotence, interruption/recovery and convergence. Do not substitute a known-candidate test for newly granted authority.

For C, prove typed rejection before applying any data, including the independent Tag, with useful native review/error presentation. Preserve all current state and replay/recovery truthfulness.

Every choice retains predecessor nonredirect, family-wide deletion, explicit restoration authorization and the separate signing/physical/native-system gates. This question does not reduce the original map.
