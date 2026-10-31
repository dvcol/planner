# Native Itinerary deletion

## Context, starting state and goal

At `37097bf`, public Core reviews and removes an Itinerary with its owned links,
label associations, appointments, ordered entries and persisted expanded
completion. Shared Items, Lists and other plans survive. The native app can
confirm Item, List and label deletion, but its Itinerary actions menu has no
Delete action.

The goal is explicit, reviewed container-only deletion through the existing
native SwiftUI confirmation Form and shared Core command. Cancel preserves the
dataset. Confirm removes the selected plan and its owned references, clears
invalid selections and retains source content, standalone List completion and
other plans' order, completion and appointments. Archive remains separate; there
is no Trash workflow.

## Definition of ready

- R10/R14 require confirmed container-only deletion without a timer or deletion
  of source Items/Lists.
- Q8 and repeated appearances retain independent contextual completion with
  global Item precedence.
- Core's full removal review, transaction, stale-review admission, replay and
  independent recovery outcomes have recorded qualification.
- Native tests use actual controls and a temporary local dataset, without
  private database queries, scripted fixture injection or production test-only
  seams.

## Definition of done for this native slice

- The native actions menu offers Delete Itinerary, including for an empty plan.
  Empty-container bulk completion remains disabled.
- The confirmation Form shows the name, complete reviewed reference count and
  container-only impact. Cancel applies nothing.
- Confirm sends the reviewed command through the shared adapter. An applied
  result clears deleted container/appearance selections, including when the
  independent recovery publication is incomplete.
- Stale or failed reviews retain the existing Form and status behavior.
  Controlled native failure presentation remains a separate qualification gate.
- Cancellation and relaunch preserve surviving source identities/content,
  standalone List membership identities/completion, other route appearance
  identities/order/completion and separate appointments.
- Focused simulator journeys, affected strict Swift lint and target compilation
  pass. Exact source epochs and inspected captures are recorded; simulator
  results do not establish native Mac runtime or physical iCloud behavior.

## Required /tdd

The native tracer creates Museum and Park, Wishlist containing both, Weekend
route containing Museum and Wishlist twice, and Rain route containing Museum and
Wishlist once. Standalone Wishlist is one-of-two Done; Weekend's five
appearances are two-of-five Done; Rain's three appearances are independently
one-of-three Done. Both plans and Museum own separate appointments.

Weekend's review must show five saved references: three entries, one persisted
expanded completion and one owned appointment. Cancel retains its five
appearance identities, two-of-five progress and appointment. Confirm removes
Weekend and its appointment while preserving Rain's original three appearances
in order, one-of-three progress and appointment; Wishlist's original two
memberships and one-of-two completion; and both globally Todo Items' notes,
including Museum's separate appointment. Relaunch must retain those results.

A second journey reviews an empty plan with no saved references, cancels
unchanged and then deletes it. It also deletes a plan with a selected direct
Item appearance, clears its detail and preserves the globally Todo Item after
relaunch. A third regression creates two successive plans and verifies the
second opens its own empty contents. Existing Item, List and Itinerary-only Tag
deletion journeys exercise other callers of the shared confirmation Form; an
existing Itinerary edit journey checks the retained content view. Core
unit/admission tests are reused only after exact backend/configuration hash
comparison.

## Loading regression and implementation

The initial rich tracer stopped before Delete during setup: the second plan
remained at Opening Itinerary. A reduced two-plan journey reproduced the issue.
Temporary logs showed a completed read at the current revision was discarded
when a native column transition canceled its task. They also exposed a hidden
mobile Lists tab rendering itinerary columns in addition to the active
Itineraries tab.

The mobile Lists tab now retains its List columns, while Mac still selects the
appropriate sidebar columns. The Itinerary detail accepts its completed read
when its store revision is still current; its identity remains tied to the
selected plan. Attempts to change the task key and defer creation selection did
not solve the loading issue and were removed. Temporary diagnostics were
removed. The original rich tracer then completed setup and reached the missing
Delete action, establishing the feature's functional red separately from the
setup failure.

The root view owns the deletion sheet so clearing a deleted child selection does
not remove the confirmation while a saved change reports incomplete recovery.
The Itinerary content/detail pause reads during review, refresh after dismissal,
and keep the Form responsible for its status. Delete explains that source Items,
Lists, other plans and their appointments remain available.

## Qualification and remaining gates

The machine-readable record preserves commands, source hashes, result summaries,
test trees and attachment provenance. Eight unique native functions are
qualified on each simulator: three new Itinerary journeys and five existing
shared-Form/content regressions. The creation regression also appears in the
caller runs; it is counted once per platform.

| Run                                     | Passed | Failed | Skipped | Qualification use                                             |
| --------------------------------------- | -----: | -----: | ------: | ------------------------------------------------------------- |
| iPhone caller regressions               |      6 |      0 |       0 | Six passing functions                                         |
| iPad caller/initial deletion run        |      6 |      2 |       0 | Six passing functions only; two observation failures retained |
| Final iPhone Itinerary journeys         |      3 |      0 |       0 | Three functions, including the repeated creation regression   |
| Restarted final iPad Itinerary journeys |      3 |      0 |       0 | Same three functions with fixed source hashes                 |

The functional red completed the fixture and failed at the missing Delete action
in 192.162 seconds. The first implementation kept the original red test bytes
and reached review/cancellation, then failed because the test searched for a
Schedule row only among Buttons. The exported hierarchy exposes that exact row
as Other, and the failure frame shows the retained appointment. Four Schedule
lookups were corrected without changing their identities or expected values. A
later observation failed by searching for the native Item Toggle as a Button;
three assertions now use the existing generic-element lookup and still require
global Todo. Production bytes remained fixed after the first implementation. The
final rich journey passes in 258.280 seconds on iPhone and 293.921 seconds on
iPad.

One final iPad attempt was interrupted after repeated 60-second
animation-completion waits. Its creation regression had passed, but the run did
not finish and contributes no qualification. The read-only simulator capture
shows a partly covering sidebar and no loading spinner; the sampled app was
idle. Neither observation establishes responsiveness or a cause. Restarting only
that simulator, without erasing data or changing the 288 source/configuration
file hashes, produced the passing three-function run above. Responsiveness
remains part of the native polish gate.

All twelve qualification captures were individually inspected and retain their
actual test/attachment identities in the record:

| Observed state                                                 | iPhone  | iPad    |
| -------------------------------------------------------------- | ------- | ------- |
| Second new plan opens its own empty contents                   | Capture | Capture |
| Empty-plan deletion review                                     | Capture | Capture |
| Selected child cleared after deletion                          | Capture | Capture |
| Repeated route and owned appointment review                    | Capture | Capture |
| Deleted plan absent; other plan retained                       | Capture | Capture |
| Other route's order, completion and appointment after relaunch | Capture | Capture |

The separate initial setup failure records Opening Itinerary before the Delete
behavior was reached. The final captures still expose phone title truncation and
iPad sidebar presentation concerns; passing data journeys do not close those
polish findings.

Strict Swift lint passes for the five affected source/test files. Mac app and
UI-test bundles compile; native Mac UI runtime remains zero. Exact comparison of
242 backend/configuration files allows reuse of the preceding 54 Core, 54
simulator Core and three authenticated HTTP functions, with no new backend
runtime claim. Schema 14, portable format 1, local-only mode and MCP's refusal
of source deletion remain unchanged.

Calendar/estimate choices await Q59-Q61; zero-match groups/loading await
Q57/Q58. Native administration/recovery, controlled save-failure presentation,
native Mac runtime, signed physical sync/account/Share and whole-app polish
remain open. Local deletion markers do not prove deletion winning against a
returning offline device. Apple Calendar export remains outside this map.
