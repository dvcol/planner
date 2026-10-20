# Native List organization Intents

Status: Remove and Move are implemented. All 64 affected adapter tests and Mac, Simulator and unsigned device builds pass. Actual system invocation and physical acceptance remain open.

## Context and starting state

At `29a134d3`, App Intents can add an Item to a List, but cannot remove its membership or move it to another List. Core already implements both operations atomically. A List permits one membership per Item. Removing that association preserves the Item; moving creates a local Todo destination membership or retains an existing destination membership unchanged.

## Goal and expected end state

Add Remove Item from List and Move Item between Lists using existing Item/List entities and canonical Core commands. Resolve the current membership from the selected Item/List pair. Missing, deleted or removed references reject explicitly without changing action scope or substituting global deletion. Cached names, archive flags and completion never overwrite current data. A new Move destination appends in saved order; an existing destination keeps its identity, order and local completion.

## Definition of ready

- Q33 approves ordinary organization flows; permanent source Delete and recovery administration remain absent from Intents.
- Q112 A approves production App Intent invocation through Apple's dependency manager and disposable real Core storage, with public source/appearance reads and real recovery-filesystem failures.
- Existing Core commands, identity values and native platform configurations suffice. No new Core contract, target, package, test-only production hook or persistence format is needed.

## Required tests and definition of done

Implement one executable missing-action red and following green at a time. Reopen actual storage to prove precise removal, retained source/schedule/other memberships, atomic Move, new destination Todo and preservation of an existing destination's state/order. Qualify missing/deleted pairs, same-List Move, cancellation, unavailable storage and actual incomplete recovery without an automatic duplicate or replay. Keep truthful rejected, unverified and applied outcomes.

Run all affected adapter tests together, compile Mac, Simulator and unsigned device products, inspect actual metadata and extension embedding, and run affected strict Swift/Markdown lint and whitespace checks. Retain commands, source epochs, results and limits. Actual system invocation, signing and physical/account gates remain separate; this slice cannot complete the map.

## Executed removal slice

The missing Remove action throws after valid graph setup through the actual SDK invocation, 1.292 seconds. After implementation, the first behavioral run catches an incorrect test assumption that a List's references contain only its memberships. The public read also retains incoming itinerary entries. Correcting that expected value, without a production change, gives a passing 0.423-second removal journey.

Reopened storage retains the shared Item's title, notes, content hashes, Last updated and global/archive settings. Another List membership, the original List's surviving child's identity/order, the incoming itinerary List reference, the direct Item appearance and its inclusive all-day schedule remain intact. Only the selected membership becomes missing. Cached entity titles and state do not overwrite current data.

## Executed Move slices

The missing Move action throws after valid graph setup, 0.503 seconds. The canonical implementation passes in 0.291 seconds. The source's locally Done membership disappears; the destination appends a distinct Todo membership after its existing child. The original and destination Lists remain live itinerary branches, and the newly reachable destination appearance starts Todo independently. Another locally Done membership stays Done. Shared Item hashes, Last updated, global/archive settings and the all-day schedule remain unchanged.

Moving into an existing destination membership passes in 0.315 seconds without further production changes. The destination retains its original identity, middle position and local Done state. The source membership is removed, with no duplicate destination entry or global completion change.

## Failure and preservation qualification

Same-List Move, missing/wrong-kind references, absent Item/List pairs and natively deleted targets reject without partial source removal, 0.293 seconds. Rejected commands retain source references, hashes and Last updated; deleted Items and destination Lists remain absent after reopening.

Precancelled Remove and Move preserve an otherwise valid source membership and leave the destination empty, 0.096 seconds. Actual post-save recovery-file obstruction is exercised for both actions, 0.421 seconds together. The applied removal, or both sides of the atomic Move, remain durable while another mutation is blocked. Native retry acknowledges the original operation and preserves its exact references. A subsequent explicit re-add creates a fresh local Todo membership instead of resurrecting the original Done association. These qualification cases require no further production changes.

Unavailable storage rejects both actions, preserves the actual obstructing file and acknowledges no change, 0.006 seconds.

## Combined and platform qualification

All 64 affected Item/List/Itinerary adapter tests pass together with zero failures or skips in 22.785 seconds, including seven new List-organization cases. The actual XCTest summary is retained in the final packet. Mac metadata extracts eighteen actions, three entities and three queries. Its identifiers match the prior sixteen-action catalog plus Remove and Move exactly. All 988 frozen source/configuration inputs match the current source. Timings above are XCTest durations, not physical performance measurements.

The production app and native UI target compile for the generic iPhone/iPad Simulator destination. The generic unsigned iOS device build also passes and embeds one mobile Share extension; both executables are arm64. Mobile/device metadata matches the Mac catalog, and all 988 inputs match this checkpoint in both platform packets. Affected strict Swift/Markdown lint and final Git whitespace checks pass. Existing ad hoc Mac signing is reused; mobile configurations remain unsigned. No native UI, Core contract/schema, backup format, dependency or target changes are introduced. No device is installed or launched.

Packets under [the compatibility evidence](evidence/navigation/native-itinerary-window-compatibility/) retain actual commands, source epochs, original logs and result codes. Removal uses `app-intent-list-remove-*`, Move uses `app-intent-list-move-*`, and the remaining failure/combined/platform checks use `app-intent-list-organization-*`. The unsuccessful removal assertion is retained separately from the corrected passing journey.

Actual Shortcuts/Siri discovery/invocation, background/locked execution, system confirmation, native capture invocation and explicit unverified-outcome fault qualification remain open. Existing temporary-store cleanup can unlink SQLite files while SDK-retained stores still hold connections; original logs retain those warnings. This establishes neither clean shutdown nor a production integrity defect. Richer Intent fields, contextual completion/reorder/scheduling actions, Q100 B signed Agent Control/reader/real clients, account-bound CloudKit, installed Share, physical performance and feature-complete whole-app UI polish remain on the map. No whole-map completion, signing/account/entitlement changes or physical installation is claimed.
