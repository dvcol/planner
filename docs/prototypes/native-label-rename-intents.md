# Shared-label rename Intents

Status: both shared-label rename actions are implemented. All 23 affected label-adapter cases and Mac, Simulator and unsigned device builds pass. Actual system invocation remains open.

## Context, starting state and goal

At `d7bc97f5`, native Planner/Core edit shared labels, while Intents only create/read Categories and Tags. Renaming must edit the selected shared object rather than copy names into owners or rebind associations. Add Rename Category and Rename Tag using a required native New name field and the existing typed edit commands.

## Definition of ready

Q33 approves ordinary edits and changed-field hash guards. A6 keeps owner timestamps unchanged when shared label metadata changes. Q112 A approves the production Intent/EntityQuery boundary with Apple's dependency manager and disposable real storage. Use current label hashes, a name-only patch and truthful recovery outcomes. No new direct helper test boundary, Core API, package, target or test-only production hook is needed.

## Required tests and definition of done

Record executable missing-action reds before each label kind. Reopen real storage to prove live renamed labels on both Item/Itinerary owners and Item rows, preserving identity/lifetime, color/icon, references, owner content/hashes/timestamps, local/global flags, saved order and booking. Cached names cannot replace current data. Duplicate names remain separate labels with unchanged owner bindings.

Qualify blank names, wrong-kind/missing/deleted IDs, cancellation, unavailable storage and actual post-save recovery failure without replay. Run affected label-adapter regressions, strict lint/type/whitespace checks, actual Mac/Simulator/unsigned device builds, complete metadata/embedding checks and source verification. Retain earlier broader evidence without claiming a full runtime rerun. Actual system discovery/invocation, signing/account setup, physical qualification and whole-map completion remain separate gates.

## Executed slices

Category renaming first fails at its missing action in 0.477 seconds, then passes in 0.231 seconds. A colored/icon-bearing Category remains the same shared object. Reopened Item/Itinerary source labels and Item rows show the new name; owner hashes, timestamps, references and content remain unchanged. Standalone/local completion, saved references and the all-day booking survive. Color/icon and the other shared Tag are preserved.

Tag renaming first fails at its missing action in 0.678 seconds, then passes in 0.172 seconds. Its identity/lifetime, color/icon hashes and owner bindings stay unchanged. Only the Tag name hash changes; the other Category remains unchanged, and both source/row reads show the new Tag name.

Seven rename cases then pass. Renaming either kind to an existing name retains two independent IDs and original owner bindings. Blank names, missing/wrong-kind IDs and deleted labels reject without changing other data or resurrecting labels. Pre-cancelled renames preserve both content and timestamps. Actual unavailable storage rejects both actions and preserves the obstructing file.

Actual post-save recovery obstruction is exercised separately for Category and Tag. Each applied rename remains readable while another mutation is blocked. Native retry acknowledges the same operation without rewriting label content/timestamp/references or owner data; a later explicit rename succeeds. These safety checks need no further production behavior change. Timings are XCTest durations, not physical performance measurements.

## Combined and platform qualification

All 23 Category/Tag/rename adapter cases pass with zero failures/skips in 11.740 seconds. The actual XCTest summary is retained. The original log contains no compiler warnings or SQLite lifetime diagnostics. All 25 owned fixtures are verified disposed after host exit and closed database handles. Broader runtime evidence is retained, not rerun; this change adds two actions to the existing label files and one test file. All 997 other prior inputs are unchanged, and existing label Create/Get/query source prefixes are byte-for-byte unchanged.

Mac metadata preserves the complete prior catalog and adds exactly RenamePlannerCategoryIntent and RenamePlannerTagIntent: thirty actions, seven entities and seven queries. All three native enums remain unchanged. Simulator app/native UI-target and unsigned generic iOS-device builds pass with identical catalogs/cases. The device app embeds one mobile Share extension; both executables are arm64. All 1000 frozen inputs match current source in all three final packets.

Strict affected Swift/Markdown lint, actual platform type checks and final Git whitespace checks pass. No Core/schema, target, dependency, transport, backup format, entitlement or native UI changes are introduced. Existing ad hoc Mac configuration is reused; no signing/account setup, physical installation or actual system invocation is claimed.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `app-intent-label-*-rename-*` and `app-intent-label-rename-*` packets, original commands/logs/source epochs and actual exits. Expected missing-action failures retain failed qualification with separate inspected fixture disposal. Passing runs use the guarded post-host verifier.

Label associations, richer editable fields and remaining ordinary scheduling/capture/bulk Intents remain on the map. Actual system discovery/invocation, background/locked behavior, native system confirmation and explicit unverified-operation fault qualification remain open. Q100 B signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical performance and feature-complete whole-app polish also remain open. The map is incomplete and signing remains deferred.
