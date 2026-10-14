# Native capture HTTP transport

## Context and goal

Q78 A approves a production HTTP transport interface, controlled Core lookup outcomes and separate native delegate qualification. Before this slice, PlannerCore had no production module for a single header-only request. Higher-level Maps lookup remains unfinished.

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

No live Apple/Google request, physical Share lifecycle, socket allocation or iOS transport runtime qualification is claimed. The fixture verifies actual Foundation delegate behavior under controlled I/O; it does not establish wire-byte or memory limits for real senders.

## Remaining map work

Core must integrate the module, validate every provider URL/hop, implement the eight-second attempt and stale draft/operation protection, preserve original bookmarks on failure, and expose appropriate preview feedback through native and agent adapters. Controlled Core response tests, native socket/provider qualification, memory/lifecycle measurements, Share/Intents, Calendar implementation and whole-app polish remain open.
