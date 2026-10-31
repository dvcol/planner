# Final Mac completion and search checks

31 October 2026. Two existing native journeys now pass on the signed Mac build:

- Catalog completion and relaunch: 31.478 seconds. The multiline row control
  remains attached to the exact saved Item; checking and reopening survive
  relaunch without opening another source.
- Itinerary search retention: 24.178 seconds. Switching to Items and back keeps
  the search text and matching itinerary context.

The first attempt fails both tests before feature actions. Its captures show
Codex in front and Planner's disabled accessibility tree. The private design
helper queries the sidebar without activating Planner. It now uses the shared
`openPlannerSection`, which activates the app and waits for saved navigation.
No production view or persistence code changes for this correction.

The [review record](evidence/native-mac-ui-final-2026-10-31/review.json) retains
the failed and passing results, compressed logs, exact commands, 262 unchanged
input/product hashes and five original PNGs. Three originals are inspected:
the [multiline row](evidence/native-mac-ui-final-2026-10-31/multiline-before.png),
the [reopened source](evidence/native-mac-ui-final-2026-10-31/same-item-after-relaunch.png)
and [retained search](evidence/native-mac-ui-final-2026-10-31/search-after.png).
The represented two-line row control is vertically centered and the saved
title remains readable in details. This does not establish every width or
assistive setting.

Strict affected Swift formatting and whitespace checks pass. The corrected
native test build succeeds. Both executed tests pass without changing manual
UI-automation authentication policy. The installed development app is not
replaced.

Physical Maps Share, the remaining contrast/VoiceOver and divider review,
release distribution checks and explicit daily-use acceptance remain open.
This pair adds no iCloud stress or installed Mac Share test.
