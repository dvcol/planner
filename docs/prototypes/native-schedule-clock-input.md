# Native schedule clock input investigation

Status: historical pre-Q96 diagnostic evidence. The human approved Q96 A on 17 October 2026. The [implementation report](native-schedule-time-input.md) now records the value module, real-Core qualification and native form integration in progress. Statements below about the then-proposed interface and old form describe that diagnostic epoch; they are not current pending approvals.

## Context and goal

The accepted schedule requirements include rejecting nonexistent local times, choosing repeated occurrences explicitly for new/changed clock input, retaining unchanged stored instants and comparing resolved endpoints. The current native form binds DatePicker directly to resolved Date values. Before replacing it, determine the actual native input controls and the limits of the proposed Foundation operations.

The end state for this investigation is a concrete production/test contract and reproducible evidence explaining the missing work. The end state for the later implementation is the accepted schedule behavior through both native form callers. [The contract proposal](../native-schedule-time-input-contract-review.md) names that interface, exact fixtures, definition of ready and required tests.

## Existing seams and limits

Temporary native UI probes use the already approved production UI seam, a disposable local dataset and actual Schedule controls. They do not add a unit-test seam, package, production flag or dependency injection. The existing test source is restored after each terminal invocation, while the exact diagnostic controller is retained separately. No Schedule is submitted by these probes.

The Foundation probes are throwaway API investigations on Mac. They import Foundation, without importing Planner. Their assertions and observations do not qualify a Planner implementation or iOS behavior. The proposed value-module interface still requires confirmation before its unit tests are written.

## Foundation observations

On macOS 27.0.1 with Xcode 27.1 and timezone data 2026e, complete civil-field strict matching rejects the tested New York and Lord Howe gaps. Clock-only strict matching can advance to the next day. New York's repeated 01:30 returns the expected 05:30Z and 06:30Z.

Lord Howe's 5 April 2026 01:45 exposes a limit of the tested first/last operations. Both return 4 April 14:45Z, although independent instant-to-civil round trips also confirm 15:15Z. These offsets differ by 30 minutes. Calendar/NSCalendar search and enumeration variants reproduce the mismatch, while the transition API reports the offset change. No fixed one-hour correction or complete replacement algorithm is established by these observations.

A saved later New York occurrence with fractional seconds remains exact when retained as Date. Reconstructing it from its displayed minute instead loses the later occurrence and fraction. The implementation must retain stored authority separately from its native display carrier.

Apple documents [strict matching](https://developer.apple.com/documentation/foundation/calendar/nextdate(after:matching:matchingpolicy:repeatedtimepolicy:direction:)), [first/last policies](https://developer.apple.com/documentation/foundation/calendar/repeatedtimepolicy) and the [transition API's scope](https://developer.apple.com/documentation/foundation/timezone/nextdaylightsavingtimetransition(after:)). The retained facts note supplies installed SDK references, commands, raw outputs and the narrower limits. The observed Mac mismatch is not a claim about every Apple runtime.

## Native control observations

The first iPad diagnostic selects America/New_York and 1 November 2026. It passes in 35.905 seconds, but its array-indexed supposed Time button reopens Date because the picker also exposes a wrapping Button. Its screenshot is inspected and retained as date-control evidence only.

A corrected selector resolves the observed Time label. This diagnostic passes in 36.568 seconds. Its inspected original capture shows the actual native hour/minute wheels. The accessibility speech values include units. A subsequent regression controller passes those speech values to the adjustment API and fails before entering 01:30. The error reports numeric wheel options instead. That failure is a controller observation and provides no product-red credit.

The corrected regression tracer uses those observed numeric options. It verifies the native fields show 1 November 2026, 01:30 and America/New_York after dismissing the Time popover. The original screenshot and hierarchy show no occurrence choice and an enabled Save. The Q11 assertion that Save must remain unavailable fails in 44.581 seconds, with one function and one failure, underlying xcodebuild exit 65. This is a product regression observation, distinct from the preceding wheel-controller failure in 40.831 seconds. The tracer does not press Save, so it establishes no stored wrong-occurrence outcome.

| Observation | Literal result | Meaning |
| --- | --- | --- |
| First date-control diagnostic | Passed, 35.905 seconds | Date selected; supposed Time action reopened Date. |
| Actual Time-control diagnostic | Passed, 36.568 seconds | Native hour/minute wheels inspected. |
| Speech-value wheel controller | Failed, 40.831 seconds | Numeric options required; target clock not entered. |
| Corrected Q11 native tracer | Failed, 44.581 seconds | Required clock/zone confirmed; Save enabled without explicit occurrence choice. |
| Four mobile compiler invocations | Passed | Diagnostic controllers compile; no passing implementation claim. |

All three retained original screenshots were inspected individually. The final one shows the complete native form and exact repeated-time fields. Earlier passing diagnostics establish no missing/repeated-time correctness. The temporary tracer and all compiler/runtime source epochs remain in the packet; the active test file is restored exactly to its committed version.

Both contract reviews required distinguishing new/rescheduled drafts from unchanged stored endpoints and normalizing picker comparisons at civil-minute precision. The proposal now specifies those cases and their contrasting literal tests. Standards and Spec report no remaining contract finding. This is review of an unimplemented proposal, not approval from the human or qualification of a production module.

## Evidence and remaining work

[The evidence packet](evidence/navigation/native-schedule-clock-input/) retains compiler/runtime commands, literal results, frozen source/product hashes, original hierarchy/capture files, historical controller attempts and the Foundation sources/logs. The [Calendar resize report](native-calendar-grid-inspector-layout.md) links the prior compatibility checks; this investigation supplies no new layout acceptance.

Q94 label presentation and Q95 Item windows remain independent pending choices. Q96 concerns the new production time-input interface and real-Foundation unit seam. Signing, Mac UI runtime, physical CloudKit/account/Share qualification and whole-app native SwiftUI polish remain under their existing gates. No complete scheduling or map gate is closed.
