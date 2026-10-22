# Native webpage new-window links

## Context, before and after

Q138 A accepts one Planner reader page. A website link reporting a new-window navigation must open in that page, with native Back returning to the previous page. Saved bookmark identities/URLs and the originating Item remain unchanged. The current delegate allows navigation but supplies no explicit new-window handling.

The target is the reported ordinary `target="_blank"` link. Unsupported scripted popups retain the native component's restrictions; this slice adds no tabs, window manager or download workflow.

## Definition of ready

Q132-Q141 accept the reader and navigation policies. Reuse the existing actual native UI seam and private loopback HTTP fixture. No direct controller tests, production injection, target or package are added. The installed Apple SDK's `WKNavigationAction.h` documents that a nil target frame identifies a new-window navigation. Actual SwiftUI WebPage behavior must still be observed.

## Required /tdd and definition of done

Create a real bookmarked Item through its native editor. Load Museum, follow an ordinary link to Garden with `target="_blank"`, and require Garden's rendered content and actual HTTP request. Go Back once to Museum, then Return to the exact saved bookmark and source. Record the unchanged test's failure before any necessary production correction.

Qualify the affected native behavior on phone/tablet, Mac compilation, strict affected lint and exact source/product/capture evidence. Ordinary linked-page recovery and same-pane replacement remain regression checks where changed. Do not infer scripted-popup, download, app-link, physical or actual Mac UI acceptance from this case. Signing remains deferred.

## Observed correction

The [native red](evidence/navigation/native-itinerary-window-compatibility/native-browser-new-window-red/test-summary.json) loads Museum and taps its real new-window link, then fails waiting for Garden. After the assertion, Xcode restarts its test harness and cannot collect Simulator diagnostics because its diagnostic process cannot locate `simctl`. The retained structured result still records one failed function; the later empty harness launch supplies no passing credit.

The [unchanged iPhone green](evidence/navigation/native-itinerary-window-compatibility/native-browser-new-window-green/test-summary.json) forwards the reported HTTP/HTTPS request into the existing WebPage, cancelling its original new-window disposition. The delegate keeps a weak page reference. Garden renders, Back reaches Museum once, and Return preserves the original bookmark identity/URL and Item. The [function comparison](evidence/navigation/native-itinerary-window-compatibility/native-browser-new-window-green/unchanged-test.json) matches both bodies. Its original capture is inspected. No additional page, controller test seam or saved-data change is introduced.

## Final local qualification

The new-window function passes on iPhone. The [affected phone regression](evidence/navigation/native-itinerary-window-compatibility/native-browser-new-window-phone-regression/test-summary.json) also passes both linked-page Retry and toolbar recovery functions. The [dark iPad regression](evidence/navigation/native-itinerary-window-compatibility/native-browser-new-window-tablet-regression/test-summary.json) passes new-window navigation, live reader replacement and delayed old-response handling. These are six executions of five distinct functions. All passing runtime invocations have zero failures/skips, SQLite unlink diagnostics, harness restarts and Simulator diagnostic-collection failures.

The [epoch reconciliation](evidence/navigation/native-itinerary-window-compatibility/native-browser-new-window-tablet-regression/epoch-reconciliation.json) matches all 1,070 inputs across these three runtime invocations and the [Mac build-for-testing](evidence/navigation/native-itinerary-window-compatibility/native-browser-new-window-mac-compiler/qualification.json). Each runtime's four products and Mac's nine products match at collection time. All six original captures are retained; the phone and tablet new-window captures are inspected individually. Strict affected Swift/Markdown lint and whitespace validation pass.

The earlier [eleven-function lifecycle checkpoint](native-webpage-lifecycle.md#final-local-qualification) keeps its own source epoch and broader reader coverage. This follow-up qualifies ordinary reported new-window links and the affected regressions above, not every browser function on both platforms again. Scripted-popup behavior, other new-window forms, downloads/external-app policies, persistent cookies, external-fallback target binding, source removal, layout changes, actual Mac UI and physical acceptance remain separately open. Signing stays deferred.
