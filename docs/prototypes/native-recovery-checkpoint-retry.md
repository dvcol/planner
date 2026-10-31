# Native recovery checkpoint retry

## Context, before and goal

Core can identify committed operations whose independent recovery copy is incomplete, and retry their checkpoint without executing the mutation again. Native Planner currently remembers a mutation block only in memory and offers no retry. After relaunch, controls can appear enabled until Core rejects the next write.

The goal is truthful, persistent native recovery status. Read the existing current-dataset status during opening, keep incomplete changes readable while blocking further mutations, and provide an explicit checkpoint-only retry in native Settings. A visible main-view notice opens that destination. A successful retry clears the block only after refreshed Core evidence; an unavailable status or failed retry must not claim success. Backup and recovery administration remain manual.

## Definition of ready

A15/A18, R21 and the [approved native recovery contract](../portable-data-contract.md#native-import-delete-and-recovery-forms) authorize status and checkpoint retry. Core's existing status read supplies incomplete operation IDs, and its retry method returns the original result. Q52 authorizes production views in the fixture app; public Core and native UI are the agreed test boundaries. No new public command, schema, account selector or test-only production injection is needed. Q83 is independent.

## Required /tdd and definition of done

- Obstruct configured recovery files at the real native post-save boundary while creating an Item. Require an applied/incomplete outcome, restore file access, and launch production views against the actual store without reseeding on relaunch.
- Start with a functional missing native recovery-control failure. Show the committed Item and prior independent Item while creation controls are disabled. Relaunch before retry and retain the block and exact Item identity.
- Open native Settings from the notice. Show incomplete recovery and a Retry Recovery Copy action, with loading feedback and disabled conflicting controls during work.
- Place the notice inside native navigation content, preserving toolbar access. Verify that its Recovery action does not overlap the New Item control and inspect the original phone/tablet captures.
- Retry the exact known-applied operation through Core's checkpoint method. Claim Saved on this device only after verified recovery; preserve the original Item identity, content and single occurrence.
- Apply a later independent native change, relaunch, and verify both changes survive. Unverified operations cannot use checkpoint retry; unavailable evidence and continued retry failure keep writes blocked and expose a useful message/recheck path.
- Qualify continued publication failure with a readable but nonwritable recovery namespace. Qualify unavailable evidence with a malformed checkpoint while keeping the committed database readable; rechecking must preserve the block and offer no unknown-operation retry. Export control availability is distinct from actual delivered-file qualification.
- Run phone/tablet native journeys, affected recovery/import regressions, strict lint and Mac compilation. Inspect original captures and retain exact source/result evidence. Core's deeper retry/graph/admission qualification remains separate from native proof.

## Execution

The tracer first reached the committed Item and failed at the missing native recovery notice. The implementation reads current-dataset Core status during opening and Settings inspection, retains the incomplete operation IDs and uses only the existing checkpoint retry method. List writes now use the same result handling as other native mutations. Unavailable evidence keeps writes blocked; successful retry refreshes evidence before unblocking.

Native fixtures use actual post-save filesystem obstruction. Writable recovery permits repair, a readable/nonwritable namespace retains a retry failure, and a malformed checkpoint makes status unavailable without damaging the committed database. Fixtures reopen without reseeding.

An intermediate success journey incorrectly expected a catalog row while the newly created List's detail was selected. Retained hierarchies show the saved List and No items, with native Back on phone and Show Sidebar on tablet. The corrected journey uses those controls, preserving its before/after List identity assertion. Visual inspection then found the notice covering the phone toolbar; placing it inside navigation content and adding a nonoverlap assertion addresses that defect. Earlier runs and their diagnostics do not substitute for final qualification.

Six native functions across two suites pass on each simulator, with zero failures or skips. They cover successful retry after relaunch and a later List save, continued publication failure, unreadable recovery evidence and recheck, retained-copy export, reviewed restoration/Cancel, and Skip/Overwrite conflicts. The success journey verifies original Item/independent Item IDs and the later List ID/name through relaunch, retained notes and one Item occurrence. The notice does not overlap New Item.

The final change moves raw checkpoint/file errors behind a native Details disclosure, preserving a readable primary message. Its two affected error functions pass again on each simulator with the final compiled view. These are six unique functions per device, followed by two focused reruns, not eight unique functions. Only SavedRecoveryStatusSection changes between these stages; source/product hashes identify both revisions. Other production and test sources stay fixed.

The actual post-save failure never removes the committed Item. An incomplete copy blocks creation across relaunch. Successful retry establishes fresh Core evidence before showing Saved on this device and enabling the later independent List save. Permission failure keeps the incomplete state and exposes recheck; malformed checkpoint evidence exposes unavailable status, keeps reads available and offers no unknown-operation retry. Export control availability is checked in that state; delivered-file semantics are not newly qualified here.

The final standards review inspected 16 original captures individually: four successful-retry captures per device and all eight latest error captures. Root also inspected the blocked notice and final failure presentation on each device. These checks found no overlap or unreadable recovery controls; they do not credit the other retained captures as visually re-reviewed or close whole-app polish. The specification review found no actionable issue.

Affected strict Swift/Markdown lint, whitespace checks and the final Mac app/test-host build pass. Mac runtime remains zero. Core/HTTP, storage schema 18 and portable format 2 are unchanged; no new Core/HTTP test runs are credited. Busy indicators/disabled controls are implemented, but prolonged in-flight rendering and cancellation need separate qualification.

The execution packet retains complete final baseline and focused-error capture manifests, raw test results, earlier functional red/navigation/layout diagnostics, commands and both stages' source/product hashes. Initial failures and pre-layout screenshots are excluded from final pass/visual credit.

## Remaining gates

Physical account/cutoff/sync/Share, native unverified-proposal restoration, unavailable-store recovery, full-graph restoration, broad adaptive/accessibility/scale and whole-app polish remain open. Mac compilation does not prove Mac runtime, and local recovery acknowledgement does not prove cloud delivery.
