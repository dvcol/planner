# Native Item estimate editor

This report retains its original source epoch. The [shortcut continuation](native-estimate-shortcuts.md) adds the accepted named presets and requalifies the represented Item estimate journeys on the current phone/tablet source. Its Mac runtime gate remains open separately from compilation.

## Context, before and goal

At `0c4ea3a`, Core supports guarded Item estimate edits and exact minute/display-unit data, but the native creation/edit forms have no estimate controls or detail summary. Q48 A, Q49 A and Q74 A require an inline native editor that preserves duration when changing units and exposes exact smaller-unit remainders. An estimate remains separate from a booked Schedule.

## Definition of ready

- The accepted public Core and native UI seams remain the test boundaries. Use the existing create/edit commands and captured field hashes, with the existing durable-save acknowledgement.
- One year is 365 days and one month is 30 days. Estimates are positive whole minutes; No estimate clears the optional value. Unit selection changes representation, and quantity changes change duration.
- Use native Form, Toggle, Picker, Stepper and LabeledContent. Main Save/Cancel controls the complete Item draft; no raw numeric duration input or separate estimate sheet is added.

## Definition of done and required /tdd

- Actual native create/edit, cancel/save and relaunch journeys preserve 125 minutes as two hours plus five minutes, including unit changes. Notes, source identity and other content remain live and unchanged.
- One 365-day year displayed as Months is twelve months plus five days. Save and relaunch retain exact minutes and the selected display unit. Explicit clearing persists No estimate.
- Display the shared estimate in ordinary Item, List appearance and Itinerary appearance details and compact row metadata. Contextual completion remains independent; an estimate edit never adds a Schedule or fills its end.
- Integer arithmetic never overflows or saves zero/negative values. Native decrement/increment availability follows the supported positive minute value; clearing is explicit.
- Focused native phone/tablet journeys, affected compatibility checks, strict Swift lint and Mac compilation pass. Inspect actual captures. Record Mac runtime and physical-device checks separately; compilation is not runtime proof.

## Execution boundary

The first native tracer reaches the missing inline-control failure. The production section stages native unit/count controls and exact remainders through the existing Core value. Initial compiler argument-order and accessibility-selector failures remain separate from successful runtime qualification. The native Stepper exposes generated child identifiers ending in -Increment/-Decrement in this SDK.

The two estimate journeys pass on both iPhone 18 Pro and iPad Air 11-inch simulators running iOS 27: four executions, zero failures and zero skips. The first edits an existing Item through Cancel and Save and preserves 125 minutes, its notes and its saved representation after relaunch. The second creates a year estimate, changes its representation to twelve months plus five days, verifies the row caption after relaunch, then checks Cancel and Save when clearing it. No Schedule is created.

Actual phone and tablet captures show native grouped controls with readable remainder rows. Phone editor, phone year and tablet year are exported XCTest attachments. The tablet capture includes the system keyboard because the title field remains focused; the controls and Save remain visible.

The Mac app and test host compile; Mac UI runtime executions remain zero. Eight affected Swift files pass strict formatting lint. Two focused existing Item-edit and itinerary-appearance compatibility journeys pass on iPhone, bringing this slice to six native executions with zero failures/skips. Results are tracked in the execution record. The successful estimate results match the recorded 61-file app/UI-test source snapshot.

The editor uses checked integer addition, disables increments that exceed Int64 and disables decrements that would save zero. Those guards are reviewed code; this slice does not claim native maximum-value or minimum-value journey coverage. Existing public Core estimate validation remains separate evidence. The shared List/Itinerary estimate sections compile, but these two estimate journeys do not qualify editing an estimate through every context or independent source-identity inspection.

Container aggregate/remaining estimates, Calendar, controlled provider fixtures, large-list performance, physical sync/account/Share and whole-app polish retain their separate gates.
