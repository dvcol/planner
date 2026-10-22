# Native webpage failure and Retry

## Context and goal

The [first reader](native-webpage-reader.md) renders saved websites and returns to valid sources. Its event task ends after a navigation error, while Retry clears the error and calls Reload. This does not establish repeated recovery, particularly when the initial page never loaded.

The target is a useful native failure view after each failed attempt, with Retry able to recover once the site is available. The saved bookmark's identity/URL and owning Item remain unchanged. Return remains available during failure. This slice does not add provider content to saved data, session administration or a new test boundary.

## Definition of ready

Q132-Q141 already accept native browsing and failure/fallback behavior. Use the existing actual native UI seam and the private loopback HTTP fixture's real external-I/O boundary. No direct reader/controller test, production injection, package or target is introduced.

Apple documents that each [navigation sequence](https://developer.apple.com/documentation/webkit/webpage/navigations) starts observing when created and terminates on navigation error. The production observer must cover later attempts rather than treating one sequence as a permanent subscription.

## Required TDD and done criteria

Serve bookmark metadata normally but close actual guide GET connections while the fixture is unavailable. Open the saved guide and observe the native failure view. Retry while unavailable: require another real request and the failure view again. Make the external fixture available, Retry again, then require rendered content and unchanged exact bookmark identity/URL after Return.

Observe the behavioral failure before changing production. Preserve that run and the unchanged test's passing correction. Then qualify the affected native reader cases on phone/tablet, native app/UI-test compilation, strict affected lint and exact source/product/capture evidence. Keep failed attempts distinct from passing results.

Initial repeated failure/recovery is the first case. Failure after navigating away from an already loaded page, cancellation/late responses and broader browser policies retain their own acceptance until actually exercised. Signing remains deferred.

## Observed initial recovery

The unchanged initial-failure test exposes two distinct defects. [The first run](evidence/navigation/native-itinerary-window-compatibility/native-browser-repeated-failure-red/test-summary.json) observes eight guide requests before Retry and no additional request afterward: native Reload has no loaded document to reload. Explicitly loading the saved URL fixes that request, but [the next run](evidence/navigation/native-itinerary-window-compatibility/native-browser-retry-request-red/test-summary.json) cannot observe the subsequent failure. The navigation observation task has already ended.

The [passing correction](evidence/navigation/native-itinerary-window-compatibility/native-browser-repeated-failure-green/test-summary.json) renews the native event sequence after errors and can load an initially failed page explicitly. It observes both unavailable attempts, actual content after recovery and the retained exact bookmark after Return. The [function hash reconciliation](evidence/navigation/native-itinerary-window-compatibility/native-browser-repeated-failure-green/tdd-function-reconciliation.json) proves the same test body in both failing runs and this passing run. Its original recovered-page capture was inspected. This is one iPhone case, not final cross-platform or complete failure acceptance.

The next [linked-page test](evidence/navigation/native-itinerary-window-compatibility/native-browser-linked-failure-red/test-summary.json) opens Museum successfully, follows the unavailable Garden link, makes Garden available and chooses Retry. It does not reach Garden. The [unchanged passing case](evidence/navigation/native-itinerary-window-compatibility/native-browser-linked-failure-green/test-summary.json) qualifies a main-frame request tracker through Apple's native navigation delegate. Retry targets the attempted HTTP/HTTPS URL, distinct from the saved bookmark and last committed page. The private tracker changes no Core request, saved content or backup format.

The toolbar's Reload control has the same initial-failure gap: [its red](evidence/navigation/native-itinerary-window-compatibility/native-browser-toolbar-recovery-red/test-summary.json) cannot recover the first guide. The [unchanged passing correction](evidence/navigation/native-itinerary-window-compatibility/native-browser-toolbar-recovery-green/test-summary.json) uses recovery while failure is displayed, keeping native Reload for successful pages. This one journey covers both the initially unavailable saved guide and a later unavailable linked page. Per-case function reconciliations are retained beside the green results.

A [separate history case](evidence/navigation/native-itinerary-window-compatibility/native-browser-recovery-history-check/test-summary.json) loads Museum then Garden, fails a Garden reload, recovers and goes Back once to Museum. It passes without another production change. This establishes the represented Back-history outcome rather than assuming an explicit reload/retry cannot add a history entry.

## Final local qualification

The [final iPhone run](evidence/navigation/native-itinerary-window-compatibility/native-browser-recovery-final-phone/test-summary.json) and [final dark iPad run](evidence/navigation/native-itinerary-window-compatibility/native-browser-recovery-final-tablet/test-summary.json) each pass all nine functions, with zero failures/skips and zero SQLite unlink diagnostics. These are eighteen executions of nine functions. Each run reconciles all 1,070 source/configuration/resource inputs and four actual products. All nine original captures per device are retained; the four recovery captures on each were inspected individually.

The [Mac build-for-testing](evidence/navigation/native-itinerary-window-compatibility/native-browser-recovery-mac-compiler/qualification.json) compiles the affected app/Share/UI-test targets and reconciles the same 1,070 inputs plus nine products. It does not launch Mac UI automation. No paid-team setup, protected Agent Control storage or physical qualification is inferred.

The controlled failures are closed HTTP connections, not a claim about every HTTP status, authentication challenge or website. This slice qualifies initial repeated Retry, failed linked-page targeting, toolbar recovery and the represented Back-history outcome. Cancellation/late responses, replacing a live reader session, layout changes while loading, external-fallback target binding, website cookies, source removal and the remaining navigation policies stay open. Strict affected Swift/Markdown lint and whitespace validation pass; whole-app polish remains after feature completion.
