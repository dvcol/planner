# Native active dataset export

## Context, before and goal

At `c1f1f35`, acknowledged/prepared recovery selections expose their retained data-only bytes. The approved active-dataset export method is absent. A recovery snapshot can be older than current applied changes when independent publication is incomplete; it cannot substitute for active export.

The goal is native `exportData(session:)` returning the complete validated current portable graph, including archived content and minimal deletion history, without changing domain data, receipts, checkpoints, preferences or selection. Invalid/unresolved/read-failed storage must fail the whole export rather than return shortened data. Export remains available during known incomplete recovery and never establishes saved/uploaded success by itself. No MCP/App Intent export endpoint or file-writing UI is added by this Core slice.

## Definition of ready

- Q33 and A21 approve native data-only export and the existing public facade. The [portable contract](../portable-data-contract.md#validation-and-faithful-export) fixes format-1 fields and whole-export failure.
- Public Core/store/reopen/file-I/O and authenticated HTTP seams are already accepted. Tests use actual commands and inspect returned bytes, without private database queries or injected export factories.
- The current schema-14 graph already has validated portable projection types. Unsupported lineage/import/restore integration remains separate map work; no unsupported data may be silently omitted.

## Definition of done

- Empty/current/archived full supported graphs export versioned UTF-8 portable data with stable identities, exact native values, order, global/local flags, schedules and minimal deletion markers.
- Active applied changes export during incomplete recovery even if the recovery root is unreadable. Export leaves the mutation block and original operation outcome intact.
- Complete graph traversal validates required bindings and physical record coverage; failure produces no shortened successful backup.
- Foreign sessions and missing/unreadable stores fail usefully. Independent prior recovery and current content/checkpoints remain unchanged after reads/reopen.
- Internal dataset/account/control/proposal/receipt fields, provider caches and app/device presentation are absent.
- Native app/host compilation, affected lint, focused Core/native/HTTP checks and exact source/execution records pass. Native export UI, decode/import/restore, event/account/lineage and physical gates remain open.

## Required /tdd

First export the fresh empty dataset with format planner-data/version 1 and no sources. Create Hotel/Original notes, globally complete and archive it through public commands, then export. Require the same source/lifetime IDs, exact timestamps/content/Done/Archived values, complete declared root keys and no application state. Reopen and export/read again; data and acknowledged checkpoint remain unchanged.

After the unchanged tracer passes, add full-graph preservation, export during genuine incomplete recovery/unreadable recovery, scoped/store failures and actual agent rejection/non-advertisement. Controlled file inputs establish local I/O boundaries, not physical account cutoff or arbitrary database mutation.

## Qualification

The execution record retains commands, source epochs, package logs and native summaries/test trees. The approved declaration's unavailable body supplies executable red; the same tracer bytes pass after active graph export. Production remains fixed after that first green.

| Qualified surface | Functions | Suites | Invocations | Failures/skips |
| --- | ---: | ---: | ---: | ---: |
| Mac Core package | 41 | 18 | 72 | 0/0 |
| iOS 27 native Core host | 41 | 18 | 72 | 0/0 |
| Mac authenticated HTTP | 14 | 3 | 19 | 0/0 |

Three new Core functions cover five invocations. The tracer exports an empty graph and an archived/globally Done Hotel with its same ID/lifetime, exact native timestamps/content and complete declared portable root keys. Reopen preserves the data and checkpoint. Existing full-graph qualification now exports before and after checkpoint repair, retaining six sources, two memberships, three route entries, one expanded context, four label associations, two bookmarks, two schedules and a prior deletion marker. Literal order, independent completion, estimate/archive/date values and IDs remain checked; normalized active/proposed/acknowledged graphs match.

A genuine post-save recovery obstruction leaves Museum applied while the recovery root is unreadable. Active export still includes Hotel and Museum. Returning recovery access shows the original checkpoint 1, the same pending known operation and the mutation block; exporting did not repair or acknowledge that action. Reopen/export retains current applied data. Foreign facade sessions, missing initialized stores and deliberately invalid SQLite stores fail the entire export, preserving independent acknowledgement and original-store content after restoration. CoreData diagnostics from the malformed store are expected fixture output; every test function passes.

The native exporter reads under the authorized writer gate without saving, preparing or publishing anything. It validates the complete supported portable projection and separately checks physical bookmark/Schedule/itinerary-entry/expanded-context coverage so missing relationship traversal cannot silently shorten those groups. Output is readable UTF-8 JSON, data only. Temporary caches, native status and internal account/dataset/control/proposal/receipt/presentation fields are not exported.

The authenticated `exportData` command attempt is unavailable at `/command/type`, retaining Hotel and its acknowledgement; native Delete/import/restore remain forbidden. Production MCP/Intent registrations are unchanged. Six affected Swift files pass strict lint, and the Mac app/HTTP tests compile and execute. Native Mac UI runtime remains zero. All 302 native qualification source/configuration hashes stay fixed. Schema 14, portable format 1 and local-only mode are unchanged.

Current supported local graph export is qualified; transient mirrored orphan/duplicate states and complete restoration/consolidation lineage need their separate native/physical fixtures. Native file export, decode/import/restore UI/commands, status/editor presentation, account/cloud events, process/interruption, signed sync/Share and whole-app polish remain open. Calendar/estimate choices await Q59-Q61; groups/loading await Q57/Q58. Export itself is not saved/uploaded acknowledgement.
