# Ordered Link reads in Shortcuts

Status: both reads, 12 Link cases, 50 affected adapter cases and Mac/Simulator/unsigned device builds pass locally. Q116 A subsequently approves generated bookmark references; the [separate Core amendment](core-owned-link-edit-results.md) is implemented. These read actions retain their original contract.

## Context, starting state and goal

At `db964299`, Item and Itinerary sources own ordered Links with stable identities. Native editors and Core expose them, but Shortcuts cannot read those collections. Add Get Item Links and Get Itinerary Links using the selected typed owner. Return native Link values in saved order, with distinct identities for intentional duplicate URLs. An Itinerary's own Links stay separate from the bookmarks of its referenced Items.

## Definition of ready

Q33 permits ordinary data reads; Q112 A approves production Intent and EntityQuery invocation with Apple's dependency manager and disposable real storage. Existing Item/Itinerary source reads supply the entire owned Link field. Reuse that interface and test seam. No new Core command/query, storage/wire schema, package, target or production test hook is required. The owner-first workflow follows Q114's scoped selection pattern.

## Native result and identity behavior

Each Link exposes its original URL text, a usable native URL, optional label, current owner title and one-based saved position. Display uses the label or original URL, with owner/position context to distinguish duplicate bookmarks. Position is display context, never identity. The native entity ID combines owner kind, owner UUID and bookmark UUID. This native-only identifier does not replace Core's typed identities or authorized dataset binding.

Entity resolution reads current saved Links for those exact owners, deduplicates repeated identities and retains caller order. Removed or malformed identities never fall back to a matching URL, another owner or a global operation. Without a selected owner, the default query suggests no global bookmark collection. The explicit Get Links actions select an owner first and return its ordered collection.

Original text remains exact; native URL conversion supplies an openable value without rewriting saved content. Core-owned classification/provenance remains in Core. These user-facing values do not invent provider evidence from URL text or expose technical metadata as editable properties.

## Required tests and definition of done

Record missing-action reds and real-storage passes for both owners. Verify order, duplicate identities, optional/empty labels, native URL conversion, owner/reference separation and unchanged content, identities, references and timestamps after reads/reopening. Qualify current-value entity resolution after owner/Link edits and ordering, removed/foreign/malformed selections, archived owners, empty collections, more than one 64-row page, cancellation and unavailable storage. Missing owners must fail rather than appear to have no bookmarks.

Run affected Intent regressions, strict lint and Mac/Simulator/unsigned device compilation. Verify metadata, native array/URL property contracts, source hashes and mobile Share embedding. Dispose owned fixture stores only after host and SQLite closure. Actual system discovery/invocation, picker conversion and physical performance retain separate gates; signing stays deferred.

## Initial vertical slice

The first Item read fails at its missing production action/query, then compiles and executes against real storage. One assertion incorrectly expects a `place-id` query parameter in ordinary bookmark text to establish an owned provider ID. Public Core source reads for that fixture have no such provider evidence. That failed run is retained without qualification credit. The native result is kept to useful bookmark content and context; Core classification/provenance and persistence behavior remain unchanged. Corrected ordered Item reading and exact identity resolution pass.

The corrected Item slice passes in 0.235 seconds, retaining three ordered Links including two equal URLs with different saved identities. Native URL values preserve the supported escaped spelling and optional labels. Itinerary reading records its missing-action red and passes in 0.080 seconds; its own route bookmark is returned without flattening referenced Item bookmarks. Both verify unchanged owner data and references after reopening.

## Safety and affected regression evidence

The first safety run passes 11 cases and fails one fixture before the Intent read. That new fixture supplied an unescaped Unicode URL, which the existing `encodingInvalidCharacters: false` validation rejects. A separate public Foundation probe confirms the raw form fails and its escaped form succeeds. No production URL policy changes. The corrected fixture uses a valid escaped URL and retains Unicode, empty and absent label checks. Failed qualification and owned-fixture cleanup remain explicit in the packet.

All 12 Link cases then pass in 1.499 seconds. Identity lookup refreshes live owner titles, URLs, labels and positions while retaining public bookmark IDs. Invalid/foreign/wrong-kind/deleted IDs do not retarget, including a removed bookmark whose identical-URL sibling survives. Empty existing owners return empty collections; unavailable or missing owners fail. Both owner kinds return all 130 saved Links without a 64-row truncation. Cancellation leaves source data intact. Archived/global completion, a locally Done membership and its booked Schedule remain unchanged by reads.

Actual post-save recovery obstruction qualifies read availability while further mutations remain blocked. Item and Itinerary Link reads and exact entity resolution succeed without acknowledging or replaying the incomplete operation. Native recovery later acknowledges the original edit without rewriting owner fields, references or timestamps. No recovery administration Intent is exposed.

The combined run passes all 50 affected Link, location, Item and Itinerary adapter cases with zero failures/skips in 18.658 seconds. The actual summary and log contain no compiler diagnostics or SQLite lifetime warnings. All 55 final fixtures, 12 corrected-safety fixtures, 12 failed-safety fixtures and three earlier Item/Itinerary fixtures are disposed only after verified host exit and closed SQLite handles. Missing-action compiler failures retain no runtime credit. These timings are adapter XCTest durations, not physical performance measurements.

## Platform and source qualification

Mac metadata retains all 43 prior action identities and adds the two Link reads, giving 45 actions, eight entities and eight queries. Each read has one required correctly typed owner and returns an array of the native Link entity. Its five properties include a native URL, original text, optional label, owner title and integer position. Every prior action parameter contract and enum case remains unchanged. All 1007 prior inputs are unchanged; two new production/test files bring the verified epoch to 1009 inputs. Strict affected Swift lint passes.

The actual Simulator app/native UI-test target and unsigned generic iOS-device builds pass with matching 45-action catalogs, Link array outputs, property types, owner parameters and prior enum cases. Both platform packets verify the same 1009 current source hashes. The device app embeds exactly one mobile Share extension and both executables are arm64. Strict affected Swift/Markdown lint, platform type checks and staged whitespace checks pass. No device is installed or launched and the existing ad hoc Mac setup is reused without signing/account changes. Compilation and metadata are not actual system invocation proof.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `app-intent-*-links-read-*` and `app-intent-link-read-*` packets with commands, actual exits, source hashes, native metadata, summaries and fixture verification. No Core result/wire/schema, package, target, entitlement or native UI change is introduced. System invocation, signed Agent Control, account-bound/shared storage and CloudKit implementation/proof, installed Share, physical performance and feature-complete whole-app UI polish retain their separate map gates. Signing remains deferred.

[Q116 A](../owned-link-edit-result-contract-review.md) approves a separate public edit-result amendment for returning newly added bookmark identities without another post-save read. Its Core implementation is qualified separately; native Add Link remains the next slice. [Q115](../native-estimate-intent-input-review.md) remains pending for estimate input.
