# Memberships owned by losing restored Lists

## Local Core checkpoint, 26 October 2026

Q161 now retires memberships owned by a proven losing List while keeping the
winning List's complete contents and every shared Item. A discarded membership
does not merge into a winning membership for the same Item. Its original public
identity/lifetime receives an existing membership closure marker, and its original
Add binding remains truthful in membership provenance. This automatic retirement
does not create a strict user Remove barrier or a successful user command receipt.

Independent itinerary stops still follow the winning List. Their identities,
order and surviving child completion remain unchanged. Expanded rows belonging
to discarded memberships retire with those memberships rather than transferring
to a different child appearance. Repeated stops retain independent completion.

## Projection and persistence

The existing source-maintenance plan validates exact native ownership, original
provenance, duplicate identities and expanded scope before admitting retirement.
Its snapshot materializer can exclude those admitted memberships while retaining
the winning List's expanded rows. Ordinary materialization keeps its existing
strict behavior. Completeness excludes only exact admitted expanded objects.

Native expanded rows retire before stop rebinding. Membership closure, original
provenance and losing-source retirement stage in the same existing durable
transaction. Marker/provenance ordering follows the saved snapshot's existing
canonical order. No independent recovery workflow is added.

The Schema18 edit changes only the snapshot method. Stored declarations and
physical model19 remain unchanged. Portable5, writer gate23, maintenance rule3,
recovery envelope2, public APIs and approved test boundaries remain unchanged.

## Late flags and retained history

A second tracer caught overly strict checks in the initial implementation: a
late initial Done flag on a discarded standalone or expanded child blocked
retirement after its saved Reopen. Those discarded flags now make no contribution
to surviving completion. Exact saved causal history remains intact and receives
full-graph validation. Binding checks and surviving-state checks remain strict.

The unchanged counterexample passes after deleting those retiring-state checks.
Both forms retain their exact native completion authority through export and
reopen, with the saved Reopen still represented. No state transfers to the winner.

## Verification

The primary tracer first reproduced the original rejection, then qualifies a
standalone List and two repeated itinerary stops. The winning child's first stop
stays Todo and second stays Done, opposite to the losing child inputs. Apart from
one exact closure and original Add provenance, the complete export stays equal
to the pre-delivery graph. Sources, timestamps, shared Items and old receipts
survive reopen/redelivery. Stale standalone/expanded IDs fail; a stale Complete
action rejects without changing recovery files or targeting the winning child.

Real recovery-directory obstruction preserves native memberships, expanded rows,
entry bindings, recovery bytes and writer control. Restoring access allows the
ordinary retry. Contradictory Add provenance naming another Item or List lifetime
rejects before writes and preserves the original authority bytes.

| Boundary | Final result |
| --- | --- |
| Mac Core storage | 36 functions in five suites, no failures or skips |
| iPhone Simulator Core storage | 34 functions in five suites, no failures or skips |
| Migrations | Genuine Schema18 and Schema12 expanded-completion fixtures pass on both platforms |
| Inputs | 813 Mac and 1,160 phone inputs match; all 813 shared inputs and 514 frozen fixture inputs reconcile |
| Products | Both recorded test products per platform match their executed files |
| Static checks | Strict Swift formatting and whitespace checks pass |

Neither final cohort has SQLite unlink diagnostics. Counts describe test
functions, including parameterized functions. The affected suites also retain
prior source, owned-bookmark/booking/label, independent target and generic
maintenance failure/interruption coverage.

Evidence under
[`native-membership-consolidation`](evidence/native-membership-consolidation/)
uses `native-owned-list-membership-*` and `native-owned-list-stale-flag-*`.
The [validation record](evidence/native-membership-consolidation/native-owned-list-membership-validation.json)
reconciles final source/products, migration execution, unchanged fixtures and the
method-only Schema18 edit. Original failures remain retained. Verified cleanup
removed two passing Mac tracer fixtures and 263 passing phone fixtures after
host/database closure checks, preserving failed/interrupted data and result bundles.

## Remaining scope

Losing Itinerary-owned entries now have a separate
[local checkpoint](native-restored-owned-itinerary-stops.md). Broader owned
restoration/import histories, duplicate or partial owned-context delivery and
List-specific native-save/publication/interruption need qualification. Existing
generic checks do not prove all those payload-specific outcomes. Native controls,
HTTP, actual Mac/system, cloud/physical convergence and whole-app acceptance retain
their separate gates. Signing stays deferred.
