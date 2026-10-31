# Native Calendar Month alignment

The core UI pass centers the native month picker when the agenda is stacked
below it. The picker keeps its existing 400-point maximum width. Wide layouts
still put the month beside the selected-day agenda through the existing native
adaptive layout. Saved Schedule forms, identities and date queries are unchanged.

## Observed correction

The original maximum-text iPad capture leaves the compact month against the
left edge of the full Calendar pane. The first layout probe removes its width
cap. Its geometry assertions pass, but visual review catches a stray date in
phone landscape. That probe is replaced with one full-width centering frame
around the original native-sized picker. The final phone capture has no stray
date in the represented landscape state.

The focused native journey checks the actual pane alignment and retains the
same saved Schedule in the agenda through rotation. It uses native scrolling
to reveal the saved Schedule row before leaving Item details; the first
maximum-text phone attempt stopped before Calendar because that row was not
loaded into the visible Form.

## Qualification and limits

The final checkpoint covers dark phone and iPad at maximum accessibility text
size with Increase Contrast, plus ordinary-text light iPad. Each execution
creates a real all-day booking and retains its agenda identity through
rotation. Matching Mac compilation covers the native app, Share and UI-test
products. Strict Swift formatting and Markdown lint pass.

The six final original captures are inspected. Execution packets, settings
restoration, input/product hashes and earlier failed/probe runs are retained in
the evidence.

This is a layout correction, not a whole-app accessibility pass. Native iPad
weekday labels remain tight at maximum text size. The phone landscape capture
shows a scrollable partial month at that size; it does not prove every date or
agenda row is immediately visible. Existing search/contrast findings, actual
Mac interaction and physical/signed-store/synchronization checks remain open.
Signing remains deferred. Advanced portability stays outside MVP.
