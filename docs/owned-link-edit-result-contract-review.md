# New bookmark identities in edit results

Status: accepted, Q116 A, 21 October 2026. Implementation and qualification are in progress. Ordered native Link reads retain their existing contract.

## Context and starting state

At `db964299`, editing an Item or Itinerary's Links can create owned bookmarks. Core assigns and saves their stable IDs, but those two edit results list only newly added label associations in `generatedIdentities`. Removing a bookmark already adds its reference to `affectedIdentities`. An Add Link Intent therefore cannot obtain its new bookmark ID directly from the successful edit result.

The native Link value needs its identity, exact original URL, usable native URL, optional label, owner title and saved position. The authored values and appended position are known before submission; the Core-generated ID is not. A second read after saving can fail or observe another change. It must not turn an already applied edit into a false claim that nothing was saved.

Core creation commands also omit owned-link references, but changing those existing results is not needed for this Add Link slice and is outside this proposal. Ordinary creation and historical creation receipts retain their current contracts. This amendment changes only new `editItem` and `editItinerary` results when their Links replacement allocates bookmarks.

## Q116 alternatives and impacts

A. Extend those two edit results with their newly created bookmark references. Preserve the existing generated and affected identity sequences as prefixes, then append each new `.ownedLink(id, owner)` in saved Link order to both sequences. An Add Link Intent can return the exact new Link directly from its successful result. Existing MCP callers see additional generated/affected references for new edits; source-only projections and data semantics stay unchanged. This requires public Core, replay/recovery and real HTTP qualification.

B. Keep Core result metadata unchanged. Add Link returns its owner and a truthful confirmation. A caller uses Get Item/Itinerary Links afterward to read the saved collection and select a bookmark. This avoids a result-contract amendment, but does not return the exact new bookmark for immediate chaining; duplicate URLs and concurrent changes make a later selection a separate read.

Recommendation: A, so a successful ordinary addition can return its precise identity without a fallible post-save lookup.

## Accepted result rules

- Existing label-association generation order and existing affected references stay unchanged. Append new bookmark references after those prefixes.
- A newly generated Link is an ID in the replacement's saved Links absent from that owner's previous Links. Retained IDs, URL/label edits to existing IDs and reordering create no generated Link references.
- Equal URLs can create different owned Links. Return each newly allocated identity once; apply no capture-style deduplication.
- A removed Link keeps its existing affected reference and is not generated. Other owners, content, references, completion, ordering and bookings retain normal field-edit behavior.
- Replaying a prior operation returns its stored original result exactly. Do not backfill bookmark references into old receipts, operation-status reads or recovery acknowledgement.
- Keep the existing typed/wire owned-link reference representation. Add no schema version, result field, command, migration, new target or test-only hook.

For example, an owner has Link A. One edit keeps A, adds Category association L and appends new Links B and C with the same URL. The existing generated prefix is `[L]`; the new generated result is `[L, B, C]`. A's public identity is retained. If another edit replaces A with B and C, its existing affected prefix includes the owner and removed A; append B and C afterward. Updating A's label alone generates no identity.

## Definition of ready

Q116 A approves this result amendment. Q33 already approves guarded ordinary edits and mixed source/reference results. Existing result enums, Codable receipts and MCP execute/status serialization support `.ownedLink` references. Read-only inspection confirms both edit paths' omission and stored-result replay behavior. Existing public Core/store and HTTP operation boundaries, plus Q112's production Intent boundary, remain the test seams.

## Required tests and definition of done

Test both edit commands through real storage, with retained, edited, removed, reordered and newly allocated Links. Assert saved-order generation, intentional duplicate URLs, mixed label/bookmark prefixes and unchanged source-only projections. Reopen, replay and read operation status to prove exact stable identities/results. Preserve historical receipt behavior with no backfill, including recovery comparison of committed and acknowledged results. Exercise actual recovery-filesystem failure and retry without mutation replay.

Verify real MCP execute/status return the same additional references and preserve no-change behavior. Then qualify native Add Link output at the existing production Intent seam, including its exact new ID, cancellation, invalid input and applied/incomplete outcomes. Retain unrelated content, links, labels, completion, references and bookings. Run affected lint/type checks and platform builds; actual Shortcuts system invocation and physical testing retain their separate gates.
