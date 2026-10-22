# Native webpage persistent-cookie qualification

## Context and accepted behavior

Q137 A selects Apple's default persistent website store, shared by Planner windows. Website data remains separate from saved Planner content and backups. `SavedWebsiteSession` already configures `WebPage.Configuration.websiteDataStore` with `.default()`. Closing a reader releases its session; this choice does not restore browser tabs/history after launch.

The next local slice qualifies the existing behavior through the approved native UI and loopback HTTP fixture boundaries. It adds no production interface, test-only app control, provider injection, package or target. If the first real journey passes, report qualification of existing behavior rather than inventing a red/green implementation claim.

## Required journey and definition of ready

Extend the existing `BrowserJourneyServer` only in the UI-test target. Give this test a unique cookie name and a literal remembered value. The actual HTTP response sets a persistent, first-party, HttpOnly cookie only after the native webpage's Remember visit link is selected. The server renders the incoming cookie's state into the webpage. Observe only this test's unique cookie value, never unrelated request cookies.

First verify the visit is not remembered. Set it through the page, then verify it through another actual request. Return to the same saved Item, reopen its guide and verify the visit remains remembered. Terminate and relaunch Planner with the same disposable dataset, open the same exact saved bookmark and verify the cookie again. Finally clear only the test's cookie through an expiry response, verify it is absent, and return to the unchanged Item/bookmark.

Keep expected outcomes independent of the fixture's cookie parser: the native webpage must show the specified absent/present headings, and the recorded incoming test-cookie values must match the literal remembered value after each relevant request. Never accept a page heading that is rendered unconditionally.

## Definition of done and limits

Execute the native journey on phone and dark iPad, preserve original visibly painted browser captures and exact input/product comparisons, and run the affected reader regressions and Mac compilation. Strictly lint the touched Swift/docs. A passing mobile journey qualifies that first-party cookie behavior in the named native runtimes. It does not prove third-party cookies, actual third-party login, cross-window Mac behavior, browser history restoration or physical-device website sessions.

## First local execution

The [phone journey](evidence/native-webpage-cookies/persistent-cookie-phone/qualification.json) passes in 82.728 seconds. It observes the initial absent state, incoming remembered cookie after the native page action, persistence through a new viewer and actual app termination/relaunch, then the absent state after expiring only this test's cookie. The exact saved bookmark identity and original URL remain unchanged. Its original visibly painted Returning visitor capture is inspected. Matching [Mac app/Share/native-test compilation](evidence/native-webpage-cookies/persistent-cookie-mac-compiler/qualification.json) passes with no runtime credit. Production is unchanged from the Map provider-context checkpoint, so no red/green implementation claim is made. Dark-tablet and affected HTTP reader regressions follow.

## Final local qualification

The [dark iPad cohort](evidence/native-webpage-cookies/persistent-cookie-dark-tablet/qualification.json) passes persistence plus the two affected history/recovery functions. The [phone regressions](evidence/native-webpage-cookies/persistent-cookie-phone-regressions/qualification.json) pass the same two existing functions. Together with the initial phone persistence journey, these are six native executions across three functions. All six selected original captures are inspected, with native browser painting verified by the existing pixel-contrast assertion. The loopback fixture observes only the unique test-cookie value and expires it before the successful journey ends.

[Exact comparison](evidence/native-webpage-cookies/persistent-cookie-phone-regressions/source-epoch-comparison.json) matches 1,074 inputs across both mobile cohorts, the phone regressions and Mac compilation. Simulator packets retain four executable products each, Mac compilation nine. Passing native runs have zero failures/skips or SQLite unlink diagnostics; dark appearance is observed and restored. Production remains unchanged from 0924dde4. This qualifies the represented first-party persistent cookie and its expiry through viewer closure and actual app relaunch. It does not establish third-party login/cookies, Mac cross-window sharing, browser tab/history restoration or physical-device behavior.
