# Native Calendar all-day date captions

## Context and goal

The agenda now orders saved assignments chronologically, but two all-day assignments to the same Item both display only All day. Users cannot distinguish their saved spans without opening each one. This step adds each assignment's actual civil date range to its compact native caption and accessibility value. A single-day assignment shows its date. Schedule identities, inclusive dates and source content remain unchanged.

## Definition of ready

The accepted Calendar scope preserves all-day civil dates across travel and retains both selected dates. Existing Item/Itinerary Schedule rows already format those values using Apple's native DateIntervalFormatter with a Gregorian/GMT calendar. Reuse that presentation instead of creating a different date interpretation. The native UI remains the agreed public test seam.

## Definition of done for this step

- All-day agenda captions show their saved dates beside All day, with the complete value exposed to accessibility.
- Share the existing native civil-date formatter between Schedule details and Calendar. Device-zone changes must not shift its civil fields. Timed captions retain the display timezone and Start only behavior.
- Extend the overlapping all-day journey to compare each agenda caption with its actual saved Schedule description. The two different starts must remain distinguishable and keep chronological identity order.
- Run the focused red/green, both five-journey native Calendar suites, strict lint and the Mac app/test-host build. Record the final source revision and inspect date captions on both simulators.

## Tests and qualification

The caption regression failed at its exact accessibility-value assertion before production changes: both entries exposed All day while their saved descriptions had different date spans. After reusing the native formatter, one focused journey passes on each simulator. Final qualification passes five functions in two suites per simulator, without failures or skips. Strict lint passes three Swift files, and the Mac app/test host builds with zero Mac UI functions. Both source review axes have no confirmed findings. Execution evidence records actual result trees, commands, verified final source hashes and two inspected native captures from the same revision. Ordering is separately committed and qualified in [the agenda ordering evidence](native-calendar-agenda-order.md).

## Remaining work

Q79–81 retain their pending Calendar layout/component/query choices. Day/Week, Month event overview, display-zone override, mixed/timed/tie fixtures, DST/travel, external refresh/deletion, paging/performance, accessibility/keyboard and Mac runtime remain required. Apple Calendar export remains outside the map.
