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

## Populated dark iPad follow-up

Three existing production UI journeys now pass in confirmed dark appearance on
iPad: browser return to a locally completed List appearance, itinerary composition
and filtered counts with the native contrast audit, and exact List-map selection
through portrait/landscape rotation. All 1160 source inputs and four actual
products were verified. The previous device appearance was restored afterward.
The [run packet](evidence/native-membership-consolidation/native-final-populated-dark-tablet/boundary-validation.json)
retains five inspected original captures and their hashes. The browser capture
shows returned Item details, not browser chrome.

Grouped Forms, nested List spacing, progress and filtered counts remain readable.
Collection and detail maps retain provider attribution and search uncertainty;
local completion stays distinct from the source Item. This checkpoint requires
no production styling change. It does not qualify Mac pane/title behavior or
unrepresented scene states.

The Map footer did expose one small copy defect, "1 of 1 items located". The
shared caption now chooses the singular noun when one Item matches. Existing
native expectations are updated. The [affected iPad journey](evidence/native-membership-consolidation/native-final-map-caption-tablet/boundary-validation.json)
passes with the actual singular caption, provider/uncertainty controls and
unchanged bookmark identity/URL. Its original footer capture is inspected.
There are no failures, skips or SQLite-unlink warnings in either follow-up.

## Dark iPhone reader, Calendar and Map

Three existing production journeys pass in confirmed dark appearance: a saved
website and its rich card open inside Planner and return to the original Item;
a start-only Calendar booking keeps its exact saved caption through relaunch;
and the Map Locations controls retain attribution, uncertainty and the original
bookmark. The [verified run](evidence/native-membership-consolidation/native-final-reader-calendar-map-dark-phone/boundary-validation.json)
contains four inspected original captures. All 1160 source inputs and four actual
products match the executed epoch. Device appearance is restored afterward.
There are no failures, skips or SQLite-unlink warnings.

The native browser toolbar and page, month picker/agenda, Map footer and Locations
sheet render in dark mode. The compact browser title truncates beside its history
controls; the loaded page retains the full heading. This is a visual limit, not
Mac title-width qualification. No production layout or website content changes
are made for these checks.

## Dark iPad draft, Filters and recovery forms

Three more existing production journeys pass in confirmed dark iPad appearance.
The rich New Item draft retains title, notes, duration, owned location and link
across portrait/landscape changes, then saves into its original List and survives
relaunch. Cumulative Category/Tag filters narrow catalog and List rows, preserve
full progress, support Any/All selection and clear correctly. Recovery inspection
keeps the current Tag intact through relaunch.

The [verified run](evidence/native-membership-consolidation/native-final-forms-filters-recovery-dark-tablet/boundary-validation.json)
retains ten inspected original captures, including the open native Filters form,
its scrolled All-selected state, both draft layouts, contextual details and manual
recovery/label administration. Native Forms, popovers, split panes and system
buttons retain readable spacing in these states. The filter popover scrolls to
its later criteria. A partially scrolled form is not a clipped-layout defect.
No production layout changes were needed.

All 1160 native inputs and four actual products match the executed epoch.
Appearance is restored, with no failures, skips or SQLite-unlink warnings.
The only test change adds one review capture to the existing filter journey;
its assertions and production interfaces remain unchanged. Strict formatting
subsequently wraps that attachment call without changing its behavior. The
[narrow compiler check](evidence/native-membership-consolidation/native-final-forms-compiler/qualification.json)
passes for all 1160 final inputs and records that formatting separately from UI
execution. It adds no runtime credit.

## Remaining UI acceptance

The represented phone/iPad scene states above have local evidence. They do not
close whole-app acceptance, unrepresented failure states, full accessibility,
contrast/text-size review or physical behavior. Actual Mac window, column and
keyboard interaction remains unqualified. Its last observed host still had the
14 October boot and 17 October test broker; this checkpoint makes no unchanged
startup retry. That runtime gate is separate from signing.

Q163's crossed-family policy remains pending. Signing stays deferred, and the
user's final coherence/layout review is still required.
