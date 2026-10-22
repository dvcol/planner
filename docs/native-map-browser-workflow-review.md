# Native map and webpage workflow review

## Context, starting state and goal

The [product brief](product-brief.md) retains a filtered native Apple map with annotation-to-Item selection and an in-app webpage viewer. The [scope audit](local-scope-audit-2026-10-22.md) finds neither complete. Current compact maps show one location; saved website links and rich cards open externally. These existing features remain useful but do not establish the broader workflows.

The goal is a native secondary representation of the same Planner data, with live identities, coherent filters and useful webpage navigation. No new completion, archive, schedule, backup or provider-content policy is proposed by these workflow choices.

This review is a proposal. Q127-Q130 retain their separate pending questions. The Share regression and compiler checks proceed independently.

## Verified implementation facts

At `85520780`, the shared `ItemLinksSection` and its rich-card component use SwiftUI Link. They are used by saved Item, contextual appearance and Itinerary details. There is no embedded webpage scene. The app targets OS 27, so the current native [SwiftUI WebView](https://developer.apple.com/documentation/webkit/webview-swift.struct) is available. Its surrounding browser controls and website-storage choice still need a concrete implementation contract.

The pre-made mobile [Safari view controller](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller) supplies standard browser controls. Apple requires modal presentation; it cannot be inserted into a split-view detail pane. Its website storage is managed differently from a configurable WebPage. It is a valid alternative mobile workflow, rather than an interchangeable pane component. The Mac target is native macOS.

Core already supplies cumulative Global, Inbox, List and Itinerary queries, complete matching identity sequences and row reads with owned locations. It has no dedicated map projection or coordinate-presence filter. `hasAddress` checks a formatted address, not a pin. The native loader retains only visible 64-row pages and neighboring pages; mapping those hydrated rows would omit other matching Items.

Global selection identifies an Item. A List or Itinerary selection must retain its exact membership, entry or expanded-appearance identity. Two appearances can occupy the same coordinate while retaining independent local completion. Coordinates cannot serve as selection identities. Existing temporary address/Maps previews do not authorize saving provider coordinates or silently resolving ambiguous locations.

## Q131 - How to reach the filtered map

An Item catalog, Tokyo Food List and Tokyo Weekend Itinerary can each have different filters and action scopes. Both options below must represent all eligible matches, not merely the currently hydrated row pages, and preserve the chosen scope's exact identities.

A. Add a native List/Map mode for the current Items, Inbox, List or Itinerary view. Changing representation retains that collection's filters and selection. This makes the map another way to inspect the current plan and avoids another main destination. It adds a view control to collection navigation, whose placement and narrow-width behavior need qualification.

B. Add a main Map destination with a scope selector for All Items, Inbox or a particular List/Itinerary. It offers a discoverable map entry point and can retain an independent map scope, but adds a sixth main destination and another scope-selection workflow. Choosing a contextual scope must still retain its local appearance identities.

Recommendation: A, following the brief's secondary representation of the current TODO data. The exact wide/compact pane arrangement follows this choice. It must not assume that the unresolved Mac Calendar inspector is safe to reuse.

## Q132 - Native webpage presentation

A saved guide should be readable inside Planner while keeping a clear route back to its Item or Itinerary. Both choices retain an explicit external-browser action and use Apple's web engine.

A. Use SwiftUI WebView/WebPage on all three platforms. Put browsing in the existing detail area on Mac/wide iPad and use a pushed page on compact layouts. Planner provides a small native toolbar for history, reload, return and external opening. This follows the brief's current SwiftUI API preference and preserves collection context, but requires qualifying that surrounding browser UI.

B. Use the complete pre-made Safari browser modally on iPhone/iPad; use SwiftUI WebView in the Mac detail area. Mobile gets Apple's standard browser UI, while iPad browsing temporarily covers the planning panes. This needs a genuine native modal-presentation bridge, not an embedded Safari child view, and leaves website sessions under that component's supported controls.

Recommendation: A for the accepted pane-based planning workflow and the brief's available SwiftUI API preference. B is the pre-made mobile alternative if its modal workflow is preferred. Website-session lifetime and detailed navigation/download policies follow this component choice rather than being silently assumed here.

## Q133 - Primary ordinary website action

Current website text links and rich cards open the system browser immediately. This decision concerns ordinary webpages; existing Maps-link/native-app behavior has its own accepted rules. Either viewer option above can support these opening workflows.

A. A normal tap opens the webpage inside Planner. A native contextual action opens it in the default browser. The in-app viewer is immediately discoverable and preserves planning context; external opening takes the additional action.

B. Keep normal tap opening the default browser. Add an explicit Open in Planner contextual action. This preserves the current primary interaction, but in-app browsing is less discoverable.

C. A normal tap opens a native menu containing Open in Planner and Open in default browser. Both paths are explicit every time, at the cost of an additional selection for every website. This adds no remembered opening preference.

Recommendation: A to make the accepted in-app browsing capability directly useful. No device preference or backup field is needed for these choices.

## Definition of ready

Review Q131-Q133 before implementing their dependent navigation. Then settle the next dependent frontier: complete map-location loading, overlapping appearances and missing/ambiguous-location presentation; browser website-session lifetime and navigation policies; and any changed public read interface or additional direct-test boundary.

Reuse the existing public Core query/read and native UI seams wherever sufficient. Do not add production test-only controls. A new public declaration or direct app-hosted interface must receive its concrete review before tests. Keep the accepted contextual completion, draft protection, generation checks and manual administration boundaries intact.

## Definition of done and required /tdd evidence

For the map, exercise real saved data through the selected workflow. Cover cumulative search/List filters across every matching identity, offscreen matches, owned and temporary locations under the reviewed policy, missing/ambiguous results, co-located appearances and exact selection/action scope. Live edits, removal/deletion, dataset changes, cancellation and stale pages must not retarget actions. Qualify actual phone/tablet interaction and Mac resizing/keyboard behavior, with explicit empty/loading/error states. Physical allocation, latency and provider behavior retain their own gates.

For webpages, load an actual page through the chosen native component and exercise history, reload/failure, return/close and explicit external opening. Keep the original saved URL and selected owner/appearance identity truthful through source edits/removal and navigation. Test the reviewed external navigation, new-window and download policies at their actual boundary. Confirm website data remains outside Planner content/backups. Controlled HTTP/native-UI fixtures need a concrete plan rather than an ATS bypass or a live-website-only failure test.

Use the agreed production public interfaces for behavioral tests and the existing native UI boundary for rendered workflows. Inspect original captures on phone/tablet and qualify actual Mac layouts when its runner is available. Compilation, metadata previews, a single pin, a partially loaded viewport or opening the external browser supplies no aggregate-map/embedded-browser completion credit. Whole-app light/dark and accessibility polish remains after feature completion.

## Worked qualification fixtures

The map fixture should have 130 matching Items, with four eligible located identities at positions 1, 64, 65 and 130. Positions 65 and 130 share a coordinate. Every located identity must remain reachable even when only the first native row page is hydrated or earlier pages are released. A Category filter retaining positions 65 and 130 must exclude the other locations. A repeated Hotel in two itinerary entries retains two independent contextual selections; completing the second must leave the first locally Todo. Exact source/appearance IDs, not route positions, identify these actions. The reviewed missing-location policy supplies its own explicit zero/ambiguous/provider-failure cases.

The browser fixture should expose Page A with a link to Page B. Opening A, following B, Back, Forward and Reload must display the expected page while the saved bookmark remains A with its original identity. A controlled failed request followed by Retry must preserve saved content. Returning reaches the same valid owner/appearance; the reviewed source-removal policy supplies the deleted-owner outcome. The concrete local HTTP/HTTPS fixture and component-specific test boundary remain part of the next contract, not an unreviewed production injection.
