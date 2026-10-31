# Retained Link editing in Shortcuts

Status: both edit actions and seven new production-interface cases pass locally, alongside the 18 existing Link cases. All 69 affected declarations and Mac/Simulator/unsigned device builds pass. Actual system picker injection remains unqualified; signing stays deferred.

## Context, starting state and goal

At `41ff8ead`, Shortcuts can read and add owned Links but cannot change a retained bookmark. Core already supports complete guarded Links replacement, preserving retained identities and intentional duplicate URLs. Add Item/Itinerary bookmark editing without interpreting cached URL, label or position as current content.

## Definition of ready

Q33 authorizes ordinary data edits. Q112 approves production App Intent/EntityStringQuery tests using Apple's invocation/dependency interfaces and actual disposable storage/filesystem failures. The existing optional-text convention leaves omitted fields unchanged and clears optional text when explicitly empty. Core commands, field guards, link ownership/lifetime validation and truthful recovery outcomes already exist. No public Core/wire contract, target or test hook is added.

## Resulting behavior

Edit Item Link and Edit Itinerary Link require their typed owner and exact native Link. Optional URL and label fields select changes; at least one must be provided. Empty label text clears the label. A URL cannot be cleared and must satisfy Core's existing absolute HTTP(S) validation. Other authored label text, including spaces and Unicode, is preserved.

The handler checks owner identity, reads current saved Links, finds the exact bookmark ID and constructs a guarded ordinary edit. Omitted values come from current storage, and the saved order is retained even when the supplied Link contains older values. A removed identity fails rather than selecting a same-URL sibling. Referenced Item bookmarks remain separate from an Itinerary's own Links. Other content, relationships, completion/archive state, progress, estimates and bookings remain intact.

Actions return native confirmation dialogs. Incomplete recovery reports the locally applied change and blocks another mutation until native recovery acknowledges the same operation. Unverified outcomes require recovery review. No post-save read, global completion action or recovery administration is introduced.

## Native picker declarations

The existing Link query now conforms to EntityStringQuery and declares each edit action's owner dependency, following the established itinerary-entry pattern. It returns choices from the selected owner, in saved order, using Foundation's localized standard comparison for URL/label matching. Without an owner it offers no global suggestions; exact identity resolution retains its existing behavior.

Artifact inspection found that the initial default-query parameter declaration omitted an explicit query identifier. Both Link parameters now explicitly use PlannerLinkEntityQuery, and extracted metadata verifies that binding. The before-correction metadata is retained separately. Direct tests qualify unscoped search, cancellation, unavailable-storage failure and exact identity reads. Actual system dependency injection and positive scoped picker/search interaction remain open; they are not inferred from those tests or metadata.

## Definition of done and test evidence

The first edit case fails at runtime before implementation and passes afterward for both owners. Seven new XCTest cases verify retained identities/classification, duplicate siblings, live values despite stale cached entities, explicit clearing, saved order, foreign/removed identity rejection, atomic invalid-input failure, precancellation, archived/completed owners, planning references/bookings, unavailable storage and actual post-save recovery failure/repair. Tests reuse the established real-store fixtures across test files; production signatures gain no test controls.

The final new suite passes seven cases in 0.755 seconds. The affected run passes 63 XCTest cases in 15.450 seconds and six real HTTP Swift Testing declarations in 0.857 seconds, with zero failures/skips. One HTTP declaration has two owner cases. All 74 final marked fixtures are disposed after host/SQLite closure, with empty compiler and SQLite lifetime diagnostics. The expected-red fixture, one initial-green fixture and 28 safety-run fixtures are also disposed only after verified closure, preserving each original result.

Mac, the actual Simulator app/native UI-test target and unsigned generic device builds pass. All three verify 1025 identical frozen inputs. Only the native Link file and shared test-helper visibility change among previous inputs; one new test file is added. Every other prior input remains unchanged. Native metadata has 49 actions and the original eight entities/queries. The two additions have correctly typed required owner/Link fields, optional URL/label Strings and dialog-only outputs. All 47 prior parameter/output contracts, entity properties and enum cases remain unchanged. Only the Link query's advertised search capability changes. The device app embeds one arm64 mobile Share extension alongside its arm64 app. Strict affected Swift/Markdown lint and platform type checks pass.

The evidence directory retains `app-intent-edit-links-*` packets with original commands, exits, logs, source overlays/hashes, result summaries, before/after query metadata, catalogs, product checks and fixture-lifecycle reports.

## Remaining map work

[Native Link removal/reorder](native-link-removal-reorder-intents.md) subsequently implements those local workflows. Other richer Intent fields/reads, scheduling/capture/bulk actions remain. [Q115](../native-estimate-intent-input-review.md) still needs the estimate-input choice. Actual Shortcuts/Siri discovery/invocation, system picker injection, background/locked launch, signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical qualification and feature-complete whole-app UI polish retain their separate gates. No account/signing setup or device installation occurred; the map remains incomplete.
