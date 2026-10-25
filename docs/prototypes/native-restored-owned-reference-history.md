# Discarded bookmark and booking history

## Local Core checkpoint, 26 October 2026

This follow-up completes ordinary owned-identity closure for the Q161
[bookmark](native-restored-owned-links.md) and
[booking](native-restored-owned-bookings.md) slices. Winning Item and Itinerary
contents stay intact. Maintenance records the discarded bookmark or Schedule's
exact identity and lifetime in existing deletion history, in the same durable
transaction that retires its native row and losing owner. Repeated delivery
reuses that closure.

The failing real-store tracer showed that an older, independently valid backup
could otherwise restore the discarded reference without authorization. Four
retained acknowledged checkpoints prove that the original bookmark871/872 or
Schedule873/874 became live on winning owner814 for both Item and Itinerary.
The [diagnosis](evidence/native-membership-consolidation/native-owned-reference-import-red/unauthorized-import-diagnosis.json)
records their exact bindings and retained checkpoint hashes.

The correction uses existing deletion targets, restoration families and import
authorization. It adds no public interface, model, format, rule version, writer
gate, package or test boundary. Portable5/model19/rule3/gate23 and recovery
envelope2 remain unchanged.

## Qualified behavior

- A reviewed Overwrite without restoration authorization rejects and changes
  neither saved data nor recovery files. Its operation has no reliable applied
  evidence, and review identifies the exact reference requiring restoration.
- A separately reviewed authorized import retains the public bookmark/Schedule
  identity, creates a fresh local lifetime and binds it to winning owner814.
  Incoming owner815 and its candidate operation are not adopted.
- The full graph comparison permits only represented source values, the restored
  reference and its new restoration family. Existing closures, families and
  independent data remain unchanged. The acknowledged payload matches export.
- Reopen and exact command replay retain the saved result and checkpoint.
  Reimporting the old closed reference still needs restoration authorization;
  authorized reimport retains the current restored lifetime and graph.
- Existing winner-content, stale-ID, redelivery and real unwritable-recovery
  tests now assert each exact new closure as the only permitted graph delta.
  Preparation failure leaves native and recovery data unchanged until Retry.

## Verification and limits

| Boundary | Final result |
| --- | --- |
| Mac Core storage | 45 functions in eight affected suites, no failures or skips |
| iPhone Simulator Core storage | 43 functions in eight affected suites, no failures or skips |
| Inputs | 813 Mac and 1,160 phone inputs match the workspace; all 813 shared inputs match |
| Products | Both recorded test products per platform match their executed files |
| Compatibility | 514 frozen fixture inputs and all 18 schema sources unchanged |
| Static checks | Strict Swift formatting, Markdown and whitespace checks pass |

Both platforms execute the genuine Schema18 and Schema12 migration functions.
Neither final cohort has SQLite unlink warnings. Counts describe test functions,
including parameterized functions, rather than individual assertions.

Packets under
[`native-membership-consolidation`](evidence/native-membership-consolidation/)
use the `native-owned-reference-*` prefix. The
[validation record](evidence/native-membership-consolidation/native-owned-reference-import-validation.json)
reconciles inputs, products and lossless manifest compression. Intermediate test
compile/assertion diagnostics remain retained and are not production-failure
evidence. The initial unauthorized-import tracer supplies the behavioral failure.

Verified cleanup removed eight passing Mac tracer fixtures and 137 passing phone
fixtures after their hosts and database handles closed. Failed and interrupted
datasets, original result bundles and the full Mac interruption cohort remain.

Mixed source families, pre-existing owned restoration families, broader
association/history reconciliation and reference-specific save/publication
interruptions remain open. This checkpoint adds no HTTP or native UI evidence.
Actual Mac/system, CloudKit/account, physical-device and whole-app acceptance
remain separate gates. Signing stays deferred.

## Combined Itinerary contents

A further real-store tracer puts a Guide B bookmark, a timed booking, Category
and Tag selections, two direct stops and one expanded List branch on the same
losing Itinerary. The winner already has Guide A, its own booking and labels,
and a two-stop route referencing shared Item/List data. One maintenance receipt
and its retained proposal establish that all losing contents retire together.
The only seven graph additions are the exact owned-reference closures. Every
winning value, timestamp, association, route, shared source and existing history
matches the graph captured before competing delivery. Reopen and full redelivery
retain that result.

The Mac tracer and all 23 functions in the affected iPhone maintenance suite
pass. The [combined validation record](evidence/native-membership-consolidation/native-owned-mixed-itinerary-validation.json)
reconciles 813 Mac and 1,160 phone inputs, both test products per platform and
zero SQLite unlink diagnostics. All 90 Core production inputs and 514 frozen
fixture inputs match the preceding checkpoint. This adds tests and evidence
only. Verified cleanup removed one passing Mac and 61 passing phone datasets.

This qualifies mixed collection kinds on one declared source family. It does
not establish reconciliation across several simultaneous source families or
pre-existing owned restoration families, and adds no native UI or HTTP credit.

## Related Item and List restoration families

A new real-store case declares independent open families for Museum and Tokyo
Food. Their winning versions retain an Item membership and the route Museum →
Tokyo Food → Museum, with distinct direct and expanded completion. The losing
Item owns Guide B. The losing List owns a different membership referencing that
losing Item, plus an expanded completion in the independent route.

Both native delivery orders converge through one existing maintenance receipt.
The original three appearances retain their order and two finished states. The
only graph additions are exact closures for discarded membership403/843 and
bookmark871/872, plus membership403's truthful original List815/Item815 Add
provenance. All winning values, identities, existing history and user receipts
match the pre-delivery graph. The retained proposal equals export. Reopen and
repeat delivery in the opposite order retain the complete graph exactly.

The private fixture can now seed the second List family. Its unchanged defaults
and affected callers pass 47 Mac and 45 iPhone functions in eight suites,
including genuine Schema18 and Schema12 migration. The
[validation record](evidence/native-membership-consolidation/native-related-source-families-validation.json)
reconciles 813 Mac and 1,160 phone inputs and both test products per platform.
All 90 Core production inputs, 514 frozen fixtures and 18 schema sources remain
unchanged. Neither final cohort has SQLite unlink diagnostics. The first tracer
used an incomplete literal expected provenance record; its missing source-kind
fields were corrected. That failed assertion is retained as a test diagnostic,
not a production failure.

Verified cleanup removed two passing Mac tracer stores and 140 passing phone
stores after host/database closure. Failed and interrupted data remain retained.
This adds no production rule, format, module or test boundary. Other source-family
combinations, pre-existing owned restoration-family histories and native/system
acceptance retain their separate gates.

## Closed owned families and late delivery

The next real-store tracer retains an owned bookmark/Schedule restoration family
before retiring its losing Item or Itinerary owner. Maintenance closes that
exact family while preserving its predecessor, both declared candidates and the
winning source's complete contents. Reopen and ordinary redelivery retain the
same graph. Reviewed import requires restoration authorization and creates a
fresh owned lifetime while preserving the old closed family. The original
no-history import cases remain in the parameterized test.

A declared sibling delivered later on the surviving owner exposed a failure:
reads rejected its already-closed lifetime instead of retiring the native copy.
Existing source-restoration maintenance now admits exact closed owned identities
and candidates of explicitly closed families even when no losing owner remains.
It reuses the retained closure and records its normal durable maintenance
transaction. Public identities alone never select a different live lifetime.

A further tracer keeps a fresh authorized restoration live while that closed
sibling arrives. Schedules passed, but duplicate bookmark-ID validation ran before
projection and blocked Item/Itinerary reads. The production projection now omits
only admitted retiring bookmarks before that guard. Remaining live bookmarks
retain their ordinary identity, ownership and duplicate validation.

The same tracer obstructs the actual recovery directory. Native rows, recovery
files and writer control remain unchanged while preparation fails. Retry removes
only the closed sibling. The exact fresh bookmark/Schedule fields and native
records match their pre-delivery values, the exported graph stays identical, and
existing user receipts remain untouched. Reopen, exact replay and authorized
reimport also retain the fresh lifetime.

| Boundary | Final result |
| --- | --- |
| Mac Core storage/import/recovery | 48 functions in eight affected suites pass |
| iPhone Core storage/import/recovery | 46 functions in eight affected suites pass |
| Existing real HTTP regressions | 12 functions pass |
| Mac compilation | App, Share and test host build; seven relevant build files reconcile |
| Inputs and compatibility | 813 shared Core inputs and 1,160 phone/HTTP inputs match; 514 frozen fixture inputs unchanged |

There are no failures, skips or SQLite unlink warnings in the final cohorts.
The [validation record](evidence/native-membership-consolidation/native-owned-family-history-validation.json)
separates detailed Core/native-storage scenarios from the existing HTTP routing
regressions. Unrelated fixture products in the raw compiler inventory receive no
credit. Both genuine Schema18 and Schema12 migration functions execute on both
Core runtimes. Schema18 changes only Item/Itinerary snapshot methods; stored
model declarations and all other schema sources remain unchanged. Portable5,
model19, rule3, writer gate23 and recovery envelope2 remain in place. No public
request/result, package, target or test boundary is added. Strict Swift/Markdown
lint and whitespace checks pass.

Verified cleanup removes 24 passing Mac tracer stores, 148 passing phone stores
and 25 passing HTTP/Intent stores after host/database closure. Failed and
interrupted datasets and original result bundles remain retained. Source
manifests are losslessly compressed.

Further association/history combinations, actual Mac window interaction,
installed Share, signed/shared storage, CloudKit/account and physical acceptance
remain separate. Signing stays deferred. These data/HTTP checks add no native UI
or system Shortcuts evidence.

## Closed source families

A20 requires Delete to close the entire declared source family, including late
candidates. A real-store tracer exposed reads/export failing when a known old
candidate arrived after deletion, both with no live source and with a fresh
authorized restoration. All five source kinds reproduced the failure.

The source projection now uses the existing exact closure lookup before choosing
open-family winners. It retires proven closed native rows through the same
durable maintenance transaction. A fresh source lifetime remains untouched.
Unknown lifetimes and references across closed families gain no new authority.

The ten cases retain exact native lifetime arrays, full exported graphs and
original user receipts. Blocking the actual recovery directory leaves native
rows, files and writer control unchanged. Restoring access and reading the
source retries maintenance. Reopen, old Delete replay and repeat delivery retain
the deleted state or the same fresh restoration as appropriate.

Final affected cohorts pass 49 Mac and 47 iPhone functions in eight suites,
including genuine Schema18 and Schema12 migrations. Four existing real HTTP
regressions pass, and the Mac app, Share and test host compile. The
[validation record](evidence/native-membership-consolidation/native-closed-source-family-validation.json)
reconciles the 813 shared Core inputs, 1,160 phone/HTTP inputs and actual products.
All 514 frozen fixture inputs and 18 schema sources match the preceding commit.
No final cohort has failures, skips or SQLite unlink warnings. Existing formats,
maintenance rule and writer gate stay unchanged.

Verified cleanup removes 20 passing Mac tracer stores, 158 passing phone stores
and 17 passing HTTP stores after host/database closure. Failed/interrupted
datasets and original results remain retained; duplicate manifests are
losslessly compressed. The [remaining local checklist](../restoration-acceptance-checklist.md)
names association and authority checks separately. These results add no native
UI, system invocation, cloud or physical-device evidence.

## Unknown source lifetimes after deletion

The opposite boundary exposed a real read/export mismatch. An undeclared
Museum816 arriving after its declared family closed was rejected by export,
but an ordinary source read returned it. All five source kinds reproduced this.
The single-record source-selection shortcut treated an unknown lifetime as
ordinary data when it found no matching open family.

That shortcut now rejects a new lifetime of a known closed public identity
unless its restoration family authorizes it. It uses the same closed-identity
set as maintenance. No row is retired or changed. Reads/export reject, reopen
cannot authorize the record, and exact native lifetime arrays, recovery files
and writer control stay unchanged. No format, model, gate or public interface
changes. The first diagnostic's extra expectation of immediate bootstrap failure
was corrected before retaining the exact failing source-read responses.

The [validation record](evidence/native-membership-consolidation/native-closed-source-unknown-validation.json)
reconciles 50 passing Mac functions, 48 passing iPhone functions and four
existing real HTTP regressions. Both Core runtimes execute genuine Schema18/12
migrations in the eight affected suites. All 813 shared Core inputs and 1,160
phone/HTTP inputs match their products. The 514 frozen fixtures and 18 schema
sources remain unchanged. Mac app/Share/test-host compilation and strict
Swift/Markdown lint pass; final cohorts have no failures, skips or SQLite unlink
warnings. Passing fixture cleanup retains failed and interrupted diagnostics.
Native UI, system, cloud and physical acceptance remain separate.

## Closed membership family after Undo

The existing open membership-family test now follows the relationship through
Remove and Undo. Undo retains its public identity under a fresh lifetime. A late
old-family sibling then arrives with a different rank/local flag and expanded
completion copies in both repeated List stops. The current membership and route
retain their exact full export. One branch stays Done and the other stays Todo.
Old Remove replay and reopen retain the same restored graph.

This passes with unchanged production code. Three focused functions on both Mac
and iPhone also cover the existing legacy-closure and restored expanded-context
cases, including preparation failure. The
[validation record](evidence/native-membership-consolidation/native-closed-membership-family-validation.json)
reconciles 813 shared Core inputs and 1,160 phone inputs with actual products.
All 90 production inputs and 514 frozen fixtures match the preceding checkpoint.
Strict Swift/Markdown lint passes. The first attempt had a test-only compiler
error accessing the Undo snapshot on the applied value instead of the operation
result; no test executed in that attempt. Final runs have no failures, skips or
SQLite unlink warnings. There is no new HTTP, native UI or signing credit.

## Closed Itinerary stop families

A real-store tracer creates two repeated Item or List stops and completes only
the first. Ordinary Remove/Undo creates its restoration family; removing it
again closes that family. A late closed copy blocked the route read, and a fresh
second Undo also exposed duplicate-entry validation. All four deleted/restored
and direct/List combinations reproduced the failure.

Existing stop retirement now accepts proven closed identities even while their
Itinerary survives. The same projection filters them before duplicate validation,
and the existing transaction retires their exact expanded rows. Already retained
family closures authorize this cleanup; no extra closure is invented. Recovery
preparation failure leaves native stops, expanded rows, files and writer control
unchanged. Restored access permits ordinary query retry. Complete exports, exact
old Remove replay and reopen retain the current route, including independent
completion and a fresh Undo lifetime where present.

Two additional unknown-lifetime cases exposed a read/export mismatch. Source
reads accepted the undeclared stop while export rejected it. The same stop
admission loop now rejects an unknown replacement of a closed identity unless a
declared restoration family authorizes it. Native records and recovery remain
untouched. The private native-entry observation sorts equal public IDs by
lifetime so its before/after comparison has a stable order.

The [validation record](evidence/native-membership-consolidation/native-closed-entry-family-validation.json)
reconciles 51 passing Mac functions, 49 passing iPhone functions and four existing
real HTTP regressions. Both Core runtimes execute genuine Schema18/12 migrations
in eight affected suites. The six stop cases execute on both. All 813 shared
Core inputs and 1,160 phone/HTTP inputs match actual products, with 514 frozen
fixtures and all 18 schema sources unchanged. Mac app/Share/test-host compilation,
strict Swift/Markdown lint and whitespace checks pass. No final cohort has
failures, skips or SQLite unlink warnings. Formats, model, writer gate and
maintenance rule stay unchanged. There is no native UI, system or physical
acceptance credit.

## Closed label-selection families

Twelve real-store cases use ordinary Item/Itinerary edits and association Undo
to create and close a Category/Tag selection family. A late known copy blocked
fresh selections or made a deleted selection readable again. An unknown
lifetime was readable while export rejected it. Both owner kinds and label
kinds reproduced the failures.

The existing owned-label retirement now also admits proven closed selections
on surviving owners. It rejects an undeclared replacement of a closed selection
without mutation. Known family closure is reused without adding another marker.
Fresh selections additionally needed exact retirement filtering before duplicate
association validation, through the existing Item/Itinerary snapshot methods.
All remaining labels retain their ordinary identity, ownership and uniqueness
validation. No stored model declaration, format, writer gate or maintenance rule
changes.

Real recovery preparation obstruction preserves native selections, files and
writer control. Ordinary source-read retry retires only the closed copies. Full
exports preserve current selections, owner fields/timestamps and shared labels;
old edit replay and reopen retain the same graph. Unknown copies remain stored
and unavailable.

The [validation record](evidence/native-membership-consolidation/native-closed-label-family-validation.json)
reconciles 52 passing Mac functions, 50 passing iPhone functions and four existing
real HTTP regressions, plus Mac app/Share/test-host compilation. The twelve label
cases and genuine Schema18/12 migrations execute on both Core runtimes. All 813
shared Core inputs and 1,160 phone/HTTP inputs match actual products. All 514
frozen fixtures and 17 other schema sources remain unchanged. The retained
[Schema18 diff](evidence/native-membership-consolidation/native-closed-label-family-schema18.diff)
changes only snapshot method signatures/bodies. Strict Swift/Markdown lint and
whitespace checks pass; final cohorts have no failures, skips or SQLite unlink
warnings. Native UI, system, cloud and physical acceptance remain separate.

## Mixed Itinerary publication failure

The existing mixed-owned Itinerary test now covers ordinary retirement and a
real post-save recovery-publication obstruction. Its winning source keeps its
notes, guide, booking, Category/Tag selections and ordered direct/List stops.
The losing source contributes seven exact closures, including its repeated-stop
state. Shared sources and every other graph field retain the original values.

An actual `ModelContext.didSave` notification makes the recovery namespace
unwritable after the domain transaction. Export still returns the complete
canonical graph. Public status identifies one committed maintenance awaiting
recovery and blocks changes; an attempted Tag creation rejects with
`mutationBlocked` and has no reliable applied evidence. Original recovery bytes,
writer control and user receipts stay unchanged. Repeated reads cannot publish
or alter that recovery state.

Explicit Retry acknowledges the existing committed maintenance. Repeated Retry
returns its original checkpoint. The saved proposal equals the complete export;
reopen and late redelivery preserve that same graph without merging contents.
No production change is needed.

The [validation record](evidence/native-membership-consolidation/native-owned-itinerary-publication-validation.json)
reconciles three passing functions and five invocations on both Mac and iPhone
Simulator. The mixed cases run with existing preparation-failure and committed
source-recovery regressions. Actual products and all 813 Core inputs match;
1159 of 1160 native inputs are unchanged. Only the existing test file changes.
All 90 Core production inputs, 514 frozen fixtures and schema sources remain
unchanged. Strict Swift/Markdown lint and whitespace checks pass, with no skips,
failures, timeouts or SQLite-unlink diagnostics in the final cohorts.

The first build lacked `try` in a new assertion and executed no tests. The first
runtime expected export to fail, but its actual complete export follows the
accepted readable-data policy. Correcting that test expectation leaves
production unchanged. Both original failures and inputs remain retained.
Verified cleanup removes twelve closed marked stores from passing runs.

This qualifies recovery publication for this mixed Itinerary payload. It does
not qualify its native-save rollback or actual process interruption, the
distinct Item/List owned-content cases or label-collision faults. Those concrete
checks, Q163 and native/system/physical acceptance remain on the map. No new
module, test boundary, target, schema, format or gate is introduced. Signing
stays deferred.

## Mixed Itinerary native-save rollback

The same mixed-owned graph now executes inside the existing isolated Mac process
save-failure boundary. The native store's actual `willSave` notification lowers
the disposable child's file-size limit. SQLite reports write error 778. After
restoring the limit, both source versions' complete values, links, bookings,
labels, stops, expanded completion and retained completion history are unchanged.
Original recovery bytes and writer control remain intact.

Only an unverified maintenance preparation survives. Retry rejects it with
`maintenanceNotApplied` and changes no files. A fresh maintenance attempt uses a
different identity, retains that original proposal byte-for-byte and preserves
the complete winning graph with the seven exact owned-reference closures. Its
acknowledged proposal matches export; reopening and redelivery retain that graph.

The existing test body is shared by ordinary, publication-failure and isolated
native-save cases. Production code and the existing failure mechanism stay
unchanged. The Mac child has its own file limit; it does not affect the parent or
mobile tests.

The [validation record](evidence/native-membership-consolidation/native-owned-itinerary-save-validation.json)
verifies five passing Mac parent functions/seven invocations, including three
actual passing child executions, and three passing iPhone functions/five
invocations. Phone covers the shared ordinary/publication paths; it receives no
file-limit fault credit. The actual child transcripts, ownership records,
termination status 0 and deadline results are retained. No function is skipped or
failed, and no SQLite-unlink diagnostic occurs. Expected SQLite write errors
remain visible in the child transcripts.

All 813 shared Core inputs and actual products match. Of 1160 native inputs, only
the existing test file changes. All 90 Core production inputs, 514 frozen fixtures
and schema sources remain unchanged. Strict Swift/Markdown and whitespace checks
pass. Verified cleanup removes eighteen closed marked parent/child/mobile stores
after preserving their transcripts. Source manifests remain losslessly
compressed.

Actual mixed-payload process interruption, distinct Item/List owned-data and
label-collision faults, Q163 and native/system/physical acceptance remain open.
This adds no production hook, package, target, schema, portable format or writer
gate. Signing stays deferred.

## Mixed Itinerary process interruption

The mixed-owned graph now runs through actual Mac child termination at its
store-specific `willSave` and `didSave` notifications. Each child writes its
original complete winning backup, recovery files and control binding, then a
proof naming its stage and process identifier. The child requests SIGKILL and
never reports its unfinished test as passed. The parent verifies uncaught
signal 9 within the existing deadline; collected ownership records independently
match the proof's process identifier and dataset path.

Before native commit, recovery exposes the preparation as unverified. Fresh
bootstrap re-evaluates current data and uses a different maintenance identity;
Retry of the original proposal rejects without changing files. After native
commit, bootstrap retains the existing pending maintenance and mutation block.
Explicit Retry acknowledges that original identity, and repeated Retry returns
the same checkpoint.

Both cases retain the complete winning graph, seven exact owned-reference
closures, original user receipts, every prior recovery-file byte and writer
control. A further reopen retains the same export. The literal seven closure
targets are unchanged from the preceding mixed-owned tests; one shared assertion
checks the full graph against the original winning backup. Production is
unchanged.

The [validation record](evidence/native-membership-consolidation/native-owned-itinerary-interruption-validation.json)
verifies six passing Mac parent functions/eight invocations. Its five children
include the two deliberate SIGKILL cases and three passing native-write-failure
regressions. Three iPhone functions/five invocations qualify the affected shared
ordinary/publication paths, with no mobile interruption claim. All 813 Core and
1160 native inputs reconcile with actual products; only the existing test file
changes. All 90 production inputs, 514 frozen fixtures and schema sources stay
unchanged. Final cohorts have no failures, skips, timeouts or SQLite-unlink
diagnostics. Strict Swift/Markdown and whitespace checks pass.

Original child inputs, proof files, termination records and transcripts are
retained with the actual interrupted Mac datasets. Source manifests are
losslessly compressed. Verified cleanup removes only the five closed passing
phone stores. Distinct Item/List owned-data and label-collision faults, Q163,
native interaction, cloud/accounts, physical power loss and whole-app acceptance
remain open. No production hook, package, target, schema, format or writer gate
is added; signing stays deferred.

## Mixed Item publication failure

The mixed-metadata fixture now supports Item and Itinerary owners through their
existing native constructors. Existing Itinerary payloads and literal closure
expectations stay unchanged. A new Item test uses public editing to save notes,
a guide, Category/Tag selections and an all-day booking. Two independent
itinerary appearances retain different local completion.

The losing Item supplies a different guide, timed booking and label selections.
Ordinary retirement and actual post-save publication failure both preserve the
complete winning graph, field hashes and edit timestamp. The only graph additions
are four exact closures for the discarded guide, booking and label associations.
Independent appearance identities, order, local completion and shared sources
remain equal to the pre-delivery backup.

While recovery waits, complete content remains readable, a new write rejects
without applied evidence, and prior recovery/control bytes remain intact.
Explicit Retry acknowledges the original maintenance and preserves original user
receipts. Its saved proposal matches export. Reopen and repeated native delivery
retain that same complete graph without merging metadata.

The [validation record](evidence/native-membership-consolidation/native-owned-item-publication-validation.json)
reconciles seven passing Mac parent functions/thirteen invocations and five
passing iPhone functions/eleven invocations. Existing Item link, booking and
label tests and the shared Itinerary paths pass. Three actual Itinerary child
regressions retain native-write-failure and pre/post-save SIGKILL evidence; these
supply no Item-specific save-failure/interruption credit.

All 813 Core inputs and actual products match; 1159 of 1160 native inputs are
unchanged. Only the existing test file changes. All 90 production inputs, 514
frozen fixtures and schema sources remain unchanged. Final cohorts have no
failures, skips, timeouts or SQLite-unlink diagnostics. Strict Swift/Markdown and
whitespace checks pass. Source manifests remain losslessly compressed; verified
cleanup removes thirteen closed passing tracer/mobile stores. The Mac cohort's
interrupted datasets and child evidence remain retained.

Item/List-specific native-save/interruption and label-collision faults remain
open, alongside Q163 and native/system/physical acceptance. No production code,
module, test boundary, target, schema, portable format or writer gate changes.
Signing stays deferred.
