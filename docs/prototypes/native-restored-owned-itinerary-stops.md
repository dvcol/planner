# Stops owned by losing restored Itineraries

## Local Core checkpoint, 26 October 2026

Q161 now retires the exact direct Item stops and referenced-List stops owned by a
proven losing Itinerary. The winner keeps its complete route, identities, order,
local completion, content hashes and progress. Shared Items, Lists and their
memberships survive. Losing stops do not merge with repeated winning appearances.

This removes the remaining blanket owned-relationship rejection. The existing
source-restoration transaction now admits each owned collection through its
specific binding/graph validation. No new public API, test boundary, model,
format, writer gate, maintenance kind or recovery workflow is added.

## Projection and closure

Stop retirement requires the exact native Itinerary owner and valid saved source
and child bindings. Each discarded stop receives an existing itinerary-entry
closure marker for its original public identity/lifetime. Existing markers are
reused after redelivery. No alias redirects that identity to a different stop.

Expanded rows owned by discarded List stops retire before stop/source deletion.
Surviving source-target rebinding excludes those stops. Snapshot completeness
excludes only the exact admitted stop/expanded objects, and the proposal retains
the winner's route. Expanded-row admission is shared by List-membership and
owned-stop retirement.

Private closure identifiers distinguish the new stop kind while preserving the
existing label and membership identifiers. Portable5/model19/rule3/gate23 and
recovery envelope2 remain unchanged; every schema source remains unchanged.

## Verification

The tracer first reproduced the old rejection for empty and populated winners.
It then qualifies losing Item → List → Item routes against an unchanged winner.
The populated winner retains opposite local completion in its repeated/direct
and expanded appearances. Its entire export stays equal to the pre-delivery
graph apart from three exact closure markers. Empty winners stay empty. Shared
sources, member identities, old receipts and all unrelated state remain intact.

Discarded direct/expanded stop reads fail. A stale Complete action rejects without
changing recovery files or completing another appearance. Reopen and redelivery
preserve the exact export and closure identities.

Real recovery-directory obstruction preserves native stops, expanded rows,
recovery bytes and writer control before an ordinary successful retry. Missing
Itinerary, Item or expanded-member bindings reject before writes. Saved Done
history for discarded direct/expanded contexts remains byte-identical even when
the late native flags are Todo; it never contributes to the winning route.

| Boundary | Final result |
| --- | --- |
| Mac Core storage | 40 functions in five suites, no failures or skips |
| iPhone Simulator Core storage | 38 functions in five suites, no failures or skips |
| Migrations | Genuine Schema18 and Schema12 expanded-completion fixtures pass on both platforms |
| Inputs | 813 Mac and 1,160 phone inputs match; all 813 shared inputs and 514 frozen fixture inputs reconcile |
| Models | All 18 versioned schema source files match the preceding checkpoint |
| Products | Both recorded test products per platform match their executed files |
| Static checks | Strict Swift formatting and whitespace checks pass |

Neither final cohort has SQLite unlink diagnostics. Counts describe test
functions, including parameterized functions. The affected suites retain prior
owned-collection, independent target, List branch and generic maintenance
failure/interruption coverage.

Evidence under
[`native-membership-consolidation`](evidence/native-membership-consolidation/)
uses `native-owned-itinerary-stop-*`. The
[validation record](evidence/native-membership-consolidation/native-owned-itinerary-stop-validation.json)
reconciles final inputs/products, migrations, schema sources, frozen fixtures and
lossless manifest compression. The original behavioral red remains retained.
Verified cleanup removed two passing Mac tracer fixtures and 188 passing phone
fixtures after host/database closure checks, preserving failed/interrupted data
and original result bundles.

## Remaining scope

Ordinary proven-family owned collection kinds now have local Core checkpoints.
Mixed simultaneous source families, competing owned-record restoration histories,
individual bookmark/Schedule closure and manual-import restoration histories
still need qualification. Stop-specific native-save/publication/interruption,
native controls, HTTP, actual Mac/system, cloud/physical convergence and whole-app
acceptance remain open. Existing generic checks do not prove every payload-specific
outcome. Signing stays deferred.
