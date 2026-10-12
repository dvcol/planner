# Missing initialized store admission

## Context, before and goal

At `c538235`, bootstrap refuses an initialized dataset whose store is missing, and native status reports unavailable recovery without replacing it. Ordinary Core operations still call the general ModelContainer opener, which does not distinguish setup from use of an existing store. A live session can outlast loss of its configured store, so the subsequent read/write paths need actual qualification.

The goal is to admit creation only through explicit first-time main-app bootstrap. Ordinary source/appearance/row reads, queries, reviews and commands must refuse missing initialized storage without creating an empty replacement or publishing a shortened recovery checkpoint. Independent acknowledged recovery remains inspectable. Returning the original configured store restores its existing identity/content/history; no automatic recovery import is introduced.

## Definition of ready

- Q36/A21 accept the real on-disk storage-opening boundary and public Core seams; A15/A18/R13 require truthful recovery and separate retained data.
- Tests act through public bootstrap/execute/read/query/review/status/recovery. They move only a disposable configured store directory at the agreed external I/O boundary, leaving an empty existing parent to expose implicit creation.
- First-time main-app setup and Share setup/migration ownership remain unchanged. No private database queries, production test hooks or account-reset claims are added.

## Definition of done

- A previously authorized session's ordinary operations fail usefully when its initialized store disappears. No replacement store, proposal or checkpoint is created by those attempts.
- Independent acknowledged snapshot, original operation evidence and control identity remain available; dataset status stays unavailable rather than empty/saved.
- Restoring the original configured store and reopening preserves source identities/content/timestamps/hashes and history, and ordinary editing works again.
- New main-app bootstrap still creates a fresh store; Share requires main-app setup/migration and never initializes missing storage.
- Focused public real-store tests, migration/setup regressions, native target compilation, affected lint and actual authenticated HTTP admission pass with recorded red/green and counts. This local guard does not prove coherent CloudKit account cutoff or prevent arbitrary external file races.

## Required /tdd

First save Hotel/Original notes with acknowledged checkpoint 1. Move its configured store directory aside and leave an empty directory at the original parent path. Submit an ordinary authorized create Museum command through the existing session. It must be rejected, not report applied, create a replacement SQLite store or publish a new recovery snapshot. The original acknowledged Hotel backup must remain byte-identical and separately inspectable. Restore the original store and reopen; Hotel's identity, notes, timestamps and field hashes remain.

After this tracer passes unchanged, exercise read/query/review/row/appearance and Share/bootstrap paths against the same controlled loss, then actual HTTP. Use the prior operation's independently acknowledged status without inferring that missing current storage is healthy. Existing genuine schema migrations and fresh setup are required regression checks.

## Qualification

The [execution record](evidence/navigation/core-missing-store-admission.json) retains exact commands, source epochs, package logs and native summaries/test trees. The functional red observes the authorized create returning applied/complete checkpoint 2 after store loss. The unchanged tracer passes after the shared opener requires existing storage by default. Only first-time main-app bootstrap opts into initialization; production remains fixed after that first green.

| Qualified surface | Functions | Suites | Invocations | Failures/skips |
| --- | ---: | ---: | ---: | ---: |
| Mac Core package | 38 | 16 | 67 | 0/0 |
| iOS 27 native Core host | 38 | 16 | 67 | 0/0 |
| Mac authenticated HTTP | 14 | 3 | 18 | 0/0 |

Three new Core functions cover thirteen invocations. Ordinary source/appearance/row reads, query, review, creation/replay, Share-role read, Main/Share bootstrap and unknown status/retry paths refuse missing initialized storage. They leave it absent, preserve the prior acknowledged bytes/generation and produce no new prepared proposal. Returning the original store preserves Item identity/content/timestamps/hashes and membership flags; reopening and a later notes edit work normally.

Already acknowledged operation status and idempotent checkpoint retry can still read their independent evidence without creating current storage. This is not a claim that the missing dataset is healthy; native dataset status remains unavailable. Fresh Share requires main-app setup, then explicit main setup creates the store. The existing genuine owned-link old/skipped-version, schema-6 membership and schema-13 itinerary-schedule migration suites pass.

Two actual authenticated HTTP cases, create and source read, reject unavailable storage without fabricated data or recovery success. They preserve Hotel's acknowledgement and allow the original store to reopen unchanged. The Mac app compiles and the HTTP tests execute; native Mac UI runtime remains zero. Four affected Swift files pass strict lint, and all 299 native qualification source/configuration hashes stay fixed. Schema 14, portable format 1, local-only mode and public storage configuration remain unchanged.

Share processRole tests use separate facades in one process; embedded/host-closed Share and physical account reset remain separate evidence. A pre-open file-existence guard does not prevent arbitrary deletion races outside participating coordination. Coherent account/ownership cutoff, account/cloud events, manual restore/import/export, native status/recovery UI, interruption/process, lineage/convergence and whole-app polish remain open. Calendar/estimate choices await Q59-Q61; groups/loading await Q57/Q58.
