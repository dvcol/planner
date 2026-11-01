# Calendar scrolling axes and live clock, 1 November 2026

Day and Week use a continuous horizontal date track above one local-clock day.
Vertical movement changes the visible time, never the date. Month and Year keep
their vertical rolling windows. Extending the window preserves fractional
horizontal position and visible hours; no paging or snapping is added.

Date and all-day headings remain above the hours; one hour ruler stays on the
leading edge. Scrolling the booking list and grid continues to update the same
date/time focus. Selected events retain their exact Item/Itinerary and Schedule.
The existing clock-change lanes and saved instants are unchanged.

Saturday and Sunday have adaptive background shading at every scale. One minute
clock drives the current-time line, label and today dot; foreground rendering
uses the current instant. The line is above event fills, cannot intercept taps,
and is hidden when today is outside the visible date range.

## Focused verification and reference comparison

Five iPhone Simulator journeys pass: the four-scale portrait handle, linked
landscape list/grid and exact Item navigation, Day/Week movement beyond the
initial rolling window and back through adjacent periods, with vertical date retention, dark
Day/Week/Month/Year rendering, and the late start-only appointment viewport.
The dark captures are visibly dark after supplying the standard system
AppleInterfaceStyle launch default; an appearance setting alone previously
produced light captures and is not counted as dark evidence.

Compared with the supplied references, the calendar retains the left landscape
booking list, seven visible Week columns, pinned date/hour context, floating
controls, weekend distinction and live red clock. Dense overlaps retain complete
accessible labels and the companion booking list. Weather, third-party calendar
sets and additional scales remain outside this change. Physical-device and Mac
visual acceptance are separate from the Simulator evidence. Raw captures and
run logs remain temporary and are excluded from Git.

The production app also passes its existing Calendar modes/landscape and editor
cancellation journeys after adding sharing invitation handling. Fresh light-mode
captures confirm the left booking list, seven Week columns, weekend tint and
current red time marker. Compared with the reference, narrow Week event titles
remain abbreviated while the linked list shows their full titles; empty dates
also retain more vertical space. These are recorded visual differences, not a
claim of pixel-identical reproduction. The previously reviewed dark captures
remain separate evidence.
