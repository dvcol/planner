# Native webpage lifecycle

## Context and goal

The [reader](native-webpage-reader.md) and [recovery follow-up](native-webpage-recovery.md) qualify normal browsing, repeated failures and native history. They do not establish replacing an already visible reader, resizing during loading or late responses after cancellation.

On wide layouts, an Itinerary's saved links remain available beside its reader. Opening Museum then Garden must load Garden without requiring a return to the Itinerary first. Each request retains its exact bookmark and source context. Return must reach the valid originating plan, with both saved URLs/identities unchanged. An old load, observer or failure must not replace the new reading state.

## Definition of ready

Q132-Q141 already accept pane/page browsing, exact source context and the relevant navigation policies. Reuse the existing actual native UI seam and private loopback HTTP fixture's real external-I/O boundary. No direct controller tests, production test hooks, package or target are introduced.

## Required TDD and done criteria

First create an Itinerary with two real bookmarks through its native editor. Open Museum, then select the saved Garden bookmark from the still-visible plan pane. Require real Garden rendering, native history belonging to the new reader and the same two saved bookmarks after Return. This simultaneous-pane journey runs on iPad/Mac; compact iPhone has no second visible pane and is explicitly inapplicable.

Observe any behavioral failure before changing production. Keep the unchanged test's correction, affected ordinary reader/recovery regressions, native app/UI-test compilation, strict lint and exact source/product/capture evidence. Resizing, delayed responses, source removal, cookies and other browser policies remain separate until actually exercised. Signing remains deferred.

## Replacement result

The corrected native journey failed when Garden was selected beside the already visible Museum reader. SwiftUI retained the view's unkeyed task, so the new session never started loading. Keying that existing task to the session identity fixes the unchanged journey. The dark iPad run passes, including Garden's real GET, fresh Back history and preserved bookmark identities/URLs after Return. Its original capture is inspected. The earlier Add Link visibility failure was a driver error and supplies no behavioral-red evidence.

The [unchanged-function comparison](evidence/navigation/native-itinerary-window-compatibility/native-browser-session-replacement-green/unchanged-test.json) binds the corrected red to this green. The two wide journeys subsequently share an extracted native-editor setup helper; the final regression reruns both after that test-driver extraction.

## Delayed response check

Use the same native UI and real loopback HTTP boundary. From Museum, explicitly follow a page link whose response the fixture holds. Select the saved Garden bookmark from the adjacent Itinerary, require its rendered page, then release the old response. Garden, its new history and the original bookmarks must remain valid. Retain the actual socket-send outcome. A successful server send does not prove client delivery; a cancelled connection supplies cancellation evidence only. No production controller seam or network injection is introduced.

The [targeted dark iPad run](evidence/navigation/native-itinerary-window-compatibility/native-browser-delayed-replacement-check/test-summary.json) passes without another production change. The fixture observes one explicit `/delayed-guide` GET, holds its response until Garden is rendered, then records `contentProcessed` when releasing it. Garden remains rendered with fresh Back history and no failure overlay; Return preserves both exact bookmark identities and URLs. Its [original capture](evidence/navigation/native-itinerary-window-compatibility/native-browser-delayed-replacement-check/late-response-reader.png) is inspected. This establishes the observed native cancellation/replacement outcome after a server send; it cannot prove the abandoned WebPage received that data.

## Final local qualification

The [final iPhone run](evidence/navigation/native-itinerary-window-compatibility/native-browser-lifecycle-final-phone/test-summary.json) passes nine affected functions. Its two simultaneous-pane cases are explicitly excluded because that compact layout cannot present both panes. The [final dark iPad run](evidence/navigation/native-itinerary-window-compatibility/native-browser-lifecycle-final-tablet/test-summary.json) passes all eleven functions, including replacement and delayed-response handling. Both runs have zero failures, skips and SQLite unlink diagnostics. These are twenty final executions of eleven distinct functions.

The [epoch reconciliation](evidence/navigation/native-itinerary-window-compatibility/native-browser-lifecycle-final-tablet/epoch-reconciliation.json) matches all 1,070 source/configuration/resource inputs across both runs and the separate [Mac build-for-testing](evidence/navigation/native-itinerary-window-compatibility/native-browser-lifecycle-mac-compiler/qualification.json). Each simulator's four actual products and Mac's nine products match at collection time, before reuse of a build directory. Mac compilation covers the affected app, Share and UI-test targets and supplies no Mac runtime credit.

All twenty original final captures are retained. The final phone's List-appearance return and recovered-toolbar captures, and the final tablet's replacement and delayed-response captures, are inspected individually. The final tablet also records `contentProcessed` for the released old response. Strict affected Swift/Markdown lint and whitespace validation pass.

This slice qualifies the represented live replacement and cancellation outcome, ordinary reader returns, repeated recovery and history. Layout changes during loading/failure, persistent-cookie behavior, exact external-fallback targeting, reported new-window links, downloads/external-app policies, source removal, actual Mac UI and physical acceptance remain open. Whole-app UI polish follows feature completion; signing remains deferred.
