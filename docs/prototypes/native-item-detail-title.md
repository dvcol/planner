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
