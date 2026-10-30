# Native webpage rotation

## Context, before and after

The reader now supports live session replacement and ordinary reported new-window links. Its failure message belongs to the native view, while the WebPage belongs to the retained session. Rotation can change native navigation and layout. A successful stationary journey does not establish that the same failed or loading page remains usable across that change.

The target is unchanged website/source identity through portrait and landscape, with native Return and recovery available. Rotation must not create Planner data, substitute another bookmark or discard a visible failure. Actual Mac resizing and multiwindow transitions remain separate.

## Definition of ready

Use Q132-Q141's accepted reader workflow, the existing actual native UI boundary and real loopback HTTP fixture. No direct controller seam, production test hook, package or target is added. The rotation case runs on phone/tablet; Mac is not a device-orientation test.

## Required /tdd and definition of done

Start with a real saved Item bookmark whose HTTP connection fails. Require the native failure view. Rotate to landscape, observe the actual window geometry and require the failure/Retry/Return controls to remain usable. Rotate back to portrait, make the website available, Retry and require the original page, original bookmark identity/URL and Item after Return.

Observe a behavioral failure before any necessary production change. Keep actual native results, original captures, exact source/product reconciliation and strict affected compiler/lint checks. A passing existing implementation supplies compatibility evidence without an unnecessary production change. Loading during rotation follows as a separate vertical slice. These cases do not establish Mac resizing, arbitrary website layouts, all accessibility settings or physical-device behavior. Signing remains deferred.

## Failure-state result and pending-load case

The [first phone journey](evidence/navigation/native-itinerary-window-compatibility/native-browser-failure-rotation-phone/test-summary.json) passes without changing production. Both actual orientations retain the failure controls, and Retry recovers the original saved website. This is a compatibility pass, not a behavioral red.

Next hold a real page response after an explicit Museum-page link. Rotate while it is pending and require the native loading indicator and Return control. Release the response and require its distinct Delayed Guide content, then native Back to Museum and Return to the unchanged bookmark/Item. The fixture's delayed response gets its own literal title/body so the previously committed Museum page cannot satisfy the completion assertion. Requalify the existing old-response cancellation case against that fixture change.

## Final local qualification

The [final phone run](evidence/navigation/native-itinerary-window-compatibility/native-browser-rotation-final-phone/test-summary.json) passes both failure and pending-load rotation cases. The [dark iPad run](evidence/navigation/native-itinerary-window-compatibility/native-browser-rotation-final-tablet/test-summary.json) passes those two cases plus the existing old-response cancellation journey against the updated fixture. These are five final executions of three distinct functions, with zero failures/skips and SQLite unlink diagnostics. Planner production code is unchanged.

Both orientations are observed through the actual native window's dimensions. Failure controls remain usable; pending work retains its loading indicator and Return action. After release, the distinct Delayed Guide renders, Back reaches Museum and Return preserves the original saved identity/URL and Item. These are functional rotation checks. The retained captures occur after portrait recovery; they do not establish a complete landscape visual/accessibility audit.

The [epoch reconciliation](evidence/navigation/native-itinerary-window-compatibility/native-browser-rotation-final-tablet/epoch-reconciliation.json) matches all 1,070 inputs across both final runs and [Mac compilation](evidence/navigation/native-itinerary-window-compatibility/native-browser-rotation-mac-compiler/qualification.json). Each runtime's four products and Mac's nine products match at collection time. All five original final captures are retained; the phone/tablet pending-response captures are inspected individually. Strict affected Swift/Markdown lint and whitespace checks pass.

After those executions, strict formatting required wrapping one test-helper call. The [exact before/after comparison](evidence/navigation/native-itinerary-window-compatibility/native-browser-rotation-final-tablet/post-run-formatting.json) proves that replacement explains the entire source difference, with no changed statement, argument value or assertion. A separate [mobile build](evidence/navigation/native-itinerary-window-compatibility/native-browser-rotation-formatted-mobile-compiler/qualification.json) compiles that formatted source. The runtime captures and input/product manifests keep their original epoch; they are not relabeled as a post-format rerun.

Actual Mac resizing, narrow/wide column collapse/remounts, multitasking windows, arbitrary webpages, all accessibility settings and physical acceptance remain open. The two new orientation bodies are iOS-only; Mac compilation gives no device-rotation or actual Mac UI credit. Signing stays deferred. Q143 A independently approves native Map-loader work, which follows this checkpoint.

## Calendar reader through rotation, 31 October 2026

The existing Calendar-source journey now follows the Garden link before
rotating, observes actual landscape/portrait window dimensions, and requires
native Back and Return to remain usable. Back reaches Museum. Return preserves
the exact bookmark identity/URL and the original Schedule's full description.
Switching to Items and back to Calendar retains that same booking.

The light-phone execution passes in 89.912 seconds and dark iPad in 91.169
seconds, with zero failures or skips. All 254 native inputs are identical and
match the final workspace. No production correction is needed: this adds
compatibility evidence at the existing actual native UI and loopback HTTP
boundaries. It adds no target, dependency, test hook or provider seam.

Four original captures are inspected and retained in the
[review packet](evidence/native-webpage-rotation/calendar-2026-10-31/review.json).
The [phone landscape](evidence/native-webpage-rotation/calendar-2026-10-31/phone-landscape.png)
and [iPad landscape](evidence/native-webpage-rotation/calendar-2026-10-31/tablet-landscape.png)
show the loaded Garden page and native controls while Calendar stays selected.
Portrait captures retain the same page after returning from landscape.

Strict affected Swift lint, whitespace and Simulator/Mac test-target builds
pass. This qualifies the Calendar caller at ordinary Large text size, not
arbitrary scene destruction, every accessibility setting, third-party login,
physical devices or actual Mac interaction. No iCloud test or installed Mac
replacement is performed. The attended Mac runtime remains pending.
