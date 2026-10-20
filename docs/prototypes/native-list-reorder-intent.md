# Native List reorder Intent

Status: all four placements are implemented. All 75 affected adapter cases and Mac, Simulator and unsigned device builds pass. System invocation and physical acceptance remain open.

## Context and starting state

At `63808f81`, Core and the native app save a List's Manual order, but App Intents cannot reorder its memberships. The existing Item/List entities identify one membership per pair. Reordering must retain that identity and completion, shared Item data, other memberships and schedules. API callers that omit sort keep alphabetical results; a saved Manual order is separate from a device's selected display sort.

## Goal and expected end state

Add Reorder Item in List with a native Position enum: Beginning, End, Before Item and After Item. Before/After resolve the relative Item's current membership in the same List and require it; Beginning/End use only the selected Item/List, ignoring an inactive relative selection. Delegate the resulting typed placement to Core. Missing/deleted/removed memberships and invalid anchors reject without moving between Lists, creating a membership or changing completion.

## Definition of ready

- Q33 approves ordinary organization and the typed first/last/before/after placement contract. Q112 A approves production Intent invocation and real Core storage/read/failure boundaries.
- Existing public Core reorder, source/appearance reads and explicit Manual queries suffice. No new Core contract, package, target, storage format or test-only production parameter is needed.
- The shared process-lifetime fixture helper and guarded post-host cleanup runner are available. Signing and actual system invocation remain separate gates.

## Required tests and definition of done

Record the executable missing-action red, implement one placement journey, then qualify the remaining placements. Reopen real storage to verify exact manual order and unchanged membership identities, local/global flags, shared content, container progress/estimates, other contexts and schedule. Explicit Manual queries must follow saved order while omitted-sort queries remain alphabetical. Qualify absent/self/foreign/removed/deleted anchors, missing targets, cancellation, unavailable storage and real incomplete recovery without replay. Retain original logs and dispose fixtures only after verified host exit.

Run affected adapter classes together, compile Mac, Simulator and unsigned device products, inspect extracted action/enum metadata and extension embedding, and complete affected lint/type/whitespace checks. Preserve source epochs and actual outcomes. The whole map and physical/system gates remain open.

## Executed placement slices

The initial compile catches an incomplete expected query identity in the test: appearance rows contain both source and contextual identities. After correcting those expected values, the actual missing action throws in 0.822 seconds. The Before implementation then passes in 0.394 seconds, preserving archived/hidden children, original membership IDs, local/global and itinerary flags, shared Item hashes/Last updated, container estimates/progress and an inclusive all-day schedule. Explicit Manual queries return the changed order while omitted-sort queries stay alphabetical.

The next placement journey reaches the explicitly unsupported Beginning branch, 0.666 seconds. Adding Beginning, End and After mappings gives a passing 0.155-second journey. A missing inactive relative selection does not affect Beginning; End also works with no relative selection. Each step reopens real storage and retains the same three memberships and local Done flag.

Invalid/self/foreign/missing anchors, wrong-kind/absent targets, removed memberships and natively deleted references reject without partial reordering or membership creation, 0.603 seconds. Unrelated source content and surviving Lists stay intact. Pre-invocation cancellation preserves valid saved order, List timestamp and contextual flags, 0.215 seconds.

Actual post-save recovery-file obstruction retains the new order and original Item content/completion, 0.268 seconds. Another reorder is blocked. Native retry acknowledges the original operation without rewriting the applied List timestamp/order; a later explicit End placement succeeds. Unavailable storage rejects without acknowledgment and preserves the obstructing file, 0.009 seconds. These failure/preservation cases need no further production change.

## Combined and platform qualification

All 75 affected Item/List/Itinerary adapter tests pass together with zero failures/skips in 23.033 seconds, including six new reorder cases. The actual XCTest summary is retained. Their original log has zero SQLite lifetime diagnostics and no compiler warnings. All 77 owned fixtures are verified removed after host exit and closed database handles. All 991 frozen build/test inputs match the current source. Timings above are XCTest durations, not physical performance measurements.

Mac metadata extracts twenty actions, three entities and three queries, matching the previous catalog plus Reorder exactly. One new native enum contains the four identifiers and labels: first/Beginning, last/End, before/Before Item and after/After Item. This is extraction and adapter evidence, not actual system invocation.

The production app and native UI target compile for the generic iPhone/iPad Simulator destination. The generic unsigned iOS device build also passes and embeds one mobile Share extension; both executables are arm64. Mobile/device action and enum metadata match the Mac catalog, and all 991 inputs match this checkpoint in both packets. Affected strict Swift/Markdown lint and final Git whitespace checks pass. Existing ad hoc Mac signing is reused and mobile configurations remain unsigned. No Core contract/schema, backup format, dependency, target or native UI changes are introduced. No device is installed or launched.

The [compatibility evidence](evidence/navigation/native-itinerary-window-compatibility/) uses `app-intent-list-reorder-*` packet names and retains actual commands, source epochs, logs and result codes, including the unsuccessful expected-row compile. Expected missing-implementation fixtures are inspected and disposed separately after host/handle closure without relabeling those failures as passing tests.

Actual Shortcuts/Siri discovery/invocation, background/locked execution, system confirmation, native capture invocation and explicit unverified-outcome fault qualification remain open. Richer Intent fields, itinerary contextual/organization actions, scheduling actions, Q100 B signed Agent Control/reader/real clients, account-bound CloudKit, installed Share, physical performance and feature-complete whole-app polish remain on the map. Signing stays deferred; this slice cannot complete the map.
