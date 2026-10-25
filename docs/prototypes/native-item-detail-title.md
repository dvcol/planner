# One mobile Item detail title

## Context and scope

Mobile Item details now use one native navigation title. The original captures showed the title in both the navigation bar and the first Form section on iPhone and iPad. Global Item, standalone List appearance and itinerary appearance details each had that duplication. The user requested native hierarchy and removal of repeated headings; this is a focused correction before final whole-app polish.

Keep the mobile native title and the Form's useful state, subtitle, context, notes, estimates, labels, location and links. Retain Mac's in-pane heading because its shared window toolbar may describe the containing collection. Preserve identity, completion scope, navigation and saved content. No custom title layout, new presentation mode, public data interface or test seam is proposed.

## Global Item tracer

The existing native UI boundary hosts a new journey against the saved retired-membership fixture. It selects the real Item, verifies the native navigation title, then counts matching headings inside the actual Form containing the production completion Toggle. This separates the detail heading from any underlying catalog row. It also checks the global Todo state, original note and reachable actions.

The [original phone run](evidence/native-membership-consolidation/native-item-title-red/exit.json) fails because the Form still contains one title instead of zero while the native title is present. The capture remains an actual XCTest attachment. Xcode also reports a failure collecting additional Simulator diagnostics because its diagnostic subprocess cannot locate simctl; that happens after the exact title assertion fails and is retained separately from the product failure.

The first production change retains the global Item Form heading only on Mac. List and itinerary details remain separate follow-ups until their own native cases execute. No completion or saved-data rule changes.

The [unchanged global tracer passes](evidence/native-membership-consolidation/native-item-title-global-green/exit.json) after that mobile-only correction, including native actions, the retained note/global Todo and return to the same source row. Four actual products are verified before the next UI build reuses them. This is one scope, not acceptance of all detail contexts or platforms.

## List and itinerary appearances

The [List-appearance run](evidence/native-membership-consolidation/native-item-title-list-red/exit.json) and [itinerary-appearance run](evidence/native-membership-consolidation/native-item-title-itinerary-red/exit.json) each independently reproduce one repeated Form title with the native title already present. The List case creates a real membership through native Add; the itinerary case selects its existing saved route child. Both reach their exact duplicate-title assertion. The List correction then passes [its unchanged test and the global regression](evidence/native-membership-consolidation/native-item-title-list-green/exit.json).

Each Form now keeps that heading only on Mac. Mobile retains its native title and existing state/context/content controls. The three changes add no custom layout or stored state. Broader Calendar/reader caller acceptance, long-title truncation, resizing, accessibility sizes, actual Mac interaction and final whole-app review remain separate.

## Native readiness and retained failures

The first complete [phone cohort](evidence/native-membership-consolidation/native-item-title-phone-final/test-summary.json) passes all five functions. The corresponding [iPad cohort](evidence/native-membership-consolidation/native-item-title-ipad-final/test-summary.json) passes four and fails the itinerary journey before it reaches the detail-title assertion. That result remains failed.

The failed itinerary recording shows the catalog at eight seconds and the correct saved plan Form at ten seconds. The [unaltered extracted frames and their video provenance](evidence/native-membership-consolidation/native-item-title-ipad-final/failure-frame-extraction.json) retain that timing. The driver searched for a scrollable Form immediately after selecting the asynchronously loaded plan. It now waits for the exact plan title and full completion progress before finding the scroll surface. No production timing or test-only control changes.

The [readiness-corrected old-UI calibration](evidence/native-membership-consolidation/native-item-title-ready-itinerary-red/test-summary.json) substitutes only the original itinerary-detail source in the disposable build. It reaches the same duplicate-title assertion and fails with one Form heading instead of zero. Its [source record](evidence/native-membership-consolidation/native-item-title-ready-itinerary-red/calibration.json) verifies that the workspace stays unchanged. The corrected driver therefore still detects the original visual defect.

The [current phone cohort](evidence/native-membership-consolidation/native-item-title-phone-ready-final/test-summary.json) then passes all five functions with the corrected driver and current production UI. Both complete-history and partial-history membership journeys retain their original source and local completion across relaunch. The nine-function [Mac HTTP checkpoint and native compilation](evidence/native-membership-consolidation/native-item-title-adapter-mac/execution.json) use the same shipping sources. The [input comparison](evidence/native-membership-consolidation/native-item-title-build-input-comparison.json) records the single later difference, the iOS-only UI driver's readiness check. Nine actual Mac products and four phone products are hash-verified before reuse. This does not claim actual Mac UI execution.

Waiting for the owner alone is insufficient on iPad. The [second iPad cohort](evidence/native-membership-consolidation/native-item-title-ipad-ready-final/test-summary.json) again passes four functions and fails the generic scroll-container lookup. The driver now targets the existing production List identifier, `saved.itinerary.contents`, and performs the same bounded native scroll gesture inside that exact pane. This uses the accepted native UI boundary and introduces no production hook. The [iPad old-UI calibration](evidence/native-membership-consolidation/native-item-title-ipad-list-calibration-red/test-summary.json) then reaches the original title assertion and detects the duplicate heading. Both failed iPad cohorts keep their failed status; the successful membership functions within them remain distinct from the failed title journey.

## Final local checkpoint

| Boundary | Result |
| --- | --- |
| [Light iPhone title journeys](evidence/native-membership-consolidation/native-item-title-phone-list-driver-final/test-summary.json) | All three current functions pass, with no failure or skip. |
| [Dark iPad title journeys](evidence/native-membership-consolidation/native-item-title-ipad-list-driver-final/test-summary.json) | The same three current functions pass, with no failure or skip. |
| Complete/partial-history membership regressions | Both unchanged functions pass on each device in the earlier five-function epochs linked above. The failed iPad itinerary function does not change those individual results. |
| Mac build and HTTP | App, Share and fixture compilation plus nine real HTTP functions pass. The only later input difference is the iOS-only UI driver, as recorded in the [final reconciliation](evidence/native-membership-consolidation/native-item-title-final-verification.json). |

Both final mobile runs have 1,155 matching inputs, including the same production changes and final test driver. Four actual mobile products per run are verified; nine Mac products were separately verified. None of the final runs records a SQLite unlink warning. Strict Swift formatting, affected Markdown lint and whitespace checks pass.

All six final title captures are retained and directly inspected. Each shows the native title once and the original useful state/content. The List and itinerary cases retain their contextual state. The intermediate failure captures and result bundles remain available. Six closed passing Mac fixture stores were [safely disposed of](evidence/native-membership-consolidation/native-item-title-mac-fixture-cleanup.json). Four [byte-verified duplicate capture exports](evidence/native-membership-consolidation/native-item-title-duplicate-export-cleanup.json) were removed while preserving their originals, result bundles, compiled products, failures and Simulator datasets.

This closes the represented duplicate-heading correction. Calendar/reader caller journeys, long-name truncation, resizing/accessibility, actual Mac UI and feature-complete whole-app acceptance remain open. Q156's completion-history declaration and signed/physical/system qualification are separate gates.

## Calendar and reader caller follow-up

This slice uses the existing native UI seam, saved change-observation fixture and real loopback HTTP server. Create one Item booking through native controls, open that exact Schedule in Calendar, and require one native Item title without a duplicate Form heading. Open the saved guide and return to the same Item, preserving global Todo, original notes, the bookmark identity/URL and exact Schedule identity/value. This tests the phone navigation stack and iPad inspector as actual callers of the corrected shared Item detail. It introduces no production or test interface change. An isolated old-heading build must detect the original duplicate before current-source qualification.

### Calendar driver and calibration

The [first attempt](evidence/native-membership-consolidation/native-calendar-item-title-red/test-summary.json) stops before the heading assertion because the mobile button helper cannot select the completion Toggle. The [next attempt](evidence/native-membership-consolidation/native-calendar-item-title-toggle-red/test-summary.json) counts two matching texts, including the valid saved location name Hotel. The exact assertion now counts only a visible matching heading above completion. The [old-heading calibration](evidence/native-membership-consolidation/native-calendar-item-title-heading-red/test-summary.json) reaches that assertion and detects one duplicate while retaining the native title. The original capture is inspected; the saved location name remains valid content.

Two current-source attempts expose driver problems after passing the heading assertion. [Anchoring the Form lookup to a recycled completion row](evidence/native-membership-consolidation/native-calendar-item-title-phone/test-summary.json) loses its scroll target. The driver now uses native gestures inside the observed Form bounds. The [subsequent attempt](evidence/native-membership-consolidation/native-calendar-item-title-window-phone/test-summary.json) passes the guide round trip but expects the Items catalog immediately after switching tabs; that tab correctly retains its detail selection. The final driver uses native Back before checking the original source row. All failed invocations retain their failure status. No production change is made to accommodate these driver corrections.

The [tracer reconciliation](evidence/native-membership-consolidation/native-calendar-item-title-tracer-reconciliation.json) verifies the byte-identical prefix through the calibrated heading assertion and unchanged bodies for the three existing title journeys. The later changes concern reaching links and the retained catalog selection.

### Calendar caller local checkpoint

| Run | Executed result |
| --- | --- |
| [Light iPhone guide return](evidence/native-membership-consolidation/native-calendar-item-title-catalog-phone/test-summary.json) | One function passes: native title, actual guide GET/render, Return, unchanged completion/note/bookmark/booking and original source row. |
| [Dark iPad guide return and deletion](evidence/native-membership-consolidation/native-calendar-item-title-ipad/test-summary.json) | Both functions pass through the native Calendar inspector and existing deleted-source fallback. |
| [Light iPhone deletion regression](evidence/native-membership-consolidation/native-calendar-item-title-deletion-phone/test-summary.json) | The unchanged existing function passes, retaining the guide after deletion and returning to the surviving Calendar without recreating its source or booking. |

All four executions pass with no skip or SQLite unlink diagnostic. The [final verification](evidence/native-membership-consolidation/native-calendar-item-title-final-verification.json) matches all 1,155 inputs across the three successful runs and current workspace. Four actual mobile products per run are verified before reuse or after the final run. [Existing Mac build inputs and nine products](evidence/native-membership-consolidation/native-calendar-item-title-shipping-input-comparison.json) still match all shipping sources; only the iOS-only UI test differs. This test-only follow-up claims no new Mac compilation, HTTP regression run or actual Mac UI execution. Strict Swift formatting, affected Markdown lint and whitespace checks pass.

Ten original current captures are retained. Six are directly inspected: both title/Return captures on each device and the returned Calendar on each device, plus the separate old-heading calibration. The wide iPad captures retain the native inspector title, booking and owned location. The portrait deletion capture has an open sidebar overlay and supplies no unobstructed Calendar-layout acceptance. The fixture writer footer also supplies no shipping-layout credit. Three [verified duplicate exports](evidence/native-membership-consolidation/native-calendar-item-title-duplicate-export-cleanup.json) are removed while retaining every selected original, result bundle, failed run, product and dataset.

This qualifies the represented Calendar Item caller and valid/invalid guide-return paths. Other caller contexts, full layout/accessibility review, Mac runtime, physical/system acceptance and Q156's separate history declaration remain open. Signing stays deferred.
