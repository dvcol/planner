# Earlier native navigation qualification

These execution notes were preserved from the open native navigation ticket on 15 October 2026 to leave room for current evidence. The ticket retains its Context, starting/expected state, DoR, DoD and required tests. Each historical result proves only its stated scope; later accepted decisions and current open gates take precedence over any older pending wording below.

Source: [Native navigation ticket](https://github.com/dvcol/planner/issues/14).

## Owned Item row implementation and shutdown qualification

Context/start: the accepted Q43 row contract had no real-store row-window implementation. A row request returned unavailable, and the first implementation could return a newly archived Item through an old Active generation.

Goal/end reached in [214d296](https://github.com/dvcol/planner/commit/214d296): Item row windows read owned location/estimate/subtitle and completion/archive flags after reopening, retain the generation's fixed reference instant/display zone, clamp moving ranges safely, and reject stale generations after another facade writes. Invalid context/range inputs reject without replacing a valid query. Full notes and hashes remain outside the lightweight projection.

Two executable red/green pairs are recorded in [Core qualification](https://github.com/dvcol/planner/blob/214d296/docs/prototypes/core-local-qualification.md#generation-bound-owned-item-rows). Seventeen store package functions and four native row functions pass; generic iOS Simulator Core test bundles compile. Two further row functions passed on first execution and are qualification checks, not invented reds.

The affected MCP regression uncovered an incomplete-request shutdown timeout. [67e62c4](https://github.com/dvcol/planner/commit/67e62c4) registers/closes accepted sockets, gates reads until scoped handlers exist, and cancels child tasks on every accepting-loop exit. The final trace-free TCP test passed all 100 repetitions; all 21 affected MCP functions pass. Actual shutdown evidence retains failed attempts as well as the final result. Strict Swift/document lint and diff checks pass.

Remaining DoR/DoD: this uses the existing Item-only schema, so there are no saved links, schedules, memberships or local appearance states yet. The full graph, Q45/Q46 selectors, MCP row wire path, native rich rows and completion/drag/provider interactions still need their own public-seam /tdd slices. Earlier 21 UI results qualify their recorded revision, not this changed Core dependency. Physical/signing/CloudKit/Share/performance and human native review remain required. Navigation prototype stays open and claimed.

## Owned Item row adapter qualification

Context/start: Core had generation-bound owned Item windows, but the MCP adapter still rejected rowPresentation and exposed only source reads.

Goal/end reached in [fc762a1](https://github.com/dvcol/planner/commit/fc762a1): planner_query accepts/returns the resolved presentation context, and planner_read advertises/accepts canonical generation/offset/limit row requests. It delegates selection to Core and returns lightweight owned metadata, fixed context and typed staleSnapshot details. Successful text JSON matches structured content; errors remain typed failures rather than empty success.

The same real HTTP journey has an executed one-test red and green. Two further functions passed on first execution: another facade archives Hotel and makes the old window stale without removing Original notes; nine malformed range/identity/unknown-field requests and three invalid presentation requests preserve a valid default-context generation. Actual evidence records three qualified row functions and all 24 affected MCP functions passing, zero failures/skips, plus the intermediate build-only outcome. Strict Swift/document lint and diff checks pass.

Remaining DoR/DoD: the existing store is Item-only. Full-graph local appearance flags, saved links/schedules and Q45/Q46 selection, native checkbox/drag/preview integration, selected real MCP clients, interruption/account transitions and performance remain open. The wire encoder does not qualify absent data or provider behavior. Physical/signing/CloudKit/Share gates remain deferred, not waived; prototype tickets remain open.

## Global Item completion foundation

Context/start: the store exposed globalDone in source/row reads but had no completion command; the first executable test rejected setCompletion as unavailable.

Goal/end reached in [fd40c7f](https://github.com/dvcol/planner/commit/fd40c7f): setCompletion with globalItem scope durably completes/reopens the selected Item through the coordinated receipt and independent recovery sequence. Completing an archived Hotel preserves its content/hashes/archive state, invalidates the old Todo window and reopens as global/effective Done. Its independently decoded checkpoint has the same saved state.

Actual evidence records a one-test executable red, eighteen-function green and nineteen-function store qualification. Both native completion functions and all 24 affected MCP functions pass; simulator Core test bundles compile. The follow-up no-op/Reopen/replay/mismatch/missing-reference function passed on first execution. Replaying old Done evidence preserves current Todo and checkpoint 4. Strict source/document lint and diff checks pass.

Remaining DoR/DoD: this is global Item scope only. No appearance-local/bulk command, native checkbox facade simulation or MCP completion route is claimed. Full-graph OR precedence, Q44 controls, Lists/Itineraries, provider/drag behavior, account/interruption/convergence and performance still require their own public-seam tests. Physical/signing/CloudKit/Share and native human review remain required. Navigation prototype stays open and claimed.

## Global Item completion over MCP

Context/start: Core could save global completion/Reopen, but the MCP command union rejected setCompletion. An initial single-function selector ran zero tests and was discarded; the concrete suite then executed the new journey and failed at the unsupported command.

Goal/end reached in [66010bf](https://github.com/dvcol/planner/commit/66010bf): planner_execute advertises globalItem completion and delegates it to Core. The actual HTTP journey completes Hotel, reads a Done row, reopens Todo, and replays the earlier Complete operation. Replay retains current source values/timestamps/hashes/Todo and checkpoint 3 while returning its original checkpoint 2. Native store reopening preserves Original notes and independent recovery.

Actual evidence records the four-function red/green pair, the first-execution rejection qualification and a second scope-field red fixed by exact variant validation. Ten invalid Boolean/scope/identity/field requests preserve the original Item and checkpoint with no applied operation evidence. Correctly shaped appearance completion is unavailable; a mixed appearance/global scope rejects its extra itemId rather than guessing a global action. All 26 affected MCP functions pass, zero failures/skips. Strict source/document lint and diff checks pass.

Remaining DoR/DoD: appearance-local/bulk commands, full-graph OR precedence, native checkbox/drag/preview interactions, chosen real MCP clients, interruption/account/convergence and performance still need their own public-seam tests. There is no provider I/O or native checkbox save in this slice. Backup/export/recovery administration remains excluded from agent tools. Physical/signing/CloudKit/Share and human native review remain required; prototype tickets stay open.

## Owned Item links and native migration, 2026-10-09

Context/start: Core rejected nonempty links; lightweight rows had no previewLink, and the HTTP creation/source route did not accept or encode links. Accepted Q43/Q46 require owned data with stable identity/order and one non-Maps preview bookmark. Public facade and authenticated loopback seams are already approved; no new product policy is introduced.

Goal/end reached in [b0bc73e](https://github.com/dvcol/planner/commit/b0bc73e) and [ed794ae](https://github.com/dvcol/planner/commit/ed794ae): new Item-owned HTTP(S) links save with independent recovery, retain exact URLs/labels/order and stable IDs across reopen/replay, and appear in full source reads. Rows count links and fetch one eligible bookmark with native rank/UUID sorting and fetchLimit 1. Map links remain in details; Menu supplies the selected row preview. No provider I/O occurs in Core or this wire projection.

Schema V1 stays frozen. Main-app native migration to V2 preserves an actual old Hotel's identity/dates/hashes/global Done/Archive, replay receipt and three acknowledged checkpoints. Share requires main-app migration first, then saves a new linked Museum at checkpoint 4. Normal completion/archive/notes commands retain links in every recovery copy; portable source content does not duplicate the normalized ownedLinks array.

Core evidence records two genuine red/green cycles, 24 passing affected package functions, five passing native Mac functions, 26 affected MCP regression functions and successful unsigned generic iOS Simulator test-bundle compilation. Wire evidence records six-function red/green, seven-function qualification and all 28 passing affected MCP functions, zero failures/skips. Thirteen malformed/forged requests preserve source/window/checkpoint with no applied receipt or partial link array. Syntax/resource build failures are explicitly excluded from behavior proof. Strict source/document lint and whitespace checks pass.

Remaining DoR/DoD: guarded link replacement, capture/redirect/stable-provider-reference parsing, native website image/no-image/error/obsolete-result I/O, saved checkbox/drag interactions and full List/Itinerary/appearance/Schedule persistence are still required. These localOnly and native test-host results do not prove real Share extensions, cross-process/account/CloudKit convergence, selected MCP clients, migration interruption, long-list performance or the human's final native review. Backup/export/import/recovery administration stays manual. Prototype tickets remain open.

## Guarded owned location, 2026-10-09

Context/start: owned locations were readable after creation, but guarded edits and the HTTP creation/edit route were unavailable. Accepted Q43 requires useful owned address data in rows, and the approved compound-field contract guards a complete location rather than half a coordinate pair.

Goal/end reached in [061d7eb](https://github.com/dvcol/planner/commit/061d7eb) and [cf225d9](https://github.com/dvcol/planner/commit/cf225d9): the public Core facade and authenticated HTTP route now save complete location Set/Clear with required changed-field hashes. Unrelated notes/global/archive edits preserve the location guard. A stale location rejects the whole compound edit with its typed current value/hash. Old operation replay retains a later Clear and its original receipt/checkpoint; owned bookmarks and unrelated content/state remain intact.

Core evidence records one executed red/green, two qualified functions, all 26 passing affected package functions, two native Mac functions, 28 MCP functions and unsigned generic iOS Simulator test-bundle compilation. Wire evidence records eight-function red/green, nine-function qualification and 29 passing affected MCP functions across 14 suites, excluding the separately measured ReadLoadTests. Twenty-four malformed creation/compound-edit requests reject together with exact property paths, no applied receipt and unchanged source/window/checkpoint. Strict affected Swift/document lint and whitespace checks pass.

Remaining DoR/DoD: native location editing, geocoding/image provider I/O with obsolete-result rejection, guarded bookmark replacement, saved checkbox/drag behavior and the full List/Itinerary/appearance/Schedule graph still need their accepted public-seam tests. Chosen clients, signed reader, cross-process/physical account/CloudKit/Share, interruption and long-list performance remain open. Earlier native screenshots qualify their recorded revision, not this changed Core/wire source. Signing remains deferred; backup/export/import/recovery administration stays manual. These prototypes remain open.

## Guarded bookmark replacement, 2026-10-09

Context/start: saved Item bookmarks could be created/read, but links replacement was unavailable. Q43/Q46 require current owned link metadata and one selected website preview. The accepted content contract replaces the complete ordered array under its prior hash, preserving owned identity/lifetime and excluding provider preview data.

Goal/end reached in [aa1005e](https://github.com/dvcol/planner/commit/aa1005e) and [70112c0](https://github.com/dvcol/planner/commit/70112c0): public Core and authenticated HTTP editing now retain/reorder existing owned IDs, change their URL/label/classification, generate new link identities, remove omitted links and accept an empty array. Unrelated Item fields/state and other owners remain intact. Source hashes compare the complete current ordered links. Stale compound edits reject together with typed current values/hash; foreign/repeated IDs and invalid URLs never apply a valid prefix. Old replay retains a later empty value and returns its original checkpoint.

Core evidence records the executed one-function red/green, subsequent qualification, all 28 passing affected package functions across 11 suites, two native Mac functions, 29 affected MCP functions and unsigned generic iOS Simulator test-bundle compilation. Independent checkpoint inspection proves retained link lifetimes and removal without deleting the other owner. Wire evidence records ten-function red/green, eleven-function qualification and 31 passing affected MCP functions across 14 suites. Seven malformed/foreign compound requests preserve source/window/other owner/checkpoint without applied evidence. ReadLoadTests stays excluded from these regressions to preserve its isolated measurement. Strict affected source/document lint and whitespace checks pass.

Remaining DoR/DoD: native bookmark/location editing, provider image/no-image/error/obsolete-result I/O, saved rich-row/checkbox/drag interactions, full reference-result values and List/Itinerary/appearance/Schedule persistence remain required. These localOnly/native test-host outcomes do not establish real Share/account/CloudKit convergence, migration interruption, selected clients/signed reader, physical long-list performance or final native review. Stored V2 attributes/relationships remain unchanged. New link identities are available in source/backup reads; the current limited operation result identifies its affected source. Backup/export/import/recovery administration remains manual. The prototypes remain open.

## Direct timed appointments, 2026-10-10

Context/start: Item rows carried a fixed presentation context but had no saved Schedule pool. Existing V2 datasets already contained bookmarks, completion/archive state and acknowledged recovery. Q45 requires a real ongoing/next-future/latest-past assignment, without an estimated end.

Goal/end reached in [7913a54](https://github.com/dvcol/planner/commit/7913a54): Core now saves independent direct timed Item appointments through the coordinated writer and recovery sequence, preserving Item Last updated/content/hashes. A supplied end is optional and strictly later, with a valid planning zone and fixed finite instants. Generation-bound native row fetches select latest-start ongoing, earliest future, then latest past, with ascending Schedule UUID ties and a count of all other retained records. Start-only exact starts are eligible as next; afterward they have no ongoing interval. Replay returns one original identity/checkpoint, while a changed payload rejects.

Core evidence records two executed red/green cycles, start-only/end-boundary/overlap/invalid-input qualification, retained assignments across content/bookmark/completion/archive edits, all 34 passing affected Core store functions in 12 suites, seven native Mac appointment/migration functions, 31 affected MCP functions and unsigned generic iOS Simulator test compilation. Genuine committed V1 and V2 stores migrate to V3 without losing source/link identities, lifetimes, order, dates, hashes, state or original receipt/checkpoint evidence. Share role requires main migration first, then can save into the migrated store. Strict affected source/document lint and whitespace checks pass. ReadLoadTests remains separate.

The authenticated HTTP route is now qualified in [69a2e14](https://github.com/dvcol/planner/commit/69a2e14). Wire evidence records a twelve-function red run with one unsupported-command failure, twelve-function green, thirteen-function qualification and 33 passing affected MCP functions across 14 suites. Fixed Tokyo/Paris row contexts preserve exact instants/end/zone; replay retains the earlier checkpoint without removing a later assignment. Sixteen malformed/unsupported requests preserve source/window/checkpoint and create no applied evidence. Valid supplied ends retain fractional seconds and invalidate old generations. HTTP source association reads still need their complete declared reference values; they currently return unavailable rather than inventing an empty array.

Remaining DoR/DoD: all-day and Itinerary Schedule forms/inheritance, edit/remove, complete source/reference-result values, scheduled filters, saved native pickers/row actions, preview/geocoding I/O and the remaining live reference graph. Local-only native test-host execution does not establish actual Share extension execution, migration interruption, signed clients/reader, physical CloudKit/account recovery or device performance. Existing linkd diagnostics remain unqualified. Signing stays deferred; backups/export/import/recovery remain manual. These prototypes remain open.

## Complete owned Item association reads, 2026-10-10

Context/start: Item source reads exposed only Schedule source IDs, omitted bookmark association metadata and returned unavailable over HTTP whenever reference arrays were nonempty. A saved Item must remain readable after scheduling, with the identities needed for authorized data actions.

Goal/end reached in [498d2f2](https://github.com/dvcol/planner/commit/498d2f2): `PlannerSourceRead.references` now returns typed ownedLink owner metadata and direct Schedule source metadata. Bookmarks follow saved logical order; Schedules follow UUID order. HTTP emits the complete declared members with explicit nulls for inapplicable owner/source/appearance fields. Item content/bookmarks/hashes/Last updated remain intact. Removing Map removes its reference metadata while retaining Menu and both appointments. This resolves the earlier nonempty-reference read limitation for the saved Item graph.

Joint evidence records one-function Core red/green, exact typed binding/removal qualification, 35 passing affected Core store functions in 13 suites, eight native Mac reference/appointment/migration functions and unsigned iOS Simulator test compilation. The fourteen-function HTTP red run has five failures from the old empty-reference guard, including the new scheduled-source journey; the exhaustive codec resolves all five. Fourteen-function green and all 34 affected MCP functions in 14 suites pass without skips. Strict affected source/document lint and whitespace checks pass. ReadLoadTests remains separate.

Remaining DoR/DoD: complete Schedule source/form-hash reads and guarded edits/removal, other graph/reference variants, all-day/Itinerary scheduling, native saved row/editor actions, preview/geocoding I/O and physical-device gates. Persisted schema/recovery format are unchanged in this slice. Actual Share, interrupted migration, signed readers/clients, CloudKit/account convergence and performance remain unqualified. The prototypes stay open; administration stays manual and signing remains deferred.

## Schedule source reads and form hashes, 2026-10-10

Context/start: direct timed appointments could be saved and summarized, but reading a Schedule under its own identity was unavailable. Guarded editing needs the original form and a lifetime-bound form hash, with truthful absent state/time fields.

Goal/end reached in [afb807e](https://github.com/dvcol/planner/commit/afb807e): native SourceRead now distinguishes Item and Schedule payloads. Existing Item values retain their behavior; Schedule reads return their own identity, planned Item reference, unchanged form and exactly one typed form hash. Core validates the owner lifetime against an existing Item without loading its full content. HTTP accepts and encodes the same source value, with explicit null timestamps/completion/archive/progress and empty labels/references. The wire source envelope stays unchanged.

Joint evidence records one-function Core red/green, independent accepted byte-fixture form-hash qualification, 36 passing affected Core store functions across 14 suites, nine native Mac source/reference/appointment/migration functions and unsigned generic iOS Simulator test compilation. Fifteen-function HTTP red has one Item-only-admission failure; fifteen-function green and all 35 affected MCP functions in 14 suites pass without skips. Native-generated context UUIDs are bound using actual independent recovery, with literal fixture form bytes and no production encoder/private table/test-only ID injection. Strict affected source/document lint and whitespace checks pass. ReadLoadTests receives only its typed caller update and retains no new performance claim.

Remaining DoR/DoD: guarded Schedule edits/removal, all-day and Itinerary forms/inheritance, remaining graph/source variants, native saved editors/row actions and provider/device qualification. Source read typing changes no persisted schema or recovery format. Actual Share, interrupted migration, signed reader/client, CloudKit/account convergence and physical performance remain unqualified. The prototypes stay open; administration stays manual and signing remains deferred.

## Guarded complete Schedule edits, 2026-10-10

Context and starting state: direct timed assignments and complete form/hash reads existed, but changing that retained form was unavailable. Goal: replace one Schedule form with its prior hash while preserving the Schedule and planned Item identities.

Reached end: [d14bf4e](https://github.com/dvcol/planner/commit/d14bf4e) adds native complete-form editing, useful typed stale-form details, exact receipt replay and independent before/after recovery. Invalid or stale edits leave saved state, issued generation and checkpoint unchanged. Successful edits preserve Item content/bookmarks/hashes/Last updated; a prior exact replay cannot overwrite a later form.

Validation: two actual public-store red/green cycles; 39 affected package functions across 15 suites, three native Mac Schedule edit functions, 35 affected MCP functions excluding isolated ReadLoadTests, and an unsigned generic Simulator test build. Strict affected Swift/document lint and whitespace checks pass. Executed evidence records scope, counts and source hashes.

Remaining DoR/DoD: HTTP edit admission and real wire tests; zone-only edits/removal; all-day/Itinerary forms and inherited summaries; remaining shared graph, native saved controls, actual Share, signed reader/clients, physical CloudKit/account/interruption and performance gates. The ticket remains open. Existing native screenshots qualify their original revisions only.

## Guarded Schedule editing over HTTP, 2026-10-10

Context and starting state: complete form editing was implemented in Core, while HTTP admitted only creation. Goal: expose the same guarded form replacement through strict authenticated admission.

Reached end: [5c586b6](https://github.com/dvcol/planner/commit/5c586b6) advertises and decodes the accepted command through the same native writer. Real requests retain fractional instants and identity, return complete current form/hash for stale edits, preserve Item content/time, and replay original checkpoint 3 without replacing a later checkpoint-4 form.

Validation: actual sixteen-function red/green, seventeen-function qualification with 21 malformed/unavailable requests, and 37 passing affected MCP functions across 14 suites. Rejections retain operation identity, source, issued row window and checkpoint without applied receipts/proposals. Native compilation, strict affected Swift/document lint and whitespace checks pass. Evidence records exact results and source hashes.

Remaining DoR/DoD: zone-only editing/removal, all-day/Itinerary forms and inherited summaries, full graph, native saved controls, actual Share, signed clients/reader, physical CloudKit/account/interruption and performance. ReadLoadTests stays separately qualified. The ticket remains open. Administration remains manual; screenshots qualify their recorded revisions only.

## Fixed-instant planning timezone changes, 2026-10-10

Context and starting state: complete Schedule replacement existed, while timezone-only changing was unavailable. Goal: replace only the planning zone using the prior complete-form hash while preserving the actual start and optional end.

Reached end: [4ecd459](https://github.com/dvcol/planner/commit/4ecd459) implements native and strict authenticated HTTP zone changes through the same guarded save/recovery path. Tokyo-to-Paris preserves fractional instants, identity/lifetime and Item content/time across reopen. Start-only stays start-only. Intervening start/end changes reject stale zone edits with complete current form/hash; original replay cannot overwrite a later form/zone. Modified replay leaves its recorded success intact.

Validation: actual native and HTTP red/green; 41 affected package functions in 16 suites, five native Mac zone/edit functions, nineteen concrete HTTP functions, and 39 affected MCP functions in 14 suites. Eleven malformed HTTP requests preserve source, issued rows and checkpoint without applied evidence/proposals. Unsigned generic Simulator compilation, strict affected Swift/document lint and whitespace checks pass. Evidence records exact runs and source hashes.

Remaining DoR/DoD: Schedule removal; all-day/Itinerary forms and inherited summaries; full reference graph; native saved pickers/controls; actual Share; signed clients/reader; physical CloudKit/account/interruption and performance. ReadLoadTests remains separate. This ticket remains open. Administration stays manual and prior screenshots qualify their recorded revisions only.

## Selected Schedule removal and minimal metadata, 2026-10-10

Context and starting state: direct timed creation/form/zone editing existed; selected removal and persisted deletion metadata were unavailable. Goal: remove one selected assignment while retaining its source/other assignments and durable identity closure, without adding Trash.

Reached end: [53946e5](https://github.com/dvcol/planner/commit/53946e5) adds native removal with an atomic receipt/content-free marker and independent recovery. Native schema 4 adds the marker alongside unchanged schema-3 models. Version-1 portable recovery retains its exact declared metadata array. Removal preserves Item content/bookmarks/hashes/Last updated/completion/archive. Every implemented writer retains prior deletion history, and prior receipt replay cannot recreate the removed assignment.

Validation: actual public-store red/green; 44 affected package functions across 17 suites, five native Mac removal/migration functions and 39 affected MCP functions excluding ReadLoadTests. Genuine V1/V2/V3 fixtures prove main-app migration ownership, retained content/IDs/lifetimes/hashes/time/state, original receipt replay and old recovery bytes. The V3 fixture was generated from archived committed code and copied after process exit with complete tracked SQLite/WAL/SHM/control/recovery, producer, manifest and checksums. Unsigned generic Simulator compilation, strict affected Swift/document lint and whitespace checks pass. Evidence records exact runs and corrected qualification attempts.

Remaining DoR/DoD: HTTP removal admission; all-day/Itinerary forms/inherited summaries; other deletion/closure/restoration-family variants and full graph; native saved UI; actual Share; signed clients/reader; physical CloudKit/account/interruption and performance. Markers alone do not prove deletion winning against old offline edits. This implementation ticket remains open. Administration stays manual and screenshots qualify their recorded revisions only.

## Selected Schedule removal route, 2026-10-10

Context/before: Core can durably remove a selected direct timed Schedule with minimal deletion metadata, but HTTP admission does not expose it. Goal/end reached: `removeSchedule` accepts exactly a Schedule UUID and delegates to Core. The Item and other appointments remain saved; the last removal yields an explicit unscheduled row. Exact replay returns the original checkpoint while retaining later source changes. Changing its target under the same operation identity rejects.

[Implementation 40e95e3](https://github.com/dvcol/planner/commit/40e95e3) and actual evidence record the executed unsupported-admission red, twenty-function green, 21 passing row-routing functions and 41 affected MCP functions across 14 suites. Eleven invalid requests preserve source, rows, checkpoint and absence of applied evidence. The first qualification test used a nonexistent displayTitle row field; its corrected title assertion passes. Native compilation, strict affected Swift/document lint and whitespace checks pass. ReadLoadTests remains separate.

DoR/DoD still open: all-day/Itinerary assignments, full shared graph and saved native controls/provider I/O. CloudKit deletion versus obsolete offline edits, account/interruption/performance, actual Share and signed chosen clients/reader remain required. Local markers are not proof of CloudKit convergence. The original ticket gates and final review remain in force; this ticket stays open. Administration stays manual.

## Native inclusive all-day Schedules, 2026-10-10

Context/before: direct Item scheduling supports fixed timed forms only. Goal/end reached: exact Gregorian civil dates and inclusive ranges save independently of activity estimates or display travel. Complete timed/all-day replacements retain Schedule identity/lifetime and the single form guard; zone-only all-day edits reject without saving. Rows select actual ongoing/next/past records across Tokyo/Paris and the gap between separate weekends.

[Implementation e50c14d](https://github.com/dvcol/planner/commit/e50c14d) and actual evidence record three public-facade red/green loops, 24 invalid create/edit attempts, literal independent form hash bytes, 49 passing affected store functions, eight native Mac functions and 41 affected MCP functions. An unsigned generic Simulator test build, strict affected Swift/document lint and whitespace checks pass.

A genuine schema-4 fixture produced from committed Core preserves owned content/links, global/archive state, Item time/hashes, fractional timed assignments, deletion markers, old receipts and byte-identical historical recovery across main-owned migration. Share-role saving after initialization succeeds under schema 5. This tests the process role, not extension embedding.

DoR/DoD still open: all-day HTTP writes, Itinerary forms and full graph, saved native calendar/picker/editor/provider I/O. CloudKit form cohesion and deletion versus obsolete edits, account/interruption/performance, actual Share and signed clients/reader remain required. Prior screenshots qualify their original revisions. The original ticket gates and final review remain in force; this ticket stays open. Administration stays manual.

## All-day Schedule forms over HTTP, 2026-10-10

Context/before: native Core saves timed/all-day forms, while HTTP create/edit accepts timed forms only. Goal/end reached: strict advertised union admits all-day forms with exact integer Gregorian components and explicit nullable end. Core owns inclusive validation, complete form/hash conflict handling and durable saving. Timezone-only changes remain timed-only.

[Implementation a9b34af](https://github.com/dvcol/planner/commit/a9b34af) and actual evidence record unsupported admission red, corrected one-function green, 23 passing scheduling wire journeys and 43 affected MCP functions across 15 suites. The actual HTTP journey retains travel dates, complete stale-form/hash details and original replay checkpoints without overwriting a later timed conversion; selected removal retains Item content/time/hashes and independent minimal deletion metadata. Forty-four invalid civil create/edit requests preserve source, issued row window, checkpoint and absence of applied evidence/proposals. Native compilation, strict affected Swift/document lint and whitespace checks pass. ReadLoadTests remains separate.

DoR/DoD still open: Itinerary assignments/full graph, native saved calendar/picker/editor/provider I/O, actual Share and signed chosen clients/reader. CloudKit form cohesion/deletion versus obsolete edits, account/interruption and physical performance remain required. Prior screenshots qualify their original revisions. Original gates/final review remain in force; this ticket stays open. Administration stays manual.
