# Native map and webpage workflow review

## Context, starting state and goal

The [product brief](product-brief.md) retains a filtered native Apple map with annotation-to-Item selection and an in-app webpage viewer. The [scope audit](local-scope-audit-2026-10-22.md) found neither complete. At the review starting point, compact maps showed one location and saved website links/rich cards opened externally. These existing features remain useful but do not establish the broader workflows.

The goal is a native secondary representation of the same Planner data, with live identities, coherent filters and useful webpage navigation. No new completion, archive, schedule, backup or provider-content policy is proposed by these workflow choices.

The user accepts Q131 A, Q132 A and Q133 A: collection List/Map modes, SwiftUI browsing in the detail area or compact pushed page, and ordinary website taps opening inside Planner. The alternatives below retain the reviewed context. Q134-Q141 also accept A. The concrete shared read and component qualification contracts follow those choices. Q127-Q130 retain their separate pending questions; independent implementation and qualification continue.

## Verified starting facts

At `85520780`, the shared `ItemLinksSection` and its rich-card component use SwiftUI Link. They are used by saved Item, contextual appearance and Itinerary details. There is no embedded webpage scene. The app targets OS 27, so the current native [SwiftUI WebView](https://developer.apple.com/documentation/webkit/webview-swift.struct) is available. Its surrounding browser controls and website-storage choice still need a concrete implementation contract.

The pre-made mobile [Safari view controller](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller) supplies standard browser controls. Apple requires modal presentation; it cannot be inserted into a split-view detail pane. Its website storage is managed differently from a configurable WebPage. It is a valid alternative mobile workflow, rather than an interchangeable pane component. The Mac target is native macOS.

At that commit, Core supplies cumulative Global, Inbox, List and Itinerary queries, complete matching identity sequences and row reads with owned locations. It has no dedicated map projection or coordinate-presence filter. `hasAddress` checks a formatted address, not a pin. The native loader retains only visible 64-row pages and neighboring pages; mapping those hydrated rows would omit other matching Items.

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

## Next frontier, Q134-Q141

Q131-Q133 are settled. The user also accepts A for every question Q134-Q141 below. The alternatives retain the reviewed impacts. Concrete data/component contracts and qualification follow these choices.

| Question | A | B | Main consequence |
| --- | --- | --- | --- |
| Q134, Map width/details | Wider preferred native collection pane with existing third-pane details; compact details push. | Main-width Map with selected details in a native popover/sheet. | Persistent side-by-side context versus more map width. |
| Q135, unresolved locations | Start bounded, cancellable temporary resolution while Map is open. | Require an explicit Resolve missing locations action. | Automatic usefulness versus control over provider requests. Both retain the complete matching set and explain unresolved/ambiguous results. |
| Q136, coincident locations | Counted marker with an exact native appearance-choice list. | Individual markers with a Locations-list fallback. | Clear overlap selection versus more direct individual markers. Both preserve exact contextual identities and an accessible location list. |
| Q137, website state | Apple's default persistent website store shared within Planner. | Memory-only website storage per Planner window. | Retained site logins versus state cleared when its window closes. Neither restores browser tabs/history or enters backups. |
| Q138, new-window links | Open reported requests in the current Planner browser page. | Open reported requests in the default browser. | Planning context versus external browsing. Unsupported scripted popups retain the native component's limitations. |
| Q139, downloads | Explanation and explicit external-browser fallback for downloads/unsupported content. | Integrated downloading and native file saving. | A focused reader versus additional native integration, file lifetime and failure handling. Displayable content remains inline. |
| Q140, external apps | Direct supported Mail/Phone/Maps clicks use the system; automatic app redirects offer an explicit Open action. | Immediately hand all reported supported app navigations to the system. | User-controlled automatic app switching versus fewer steps. Unknown/executable/file schemes remain unsupported. |
| Q141, removed source context | Keep reading, then return to the valid containing collection with an explanation. | Close browsing immediately and apply existing selection rules. | Preserved reading position versus strict attachment to a live source context. Neither recreates data or retargets contextual actions. |

The delegated SDK/source check confirms native exact-value [Map tags](https://developer.apple.com/documentation/mapkit/mapcontent/tag%28_%3A%29), configurable [website storage](https://developer.apple.com/documentation/webkit/webpage/configuration/websitedatastore), and WebPage navigation controls. It finds no general SwiftUI new-window-creation or download-result delegate. Ordinary new-window links and scripted popups therefore need actual qualification, not an assumed Safari-equivalent window manager. Earlier socket fixtures serve HEAD responses and do not establish WebKit rendering. The [first reader slice](prototypes/native-webpage-reader.md) now uses a private loopback HTTP fixture through actual WebKit GET requests and native UI to qualify page rendering, history/reload and valid returns. Cookie lifetime and the remaining navigation policies retain separate gates. Current app configuration contains no ATS exception.

Q142 A accepts the complete saved-data Map projection. The [implemented Core/HTTP read](prototypes/core-map-row-windows.md) returns offscreen saved locations and original Maps links with exact context. A Map built only from retained native pages would still omit matches. The [Q143 collection loader](native-map-collection-contract-review.md) is proposed; its additional direct test seam remains pending.

## Definition of ready

Q131-Q141 settle the navigation, location and browsing policies. Q142 A accepts the added public read declaration before its tests and implementation. The [Map-row contract](map-row-contract-review.md) reuses existing Item-query generations and the approved public Core/HTTP test boundaries.

The shared Map declaration is accepted and implemented. Q143 reviews native complete-collection loading and its additional direct test boundary. The first supported WebPage integration reuses the existing actual native UI seam and real loopback network I/O; no browser controller seam or production test callback is introduced. Broader direct testing still requires its own concrete review.

Reuse the existing public Core query/read and native UI seams wherever sufficient. Do not add production test-only controls. A new public declaration or direct app-hosted interface must receive its concrete review before tests. Keep the accepted contextual completion, draft protection, generation checks and manual administration boundaries intact.

## Definition of done and required /tdd evidence

For the map, exercise real saved data through the selected workflow. Cover cumulative search/List filters across every matching identity, offscreen matches, owned and temporary locations under the reviewed policy, missing/ambiguous results, co-located appearances and exact selection/action scope. Live edits, removal/deletion, dataset changes, cancellation and stale pages must not retarget actions. Qualify actual phone/tablet interaction and Mac resizing/keyboard behavior, with explicit empty/loading/error states. Physical allocation, latency and provider behavior retain their own gates.

For webpages, load an actual page through the chosen native component and exercise history, reload/failure, return/close and explicit external opening. Keep the original saved URL and selected owner/appearance identity truthful through source edits/removal and navigation. Test the reviewed external navigation, new-window and download policies at their actual boundary. Confirm website data remains outside Planner content/backups. Controlled HTTP/native-UI fixtures need a concrete plan rather than an ATS bypass or a live-website-only failure test.

Browser controls must also preserve the corrected shared Mac toolbar ownership: repeat the long-List-title selection/available-width checks with browsing open. Wide/compact navigation must protect edited drafts and preserve the exact source context; a removed origin follows Q141 A instead of retargeting an action.

Use the agreed production public interfaces for behavioral tests and the existing native UI boundary for rendered workflows. Inspect original captures on phone/tablet and qualify actual Mac layouts when its runner is available. Compilation, metadata previews, a single pin, a partially loaded viewport or opening the external browser supplies no aggregate-map/embedded-browser completion credit. Whole-app light/dark and accessibility polish remains after feature completion.

## Worked qualification fixtures

The map fixture should have 130 matching Items, with four eligible located identities at positions 1, 64, 65 and 130. Positions 65 and 130 share a coordinate. Every located identity must remain reachable even when only the first native row page is hydrated or earlier pages are released. A Category filter retaining positions 65 and 130 must exclude the other locations. A repeated Hotel in two itinerary entries retains two independent contextual selections; completing the second must leave the first locally Todo. Exact source/appearance IDs, not route positions, identify these actions. The reviewed missing-location policy supplies its own explicit zero/ambiguous/provider-failure cases.

The browser fixture should expose Page A with a link to Page B. Opening A, following B, Back, Forward and Reload must display the expected page while the saved bookmark remains A with its original identity. A controlled failed request followed by Retry must preserve saved content. Returning reaches the same valid owner/appearance; the reviewed source-removal policy supplies the deleted-owner outcome. The [first reader fixture](prototypes/native-webpage-reader.md) implements the two-page/history scenario at the existing native UI and real external-I/O boundary, without a production injection or ATS exception. Failed-request/Retry and source-removal outcomes remain unfinished.
