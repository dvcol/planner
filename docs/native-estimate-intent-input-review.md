# Estimate input in Shortcuts

Status: Q115 A accepted on 21 October 2026. Quantity, Unit and Additional minutes are approved, using the existing production Intent test boundary.

## Context and settled behavior

At `249936f7`, Item/List/Itinerary estimates work through Core and native editors but have no App Intent parameters or estimate reads. The [accepted duration rules](duration-and-search.md) and [content catalog](content-and-reader-review.md) require positive whole Int64 minutes and a separately retained display unit. The range is 1 through 9,223,372,036,854,775,807 minutes. A unit does not require divisibility: 125 minutes displayed in hours means 2 hours 5 minutes. The existing app picker preserves this value when its display unit changes.

Fixed minute factors are minute 1, hour 60, day 1,440, week 10,080, month 43,200 and year 525,600. These are planning estimates, independent from calendar arithmetic, DST or booked Schedule ends. An Item estimate can be explicitly cleared. Clearing a List/Itinerary manual estimate selects calculation; a deliberate manual value otherwise persists. Core supplies full/calculated/remaining summaries and uncertainty, so an adapter must not invent another aggregation formula.

## Verified public SDK facts

The installed Xcode 27 SDK accepts native Int and six-case AppEnum parameters. Int is 64 bits on the supported arm64 target. Native `Measurement<UnitDuration>` parameters support hours/minutes/seconds and subsecond units, with no pre-made day/week/month/year choices. Their Double value cannot preserve every Core minute integer: adjacent values at Int64.max collapse, and converting Double(Int64.max) back exactly fails.

Swift.Duration is also a supported native parameter with the same missing large-unit choices. It retains elapsed attoseconds rather than the user's chosen display unit. Its signed Int128 representation holds at most 2,835,686,391,007,820,528 positive whole minutes, less than Core's accepted maximum. Public attoseconds permit safe integer inspection, but cannot extend that representation. DateComponents parameters expose date/time/dateTime configuration and do not establish an elapsed-duration picker.

The [retained probe](prototypes/evidence/navigation/native-itinerary-window-compatibility/app-intent-estimate-parameter-facts/) contains the actual source, compiler command/exit and executable output. It compiles public parameter declarations and verifies units, precision and bounds. It invokes no Planner action, Shortcuts system picker or GUI, and changes no signing/account setup. Public references: [duration parameter configuration](https://developer.apple.com/documentation/appintents/intentparameter/duration), [UnitDuration](https://developer.apple.com/documentation/foundation/unitduration), [Swift.Duration](https://developer.apple.com/documentation/swift/duration) and [DateComponents parameters](https://developer.apple.com/documentation/appintents/intentparameter-date-components).

## Q115 alternatives and impacts

A. Native Quantity, Unit and Additional minutes parameters. Unit offers all six planning units; Additional minutes defaults to zero. Two Hours plus five minutes preserves 125 minutes with Hours display. Checked integer multiplication/addition supports the complete accepted range without floating-point conversion or a duration string. For example, Int64.max minutes can be entered directly as Minutes or as 17,548,272,520,652 Years plus 84,607 minutes. This requires three fields.

B. Native Minutes and Display unit parameters. Two fields preserve the same exact values and range, but users must convert larger durations themselves.

C. Apple's native duration parameter and a separate display-unit enum. This offers system duration entry but requires conversion for larger units and narrows the Shortcuts maximum below Core's. It would explicitly revise full-range parity for this adapter; it must not be selected silently.

Recommendation: A, matching all existing units while preserving exact mixed durations and range. Actual system field presentation, entry range and round-tripping remain qualification gates under every option. The existing native app editor is unchanged.

## Definition of ready and required validation

Q115 A authorizes the selected input presentation. Q33's ordinary edit authority, changed-field hash guard and Q112 A's production Intent invocation boundary already apply. No additional test hook, target or direct private-helper test boundary is proposed.

After the choice, test literal mixed durations and every fixed unit through the actual production action with disposable real storage. Qualify the upper bound, checked conversion failures, nonpositive input, explicit clearing, unrelated owner fields/references/completion/bookings, derived container estimates, cancellation and truthful recovery outcomes. Use current Core summaries for reads and distinguish uncertainty. Verify metadata and affected platform compilation separately from actual system invocation. None of these checks may claim physical performance or system-picker proof from a standalone type probe.
