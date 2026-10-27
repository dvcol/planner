# Calendar shared time ruler

The latest sizing and Mac execution checkpoint is
[below](#accessibility-sizing-and-mac-follow-up).

## Scope, 27 October 2026

The user reports repeated hour labels in every empty Week column. Day and Week
use the existing SwiftUI event grid. Mobile Month continues to use Apple's
native `UICalendarView`; it supplies date selection and decorations rather than
a timed appointment grid. No component dependency or saved-data contract changes.

Day and Week now share one leading hour ruler. It stays at the visible leading
edge during horizontal scrolling, while each day retains its hour separators.
Removing the repeated gutters gives appointments more room. Initial scrolling
reserves the ruler's width so the selected booking remains visible beside it.
The ruler follows the existing Dynamic Type scaling and system appearance.

## Executed checks

The [result packet](evidence/native-calendar-shared-time-ruler/result.json)
separates final builds, successful mobile runs and earlier unsuccessful attempts.
All 1,164 final native inputs match both builds and both mobile runs. Actual
mobile product hashes match after execution. The final Mac app, Share extension
and UI runner pass strict signature verification; nine products are hashed.

| Final execution | Passed | Failed | Skipped |
| --- | --- | --- | --- |
| Light iPhone | 3 | 0 | 0 |
| Dark iPad | 4 | 0 | 0 |

Both devices exercise the single hour-label set, the ruler's stable position
after a horizontal pan, an all-day span, saved start-only appointments and
separate overlapping bookings in Day and Week. The selected booking must remain
clear of the ruler. Relaunch preserves its saved Schedule description. The iPad
also preserves the selected Schedule and source through inspector hide/reopen
and orientation changes. Both runs restore their previous system appearance.

Three retained original captures were inspected:

- [iPad Week](evidence/native-calendar-shared-time-ruler/tablet-week.png)
- [iPad details](evidence/native-calendar-shared-time-ruler/tablet-details.png)
- [iPhone Week](evidence/native-calendar-shared-time-ruler/phone-week.png)

The compressed records retain commands, input/product hashes, source snapshots,
terminal results and earlier failure evidence. Broad automatic failure videos
and unrelated desktop diagnostics remain outside the repository. The compact
packet replaces the redundant standalone stale-cache failure packet.

## Mac scope and earlier failures

An intermediate Mac run passes Month, Day and Week at actual
1,200-to-860-to-1,200-point widths. The same selected Schedule, source notes and
saved caption survive. Its fourth test fails before reaching the grid: the
native End date control is a field/stepper, while the mobile driver expects a
popover button. The run remains three passes and one failure, not a passing
cohort. It predates the final initial-scroll alignment correction.

The original inspector tests also matched nested accessibility elements with
the same Notes text. Selecting the first matching element removes that query
ambiguity; the geometry and identity assertions remain. The Mac End date driver
now uses native keyboard entry. It compiles, but its runtime remains unqualified.
At this initial checkpoint, final-source Mac execution awaited the user's
readiness for manual Enable UI Automation authentication. Authentication-free
mode is not enabled.

An earlier tablet setup fails before a test starts because an old command points
to removed dependency manifests. Using the current built test products resolves
that setup issue. The first actual tablet cohort then fails a ruler-position
assertion that incorrectly assumes the grid begins at screen x=0. Native sidebar
insets explain that mismatch. Its capture also reveals a selected booking partly
under the ruler. The final code corrects initial alignment, and the final tests
check stable ruler position and the booking's visible leading edge.

Final Mac runtime, divider movement, an explicit assertion of reclaimed Calendar
width, broader keyboard/accessibility and physical-device review remain open.
These checks do not qualify CloudKit, account transitions or installed Share.

## Accessibility sizing and Mac follow-up

The largest-text captures expose narrow day columns and a visible Date label
wrapping vertically. Day and appointment minimum widths now use native
`ScaledMetric` values. The compact native date picker hides its visible label
while retaining its accessibility label. A one-point scroll target aligns the
selected day beside the ruler independently of the wider column's size.

The first large-text phone journey also stops before Calendar: the saved
Schedule row is below the visible Item detail cells. The driver now scrolls the
native form before reading that row, including after relaunch. Larger overlap
lanes expose a second driver limit: querying hittability on a far-offscreen card
raises a native error. Bounded native drags first bring each card's center into
the visible area beside the ruler. Exact identities, widths, non-overlap and
actual hittability assertions remain.

The [follow-up packet](evidence/native-calendar-shared-time-ruler/accessibility/result.json)
retains the following distinct executions and their failures:

| Cohort | Passed | Failed |
| --- | --- | --- |
| Before sizing, largest-text phone | 2 | 1 |
| Before sizing, largest-text iPad | 3 | 0 |
| Corrected sizing, largest-text phone | 2 | 1 |
| Corrected sizing, largest-text iPad | 2 | 1 |
| Corrected overlap driver, largest-text phone | 1 | 0 |
| Corrected overlap driver, largest-text iPad | 1 | 0 |
| Ordinary light phone | 3 | 0 |
| Ordinary dark iPad, including Week inspector rotation | 4 | 0 |
| Mac Month/Day/Week resizing and first End date trial | 3 | 1 |
| Mac segmented End date entry before popover dismissal | 0 | 1 |
| Mac End date entry with explicit popover dismissal | 1 | 0 |

All cohorts have zero skips. The corrected sizing cohort passes all-day/ruler
and saved start-only/relaunch checks on each device; only its overlap driver
fails. The targeted overlap reruns complete those two remaining scenarios.
Largest-text runs use dark appearance and Increase Contrast, then restore all
three Simulator settings. Ordinary runs restore their original appearance too.

The Mac resize cases retain the selected Schedule, source notes and saved
caption through 1,200-to-860-to-1,200-point window changes. The date-field trial
initially submits a single-day span. Native day-component entry then reaches
29 October, but leaves the calendar popover covering Save. The final driver
explicitly dismisses that popover inside the editor before submitting. The
saved result has the intended three inclusive all-day banners beside the
independent timed booking. This is a test interaction correction; the production
Schedule form is unchanged. Manual automation authentication remains required
before and after every Mac run.

Final Mac and mobile compilation share all 1,164 native inputs. Later changes
affect the test driver; two actual main-app products per platform remain
byte-identical across the represented successful checks. Each UI execution
retains its own test-source and product hashes. This is not one all-green batch.

Four inspected original captures are retained: corrected
[largest-text phone](evidence/native-calendar-shared-time-ruler/accessibility/phone-largest-week.png),
[ordinary phone](evidence/native-calendar-shared-time-ruler/accessibility/phone-ordinary-week.png),
the [Mac saved span](evidence/native-calendar-shared-time-ruler/accessibility/mac-saved-three-day-span.png)
and a [narrow Mac finding](evidence/native-calendar-shared-time-ruler/accessibility/mac-narrow-sidebar-finding.png).
The last capture shows a clipped sidebar despite the existing detail assertions
passing. That defect remains open. Largest-text sidebar wrapping and partial
cards/headings at panned viewport edges also retain their visual-review limits.
Divider movement, explicitly measured width recovery, full assistive review and
physical acceptance remain open. No signing resources, iCloud/account settings,
saved-data rules or production storage configuration change.

The subsequent [bounded split-pane checkpoint](native-calendar-mac-inspector-resize.md#bounded-split-pane-27-october-2026)
corrects that Mac sidebar clipping and passes strengthened Month/Day/Week pane,
minimum-width, divider and width-recovery checks. Week viewport retention and
the broader accessibility/physical gates remain open.

## Compact Mac mode control, 27 October 2026

The Mac segmented picker now hides its redundant visible label with native
`labelsHidden()`. Day, Week and Month remain named controls; mobile presentation
is unchanged. This removes the wrapped label beside the narrow mode control.

The existing Week inspector journey passes with zero failures in 109.970
seconds. It exercises 1,200-, 860- and 820-point layouts, native divider movement,
width recovery and the exact selected Schedule. The Mac build exits 0 with all
1,167 inputs matched; strict app, Share and runner signatures pass. Manual
automation authentication remains required before and after execution.

Two original owned-window captures were inspected at minimum and wide widths.
The mode control stays on one row. The selected booking can still scroll out of
the visible Week columns when narrowed; its exact details remain selected.
That viewport polish and wider accessibility/device acceptance remain open.
The [result and curated records](evidence/native-calendar-shared-time-ruler/compact-mode/result.json)
retain this limited scope without repeating mobile tests for Mac-only styling.

## Selected-card viewport, 27 October 2026

The time grid now retains an exact selected-card scroll target and brings it
beside the pinned ruler when either viewport dimension shrinks. This corrects
the narrow Week capture above without changing the selected Schedule, saved
times or Item content. Unselected grids retain their ordinary scrolling.

The first width-only correction passes Mac and phone checks, but fails the
iPad Week rotation journey. After returning to landscape, the selected card
starts at y=998.5 in an 820-point-high window. Observing height as well as width
corrects that loss. The existing Mac journey now also requires the selected
card to remain tappable and horizontally inside Calendar at 860 and 820 points
and after the native divider cycle.

Final-source checks each pass once with zero failures or skips:

| Journey | Test seconds |
| --- | ---: |
| Mac Week minimum width, divider and selected details | 119.076 |
| iPad Week inspector and portrait/landscape rotation | 82.356 |
| iPhone Day/Week saved start-only entry and relaunch | 58.457 |

Both builds pass with all 1,168 native inputs matching the workspace. Two
earlier sandbox-limited build attempts exit during package/cache setup; the
same scoped builds pass with normal authorized Xcode cache/service access.
Main, Share and Mac runner strict signatures pass, and executable hashes
remain unchanged during each test. The observed Mac test process uses the
rebuilt derived product, separately from the installed ordinary app. Manual
automation authentication remains required before and after the Mac run.

The [packet](evidence/native-calendar-shared-time-ruler/selected-card-viewport/result.json)
retains all six distinct test outcomes, build records and four inspected
original captures: narrow/wide dark Mac, landscape light iPad and light phone.
Broader accessibility, keyboard and physical Calendar acceptance remain open.
Installed Share and production CloudKit receive no qualification from this fix.
After curating those records, removing only superseded trial results and their
duplicate exports frees 79,828,602 nominal file bytes. All three final passing
results, built apps, caches and app data remain. This is not an APFS free-space
measurement.
