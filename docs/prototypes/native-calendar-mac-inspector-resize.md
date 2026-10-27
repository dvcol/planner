# Mac Calendar inspector resize

## Context and current state

Q79 A requires Calendar to use the main content width with optional native inspector details on Mac and iPad. The existing approved native UI journey creates an Item and Schedule, selects that exact booking in Calendar, hides and reopens details, and resizes the Mac window from 1,200 to 860 points and back. Notes, Schedule identity, saved caption and visible content must survive. Signing remains deferred.

The recovered Mac runtime reaches those actions. The original mobile driver needed two native corrections: Mac segmented options are RadioButtons, and a SwiftUI count Text exposes its content as its value. The [Month read](evidence/navigation/native-itinerary-window-compatibility/native-calendar-month-count-value-mac/) passes in 19.625 seconds after the count correction. No production Calendar rendering or persistence changed for that pass.

The inspector journey now reproduces an application abort during narrowing. This is a local defect, not a completed qualification or a demonstrated signing problem. The [bounds probe](evidence/navigation/native-itinerary-window-compatibility/native-calendar-window-bounds-day-inspection-mac/) verifies that macOS and XCTest both report the owned window at 1,200 by 1,423 points before the drag. Planner exits during narrowing. The temporary AppKit/CoreGraphics observation code is removed; the retained production test checks actual process survival and window width directly.

The [scoped crash record](evidence/navigation/native-itinerary-window-compatibility/native-calendar-mac-crash-diagnosis/) retains Planner-only exception/stack fields and an exact process-log message. The corresponding run aborts with an uncaught NSGenericException after repeated window constraint-update passes, at observed width 1,158. The stack includes SplitViewChildController hosting-size invalidation. This does not prove an Apple defect independent of Planner's layout.

## Diagnostic outcomes

Every listed runtime starts one real journey and fails it, with zero skipped cases. Earlier presentation or identity assertions within a failed journey do not close any acceptance gate. Each linked packet retains the actual command, source/product hashes, terminal result and original scoped observations.

| Candidate | Actual outcome |
| --- | --- |
| [Month native control correction](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Fails notes lookup, 81.476 seconds. |
| [Owned-window Month inspection](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Fails notes lookup, 75.152 seconds; capture shows clipped inspector. |
| [Day comparison](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Fails narrow-width assertion, 73.146 seconds. |
| [Detail-column inspector](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Reaches narrowing, then fails notes hittability, 58.758 seconds. |
| [Flexible Month columns](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Fails narrow-width assertion, 78.084 seconds. |
| [Combined placement and columns](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Fails narrow-width assertion, 76.597 seconds. |
| [Independent window bounds](evidence/navigation/native-itinerary-window-compatibility/native-calendar-window-bounds-day-inspection-mac/) | Confirms matching pre-drag bounds, then Planner exits, 80.634 seconds. |
| [Calendar minimum omitted](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Survives this invocation but fails actual width, 56.504 seconds. |
| [Prior toolbar styling](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Reproduces process exit, 80.885 seconds; verified List styling restored afterward. |
| [Flexible Calendar outer frame](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Fails process survival, 80.068 seconds. |
| [Inspector leaf content](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Fails process survival, 74.069 seconds. |
| [Inspector inside the Calendar navigation stack](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Fails process survival, 77.800 seconds. |
| [Fixed inspector width](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Fails process survival, 77.994 seconds. |
| [Stable details-toolbar ownership](evidence/navigation/native-itinerary-window-compatibility/native-calendar-resize-iterations/outcomes.json) | Fails process survival, 72.561 seconds. |

Apple documents the supported [inspector placement choices](https://developer.apple.com/videos/play/wwdc2023/10161/?time=536). Neither placement is assumed to guarantee this app's resize behavior. All unsuccessful production variants above are reverted. Mac screenshots deliberately use Planner's own window. Broad automatic failure diagnostics remain private; public manifests retain their hashes and exclusion reasons.

## Q127 A, accepted 23 October 2026

The user selects A, a hideable native split pane beside Calendar on Mac. The same selected Schedule and Item/Itinerary content remain live, and hiding details returns width to Calendar. Planner owns pane presentation instead of the Mac inspector modifier. The iPad inspector and saved-data contracts stay unchanged. Implementation and actual resize qualification remain open; the earlier failed inspector runs retain their original outcomes.

## Definition of ready

- Q127 A resolves the Mac presentation. Existing Q79 selection and scheduling behavior remain authoritative.
- Keep the existing native UI seam, actual window drag and exact-identity assertions. No new package, target, test-only production hook or signed-storage workaround is proposed.
- Establish a failing actual resize journey before applying the chosen production change. The runs above already establish the current inspector failure.

## Definition of done

- Day, Week and Month preserve the same selected Schedule, live source, notes and saved caption across actual 1,200-to-860-to-1,200-point resizing, without process termination or content outside the window.
- Details can close, reopen and follow another selected entry. Hidden details stay hidden across resizing; a valid retained selection is not silently changed.
- Calendar reclaims width when details close. Toolbar controls remain reachable in narrow and wide layouts. Existing List headers and draft navigation remain intact.
- Preserve iPad inspector behavior through an affected native regression and compile the affected platform targets. Record every executed case, failure and skip, inspect deliberate owned-window captures, and run affected strict Swift/Markdown lint and whitespace checks.
- Keep signed sync/account, physical devices, system Shortcuts and whole-app polish as separate open gates. A passing local resize journey cannot close them.

## Accepted split-pane implementation, 23 October 2026

Q127 A now replaces the Mac inspector with native `HSplitView` beside Calendar. The existing selected Schedule/source binding and details stack remain authoritative. Hiding details removes that pane; reopening uses the retained exact selection. The iPad inspector modifier remains on its existing platform branch.

The [first matching Mac compiler packet](evidence/native-calendar-mac-split-pane/calendar-split-pane-mac-compiler/) builds the app, Share and existing native tests from 1,081 reconciled inputs. The [bounded Day runtime](evidence/native-calendar-mac-split-pane/calendar-split-pane-day-mac/) fails before the requested function starts because automation initialization times out. It has zero passing resize credit; the result bundle's failed runner entry is not an executed Calendar journey. No repeated unchanged broker/startup retry, signing setup or native Computer Use is requested.

Actual Mac Day/Week/Month resizing, detail-pane geometry, reclaiming width and interactions remain open. The original inspector crash and unsuccessful experiments retain their historical outcomes. Compilation alone does not prove the selected replacement fixes the crash.

## Local split-pane checkpoint

The final Mac implementation also contains Month's existing seven-column minimum inside a native horizontal `ScrollView`. Its viewport follows the available pane width while retaining a 560-point readable grid. The agenda stays in the Calendar pane. This avoids making the grid's minimum a window-width requirement, but actual Mac scroll/resize behavior is still unexecuted. No custom drag handling or new navigation state is added.

The [reconciliation](evidence/native-calendar-mac-split-pane/final-reconciliation.json) distinguishes two exact source epochs rather than crediting earlier results to changed inputs:

| Invocation | Actual result | Evidence |
| --- | --- | --- |
| Initial Mac compiler | App, Share and native test targets compile; nine products reconciled. | [Compiler packet](evidence/native-calendar-mac-split-pane/calendar-split-pane-mac-compiler/) |
| Bounded Mac Day journey | Zero requested functions start. Automation initialization times out, exit 65. No resize pass. | [Failed runtime](evidence/native-calendar-mac-split-pane/calendar-split-pane-day-mac/) |
| Dark iPad Month, Day and Week | Three functions pass, eighteen original captures inspected. Exact saved Schedule, Item and caption survive hide/reopen and actual orientation changes. | [Initial iPad epoch](evidence/native-calendar-mac-split-pane/calendar-inspector-regressions-dark-tablet/) |
| Final Mac compiler with Month viewport | App, Share and native tests compile; nine products reconciled. | [Final compiler](evidence/native-calendar-mac-split-pane/calendar-split-pane-month-viewport-mac-compiler/) |
| Final-source dark iPad Month | One function passes, six original captures inspected. Its 1,081 inputs exactly match final Mac compilation. Original appearance is restored. | [Final Month regression](evidence/native-calendar-mac-split-pane/calendar-month-viewport-regression-dark-tablet/) |

Only `SavedCalendarView.swift` changes between the initial iPad epoch and final sources, adding the Mac-only viewport. The final Month execution verifies the affected mobile regression on those exact final sources. The preceding three passing iPad functions retain their own epoch. Core, Share, fixture and test interfaces are unchanged. Affected strict Swift/Markdown lint and whitespace checks pass.

Q127 A is implemented and compiled, with affected iPad regression evidence. Its Mac acceptance gate remains open. Actual 1,200-to-860-to-1,200-point Day/Week/Month resizing, detail divider movement, hidden-pane width recovery and keyboard/accessibility require actual Mac execution. Signing remains deferred and is not inferred as the startup failure's cause.

## Manual-approval runtime checkpoint, 27 October 2026

The [shared-ruler checkpoint](native-calendar-shared-time-ruler.md) now records
actual Mac execution after manual automation approval. An intermediate cohort
passes Month, Day and Week through 1,200-to-860-to-1,200-point resizing while
retaining the selected Schedule, source notes and saved caption. The same cohort
fails its separate all-day date-entry driver before reaching that grid test.
It remains three passes and one failure. Final-source Mac runtime is pending;
compilation and strict signatures pass. Final dark-iPad Week inspector rotation
also passes. These results supersede the earlier lack of any actual Mac resize
execution, but do not close divider movement, explicitly measured hidden-pane
width recovery or broader keyboard/accessibility acceptance.

The subsequent [sizing and Mac follow-up](native-calendar-shared-time-ruler.md#accessibility-sizing-and-mac-follow-up)
also passes the native all-day End date workflow after correcting segmented
entry and popover dismissal. Three resize cases pass on the same production app
bytes. Their narrow capture still clips the sidebar; the test currently checks
retained details rather than the entire navigation area. That defect and the
remaining divider/width-recovery checks keep full Q127 acceptance open.

## Bounded split pane, 27 October 2026

Stronger native assertions reproduce the clipped sidebar at 860 points. Its
Lists control is at x = -90 while the enclosing split layout spans 1,081 points.
Removing the app-wide minimum instead makes macOS refuse the requested resize
below 1,081 points. These observations concern Planner's nested layout; they do
not establish an independent Apple SDK defect.

The Mac split view now receives the navigation column's actual width and height
through a GeometryReader. Its declared minimum is 600 points with both
300-point panes present, or 300 with details hidden. The existing native panes,
divider, app minimum and Schedule selection remain. Failed picker/frame/column
probes are removed; no additional controller or dependency is introduced.

The [evidence packet](evidence/native-calendar-shared-time-ruler/mac-pane-width/result.json)
retains a failing baseline, five unsuccessful layout probes, an early New Item
setup failure and the unchanged retry's passing Week execution. The final
source then passes all three Month/Day/Week journeys together: three passes,
zero failures and zero skips in 344.236 seconds. Each journey checks actual
1,200-to-860-to-820-to-1,200-point window sizes, all five sidebar destinations,
retained notes and the exact saved Schedule/caption. Hiding details recovers
more than 100 Calendar points. The actual native divider moves 40 points in
each direction without changing the selected booking.

Original final captures for all three modes are inspected. The retained
[before](evidence/native-calendar-shared-time-ruler/mac-pane-width/before-860.png)
and [minimum-width Week](evidence/native-calendar-shared-time-ruler/mac-pane-width/week-820.png)
captures show the sidebar correction. Current Mac and mobile compilation share
all 1,164 native inputs; the final Mac run verifies actual signed products and
keeps manual automation authentication required. The production change is
Mac-only. No signing resources, account settings or saved-data rules change.

These local checks qualify pane fitting, hide/reopen, width recovery and native
divider movement. Week can still leave the selected booking outside its
horizontally visible columns after resizing; compact header wrapping, broader
keyboard/assistive review and physical acceptance remain open. This does not
qualify shared storage, installed Share, CloudKit or account transitions.
