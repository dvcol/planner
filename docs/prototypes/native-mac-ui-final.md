# Final focused Mac checks

## Completion and search

The signed native completion/relaunch and Itinerary-search pair passes in 31.478
and 24.178 seconds. The completion case preserves the same Item identity through
relaunch; search remains intact across destinations. The earlier driver attempt
failed before feature actions because the application was not active; using the
existing activation-aware navigation helper corrected the driver.

## Map and routes, 31 October 2026

`testItineraryMapFitsDistinctPlacesAndUsesAvailableWidth` passes in 159.645
seconds against application checkpoint `278da3da`. The prepared source and
signed products match before and after the run. Three distinct pins are
individually tappable, the repeated Hotel marker reports two appearances, and
walking/driving calculate all three itinerary legs. Public transport presents
its explicit external Maps fallback without claiming an inline route.

At window widths of 1200 and 1600 points, details stay bounded, the Map gains
more than 350 points, and the selected bookmark retains its identity and
original URL. Three original captures were inspected, then the raw output was
discarded under the [artifact policy](../validation.md#artifact-policy).

The installed Planner app remains unchanged. Manual UI automation authentication
is preserved. This run does not replace hands-on keyboard, VoiceOver or final
layout acceptance, or the separate mobile sender checks.
