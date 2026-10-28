# Native Mac itinerary appearance selection

The actual Mac deletion journey exposes a product defect after its mobile-only
driver assumptions are corrected. Adding Museum to an itinerary succeeds and
the native row highlights, but clicking it leaves the third pane at Choose an
Item. Its source notes are not displayed.

## Diagnosis and correction

The Item picker exposes Museum through native text `value`, and the existing
Mac back control and Actions menu differ from mobile navigation. The journey
now uses those native interfaces and matches text by label or value. Its Mac
captures use only the owned window. These driver corrections let the original
workflow reach the failing product behavior.

A narrowly filtered trace records a row-selection setter receiving `nil` on
the click, with no nonnil row delivered or observed. The outer itinerary
`ForEach` identifies entries by UUID, while its List selection expects
`SavedItineraryRowSelection`. An optional tag deeper in the hierarchy leaves
the failure unchanged and is discarded. A concrete direct-appearance tag at
the outer native row boundary restores selection. Referenced-List headers keep
their existing path. The production correction is Mac-only and changes no
saved identity, ordering, completion or persistence contract. Temporary trace
logging is removed.

## Executed qualification

The existing selected-plan deletion/relaunch journey passes in 139.146 seconds;
its command exits 0 in 141.592 seconds. Cancel preserves an empty plan, confirmed
deletion removes it, and selecting the direct Museum appearance opens its notes
and contextual Todo state. Deleting that selected plan clears its details.
After relaunch both deleted plans remain absent and the original shared Item
retains its identity, notes and global Todo state.

All 1,169 native inputs match the workspace and signed build. Nine actual
product hashes remain unchanged during execution. Main app, embedded Share and
runner signatures pass; manual automation authentication remains required
before and after the run. Three owned-window originals are inspected and
retained. Strict affected Swift formatting and documentation checks pass.

The [verified evidence](evidence/native-itinerary-heading/mac-selection-2026-10-28/result.json)
retains the distinct driver failures, exact-identity diagnostic, native-value
diagnostic, selection trace and rejected optional-tag attempt separately from
the final pass. The earlier second-plan creation/relaunch pass takes 78.535
seconds in its own three-pass/one-failure cohort; it is not represented as a
fresh all-green four-test batch.

This qualifies one direct-appearance Mac workflow with disposable local data.
Nested List/Map/keyboard interaction, full accessibility, installed Share and
synchronization retain separate gates. The duplicate Mac itinerary content and
toolbar heading remains a separate UI follow-up. Account-transition testing
stays user-deferred, and production CloudKit stays disabled.
