# Native Calendar Day and Week

## Context and goal

Before: the saved Calendar provides native Month browsing and a selected-day agenda, but no Day or Week time grid. Q60 A requires all three modes. After: native mode and date controls select the displayed period; timed appointments occupy their clock positions, all-day spans remain readable, and selecting an appointment opens its existing Schedule/source details. Presentation never fills a missing end, changes a fixed instant, or converts an all-day civil date into another date.

## Definition of ready

Q60/Q61 accept the modes and main Calendar destination. Q79 accepts available main width and native inspector details on larger devices. Q81–82 approve the shared date-window contract now consumed by Month. Existing Core query/read/store and native UI boundaries remain the agreed /tdd seams. Apple's inspected public APIs do not provide an event time grid, so use SwiftUI layout with native controls rather than introducing another framework or a Calendar export adapter.

## Definition of done for this step

- Use a native Day/Week/Month selector and date controls. Query the displayed day or calendar week through generation-bound reads; Month retains its accepted native components.
- Position timed entries from actual native day boundaries in the display timezone. Start-only entries use a clearly labeled point presentation; a minimum visible hit area does not become a saved or implied end.
- Keep simultaneous appointments independently readable and selectable. Week columns share aligned time rows despite different all-day counts. Preserve readable all-day dates and live owner titles.
- Qualify native Day/Week switching, saved identities/forms after relaunch, overlapping entry geometry/selection, all-day spans and adaptive phone/tablet layouts. Extend temporal fixtures for short/long days and repeated local hours without identifying two distinct instants as one row.
- Rerun affected Month/inspector/deletion journeys, strict Swift lint and the affected Mac app/test-host build. Inspect original captures and record actual results. Retain separate Mac runtime, physical-device, accessibility/keyboard and large-catalog performance gates where evidence is still missing.

## Implemented behavior

Day and Week now use the accepted shared query for their actual visible date window. Month keeps its native mobile component and Mac grid. A native segmented Picker and DatePicker select the mode and date. Loading and retry use existing native controls. The selection still carries the original Schedule and Item/Itinerary identities.

The SwiftUI grid uses native day boundaries and elapsed-hour row identities. Simultaneous visual appointments occupy separate lanes; narrow layouts scroll horizontally rather than reducing hit targets below 44 points. A saved start-only entry keeps its absent end. Its minimum displayed height does not write a duration or imply an end.

One pinned section header aligns all day columns. It previews at most two all-day entries per date, with a native overflow List for the remaining schedules. That List uses a native sheet with medium/large presentation on mobile. Selecting an entry closes the overflow presentation and opens its existing source details. One item-based state retains the presentation date; the sheet attaches to the stable grid root.

## Validation

The native /tdd tracers reproduced an absent selector, a centered time origin, intersecting simultaneous appointments, scrolling day headings, narrow overlap lanes and a clipped heading. The corrections passed their focused phone checks. A tablet run crossed midnight and exposed a fixture assumption about the initially visible hour; the fixture now scrolls to the retained appointment instead of changing its saved date.

Before the overflow change, all seven affected phone Month/deletion/ordering functions passed. All eleven tablet Calendar functions passed, including the three Day/Week functions and inspector. A dense all-day tracer then reproduced a header covering the timed appointment. Bounding the header restored that hit target. Its first overflow attempt failed to open; item-based presentation fixed it. Native List virtualization exposed a fixture assumption that every row was rendered initially. Traversal now collects all nine identities by scrolling. A final query also had to use the Schedule row's actual accessibility type and scroll the native source Form. All four phone functions then passed. The tablet overflow journey exposed an invisible grid-anchored popover; button anchoring corrected its position but left a zero-sized hosting ancestor and inaccessible content. Matching the working Filters sizing also failed. Overflow now uses the established native sheet flow, qualified on both devices.

All four final Day/Week functions pass on both phone and tablet, with no failures or skips. Together with the earlier window regressions, this records eleven distinct phone functions and twelve tablet functions. The earlier window regressions preceded the internal TimeGrid overflow fix; the final four renderer functions ran after it on both devices. Month/inspector paths were unchanged by that fix.

Strict Swift lint passes for the three affected files, and scoped Markdown lint passes for this report. The final Mac app and native test host compile successfully. Mac runtime was not rerun in this slice; the prior startup failure remains open. The [execution record](evidence/navigation/native-calendar-day-week/execution.json) retains actual native summaries/trees, historical failures, source/product hashes and byte-identical original captures.

| Native check | Phone | Tablet |
| --- | --- | --- |
| Inclusive all-day span and aligned ordinary Week hours | Pass | Pass |
| Day/Week saved start-only identity, description and relaunch | Pass | Pass |
| Nine all-day schedules, usable timed entry, overflow traversal and retained source form | Pass | Pass |
| Four simultaneous appointments with separate usable lanes in Day/Week | Pass | Pass |

[Phone overflow](evidence/navigation/native-calendar-day-week/phone-overflow.png) and [tablet overflow](evidence/navigation/native-calendar-day-week/tablet-overflow.png) show the native sheet. The [red header capture](evidence/navigation/native-calendar-day-week/phone-unbounded-header-red.png) records the original crowding defect.

## Remaining gates

This delivers the ordinary Day/Week layout, not the full Calendar completion gate. Week clock alignment on short/long days, repeated-hour descriptions, travel fixtures and the per-device display-zone override remain open. Native keyboard/VoiceOver/Dynamic Type qualification, additional responsive layouts, large-catalog storage performance and the broader map still require evidence. The earlier Mac runner failed before any journey executed. No signing, physical-device or native Computer Use action was performed for this slice.

## Mac runtime follow-up, 22 October 2026

### Context, starting state and goal

The recovered Mac test runtime can now execute the existing Day/Week journeys. This follow-up qualifies the native mode controls, start-only Schedule readback/relaunch, dense all-day overflow and independent overlapping appointments. It does not replace Q127's pending resize decision or the final whole-app review.

The first [Mac reproduction](evidence/navigation/native-itinerary-window-compatibility/native-calendar-overlap-overflow-mac/) starts both cases and fails them. The overlap test's indexed StaticText query misses a visible native heading. Its scoped observation retains that heading's label and bounds. The dense case reaches all nine all-day Schedule identities and the source details, but the exact saved date reads as an empty accessibility value. The captured production file hash matches the committed baseline. These are executed failures, not startup failures or evidence about signing.

### Native correction and required checks

Mac's segmented controls expose RadioButtons. The test driver now selects that native type, locates the owning-day heading through the app's native descendants and still checks its position against the grid. Mobile retains its scoped heading query. Deliberate Mac captures use Planner's owned window; broad automatic application hierarchies remain private with their hashes and exclusion reasons retained.

The saved Schedule row visibly renders its date, yet its native Other element returns an empty accessible value, even after a bounded wait. Reapplying the value after the context-menu wrapper alone does not fix it. Giving that outer element the native static-text trait alongside its existing date value does: the exact same native read returns the expected all-day date. The title, context menu, saved Schedule, form and source identities retain their meaning. The start-only journey now also rejects an empty saved caption before comparing it after relaunch. No schema, Core/MCP command, package, target or production test hook changes.

The Definition of Ready remains the approved native UI boundary and saved-time policies above. This correction's Definition of Done requires the three affected real native journeys on Mac, iPhone and iPad, matching source inputs, original capture inspection and affected Swift/Markdown checks. Tests must retain nonempty saved descriptions, the same Schedule identity through Month/Day/Week and relaunch, all nine overflow identities, exact selected-source date readback and four distinct nonintersecting usable appointment lanes. Unit tests that mirror the SwiftUI modifier would not establish these native outcomes.

### Executed results

The final [Mac invocation](evidence/navigation/native-itinerary-window-compatibility/native-calendar-modes-qualified-mac/) passes three cases, with zero failures or skips: start-only identity/caption/relaunch in 34.097 seconds; dense header/overflow/source date in 77.604 seconds; and four independent Day/Week lanes in 44.657 seconds. The [compiler packet](evidence/navigation/native-itinerary-window-compatibility/native-calendar-modes-qualified-mac-build/) records the local ad-hoc build. It carries no paid-signing or protected-storage qualification.

The same three cases pass on [light iPhone](evidence/navigation/native-itinerary-window-compatibility/native-calendar-modes-qualified-phone/) and [dark iPad](evidence/navigation/native-itinerary-window-compatibility/native-calendar-modes-qualified-tablet-retry/), nine passing executions in the final three invocations with zero failures/skips. Simulator appearance readbacks retain those settings. All 1,061 source/configuration inputs match the workspace across the final Mac build and three platform runtime epochs. The [verification packet](evidence/navigation/native-itinerary-window-compatibility/native-calendar-modes-validation/verification.json) checks all 26 original attachment hashes, including 22 images. Twelve original Month, dense-overflow/source-detail and overlap captures were visually inspected. The phone intentionally scrolls the wider overlap grid horizontally; an edge card can be partly outside its viewport.

| Case | Mac | Light iPhone | Dark iPad retry |
| --- | --- | --- | --- |
| Start-only identity, nonempty saved caption, Day/Week and relaunch | 34.097 seconds | 52.309 seconds | 52.446 seconds |
| Nine all-day entries, usable timed entry, overflow and exact source date | 77.604 seconds | 103.712 seconds | 106.371 seconds |
| Four independent usable Day/Week appointment lanes | 44.657 seconds | 57.952 seconds | 62.196 seconds |

The [first iPad group](evidence/navigation/native-itinerary-window-compatibility/native-calendar-modes-qualified-tablet/) fails its start-only case at the native creation helper's unavailable Add menu after 14.508 seconds, before any Schedule exists. Its dense and overlap cases pass in 106.785 and 62.005 seconds. The complete unchanged retry above passes. No startup workaround is introduced, and the failure's cause remains unestablished. It remains part of the broader stability qualification. An additional failure-path `simctl` lookup reports the ambient command-line-tools selection; the successful retry introduces no global Xcode selection or signing change.

Affected strict Swift formatting, scoped Markdown lint and whitespace checks pass. Earlier compiler, locator and accessibility probes remain in the [compact iteration record](evidence/navigation/native-itinerary-window-compatibility/native-calendar-modes-iterations/outcomes.json); raw unpublished packets remain local. Relocation is not disk reclamation.

### Remaining limits

The Mac all-day span/native date-entry journey has not yet executed in this follow-up. Q127's inspector resize crash remains a separate local gate. Wider accessibility/keyboard checks, physical devices, signed storage/sync/Share, actual system Intents and feature-complete whole-app polish remain open. Passing these three cases cannot close the full Calendar or map gate.
