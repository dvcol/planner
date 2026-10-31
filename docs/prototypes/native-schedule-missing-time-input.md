# Native nonexistent-time input

Status: historical pre-Q96 diagnostic evidence. The human approved Q96 A on 17 October 2026. The [implementation report](native-schedule-time-input.md) now records the value module, real-Core qualification and native form integration in progress. Statements below about the then-proposed interface and old form describe that diagnostic epoch; they are not current pending approvals.

## Context and starting state

Accepted Scheduling Q10 requires rejecting New York's nonexistent 8 March 2026 02:30 without silently substituting another hour or day. The current form binds native DatePicker controls directly to resolved Dates. The earlier [Q11 investigation](native-schedule-clock-input.md) reproduces missing repeated-time choice, but supplies no native missing-time input result.

## Goal and expected end state

Determine whether the current native form retains and rejects the missing civil time, excludes it from the actual control, or silently changes it. No Schedule is submitted in this diagnostic. A failure at a controller that cannot select the requested date/time is separate from evidence of a product-policy violation.

## Definition of ready

The accepted Q10 native UI boundary is already approved. The disposable local Item, Schedule form, planning-zone picker and observed numeric hour/minute wheels use the existing production path. This check does not implement or test Q96's proposed new unit seam. The literal date-selection driver is scoped to the observed October 2026 starting month and must verify 8 March 2026 before any clock result receives credit.

## Required tests and definition of done

- Open a new unsaved start-only Schedule for a disposable Item, select America/New_York, and choose 8 March 2026 through the native date controls.
- Record the actual hour/minute controls, attempt minute 30 and hour 02, then inspect the native form. Accepted Q10 permits no silent substitution. Retained invalid input must not enable Save.
- Capture the requested date, zone, observed clock state and literal failure/pass. Do not press Save or infer a saved outcome from the draft.
- Retain the exact diagnostic source, compiler/runtime inputs and products, restore the active UI source after the run, lint affected source/report, and separate control failures from product observations.

No production correction, unit model, Core/MCP change, physical-device or overall scheduling qualification is supplied by this investigation alone.

## Observed native result

The current iPad Air 11-inch M4 Simulator on iOS 27.0 uses Xcode 27.1's compiled app/UI target. The native date controls start in October 2026; seven Previous Month actions and day 8 produce the verified 8 March 2026 field. America/New_York is verified before interpreting the result. The Time popover exposes numeric hour/minute wheels. Adjusting minute to 30 and hour to 02 completes without a controller error, but the retained hierarchy immediately shows hour 03, minute 30 and a 03:30 Start value. Closing the popover retains 8 March 2026 03:30 in that zone.

The Q10 assertion against silently substituting another hour fails in 46.157 seconds, with one function, one failure and underlying xcodebuild exit 65. This is a product-policy failure after successful native date/zone/wheel interaction, not a driver failure to reach the requested date. The original hierarchy and individually inspected PNG show no missing-time validation message. Save appears enabled, but the subsequent Save-disabled assertion is not reached after the earlier failure. No Schedule Save action is submitted; this does not establish a persisted wrong-time result or preservation of an existing Schedule during an invalid edit.

The raw runtime log also retains a post-test xcrun warning that it cannot find simctl. The test's assertion and result are recorded before that cleanup output. The warning is retained separately from the observed Q10 failure; no additional product failure is attributed to it.

## Source, evidence and remaining scope

The packet retains the literal compiler/runtime commands and exits, frozen source/product hashes, raw log, four own-app hierarchies, original PNG and exact compressed diagnostic test source. Compiler inputs number 945; the runtime verifies 469 relevant inputs and six products before and after execution. The active UI source is restored byte-for-byte to the committed baseline after the terminal result. The diagnostic source passes strict Swift lint; report and decision-register Markdown lint are checked separately. The restored source and all production code remain unchanged.

This result complements [the missing repeated-time choice](native-schedule-clock-input.md). Both defects concern the accepted native clock-input requirements; Q96's production module and new unit seam still require the human answer. No replacement implementation is authorized by these observations. Supplied-end input, native invalid edits, phone/Mac runtime, Lord Howe native controls, persistence after rejection, signed devices and overall scheduling acceptance remain open. [Creation/resizing compatibility](native-new-item-dynamic-type.md) retains its separate passing scope. Signing and whole-app polish remain deferred as requested.
