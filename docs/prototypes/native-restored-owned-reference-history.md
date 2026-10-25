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
