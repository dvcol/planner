# Remove and reorder Links in Shortcuts

Status: four new actions, all 35 Link cases, 79 affected test declarations and Mac/Simulator/unsigned device builds pass locally. Signing and actual system picker qualification remain deferred.

## Context, starting state and goal

At `dc596833`, native actions read, add and edit owned bookmarks. Core already removes omitted bookmark identities and persists replacement order under the current Links field guard. Native removal and reordering are still absent. Add those ordinary data workflows for Item and Itinerary owners without selecting by URL, cached label or cached position.

## Definition of ready

Q33 authorizes ordinary reference mutations. Q112 approves production App Intent/EntityStringQuery tests with Apple's invocation/dependency interfaces, disposable actual storage and genuine filesystem failures. The existing itinerary-entry actions establish owner-first selection and Beginning/End/Before/After controls. Current Core commands already provide ownership/lifetime validation, guarded atomic replacement, deletion metadata and truthful recovery results. This slice adds no Core/wire/schema, package, target or test-only interface.

## Resulting behavior

Remove Item Link and Remove Itinerary Link remove exactly the selected bookmark from its explicit owner. Other bookmarks keep their identities, values and saved order. Removing the last bookmark leaves its owner present with an empty Links collection. A same-URL sibling stays independent, and repeating an already completed removal fails without selecting it.

Reorder Item Link and Reorder Itinerary Link expose a native four-case position choice. Beginning and End use the selected bookmark only and ignore an inactive relative Link. Before and After require a different, still-saved relative bookmark in the same owner. Missing, removed, self-relative and foreign anchors reject without applying a partial order. The handler uses current storage values and order, preserving newer content even when supplied native entities contain older values. All surviving bookmarks remain present once.

The shared private handler validates exact ownership/identity, reads current content and field guards, then issues the existing ordinary edit command. Its explicit Edit/Remove/Reorder cases keep the previous editing behavior and dialogs. Confirmations distinguish complete recovery from a locally applied action awaiting independent recovery; another mutation stays blocked until repair acknowledges the original operation. No post-save lookup repeats a mutation.

Both target and relative-Link parameters explicitly use the native Link query. The query declares the corresponding owner dependencies alongside its existing edit dependencies. Native metadata verifies these declarations and the exact four enum cases. Actual system dependency injection, positive scoped picker/search interaction and inactive-parameter resolution remain open; direct invocation does not establish those system behaviors.

## Definition of done and test evidence

Each feature has its own runtime red before implementation and passing tracer afterward. Removal verifies the exact deleted identity, preserved same-URL sibling, source survival and empty last-Link result for both owners. Reordering exercises all four modes in both directions with literal expected identity orders and retained values.

Five removal cases and five reorder cases additionally cover changes after selection, fresh content/order instead of cached values, foreign/stale/missing/self-relative identities, inactive foreign/removed/self anchors, repeated requests, precancellation and unavailable storage. Real post-save recovery failures cover both owners with archived/completed sources, live plans and bookings. Saved mutations stay applied, further writes remain blocked, and repair preserves data/timestamps and the original receipt rather than executing again.

All 35 Link read/add/edit/remove/reorder cases pass. The final affected run passes 73 XCTest cases in 17.511 seconds and six real HTTP Swift Testing declarations in 0.770 seconds, with no failures/skips. One HTTP declaration has two owner cases. The removal suite passes five cases in 0.685 seconds; reorder passes five in 1.107 seconds. All 88 final marked fixtures are disposed after verified host/SQLite closure. Compiler and SQLite lifetime diagnostics are empty. The two expected-red fixtures, two initial-green fixtures and 42 safety-run fixtures are also disposed after closure, preserving every original result.

## Platform and source qualification

Mac, the actual Simulator app/native UI-test target and unsigned generic device app compile successfully. Their native catalogs have 53 actions, the original eight entities/queries and one additional four-case Link-position enum. New removal parameters are the required typed owner and Link; reorder adds required Position and optional Relative Link. All four return dialogs. Every prior action parameter/output contract, entity property, query contract and previous enum case remains unchanged.

All three verified epochs have 1027 identical frozen inputs. Only the native Link file changes among prior inputs; two production-interface test files are added. The existing Core and other prior files are unchanged. The device app embeds exactly one mobile Share extension; both executables are arm64. Strict affected Swift/Markdown lint and platform type checks pass.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `app-intent-remove-links-*`, `app-intent-reorder-links-*` and `app-intent-link-mutations-*` packets with original commands, exits, logs, frozen sources, result summaries, metadata contracts and fixture-lifecycle reports.

## Remaining map work

The ordinary native Link data workflows are implemented at the approved local interfaces. Other richer Intent reads/fields, scheduling/capture/bulk workflows and [Q115's estimate-input choice](../native-estimate-intent-input-review.md) remain. Actual Shortcuts/Siri discovery/invocation, picker injection, background/locked launch, signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical qualification and feature-complete whole-app UI polish retain separate gates. No account/signing setup or device installation occurred; the map remains incomplete.
