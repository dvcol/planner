# Native collection Map integration

## Context, before and after

Q131-Q143 approve collection List/Map representations, exact counted-pin choices, an accessible Locations list, temporary provider resolution and native pane navigation. The [loader checkpoint](native-map-collection.md#final-local-qualification) supplies complete matching inputs and has twelve passing Mac production-interface cases. The app has single-location cards, but no collection Map control or presentation yet.

The first native slice opens Items as a Map without changing its filters or saved data. One Item has a coordinate-bearing Maps link; another has no location. The pin opens the linked Item's existing detail, while Locations can open the unlocated Item. Wide layouts retain the established detail pane; compact layouts push details. Source selection must retain the exact saved identity and lifetime and use the existing unsaved-draft guard.

## Definition of ready

Use the already approved native `PlannerNavigationUITests` seam and actual Planner creation/save/navigation. Reuse existing real preview facades and keep one `SavedMapCollection` per main window, preserving its occupied-operation accounting across query/dataset changes. No new target, package, signing setup, provider injection or production test control is introduced.

## Required /tdd and definition of done

Run the new native journey before implementation and retain the actual failing boundary. Add the smallest native Map, representation control and Locations presentation that passes it. Read the same complete Core query as List and keep valid detail selection. Do not rebuild an action target from a title, coordinate or route position.

Then qualify counted coincident markers and every exact appearance, missing/ambiguous/failed inputs and their native controls, source/appearance changes, cumulative filters, draft protection, representation switching and List/Itinerary integration. Use native MapKit, List, Menu, Form, Picker, ProgressView and standard split/navigation presentation. Preserve native light/dark semantics and check compact/wide, long titles, increased contrast, larger text and accessibility. Retain actual source/products and inspect original captures. Compilation alone does not qualify these interactions; Mac UI and physical gates remain separate where unexecuted.

## First native execution

The [original phone red](evidence/native-map-collection/native-items-map-phone-red/test-summary.json) creates both actual Items and fails at the missing representation control. After implementation, a second attempt reaches the rendered Map but fails because the test's existing generic helper assumes a Button. The captured hierarchy instead contains the identified Map container as Other, its actual pin Button and "1 of 2 items located." The [diagnosis](evidence/native-map-collection/native-items-map-phone-green/failure-query-diagnosis.json) preserves that failed result without passing credit.

Correcting only that element query gives a [passing phone journey](evidence/native-map-collection/native-items-map-phone-query-corrected/qualification.json). The pin opens the exact saved Maps URL. Back returns to the Map; Locations opens the unlocated Item and the previous source's link disappears. Map loading belongs to the main window, uses the same criteria as List and preserves its one operation coordinator across queries/datasets. Selection uses the existing draft guard and a fresh source-lifetime check.

Native large control sizing then gives pins and Locations more room, with a 44-point minimum for choice rows. The [final phone run](evidence/native-map-collection/native-items-map-phone-final/qualification.json) passes that Map journey and the existing catalog-completion/relaunch regression. The [dark iPad run](evidence/native-map-collection/native-items-map-dark-tablet/qualification.json) passes the same Map workflow using the detail column. Its recorded appearance is dark, Increase Contrast is disabled, content size is large, and the original appearance is preserved.

All three final native executions pass with zero failures/skips or SQLite unlink diagnostics. The two final original Map captures are inspected. Phone and tablet share 1,074 exact source hashes and four recorded executable products each. The [matching Mac build](evidence/native-map-collection/native-items-map-mac-compiler/qualification.json) compiles the app, Share and navigation-test targets with nine recorded products. It gives no Mac UI runtime credit.

## Remaining acceptance and observed limits

Items and Inbox now expose List/Map, but the executed new journey covers Items. List/Itinerary integration, coincident-marker choice and repeated local-completion scope still need their own native slices. Native address/link-choice and Retry controls, provider failures, filter/scope refresh, draft protection, representation switching and resizing/accessibility also remain open.

The inspected narrow portrait iPad capture truncates the inline Items title beside the four toolbar controls. That toolbar/column-width finding remains open. The fixture's exact single-point Map capture also does not establish useful geographic scale or tile-render readiness. These captures establish the represented workflow and ordinary light/dark presentation, not complete visual, increased-contrast, larger-text, VoiceOver, physical or whole-app acceptance. Signing remains deferred.
