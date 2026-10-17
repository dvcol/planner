# Native schedule time input contract

Status: Q96 A approved by the human on 17 October 2026. The production module interface and real-Foundation unit seam below are accepted for implementation. No module or tests at this seam exist at this approval epoch. Temporary native-control and Foundation probes retain their separate diagnostic scope.

## Context and starting state

[Scheduling Q10/Q11](itineraries-and-scheduling.md#accepted-dst-policies-scheduling-q10-q11) require rejecting nonexistent local times and an explicit occurrence choice for repeated times, for both start and supplied end. Q13 preserves resolved instants when only the planning timezone changes. These product policies are already accepted.

`SavedScheduleForm` currently binds its native DatePickers directly to `startInstant` and `endInstant`, using the planning timezone. There is no separate civil-time draft or explicit occurrence selection in the form. Its validation checks endpoint ordering, not the existence or ambiguity of the requested local clock fields. The existing Core timed form correctly accepts resolved instants, an optional end and a planning-zone identifier. That contract cannot recover an unrecorded original wall-clock selection after a picker resolves it.

The [original capability report](https://github.com/dvcol/planner/blob/31a31448c96329647b4ca38ac0f0e0230ab4f00a/docs/research/native-calendar-date-capabilities.md) requires agreeing the civil-time conversion and validation interface before its TDD implementation. The current native-control investigation records the actual controls separately from that proposed interface.

## Goal and expected end state

Keep native DatePicker, Form and Picker controls. Retain the entered civil date/time independently of its resolved instant so an invalid time remains visible for correction. Show a native occurrence Picker only when necessary, with date-specific timezone abbreviations and UTC offsets. Save is unavailable until every required endpoint is resolved and the supplied end is strictly later than the start. Cancel and invalid edits leave saved schedules unchanged.

Use the same input module for start and end. Preserve the exact saved instant, including fractional seconds, when a stored endpoint is unchanged or its planning zone alone changes. Explicit clock edits use the minute precision exposed by the native controls. Estimates never fill a missing end. Existing all-day civil-date storage, Core commands, MCP forms, backups, identities and field-hash edit guards remain unchanged.

## Proposed production interface

Add an app-internal value module named `SavedScheduleTimeInput`, used by the actual native form. Keep it in the app target. No package, target, dependency injection or public Core/wire extension is proposed.

```swift
enum SavedScheduleTimeResolution: Sendable, Equatable {
  case unavailable
  case nonexistent
  case unique(Date)
  case repeated([Date])
}

struct SavedScheduleTimeInput {
  init(proposedInstant: Date, planningTimeZone: TimeZone)
  init(savedInstant: Date, planningTimeZone: TimeZone)

  var pickerValue: Date { get }
  var resolution: SavedScheduleTimeResolution { get }
  var selectedOccurrence: Date? { get }
  var resolvedInstant: Date? { get }

  mutating func setPickerValue(_ value: Date)
  mutating func selectOccurrence(_ candidate: Date) -> Bool
  mutating func changePlanningTimeZone(_ timeZone: TimeZone)
}
```

`pickerValue` carries Gregorian civil fields in a neutral UTC calendar for the native control, with seconds and fractions cleared. It is presentation data, not a booked instant, and is never saved or exported. The chosen planning zone remains clearly displayed. The module interprets those fields in that zone and returns real candidate instants in ascending order. Zero valid candidates produces `nonexistent`; an unavailable conversion produces `unavailable`. Neither permits Save. For a saved fractional instant, `selectedOccurrence` identifies its corresponding candidate minute while `resolvedInstant` retains the exact saved value.

Only these production operations and their observable results form the proposed new unit-test seam. Candidate discovery and retained-state bookkeeping stay private. The implementation uses Foundation calendar/timezone data and verifies exact civil-field round trips. It must not assume a one-hour transition or treat identical first/last API results as proof that a time is unique. A Mac probe found that limitation for Lord Howe's half-hour repeat; the implementation must qualify the resulting candidates on the actual platforms.

## State and editing rules

1. A new input resolves a unique proposed time automatically. If the proposed civil minute is repeated, leave its occurrence unselected until the user chooses. Never silently select the earlier or later occurrence.
2. Opening a saved endpoint retains its exact instant and identifies its existing occurrence. An unrelated edit does not require another choice or round the stored value.
3. Compare picker changes at civil-minute precision after clearing seconds/fractions. A setter receiving the same civil minute preserves the exact saved instant and occurrence even if its incoming seconds differ. Changing the civil minute clears retained saved-endpoint authority and the previous occurrence choice. A unique replacement resolves immediately; a repeated replacement requires an explicit choice. A nonexistent replacement remains entered and unresolved. Changing away and then back does not silently recover a prior choice.
4. `selectOccurrence` accepts only a candidate from the current repeated-time resolution. A stale or foreign candidate returns false and leaves the current state unchanged. A unique time needs no occurrence action.
5. For an unchanged stored endpoint, a planning-zone change preserves its exact instant and updates its displayed civil fields and existing occurrence without another prompt, as required by Q13. A new or explicitly rescheduled endpoint has no unchanged stored occurrence to retain. Use its resolved instant to display the corresponding civil minute in the new zone; if that minute repeats, clear the occurrence and require an explicit choice under Q11. For example, a new 05:30 UTC draft changed to New York displays 01:30 with neither occurrence selected. An unchanged stored 05:30Z endpoint changed to that zone retains the earlier occurrence and its exact instant. An unresolved draft has no instant to convert, so it retains its entered civil fields and resolves them in the newly selected zone. Saved data still changes only after valid Save.
6. Start and supplied end resolve independently. Compare their actual instants after occurrence selection. A later end can have an earlier-looking local clock during a backward transition. Turning off the optional end does not synthesize another end.
7. Native all-day date controls retain their existing civil-date behavior. Integration must preserve existing all-day, start-only, explicit-end, zone-only and Cancel journeys. This proposal adds no new stored date form or calendar export workflow.

## Proposed tests and definition of ready

Q96 A confirms this interface before writing its unit tests. The existing macOS app-hosted `PlannerMCPTests` target imports the app through `@testable import Planner`. It can exercise this production value module against real Foundation, without a new target or test-only initializer. Public Core persistence and native UI journeys remain existing approved seams.

Use literal civil inputs and independently specified UTC expectations:

- New York 2026-03-08 02:30 has no candidate. Entering it preserves that displayed civil minute, disables Save, creates no new Schedule and leaves an edited Schedule unchanged.
- New York 2026-11-01 01:30 has 05:30Z and 06:30Z candidates. New or changed ambiguous input has no resolved instant before an explicit choice. Each choice retains the selected instant after save/reopen and unrelated source edits.
- Lord Howe 2026-04-05 01:45 has 2026-04-04 14:45Z and 15:15Z candidates, separated by 30 minutes. Returning the same candidate twice is a failure, not a unique-time result.
- An earlier New York 01:45 start is 05:45Z. A later 01:15 end is 06:15Z and is valid; the earlier 01:15 end is 05:15Z and is invalid. Exercise both endpoint choices.
- A saved fractional instant remains exactly equal as a Date value after a setter receives the same civil minute with different seconds, a planning-zone-only edit and a valid unrelated edit. Explicit changes to another civil minute produce the newly selected minute and clear stored-occurrence authority.
- A new unique 05:30 UTC draft changed to New York becomes unresolved repeated 01:30. Contrast an unchanged saved fractional 05:30Z endpoint changed into New York, which preserves its exact value and earlier occurrence. A saved endpoint that was explicitly rescheduled in the draft follows the new-input rule.
- A changed civil input invalidates the old occurrence. Reject a candidate from an earlier resolution without mutating the current selection. Ordinary unique times still save with no extra prompt.

Start with one failing behavior at this agreed production interface, implement only that behavior, then extend it. Use actual Foundation calls, not a copied resolver as the expected result. Follow with real Core save/readback through existing commands and the native UI workflows on iPhone/iPad. Native tests must actually enter the repeated/missing fields; a hierarchy probe or a pre-created resolved Date supplies no correctness credit for that input workflow.

## Definition of done and remaining gates

The native form implements accepted Q10/Q11/Q13 for both endpoints. Module tests, real Core persistence checks and focused native journeys pass with exact source/product provenance. Existing scheduling/all-day/zone-only regressions and affected strict Swift/compiler checks pass. Inspect original captures and review Standards/Spec separately.

Mac UI runtime, physical sync/account/Share, signing, performance and whole-app native polish retain their existing gates. Q94 label presentation and Q95 Item windows remain independent pending decisions. This contract review cannot close any of those gates.

## Review choice

The human selected Q96 A, approving this app-internal production module interface and its real-Foundation unit seam alongside the existing Core/native UI seams. It changes no accepted scheduling policy or wire contract. The unselected alternative was revising the interface or testing scope first.
