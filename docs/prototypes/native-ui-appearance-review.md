# Native navigation appearance review, 26 October 2026

## Findings and correction

The existing journey named Dark passed while its captures still rendered light.
An iOS launch argument alone did not establish actual device appearance on this
runtime. The journey now sets and asserts public `XCUIDevice.appearance`, then
restores the previous appearance in teardown. The Mac launch-preference branch
keeps its existing behavior. No production test hook or new test boundary is
added.

The first attempt selected the fixture target and executed zero tests. Another
used a scheme without the navigation target. Both retain their actual outcomes
and receive no UI qualification. The corrected target's initial two functional
journeys also receive no dark-rendering credit. Its named-dark editor capture
is retained as the counterexample. Earlier explicit device-appearance runs have
their own evidence; this finding does not invalidate them by inference.

## Executed local boundary

The production Planner app passes both corrected light and dark journeys on
an iPhone18 Pro and iPad Air11-inch M4 Simulator, four executions altogether.
They exercise initial navigation, New Item fields/Save, saved notes/completion,
Lists, Items, Inbox, Itineraries, Calendar, retained Item selection, rotation,
completion changes and relaunch. Appearance is explicitly set, asserted and
restored in each execution. There are no failures, skips or SQLite-unlink
warnings.

The [validation record](evidence/native-membership-consolidation/native-final-navigation-validation.json)
links the four passed executions, their actual product/source verification and
sixteen retained inspected captures. All 1160 native inputs matched their saved
source epochs. Actual phone and tablet products were verified before subsequent
builds. Native grouped Forms, controls, bottom phone tabs and regular split panes
render in genuine light/dark appearances. The reviewed editor, selected details,
empty Lists, Inbox, Calendar and landscape captures retain readable controls and
context. This checkpoint adds no production styling change or custom components.

The app's display name subsequently changes from "Planner navigation prototype"
to "Planner". The [narrow build](evidence/native-membership-consolidation/native-final-display-name-build/metadata-validation.json)
reads the actual compiled Info.plist and verifies that name and the unchanged
bundle identifier. Only that configuration input differs from the executed UI
source. Its metadata build receives no additional UI-execution credit. Screens
in this checkpoint therefore retain the earlier display name.

## Remaining UI acceptance

This starts the final UI pass; it does not close whole-app acceptance. Populated
List/Itinerary, Map, browser, filter/editor, failure and recovery scene states,
full accessibility/contrast/text-size review and physical behavior keep their
separate map gates. The unchanged Mac host still has its 14 October boot and
17 October test broker; no unchanged startup retry is attempted here. Actual Mac
window/column interaction remains unqualified, separately from signing.

Q163's crossed-family policy remains pending. Signing stays deferred, and the
user's final coherence/layout review is still required.
