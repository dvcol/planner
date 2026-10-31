# Complete native Item traversal

Status: complete native title/identity observation passes on phone and tablet. The apparent tablet blank-row observation is resolved by original-file pixel verification below. This implements an open local completeness check from the Navigation map; it requires neither signing nor Mac UI access. The [22 October reconciliation and fixture follow-up](native-item-windows.md#scale-evidence-and-current-fixture-follow-up-22-october-2026) verifies that these runs already used the moving-window loader, preserves their original epoch and records current page-boundary/rotation regressions separately.

## Context, readiness and goal

The existing fixture contains 5,000 Items and 200 Lists. Core traverses every Item in eight ordered query scenarios. Native journeys reach Item endpoints and observe every List, but do not establish observation of every intervening Item row.

Use the already accepted Q34 native UI boundary and Q52 dedicated fixture. Keep the production app, fixture data, query contracts and loading implementation unchanged. The goal is a complete native title/identity observation through overlapping touch drags, rather than inferring every row from endpoints or Core counts.

## Required observable outcome

Observe every title from Scale Item 00001 through Scale Item 05000 in the unfiltered alphabetical catalog. Each must have a nonempty row frame contained in the catalog and an actual hittable native control. Every title keeps one source identity, all 5,000 identities are distinct, and visible titles remain ordered. Open the final source and retain its expected notes and Todo state.

The controller reads Apple's public native snapshot once per observation to obtain frames, titles and identities together. Each previously unseen candidate also requires a live hittability check. Visible loading rows must finish before moving onward. This reduces repeated accessibility round trips without replacing native observation with private state or fixture-generated result identities.

No new test interface, production instrumentation, data hook, package or target is introduced. This qualifies existing behavior and makes no artificial product-red claim. Core unit qualification is reused; a unit test cannot establish native rendering or touch reachability.

## Evidence and remaining scope

Record the focused fixture build, exact commands, complete observed title/identity attachment, native results, original captures and changed-file lint. Execute phone first to qualify the controller, then tablet if that evidence supports continuing. Treat incomplete traversal or setup failure as incomplete evidence.

This check does not establish pixel readability of every row, all sort/filter combinations, total-memory bounds, scrolling hitches, the physical 300 ms target or Mac behavior. Existing physical, sync/account, installed Share, protected Agent Control and whole-app acceptance gates remain open.

## Initial local outcomes

The focused mobile and Mac fixture builds pass. Mac receives compilation credit only. After the phone crosses multiple page boundaries, the same compiled test starts on a separate tablet Simulator with dark appearance and Increase Contrast. These overlapping runs are completeness checks, not performance measurements.

The first tablet attempt fails in 125.905 seconds at its initial Items-button precondition, before any Item traversal. Its original hierarchy shows the ordinary Choose a List and Choose an Item panes with a Show Sidebar button. Items is inside the collapsed sidebar. The existing native navigation helper can reveal that sidebar, but the new test waits for Items before calling it. This is a test-driver readiness error; the attempt supplies no traversal result. Appearance and contrast are restored after the failed attempt.

The first phone attempt reaches the final row, completes both explicit 5,000-title/identity-set assertions and opens the expected far-end notes. The complete function fails in 3,678.333 seconds at its final completion check. The new driver mistakenly uses the button-only mobile plannerElement helper for a native toggle. Its query diagnostics contain no matching Button. The original final-catalog capture was inspected; no complete-journey pass or final-state value is claimed. The deferred identity attachment is also absent after XCTest aborts the function, so it supplies no complete exported title/identity list. Source and product hashes remain unchanged throughout this attempt, and appearance is restored.

The corrected driver admits the actual Items or Show Sidebar entry point, then uses the existing navigation helper. Before the long traversal, it opens the first source, checks its real completion element through the existing role-independent query, and returns to the catalog. It records the complete observed title/identity attachment immediately after traversal, before the final assertions.

That preflight passes the real toggle check on both devices. Tablet then fails in 25.550 seconds because the existing return helper expects a Back button; its catalog exists but remains non-hittable. The phone retry is deliberately interrupted after that discovery to correct the shared helper before another long traversal. It has observed 65 identities at its last logged checkpoint and supplies no complete result. Its recorded process exit is -15, rather than a test pass. Both Simulator appearance wrappers restore their original settings.

The class now shares the actual Items/sidebar readiness path across its three journeys. The first return-helper revision passes the existing phone boundary/rotation journey in 122.924 seconds, but tablet fails in 25.820 seconds. Its captured hierarchy places the Item catalog beside the selected detail, then shows the root sidebar covering it after the helper opens Show Sidebar. A container's accessibility hit point is not a reliable proxy for its child controls. Availability now requires a real hittable source row whose frame lies inside the catalog. Only a genuinely unavailable catalog invokes native return navigation.

With that correction, the existing boundary/rotation journey passes in 123.629 seconds on light phone and 134.413 seconds on dark tablet with Increase Contrast. Both retain the selected source across page changes and rotation, and restore appearance afterward. The focused fixture build passes. The exhaustive runs use that same frozen source/product epoch on both devices. Their four-hour execution allowance belongs only to the test runner; no app or agent timeout changes. All failed and interrupted attempts remain retained.

## Complete observation results

| Device and appearance | Native result | Independently verified observed pairs |
| --- | --- | --- |
| iPhone Simulator, light | One pass, zero failures/skips, 3,683.373 seconds | All 5,000 expected titles and distinct source UUIDs |
| iPad Simulator, dark with Increase Contrast | One pass, zero failures/skips, 3,565.451 seconds | All 5,000 expected titles and distinct source UUIDs |

Each original attachment contains exactly 5,000 sorted title/identity pairs. A separate verifier checks the complete literal title set, unique parsed UUIDs and byte-for-byte equality of the retained compressed attachment with the original export. Both native journeys open Item 05000, read its expected notes and verify Todo. Source/product hashes still match their recorded epoch. Appearance and contrast return to their original values. These execution times include automation and do not measure app performance.

Three original final captures were inspected. The phone detail and tablet selected detail show Item 05000 with its expected notes, Todo toggle and 91-minute estimate. The tablet's preceding catalog capture was initially misread in its scaled preview as showing blank rows. The [row-paint investigation](native-item-row-paint.md) independently decodes that untouched PNG: all fourteen visible row regions contain painted glyphs and have identical RGB bytes to both passing native paint captures. A full-resolution inspection confirms the sample title and duration. That original-file evidence corrects the initial interpretation; no production rendering defect or style fix is established. This remains separate from all-row pixel, whole-app accessibility and physical-performance qualification.

## Recorded artifacts

The compatibility evidence directory contains the native-every-item build epochs, initial traversal attempts, phone-native-item-navigation-regression, tablet-native-item-navigation-regression, and the final phone/tablet native-item-visible-row-regression packets. Packets preserve exact commands, source/product hashes, compiler or native logs, exit status, appearance restoration and selected original attachments. The phone-native-every-item-final and tablet-native-every-item-final packets include terminal summaries, complete original identity attachments and independent verification records. The deliberately interrupted retry has no readable completed xcresult; its original runtime log and interruption record remain retained without completion credit.
