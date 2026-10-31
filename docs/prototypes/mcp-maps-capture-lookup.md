# MCP Maps capture lookup

## Context and goal

Before this slice, Core had qualified selected-link Maps lookup, but the authenticated MCP endpoint did not advertise or route it. Agents could prepare, edit, review and save a capture without observing its temporary Maps preview.

The end state exposes the already accepted `planner_lookup_capture` contract through the existing official Swift SDK and stateless authenticated listener. Core retains provider eligibility, explicit HEAD hops, deadlines, draft ownership and obsolete-result protection. The adapter validates and encodes the declared values; it adds no independent save, retry, conflict or administrative policy.

## Definition of ready

- Q33 accepts the [capture adapter contract](../adapter-contract.md#capture-preparation-and-apply), its UUID fields and failure/result encodings, and the authenticated HTTP test boundary.
- Q78 A accepts the production HTTP I/O boundary used by [Core Maps lookup](core-maps-capture-lookup.md). Controlled provider responses enter that production interface; the actual adapter requests still use the real loopback listener and SDK.
- C1/C11/C12 retain original bookmarks, temporary provider candidates, editable partial capture and Add without waiting. Agent review/apply remains a legitimate authorized flow under Contract Q2.

## Definition of done for this slice

- Advertise lookup with required `formatVersion`, `draftId`, `generation` and `linkId`, rejecting additional fields. Declare external-world access in the tool metadata, without classifying it as destructive.
- Route only through the authorized dataset handler and Core's lookup facade. Preserve exact originals, unchanged owned content and save permission while encoding loading, available and unavailable preview states.
- Reject malformed versions/UUIDs, unknown fields, foreign/stale draft bindings, foreign links and non-Maps selections before outbound I/O. Revoked access fails at the real HTTP boundary.
- Prove review/apply can complete while lookup is pending, followed by a real controlled transport result delivered after cancellation that cannot change the saved Item or recreate the draft.
- Keep existing capture, source, command, review, replay and authentication behavior passing. Run scoped native Mac app/test-host checks and strict lint before committing.

## TDD and qualification

The first method selector matched zero Swift Testing functions, so its successful Xcode status was not qualification. Rerunning the selected capture suite executed five functions and reproduced the missing lookup discovery requirement. Advertising and routing the tool fixed that failure.

Controlled provider I/O then qualified preview field encoding, unchanged owned content/export, ten rejected request variants without outbound I/O, revoked-access HTTP rejection, pending-preview read plus reviewed Add, and an actual late response after cancellation. HTTP originals perform no lookup; unsupported contextual URLs keep an unavailable, usable partial capture without an automatic retry. Test storage is retained through the native test-host lifetime rather than deleted from live functions.

The final affected run passed 29 functions across eight suites, with 37 invocations and no failures or skips. The five new lookup functions cover six invocations; the rejection matrix additionally exercises ten distinct requests within one function. The macOS app and native test host compiled in that run. Three affected Swift files passed strict lint. The result bundle and normalized Swift Testing log agree on the completed outcomes; the log records the parameter invocations separately.

The named lookup fixture directories were cleaned after both the test command and its logged native host process had exited. No live native store was unlinked by a test function. Execution evidence records the exact commands, completed bundle summaries, diagnostics, source hashes and artifacts. Both source and spec reviews found no remaining confirmed findings and independently verified all eight source and ten artifact hashes.

## Remaining map gates

This slice does not qualify live Apple/Google services, native socket/physical allocation limits, the four real agent clients, native preview UI/Retry, Share or App Intents. Native Mac UI runtime, signed-device sync/account recovery, Calendar Q79-Q81 and pending Q82, scale/paging and whole-app polish retain their existing gates. Backup/export/recovery administration remains absent from agent tools.
