# Returning to a backgrounded webpage

Two existing native browser journeys now press Home, observe Planner running in
the background, reactivate it and require the foreground state before continuing.
The loading case keeps exactly one held HTTP request, its progress indicator and
Return control. Releasing the response after rotation displays the distinct
Delayed guide; Back reaches Museum. The failed-page case retains its error,
Retry and Return controls, then recovers the original guide after rotation.
Both return to the same saved bookmark identity and original URL.

The phone
and dark iPad
each pass both journeys, four executions without failures, skips or SQLite-unlink
warnings. The iPad's original appearance is restored. All 1160 native inputs
match both executed epochs; actual products are verified before build reuse.
The validation record
binds the results and four retained original captures inspected after recovery.
The phone title still truncates beside native history controls.

Only fourteen iOS-only test lines change. Production, providers, interfaces,
fixtures and targets remain unchanged. The affected native target compiles and
executes on both devices; strict Swift formatting and whitespace checks pass.
No new test seam or speculative production fix is introduced.

This closes brief background/foreground transitions with the same running
process. It does not establish suspension, process-death recovery, Mac window
remounts, physical behavior or full accessibility. The captures are after
recovery, not proof of the intermediate error/loading layout. Signing remains
deferred.
