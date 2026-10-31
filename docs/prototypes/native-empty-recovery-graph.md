# Native recovery into an empty Planner

## Context, starting state and goal

R20 requires explicit recovery into an empty local dataset while retaining source identities, references and state. Native saved Item/Tag restoration and conflict policies already have qualification. A retained plan containing Lists, repeated Itinerary references and Schedules has not been exercised through that native destination.

The goal is to restore such a plan through production native Settings and verify its observable state after relaunch. This is local qualification, not a claim that iCloud account switching or automatic upload isolation has been proved.

## Definition of ready

The accepted R20 recovery policy, Q52 production-view fixture host and existing native UI/public Core test seams apply. The current target starts empty. Another local dataset shares the recovery directory and owns the retained graph. Fixture seeding uses public durable commands and never imports into the target automatically. Q83 does not affect these source forms.

## Required /tdd and definition of done

- Select a retained saved copy with two Items, one List, one Itinerary, a Category and a Tag. It contains two memberships, three itinerary entries, two Schedules, four label associations and one bookmark.
- Review six source additions, including their two saved Schedule references. Cancel must leave the current target empty through relaunch; retained identities stay unchanged.
- Explicitly restore, then relaunch. Preserve the museum's source identity, notes, global Todo, bookmark and Tokyo start-only Schedule.
- Preserve the List's museum/lunch order, independent museum local Done, archived lunch and derived finished progress. Preserve Museum, List, Museum route order, independent first Done/other Todo appearances, and archived-child progress.
- Relaunch again and retain observed association identities, order and completion. Further source metadata, exact Schedule endpoints, deletion history, export delivery and physical account checks need their own evidence unless qualified here.
- Run the focused phone/tablet journey and affected recovery regressions, compile Mac, inspect original captures, and run affected lint. Do not turn passing existing behavior into a fabricated red: fixture/test-only qualification may pass first execution; any discovered behavior defect gets a genuine red/green repair.

## Execution

The fixture creates an empty current store and a separate retained store, with a shared recovery directory. Durable public commands seed only the retained store. No restored content is injected by the native adapter or reseeded after relaunch. Production behavior, Core/HTTP, storage schema 18 and portable format 2 are unchanged.

The targeted graph function passes on each simulator with zero failures or skips. Each device's unchanged Item/Tag reviewed-restore regression passed separately in an earlier mixed bundle; that bundle's failing graph function is excluded. Together these are two unique functions in two suites per device, distributed across separate bundles. No final two-function green bundle is claimed. Source/product snapshots retain the exact revisions. After iPad passed, the only source change adds native Back navigation to the test helper when the phone has no sidebar. No app, fixture, Core or existing regression source changes accompany that correction.

Earlier diagnostic runs found test errors: offscreen reference fields, a partially covered Review Restore control, an incorrect eight-owner expectation, wrong Schedule accessibility types, a mistyped Itinerary row identifier, a map pan intercepting the scroll, and the phone's selected-List Back path. The review contains six source owners; its two Schedules are represented references. Original captures/hierarchies established the visibility and gesture corrections. The unsupported XCTest `lastMatch` helper also had a compile failure, corrected with its supported element inventory. These are qualification/debugging failures, not fabricated product red/green evidence. No production repair was required.

The journey verifies Cancel through relaunch, explicit Restore, all six source IDs, source notes/global Todo/label previews/bookmark and start-only Tokyo Schedule, List order/local completion/archive-derived progress, repeated route order/independent completion, and the observed association/Schedule identities and description through another relaunch. It does not establish byte-for-byte equality of every portable field or compare original backup association/Schedule IDs to their restored IDs. Those remain the separate Core graph contract's responsibility.

Affected strict Swift lint and the final Mac app/test-host build pass. Mac runtime remains zero; no Core/HTTP test runs are newly credited.

The standards review inspected all ten original targeted captures individually, five per device, and found no material visual or source issue. Root inspected the iPad review/route/List and phone review/route/label captures. The List retains its 4-hour manual estimate and finished state; its itinerary branch independently shows one unfinished child. This visual observation does not add a new automated duration assertion or close broader native UI polish.

The execution packet retains actual counts, complete targeted capture manifests, exact commands and source/product hashes for both qualified revisions. Earlier failing functions, compile errors and selected diagnostics remain separately labeled.

## Remaining gates

Exact portable graph equality, original endpoint/association comparison, deletion-history restoration, unverified proposals, unavailable-store recovery, delivered-file semantics, physical account/cutoff/CloudKit/Share, Mac runtime and broad adaptive/accessibility/scale/polish remain separate gates.
