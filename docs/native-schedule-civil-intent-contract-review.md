# Civil Schedule inputs and replacement actions

Status: Q124 A and Q125 A accepted on 21 October 2026. The concrete civil inputs and two focused replacement actions below are approved. [Creation and replacement are implemented and locally qualified](prototypes/native-schedule-form-intents.md). Actual system and physical qualification remain open.

## Context and starting state

The four creation actions have no implementation yet. Core stores resolved timed instants or inclusive Gregorian all-day dates. Existing native `SavedScheduleTimeInput` discovers strict local-time candidates, including half-hour transitions. Current Shortcuts actions read Schedules, clear their end and change a timed planning zone while preserving instants. Whole-form Core replacement already exists with changed-field hash guards.

## Goal and expected end state

Create or replace a Schedule through native typed inputs without silently normalizing dates, choosing a repeated occurrence, inferring an end from an estimate or replacing its owner. Keep picker rendering and real system serialization as separate qualification gates.

## Q124, concrete creation inputs

A. Required typed Item/Itinerary owner and native Start DateComponents. Timed actions use dateTime fields plus the required planning-zone entity; End and separate Earlier/Later occurrence choices for Start and End are optional. Neither occurrence has a default. A unique local minute needs no occurrence; a repeated minute requires an explicit choice. A nonexistent minute fails. Interpret civil fields in the selected planning zone, never an embedded component timezone. Require complete Gregorian minute fields and reject invalid dates, unsupported seconds/fractions and failed exact round trips rather than truncate or normalize. Resolve endpoints independently, then require a supplied end instant strictly later than start. Reuse the qualified native resolver rather than add a Core resolver.

All-day actions use native date fields without a zone or occurrence. Omitted End means one day; a supplied equal End is valid and dates are inclusive. An earlier End fails. Existing saved civil-date validation applies.

B. Revise the concrete input fields or validation before implementing them. The four-action layout and previously accepted temporal behavior remain requirements.

Recommend A. This supplies explicit repeated-time selection and retains native date pickers. System picker rendering, Gregorian serialization and full-range entry still require actual Shortcuts invocation.

## Q125, full Schedule replacement

A. Two focused actions, Set Schedule to Timed and Set Schedule to All Day. Each selects an existing Schedule and supplies the complete new form using the corresponding creation inputs. Either can convert the form while retaining Schedule and owner identities. An omitted End clears that endpoint; action descriptions make replacement explicit. Existing Clear End and Set Timezone remain focused preservation actions.

B. One Edit Schedule action with a Timed/All day selector. Fewer library entries, but every form-specific field must be optional, inactive fields ignored and the selected form validated at execution.

Recommend A, consistent with Q118's focused creation actions. Both use the current source/form hash and ordinary edit authority, without a review or destructive-admin capability.

## Definition of ready

- Q118 A accepts four creation actions; fixed instants, explicit repeated occurrences, gap rejection, inclusive all-day dates and optional ends are already settled.
- Q124 A approves the concrete input contract. Q125 A approves two focused replacement actions.
- Q112 approves production Intent invocation with Apple's dependency manager, disposable storage and actual recovery-filesystem faults in the existing app-hosted target. No additional test boundary or test-only resolver/clock is proposed.

## Required tests and validation

At the production Intent boundary, use literal instants and dates for unique time, skipped/repeated New York hours, Lord Howe half-hour changes, a repeated-time end whose clock label precedes the start, missing occurrences and invalid/partial/normalized dates. Test each owner and form, explicit/no end, midnight/multi-day spans, zone isolation, exact generated IDs, archive acceptance, stale/missing/wrong-kind sources, cancellation and unavailable storage. Preserve source content, estimates, completion, other schedules and owner identity. Qualify actual precommit and post-save recovery failures truthfully.

Replacement tests retain the Schedule identity and owner through timed/all-day conversions, reject invalid input without a partial change, explicitly clear omitted endpoints and preserve unrelated source edits. No unchanged saved fractional instant is round-tripped through civil input by a focused zone-only or Clear End action.

Compare extracted field types and required/optional/default metadata, run affected regressions and strict lint, and compile the same frozen sources for Mac, Simulator and unsigned device. Actual picker presentation, serialization, confirmation-free ordinary execution, background/locked launch and physical qualification remain separate tests.

## Definition of done

- Accepted input/action contracts recorded before their dependent tests and implementation.
- Red/green production-interface evidence, exact persistence/recovery outcomes and original fixture lifecycle recorded.
- Affected metadata, lint and platform builds pass, with no schema, Core/MCP, backup, target or signing changes.
- Open system and physical gates remain visible; this slice alone does not close the map.
