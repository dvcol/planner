# New bookmark identities in edit results

Status: Q116 A's Core result amendment passes locally. The [native Add Link follow-up](native-add-link-intents.md) is subsequently implemented and qualified separately. Signing remains deferred.

## Context, starting state and goal

At `cb05fc36`, Item and Itinerary edits allocate and save new owned bookmarks, but omit their references from generated results. A Shortcuts action cannot return its exact new bookmark without a second read after saving. Q116 A approves [the concrete amendment](../owned-link-edit-result-contract-review.md) at the existing public Core/store, real HTTP and production Intent boundaries.

## Resulting behavior

Both edit paths preserve their existing generated/affected identity prefixes and append newly allocated owned-link references in saved Link order. Equal URLs retain distinct bookmark identities. Retained URL/label changes and reordering generate no bookmark references; removed bookmarks retain their existing affected references. Source-only projections, creation commands, wire types, receipts, schema and recovery logic are unchanged.

The production change is limited to constructing these two edit results. Existing receipt replay, status and recovery acknowledgement return their stored result rather than reconstructing it from current content.

## Tests and evidence

- The Item result assertion fails before its production change and passes afterward. The equivalent Itinerary behavior also fails before its fix and passes afterward. One initial Itinerary test used an unavailable reference property; its compiler failure is retained separately from the corrected runtime red.
- The final narrow Core run passes 31 test declarations in 12 suites in 1.363 seconds. It covers owned links, both edits, genuine migrations, ordinary creation, association Undo and recovery. The new parameterized recovery test exercises both owners, real post-save filesystem failure, exact status/replay identities, checkpoint-only repair and preserved source values.
- A genuine fixture generated from committed `cb05fc36525e4d7b92519fec97957983a73e0290` contains an acknowledged Item edit and an Itinerary edit with incomplete recovery. Both saved duplicate bookmarks while returning the old result shape. The current implementation replays and repairs them exactly, without backfilling new references. The generator, frozen baseline sources, closed-file verification and fixture hashes are retained; no receipt is fabricated through database writes.
- Real MCP loopback HTTP tests cover both owner types, mixed label/bookmark prefixes, interleaved retained links, duplicate URLs, exact wire owner references, source-only projections, operation status, replay after later reordering, and unchanged replacements. Core already records an unchanged replacement as applied with no generated identities. An initial test incorrectly expected a separate no-change outcome; that failed run is retained and the test now checks the established behavior.
- The final app-hosted run passes 50 XCTest cases in 14.376 seconds and six Swift Testing declarations in 0.810 seconds, with no failures/skips. One declaration has two owner cases. The aggregate result reports 56 declarations and the device breakdown reports 57 cases. All 58 marked fixtures are removed only after their host and SQLite handles close. Compiler diagnostics and SQLite lifetime diagnostics are empty.

The first method-specific HTTP filter selected zero tests. Its result is retained without qualification credit. Later full-suite execution exposed an older HTTP fixture deleting SQLite files while still open. That test now uses the established marked-fixture lifecycle; its diagnostic run remains unqualified. Cleanup of its 57 marked fixtures was performed separately after closure, and the corrected final run passes the normal lifecycle verifier.

Core packets are in [native-association-undo](evidence/navigation/native-association-undo/) under `owned-link-result-*`, including the genuine legacy-fixture generator. HTTP/platform packets are in [native-itinerary-window-compatibility](evidence/navigation/native-itinerary-window-compatibility/) under the same prefix. Original commands, exits, logs, source overlays/hashes, result summaries, native metadata and lifecycle checks are retained.

## Platform qualification and remaining work

The actual Simulator app/native UI-test target and unsigned generic device app compile successfully. The device app embeds one mobile Share extension; both executables are arm64. All 45 native actions, eight entities, eight queries, parameter contracts, enum cases and Link-read outputs remain unchanged. The frozen epoch has 1010 inputs; the only addition is the new Core test file. Both platform builds match the final Mac run's production inputs. The Simulator snapshot predates only the HTTP fixture-lifecycle correction. Strict affected Swift lint and platform type checks pass.

Q116's Core amendment is implemented. Its native Add Link result/confirmation and failure qualification subsequently pass in the linked follow-up. Q115 A is accepted and tracked in the [decision register](../open-decisions.md), with its [estimate-input contract](../native-estimate-intent-input-review.md). Actual Shortcuts invocation, signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical qualification and feature-complete whole-app UI polish retain their separate map gates. No signing/account setup or device installation occurred.

## Native Xcode fixture lookup, 22 October 2026

The iOS Core import follow-up exposes a native-target compilation error in this test file: its non-package branch names `NativeFixtureBundle`, whose definitions in other fixture tests are private. The [initial current-source run](evidence/navigation/core-native-import-known-family-binding-ios-core/) executes zero tests. A [committed-base build](evidence/navigation/core-native-import-known-family-binding-ios-base-build/) reproduces the same missing type with the import changes removed and the failing file unchanged.

The test now has its own private `OwnedLinkFixtureBundle` marker, following the existing native fixture pattern. `Bundle.module` remains the package path. No production code, fixture payload, test target or test seam changes for this repair. Its goal is to load the actual existing legacy receipt files in the native target; a successful compilation alone does not qualify that lookup.

The [final Mac package run](evidence/navigation/core-native-import-known-family-final-package/) and [actual iPhone Simulator run](evidence/navigation/core-native-import-known-family-binding-ios-final/) each pass 57 functions/228 executions, including both bookmark-recovery owner cases and the genuine old-receipt replay/repair case. Native iOS structured results and Mac argument counts agree with zero failures/skips. The [separate Mac Xcode invocation](evidence/navigation/core-owned-link-native-fixture-mac/) also passes those two functions and three executions, including loading the real legacy fixture through the repaired native bundle path. This is ordinary Core testing and does not establish Mac UI automation readiness. The unrelated current-family import feature retains its own [scope and qualification](core-native-import-family-bindings.md).

The initial iPhone import-suite run above also contains unsafe fixture-teardown diagnostics despite passing assertions. The [Core fixture-lifecycle follow-up](native-core-fixture-lifecycle.md) distinguishes that original result from subsequent clean executions. The separate native Mac bookmark run retains its own recorded scope.
