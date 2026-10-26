# Native Itinerary validation and link editing

New Itinerary could reject an invalid link without showing its error. Both the
editor and its parent could try to present the same shared message. The existing
native test reproduces the missing alert, and its recording retains the invalid
URL in the editor.

The correction moves the existing New Itinerary presentation state to the window
root and passes it to the catalog as a Binding. The parent suppresses its alert
while the editor is open. The same flag also keeps external plan opening waiting
for the presented workflow. No new coordinator, error model, Core contract or
storage behavior is added.

## Verification

Five final native executions pass across three existing functions:

- Light iPhone and dark iPad create two links, cancel an addition, edit a URL and
  label, reorder the original bookmark identities, cancel then confirm removal,
  and retain the surviving link and notes through relaunch.
- Both devices reject invalid links during creation and editing. Correcting the
  creation draft saves it; canceling the rejected edit preserves the original
  bookmark identity, URL and notes through relaunch.
- iPhone cancels new and edited drafts, saves a renamed title and edited notes,
  and retains the same itinerary through relaunch.

All 1160 native inputs match the workspace and Mac app, Share-extension and
UI-test compilation. Affected strict Swift and Markdown lint pass. The
[structured results](evidence/native-itinerary-link-editor/final-validation.json)
retain the exact executed test identifiers and settings restoration.

The test driver now scrolls the actual Form above the keyboard and places the
caret at the end before replacing text. Its original saved-identity/order and
Cancel assertions remain. The earlier committed-base offscreen Add Link failure
stays in the [previous archive](evidence/native-owned-field-wrapping/execution-records-index.json).
The passing endpoint probe records the complete old URL and exact replacement.
All temporary diagnostic prints are removed; no test target or production test
control is added.

## Visual review and remaining gates

Eight inspected images retain six final views, the endpoint probe and one frame
from the failed native recording. The [inspection record](evidence/native-itinerary-link-editor/visual-inspection.json)
records their hashes, dimensions and observations. The dark iPad editor keeps its
staged links above the native keyboard, and both devices show the system alert.
These ordinary-size views do not close the broader accessibility/layout review.

Actual Mac UI remains unqualified. Read-only checks still show the 14 October
boot and 17 October native test-broker start, so no unchanged startup retry is
made. Physical Share/sync, signed shared storage and final human acceptance remain
separate gates. Signing stays deferred; advanced portability stays post-MVP.
