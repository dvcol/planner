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
List-specific process interruption needs qualification. The native-save
follow-up below now covers rollback and late redelivery. The publication
follow-up below covers its represented failure cases. Existing
generic checks do not prove all those payload-specific outcomes. Native controls,
HTTP, actual Mac/system, cloud/physical convergence and whole-app acceptance retain
their separate gates. Signing stays deferred.

## Recovery-publication failure

The existing List test now covers standalone and repeated-itinerary contexts
with ordinary publication or an actual post-save publication obstruction.
Complete winning content remains readable while recovery reports one committed
maintenance and blocks new writes. A new Tag command rejects with
`mutationBlocked` and has no reliable applied evidence; recovery files stay
unchanged. Prior recovery bytes and writer control remain intact.

The full graph still differs from the winning baseline only by the one exact
retired membership closure and its truthful original Add provenance. The first
repeated stop stays Todo and the second Done, including while recovery is
pending. Explicit Retry acknowledges the original maintenance; repeated Retry
returns the same checkpoint. Original user receipts remain unchanged. Stale
membership/expanded identities still fail after recovery, and reopen/redelivery
preserve the same complete graph.

The [validation record](evidence/native-membership-consolidation/native-owned-list-publication-validation.json)
reconciles five passing functions and eleven invocations on each of Mac and
iPhone Simulator. All four main List cases execute with affected preparation,
completion-history, provenance and committed-recovery regressions. There are no
failures, skips, timeouts or SQLite-unlink diagnostics. Actual products and 813
Core inputs match; 1159 of 1160 native inputs are unchanged. Only the existing
test file changes. All 90 Core production inputs, 514 frozen fixtures and schema
sources stay unchanged. Strict Swift/Markdown and whitespace checks pass.
Verified cleanup removes 26 closed marked stores; manifests remain losslessly
compressed.

Production code and contracts are unchanged. Actual List-specific native-save
rollback and process interruption remain separate checks. This adds no module,
production hook, target, schema, portable format or writer gate. Native/system/
physical acceptance and Q163 retain their existing gates; signing stays deferred.

## Native-save rollback and late redelivery

The repeated-List fixture now reaches an actual isolated native write failure.
The child sets its file-size limit at the existing `ModelContext.willSave`
boundary and observes SQLite error 778. Both source versions, memberships,
original Add authority, stop bindings, expanded completion, causal history,
previous recovery bytes and writer control remain unchanged. The preparation
stays unverified; retrying it rejects with `maintenanceNotApplied`. A fresh
maintenance gets a different identity and preserves the complete winning graph.

This check found a real follow-up defect. After rollback, successful retry and
reopen, late delivery could make the reused SwiftData container save the old
List lifetime and nullify the stop's native List relationship. The staged graph
had already passed validation, but recovery publication then rejected it and
blocked subsequent consolidation. Targeted probes reproduced that mismatch;
a fresh-container trial removed it. The shared maintenance catch now discards
only the failed container after rollback. Ordinary reads retain container reuse.
No new recovery path, public contract, format, physical model or writer gate is
introduced. Temporary diagnostics are removed.

The first diagnostic failure came from trying to materialize an intermediate
expanded graph in the test observer. Raw binding comparison fixes that observer;
it is distinct from the later reproduced production defect. All original
failure packets remain retained.

The [final validation](evidence/native-membership-consolidation/native-owned-list-save-validation.json)
reconciles 57 passing Mac functions and 52 iPhone Simulator functions in eight
affected suites, plus twelve passing real MCP HTTP functions. Mac app and Share
extension builds pass. Executed products and 813 shared Core inputs match;
514 frozen fixtures and all eighteen schema sources remain unchanged. The Mac
cohort retains four successful native-fault children and ten deliberately killed
children whose parent recovery checks pass. Those interruption results cover
their existing generic and mixed-Itinerary payloads, not List-specific process
death. All final runs have no skips, failures, timeouts or SQLite-unlink warnings.
Manifests and logs remain compressed; failed/interrupted stores stay retained.
Verified cleanup removes 190 phone and 25 HTTP disposable stores after their
hosts exit and database handles close.

List-specific process interruption, Item native-save/interruption and collision
faults remain named local checks. Q163 and native/system/physical acceptance
retain their separate gates. Signing stays deferred.

## Process interruption follow-up

The [Item/List checkpoint](native-restored-owned-reference-history.md#item-and-list-process-interruption)
now stops the repeated-List payload before and after its actual native save.
Fresh maintenance after pre-save termination and original-commit Retry after
post-save termination preserve the complete winning membership, original Add
provenance and independent repeated-branch completion. Final Mac and phone
shared-helper regressions pass. Interrupted datasets remain retained; physical
power loss and cloud/account convergence are separate gates.
