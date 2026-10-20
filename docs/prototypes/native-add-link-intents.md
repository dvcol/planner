# Add Link actions in Shortcuts

Status: both native actions, all 18 Link cases, 62 affected test declarations and Mac/Simulator/unsigned device builds pass locally. Q116 A's Core and native result slices are implemented. Signing remains deferred.

## Context, starting state and goal

At `c6aeba2c`, the [Q116 A Core amendment](core-owned-link-edit-results.md) returns exact newly generated bookmarks from Item and Itinerary edits. The existing native Link entity/query can read and resolve those identities, but no Shortcuts action adds a bookmark. Add ordinary Item/Itinerary Link actions through Q112's approved production Intent interface, without a second source read after saving.

## Resulting behavior

- Add Item Link and Add Itinerary Link each take a required typed owner, exact original URL text and an optional label. They append to that owner's own Links. An Itinerary's referenced Items keep their separate bookmarks.
- Preserve existing ordered bookmark identities and authored values. Intentional equal URLs create distinct Links. Nil and empty labels remain distinct, and spaces in labels are preserved.
- Read the owner's current Links and field guards, then use the existing ordinary edit command. Invalid URLs, missing/wrong-kind owners, precancellation and unavailable storage fail without applying a partial edit.
- Return the exact new Core-issued Link identity, native URL, original text, optional label, owner title and position. Owner title and appended position come from the source read before submission. The native URL is prepared before execution, and constructing the returned value after saving cannot fail through URL parsing. No post-save lookup or cancellation check discards an applied outcome.
- A locally applied action with incomplete recovery still returns its exact Link and a recovery warning. Further changes remain blocked until native recovery acknowledges the original operation. An unverified outcome directs the user to review recovery; it does not claim the Link was saved. There is no new recovery/admin action exposed to agents.

These actions use existing Core commands and result types. This slice changes no Core/MCP/schema, target, dependency, entitlement or ordinary app scene.

## Tests at the approved boundary

The first production-interface test fails at runtime before Add Link is implemented, then passes for both owner types. The six added XCTest cases use actual `callAsFunction(donate: false)`, Apple's dependency manager, disposable Planner storage and the existing real filesystem obstruction. They verify exact returned identities, escaped URL spelling, empty/nil labels, duplicate URLs, current owner context, native entity resolution, retained bookmarks, other content hashes, source lifetimes/references, completion/archive state, progress, estimates and saved bookings.

Invalid and mismatched owners never redirect the write. Invalid authored URLs, cancellation and unavailable storage retain source data. Each owner also exercises a real post-save recovery failure. Its returned Link belongs to the original applied receipt; another addition remains blocked; checkpoint-only recovery preserves all saved values and acknowledges that same result without another mutation.

The first safety run exposed two incorrect test assumptions: source references include newly added owned Links, and operation status cannot read an obstructed recovery path. The corrected test compares non-bookmark references separately and repairs the filesystem before reading operation status, without acknowledging recovery. The failed run and its 18 closed fixture dispositions remain separate from qualification. No production policy was changed to fit those assertions.

The final run passes all 18 Link tests in 1.494 seconds. The affected app-hosted run passes 56 XCTest cases in 14.791 seconds plus six real HTTP Swift Testing declarations in 0.830 seconds, with zero failures/skips. One HTTP declaration has two owner cases. The aggregate summary reports 62 declarations; its device case breakdown includes that additional parameter case. All 65 final marked fixtures are disposed after verified host/SQLite closure, with no SQLite lifetime or compiler diagnostics. The original expected-red fixture and initial-green fixture are also closed and disposed, with their own results preserved.

## Platform and source qualification

Mac, the actual Simulator app/native UI-test target and the unsigned generic device app compile successfully. Native metadata has 47 actions and the original eight entities/queries. Both additions have the correct required owner, required String URL text, optional String label and single Link-entity output. All 45 prior action parameter contracts, entity properties, Link-read array outputs and enum cases remain unchanged.

All three builds verify the same 1024 frozen inputs. Only the existing native Link production/test files change relative to the Core checkpoint; 14 newly archived inputs are its already committed genuine legacy fixture. Every other prior input stays unchanged. The device app embeds exactly one mobile Share extension; both executables are arm64. Strict affected Swift/Markdown lint and platform type checks pass. Compilation and production-interface tests do not qualify actual Shortcuts/Siri invocation, dependent system picker injection or locked/background launch.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `app-intent-add-links-*` packets with original commands, actual exits, logs, source overlays/hashes, summaries, native catalogs, parameter/output checks, product checks and fixture-lifecycle evidence.

## Remaining map work

Q116 A is implemented at the approved local boundaries. [Retained-Link editing](native-edit-link-intents.md) subsequently passes its local qualification. Native Link removal/reorder and other richer Intent fields/reads, scheduling/capture/bulk actions remain separate work. [Q115](../native-estimate-intent-input-review.md) remains pending for estimate input. Actual system invocation, signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical qualification and feature-complete whole-app UI polish retain their gates. No signing/account setup or device installation occurred; the map is incomplete.
