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

## Q127, pending presentation decision

The question tool offers two concrete alternatives. A replaces only the Mac Calendar inspector with a hideable pre-made native split pane beside Calendar. The same selected Schedule and Item/Itinerary content remain live, and hiding details returns width to Calendar. Planner owns pane presentation instead of the inspector modifier. B opens Mac details in a native sheet, which blocks Calendar interaction while open and removes side-by-side comparison. Both retain the current iPad inspector and saved-data contracts. A is recommended; implementation waits for the human's answer.

## Definition of ready

- Q127 resolves the Mac presentation. Existing Q79 selection and scheduling behavior remain authoritative unless explicitly amended by that answer.
- Keep the existing native UI seam, actual window drag and exact-identity assertions. No new package, target, test-only production hook or signed-storage workaround is proposed.
- Establish a failing actual resize journey before applying the chosen production change. The runs above already establish the current inspector failure.

## Definition of done

- Day, Week and Month preserve the same selected Schedule, live source, notes and saved caption across actual 1,200-to-860-to-1,200-point resizing, without process termination or content outside the window.
- Details can close, reopen and follow another selected entry. Hidden details stay hidden across resizing; a valid retained selection is not silently changed.
- Calendar reclaims width when details close. Toolbar controls remain reachable in narrow and wide layouts. Existing List headers and draft navigation remain intact.
- Preserve iPad inspector behavior through an affected native regression and compile the affected platform targets. Record every executed case, failure and skip, inspect deliberate owned-window captures, and run affected strict Swift/Markdown lint and whitespace checks.
- Keep signed sync/account, physical devices, system Shortcuts and whole-app polish as separate open gates. A passing local resize journey cannot close them.
