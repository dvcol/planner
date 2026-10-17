# Native Item catalog window contract

Status: Q95 A approved by the human on 17 October 2026. The production interface and test seam below are accepted for implementation; no loader or tests at this seam exist at this approval epoch.

## Context and starting state

Items and Inbox use a native SwiftUI List. `SavedPlannerStore.readItems` queries Core, reads every matching 64-row page, and accumulates the complete result before the view can display it. Scrolling renders rows lazily, but native presentation data is still retained for every match. Add existing Item has a separate on-demand ownership improvement; that change does not solve catalog windowing.

Q84 C keeps Core query generations readable while their dataset, session and history bindings remain valid. This proposal changes the native catalog's temporary row retention. It introduces no Core generation eviction, expiry, release operation, data limit or agent restriction.

## Goal and resulting behavior

Start with Items and Inbox. Display the first readable page without waiting for every matching row. Load other pages as native List rows become visible and release offscreen presentation pages. Preserve the full result's stable source identities, selected Item, filters, sort and search. List contents, itineraries and the two Item pickers remain follow-up clients; this first slice does not qualify their moving-window behavior.

The full Core identity sequence and Core's own captures remain in memory under the existing contract. Bounding native row presentations does not establish bounded total memory. Measure real retention, responsiveness and scroll behavior separately before claiming a performance budget.

## Proposed production interface

Add one app-internal native loader, used directly by the existing views. Keep it in the app target, without a new package, target or public Core/wire contract. It uses a real Planner and dataset session. Its caller supplies the existing typed `PlannerItemQuery` and lifecycle identity containing dataset namespace and saved revision.

The view-facing interface provides:

- Reload for a typed query and lifecycle identity.
- Request the page containing a visible row index.
- Cancel pending work when this catalog ceases to be active.
- Read the ordered stable source identities, matching count and loading/failure state.
- Read a row's loaded presentation or its loading/failure placeholder state.

Only those operations and observable results form the proposed test seam. The cache dictionary, task bookkeeping and eviction implementation stay private. No test-only initializer option, delay, callback or debug screen is added.

## Ordering, loading and failure rules

1. Core supplies filtering, sorting, count and the ordered identity sequence. The loader does not independently sort or reconstruct query membership.
2. Read the initial page of up to 64 rows before presenting ready content. An empty result is distinct from a failed query or page.
3. Keep presentation rows for the visible pages and at most one adjacent page on each side. Pages that cease to be visible or adjacent can be released. This limits temporary native row data, never the number of saved Items or accessible results.
4. Duplicate requests for a page share existing work. Released pages are read again from the same valid generation when revisited. Stable row identities do not change when their presentation is released.
5. A different query, dataset, scope or saved revision supersedes old work. Canceled or superseded completions cannot publish into the new result. Leaving and returning to the catalog must remain safe.
6. A stale-generation response discards the obsolete page result and refreshes the query. Never mix rows from two generations. Other failures show native failure and Retry states, preserving a usable surrounding view where possible.
7. Keep the selected detail attached to its existing source while valid, including when filtering hides its row or its presentation page is released. Confirmed deletion uses the already accepted first-visible-survivor behavior. Windowing must not change a command's global/contextual scope.
8. Native controls, keyboard navigation, accessibility and row selection remain available. Loading placeholders must not masquerade as saved content or actionable Item rows. Scroll anchors and variable-height metadata require actual native testing.

## Proposed tests and definition of ready

Q95 A confirms this production seam before its TDD tests. The existing macOS app-hosted `PlannerMCPTests` target can import the app and execute the loader's production interface against a disposable real local-only Core dataset. It already supports app-internal production interfaces through `@testable import Planner`; no signing account or new test target is needed.

Use literal expected identities and titles created through Core commands. Through the loader's own interface, verify the first page, crossing and revisiting page boundaries, filtered/sorted results, observable presentation retention, replacement query results and stale-generation recovery after real saved mutations. Tests must not query private storage or assert on private cache/task structures.

Real Core alone cannot deterministically suspend a request at every internal await. Do not use sleeps as evidence of an in-flight race. Qualify deterministic replacement/cancellation outcomes available at this interface, inspect publication guards, and use the existing native UI seam for live refresh and navigation. If a remaining critical delayed-response case requires another controllable production I/O seam, propose it separately before adding one.

## Native and compatibility qualification

Use the existing 5,000-Item fixture and actual scrolling, with no test-only jump control. Verify intermediate rows while traversing and returning, selected details across page release, query replacement, live edits, rotation and narrow/wide layouts. Compile affected mobile and Mac targets. Run qualified Simulator journeys serially. Mac runtime remains an explicit open gate until its existing UI automation startup issue is resolved; compilation supplies no runtime credit.

Run affected strict Swift lint and type/compiler checks, then source and specification reviews. Record exact executed outcomes, failed attempts and original own-window captures. Do not infer RAM, hitch or physical-device latency acceptance from page counts or compilation.

## Definition of done for the first slice

Items and Inbox no longer accumulate all row presentations before display. Their agreed query, selection, deletion and action semantics still hold. Tests at the approved loader and native UI seams pass within their stated scope, and evidence distinguishes measured behavior from remaining limits. Broader list/picker windowing, physical performance, signing and whole-app polish stay on the map.

## Review choice

The human selected Q95 A, approving this native interface, retention behavior and real-Core app-hosted test seam alongside the existing native UI seam. The unselected alternative was revising the contract first. Q84 remains settled.
