# Assigned Category and Tag read Intents

Status: all four read actions, nine new cases, 41 affected label-adapter tests and Mac/Simulator/unsigned device builds pass locally. Signing remains deferred.

## Context, starting state and goal

At `a9355363`, Shortcuts can create/read/rename shared Categories and Tags and assign them to Items or Itineraries. It cannot read the selected owner's assigned labels. A global label query does not answer that question and could include labels belonging only to another source.

Add Get Item Categories, Get Item Tags, Get Itinerary Categories and Get Itinerary Tags using the existing typed owner and label entities. Each action reads the current source once and returns the requested kind from its live Core label projection. Preserve distinct identities when names are equal. Return only that owner's own assignments, without flattening its child Items/Lists or inferring labels from names. The collection is an identity set with no new manual or alphabetical ordering contract.

A valid source with no assignments returns an empty collection. Missing/deleted/wrong-kind source identities, cancellation and unavailable storage fail explicitly instead of returning a successful empty result. Archived and globally Done sources remain readable. No new Core command, schema, property strategy, dataset, label entity, query, admin action or permission is introduced.

## Definition of ready

The [content contract](../content-and-reader-review.md) already defines live shared label projections independently of editable identity selections and owner timestamps. Q33 permits ordinary reads. [Q112](../native-app-intent-test-contract-review.md) approves invoking production Intents through Apple's dependency manager with disposable real storage in the existing app-hosted target. Reuse that boundary. Two existing fixture declarations become internal to the test module for reuse; production gains no test hook or injected factory. Q115 and Q117 remain separate pending choices.

## Required tests and definition of done

Record a failing production invocation before each new action's implementation. Verify exact selected identities, fresh shared names, distinct same-name labels, unrelated labels/owners, empty assignments and no inherited labels. Compare saved data before/after reads, reopen it, and retain independent completion, order and bookings in the real graph. Test missing, deleted and wrong-kind owners, precancellation and an actual bootstrap obstruction.

During actual incomplete recovery, reads must remain truthful without acknowledging recovery or executing another mutation. Explicit native recovery must acknowledge only its original operation. Run affected assignment/rename/Category/Tag regressions, strict Swift/Markdown lint and Mac, Simulator and unsigned generic-device compilation. Verify the four new typed array result contracts and all retained action/entity/query/enum contracts against matching frozen sources. Dispose fixtures only after their hosts and SQLite handles close.

Actual system discovery, picker resolution/invocation, background/locked execution and physical qualification remain separate gates. Signing/account setup, Agent Control, sync/account/shared storage, installed Share and feature-complete whole-app polish remain open.

## Executed slices and safety evidence

Each action first fails compilation at its missing production type. These compiler failures receive no runtime credit. Item Categories then passes in 0.336 seconds, Item Tags in 0.476 seconds, Itinerary Categories in 0.346 seconds and Itinerary Tags in 0.397 seconds. Earlier passing reads are rerun as each new action is added. No extra production correction is needed for the subsequent safety cases.

The real graph has shared labels, globally Done and archived owners, two independent appearances of one Item, ordered memberships and an all-day booking. Reads preserve distinct same-name labels, exact Unicode names and current shared renames despite stale supplied entity display data. Removing only an Itinerary's Category leaves the referenced Item's Categories intact. An Itinerary with repeated Item references returns only its own Tag once, rather than the Item's Tags or repeated inherited values. Empty Item/Itinerary selections remain empty while the shared labels and other owner survive. Before/after exports are byte-identical across reads and remain so after reopening.

All nine new cases pass in 2.807 seconds. Missing, wrong-kind and deleted owner reads throw without switching targets, returning an empty success or recreating data. Confirmed shared-label deletion updates both owners' reads to empty without deleting either source or changing completion and route content. Precancellation preserves the saved planner. Actual unavailable bootstrap preserves its obstructing file and reports failure for every owner/label combination.

During an actual post-save recovery filesystem obstruction, all four actions read the applied labels while recovery remains blocked with its original operation identity. Reads do not acknowledge recovery. Explicit native retry completes that operation without changing the Item's hashes, timestamp, references or labels. No extra assignment or mutation is performed by a read.

## Combined qualification and limits

The final affected read, assignment, rename, Category and Tag run passes 41 XCTest cases with zero failures/skips in 18.287 seconds. The original log and actual result summary are retained with zero compiler diagnostics or SQLite lifetime warnings. All 46 final fixtures, nine safety fixtures and ten earlier passing fixtures are disposed only after verified host exit and closed SQLite handles. Missing-action compiler reds create no fixture stores and receive no behavior qualification credit.

Mac extraction preserves every prior action's parameters and output type, all entity definitions, every query and all enum cases. Exactly four actions are added, giving 57 actions, eight entities, eight queries and four enums. Each new action has one required typed Item or Itinerary input and a typed Category or Tag array result. The actual Simulator app/native UI-test target and unsigned generic-device builds pass with matching metadata and zero compiler diagnostics. The device app embeds exactly one mobile Share extension, and both executables are arm64.

All 1029 current input hashes match across the three platform packets. Among the previous 1028 inputs, only the production label-adapter file and the two test-fixture visibility declarations change; one new read-test file is added. Strict affected Swift/Markdown lint and Git whitespace checks pass. No Core/schema, dependency, package, target, entitlement, native UI or public command change is introduced. The existing ad hoc Mac configuration is reused without developer signing/account setup or physical installation.

The evidence directory retains the app-intent-item-categories, item-tags, itinerary-categories, itinerary-tags and assigned-labels packets with original commands/logs, actual exits, frozen source hashes, summaries, metadata and fixture verification. Test durations are not physical performance measurements. These local production-interface and build results do not qualify actual system invocation, picker resolution or whole-map completion.

[Q115 estimate input](../native-estimate-intent-input-review.md) and [Q117 deferred content properties](../native-deferred-content-read-contract-review.md) remain pending. Other native fields/reads, scheduling/capture/bulk actions, actual system invocation, Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical qualification and feature-complete whole-app polish remain open.
