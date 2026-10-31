# Native List completion Intent

Status: the local completion action is implemented. All 69 affected adapter tests and Mac, Simulator and unsigned device builds pass. System invocation and physical acceptance remain open.

## Context and starting state

At `4e9c6fe8`, Intents can complete an Item globally and organize its List memberships. They cannot change one membership's local completion. Core and the native app already implement Q8's precedence: global Done masks independent local flags; global Reopen reveals them. A List action must never silently become a global Item action.

## Goal and expected end state

Add Set Item completion in List using the existing Item/List entities. Resolve their exact current membership and set only its local flag. Other Lists and every itinerary appearance retain their state. Clearing local completion preserves global Done and must not promise that a globally Done Item now appears Todo. Missing or removed pairs reject without fallback, creation or resurrection.

## Definition of ready

- Q8 and Q33 approve contextual completion and ordinary Intent authority.
- Q112 A approves production App Intent invocation through Apple's dependency manager with disposable real Core storage, public source/appearance reads and actual recovery-filesystem failure.
- Existing entities, Core commands and the app-hosted target suffice. No new Core contract, package, target, persistence format or test-only production hook is needed.

## Required tests and definition of done

Record the executable missing-action red and following canonical implementation. Reopen a shared Item graph to verify independent List and itinerary flags, global Done precedence and restoration after global Reopen. Preserve shared content, archive state and schedule. Qualify missing/deleted/removed/wrong-kind pairs, pre-invocation cancellation, unavailable storage and actual applied/incomplete recovery with mutation blocked until native retry. Keep unverified results explicit.

Run affected adapter classes together, compile Mac, Simulator and unsigned device products, inspect extracted metadata and extension embedding, and run affected strict Swift/Markdown lint and whitespace checks. Preserve actual commands, source epochs, results and limits. System invocation and physical/account gates remain separate; completion of this slice does not complete the map.

## Executed contextual completion slice

The missing action throws after valid graph setup through the actual SDK invocation, 0.398 seconds. The canonical membership-scope implementation then passes in 0.277 seconds. Setting local Done preserves the Item's content hashes, Last updated, global completion and archive state. Cached entity names and state do not overwrite current data.

Global Done then masks every appearance. Clearing this List's local flag retains global Done and the Item's unchanged timestamp. Explicit global Reopen reveals the saved differences after reopening storage: selected List Todo, other List Done, direct itinerary appearance Todo, expanded itinerary appearance Done. Shared notes, parent archive state and the inclusive all-day schedule remain intact. The completion dialog clears the local flag without claiming that a globally Done Item now appears Todo.

Missing, wrong-kind, removed and natively deleted pairs reject in 0.299 seconds without another production correction. Rejections preserve original List references/timestamp and do not fall back to global completion. The unrelated surviving membership stays Todo; deleted sources remain absent after reopening.

## Failure and preservation qualification

Pre-invocation cancellation preserves a valid Todo membership, its original references and List metadata, 0.235 seconds. Actual post-save recovery-file obstruction retains local Done without changing global completion, Item hashes or Last updated, 0.231 seconds. Further local Reopen and a separate global Item mutation are blocked. Native retry acknowledges the original operation without changing the List's applied timestamp or references; a later explicit local Reopen succeeds. Unavailable storage rejects without acknowledgment and preserves the obstructing file, 0.004 seconds. These cases pass without further production changes.

## Combined and platform qualification

All 69 affected Item/List/Itinerary adapter tests pass together with zero failures or skips in 21.497 seconds, including five new List-completion cases. The actual XCTest summary is retained. Mac metadata extracts nineteen actions, three entities and three queries, matching the prior catalog plus this contextual action exactly. The production app and native UI target also compile for the generic iPhone/iPad Simulator destination with matching metadata. All 989 frozen source/configuration inputs match the current source in both packets. Timings above are XCTest durations, not physical performance measurements.

The generic unsigned iOS device build passes and embeds one mobile Share extension; both executables are arm64. Device metadata matches the same catalog and all 989 device-build inputs match this checkpoint. Existing ad hoc Mac signing is reused; mobile configurations remain unsigned. Affected strict Swift/Markdown lint and final Git whitespace checks pass. No Core contract/schema, backup format, dependency, target or native UI changes are introduced. No device is installed or launched.

The compatibility evidence uses `app-intent-list-completion-*` packet names and retains actual commands, source epochs, original logs and result codes, including the missing-action red.

Actual Shortcuts/Siri discovery/invocation, background/locked execution, system bulk confirmation, native capture invocation and explicit unverified-outcome fault qualification remain open. Existing temporary-store cleanup can unlink SQLite files while SDK-retained stores still hold connections; original logs retain those warnings. These checks establish neither clean shutdown nor a production integrity defect. Richer Intent fields, itinerary contextual actions, reorder/scheduling actions, Q100 B signed Agent Control/reader/real clients, account-bound CloudKit, installed Share, physical performance and feature-complete whole-app polish remain on the map. No signing/account/entitlement change, physical installation or whole-map completion is claimed.
