# Native capture HTTP transport

## Context and goal

Q78 A approves a production HTTP transport interface, controlled Core lookup outcomes and separate native delegate qualification. Before this slice, PlannerCore had no production module for a single header-only request. Higher-level Maps lookup was unfinished at this original checkpoint; its later implementation and controlled results are recorded in [Core Maps capture lookup](core-maps-capture-lookup.md).

This slice adds `PlannerCaptureHTTPTransport.head(requestURL:timeout:)`, returning Foundation's `HTTPURLResponse`. Its native implementation sends one HEAD request, refuses automatic redirects, cancels at the response stage, propagates task cancellation and applies the supplied request timeout. It accumulates no response body. The caller owns provider eligibility, each explicit redirect and the overall attempt budget.

## Definition of ready

- Q78 A accepts the production transport seam and controlled tests at the actual external I/O interface. Q18/Q19 require HTTPS provider eligibility, an eight-second attempt, four seconds per request and five redirects/six requests in the future Core orchestration.
- The real URLSession data and redirect delegates are the native implementation. A configured URLProtocol supplies controlled HTTP responses at Foundation's I/O interface; public capture APIs gain no test-only callbacks or flags.
- The standalone transport does not save content, promote provider metadata, modify a capture draft or expose administrative agent operations.

## Definition of done for this slice

- One operation sends HEAD and returns HTTP status/headers using Foundation's own case-insensitive header API.
- A redirect response is returned without following its proposed next request. Core can validate a hop before authorizing another operation.
- Cancellation before startup and while I/O is pending completes with CancellationError and cancels the native session.
- A pending request obeys the supplied timeout. Continuation completion is protected against competing terminal callbacks.
- Scoped native I/O checks and strict lint pass; the iOS app target compiles the same module. Qualified source and unfinished Core lookup remain separate.

## TDD and qualification

The first test failed because the production transport type was absent. An early URLProtocol fixture supplied headers without completing its HEAD response; Foundation reached the fixture but did not deliver the response delegate before timeout. Completing an empty HEAD response corrected the fixture. That failure is diagnostic evidence, not a transport qualification pass or proof about a live server's allocation behavior.

The controlled native checks cover HEAD/status/headers, a real Foundation redirect callback that is refused, cancellation before startup and during pending I/O, and a no-header timeout. They exercise the public transport interface and actual Foundation delegates. Core's provider/hop/draft rules still require their own facade checks.

The final scoped Mac run passed four functions in one suite, with five invocations and no failures or skips. Cancellation is deterministic: one task cancels itself before entering the module; the other waits for the actual URLProtocol startup signal before cancelling. Review identified that the fixture's startup observation could otherwise wait forever. That wait now has a two-second deadline and asserts startup; the request task is cancelled on every test exit.

Both affected Swift files passed strict lint. The iOS app target compiled the same production source successfully. Its initial build could not find deleted temporary dependency checkouts; resolving the existing pinned versions into a fresh task directory restored the build without changing Package.resolved. [Execution evidence](evidence/capture/http-transport/execution.json) records the actual logs, commands and final source hashes. Unfinished Core lookup was excluded from qualification.

That original checkpoint did not qualify live Apple/Google requests, physical Share lifecycle, socket allocation or iOS transport runtime. The fixture verifies actual Foundation delegate behavior under controlled I/O; it does not establish wire-byte or memory limits for real senders.

## Original remaining map work

At that checkpoint, Core still needed to integrate the module, validate every provider URL/hop, implement the eight-second attempt and stale draft/operation protection, preserve original bookmarks on failure, and expose appropriate preview feedback through native and agent adapters. The linked Core report and later capture reports retain their subsequent outcomes. The follow-up below records the current transport qualification limits.

## iOS runtime follow-up, 22 October 2026

The original four transport functions now pass through Xcode's generated PlannerCore package scheme on iPhone 18 Pro, iOS 27.0 Simulator. Its two cancellation arguments make five invocations, with no failures or skips. This uses the unchanged production transport and configured URLProtocol fixtures at Q78's approved external I/O boundary. No app, target, package dependency, signing or security setting changes are needed.

The [discovery packet](evidence/capture/http-transport/ios-discovery/) retains the generated scheme discovery. The [runtime packet](evidence/capture/http-transport/ios-runtime/) retains the command, original compressed log, structured results and explicit qualification. All 739 source/configuration hashes match the recorded committed package at `c794a35f`. The wrapper's original `runtimeCredit: false` means its exit alone supplied no qualification; the separate `qualification.json` records the inspected five passing invocations and their actual iOS execution device.

## Real-socket follow-up, 22 October 2026

The same approved public transport interface now has four loopback checks using Apple's Network framework in the existing test target. A private fixture binds only `127.0.0.1` on an ephemeral port. It reads the actual request line and supplies either headers, a redirect or no response. It leaves connections open so the test can observe client EOF/reset before fixture cleanup. All fixture startup/observation waits are bounded. Production source, default URLSession configuration, package settings, targets and dependencies are unchanged.

The checks establish these observable outcomes:

- The wire request is `HEAD /capture HTTP/1.1`; the caller receives HTTP 200 and the fixture header, then the server observes client closure.
- A real 301 response returns the original request URL and relative Location header. Following that Location would return 200, which fails the assertion. The connection closes.
- Cancellation waits until the server has received the complete request. The caller gets CancellationError and the pending connection closes.
- With no response headers, the one-second request times out with URLError.timedOut within three seconds, and the pending connection closes.

The first three additions passed individually through the growing Mac suite. Their [HEAD](evidence/capture/http-transport/socket-head-mac/), [cancellation](evidence/capture/http-transport/socket-cancellation-mac/) and [redirect](evidence/capture/http-transport/socket-redirect-mac/) packets retain their own source snapshots and actual results. They characterize existing production behavior; no production correction or manufactured failing baseline is claimed.

The completed suite passes eight functions and nine invocations on [Mac](evidence/capture/http-transport/socket-final-mac/) and [iPhone Simulator](evidence/capture/http-transport/socket-final-ios/), with zero failures/skips. Mac executes on macOS 27.0.1; iPhone 18 Pro executes iOS 27.0. The suite takes 1.025 seconds on Mac and 1.205 seconds on iOS, excluding compilation. Both final epochs and the current workspace match all 739 package inputs. The separate qualification files distinguish inspected results from the wrappers' provisional exit records. Scoped compilation and strict Swift formatting pass.

The iOS log retains Network's `SO_NECP_LISTENUUID` diagnostic and Xcode SDK-build parsing diagnostics. All selected runtime cases execute and pass; no app security exception or workaround was introduced.

## Live HTTPS observations, 22 October 2026

Two public coordinate links from [Apple's unified Maps URL examples](https://developer.apple.com/documentation/mapkit/unified-map-urls) and [Google's Maps URL examples](https://developers.google.com/maps/documentation/urls/get-started#search) now have live Mac observations. A temporary Swift executable compiles the exact committed standalone transport with a driver calling its public `head` interface and default configuration. It requests one hop per link with the accepted four-second timeout. It opens no Planner store and changes no app, target, package, signing or security configuration.

| Documented sample | Observed status | Elapsed |
| --- | --- | --- |
| Apple coordinate place card | HTTP 200 at the original URL | 0.638 seconds |
| Google coordinate search | HTTP 200 at the original URL | 0.320 seconds |

The calls ran at 19:15:28 and 19:15:29 UTC on 21 October, which is 22 October in the test Mac's timezone. The [observation packet](evidence/capture/http-transport/live-https-mac/) retains exact request/response URLs, timestamps, elapsed time, native stdout/stderr, compiler/lint commands, driver/source snapshots and hashes. The production hash matches the committed and current source. Strict Swift lint and compilation pass. The driver reports errors without disguising them as process failures; `qualification.json` separately verifies these two actual successful responses. They are manual observations, not additional unit-test invocations.

No response bodies, cookies, credentials or unrelated headers are recorded. HTTP 200 establishes a response to these two native HEAD requests; it does not establish a resolved POI, an owned address, preview retention, app presentation or a durable provider guarantee. These are long links with no observed redirect. Short-link expansion, provider-specific redirect chains, identifier-only enrichment, actual app/mobile provider journeys and installed Share retain separate gates. No TLS version or HTTP protocol negotiation was measured.

## Current remaining qualification

The controlled socket checks use plain loopback HTTP at the standalone transport boundary; the two live HTTPS samples above have their own narrower credit. Neither qualifies general provider behavior, TLS versions, HTTP/2 or HTTP/3, provider-specific redirects, a wire-byte/allocation ceiling, physical memory/lifecycle behavior, or the installed Share extension. Core's accepted provider, redirect-budget and stale-draft rules remain independently tested through the linked Core interface. Signed storage/account/sync, actual system Intents and final whole-app UI review remain separate map gates.
