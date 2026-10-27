# Calendar shared time ruler

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
Final-source Mac execution awaits the user's readiness for manual
Enable UI Automation authentication. Authentication-free mode is not enabled.

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
