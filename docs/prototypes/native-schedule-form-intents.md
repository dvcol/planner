# Native Schedule creation and replacement

## Context, starting state and goal

Q118 A approves four focused creation actions. Q124 A approves their concrete civil inputs, and Q125 A approves two focused whole-form replacements. Before this slice, Shortcuts could read bookings, clear their end and change a planning timezone, but could not create or replace a complete booking.

The native library now contains timed and all-day creation for Items and Itineraries, plus Set Schedule to timed and Set Schedule to all day. Creation returns the exact generated Schedule entity without a read after saving. Replacement retains the saved Schedule and its actual owner, reads current form hashes and submits through the existing guarded writer. Cached names or owner-type descriptions never redirect the action.

## Inputs and resulting behavior

Timed actions take native civil date/time fields and a separate required planning timezone. End and independent Earlier/Later choices for both endpoints are optional; neither occurrence defaults. The existing SavedScheduleTimeInput resolves candidates. A skipped time fails; a repeated minute requires its own explicit choice. A supplied End must be later as an instant, including across a repeated hour. Missing End stays absent and never comes from an activity estimate.

Gregorian minute fields must be complete and exact. Seconds/fractions other than zero, invalid dates, inconsistent supplied civil fields and unsupported calendars reject rather than normalize. The planning zone controls interpretation; an embedded component timezone does not reschedule the fields.

All-day actions take Gregorian civil dates with an optional inclusive End. Omission means one day; an equal End is valid and an earlier End rejects. No planning zone or occurrence field is declared. Whole-form replacement explicitly clears an old End when the new End is omitted. Focused Clear End and Set Timezone actions retain their existing exact-instant behavior.

Complete, rejected, unverified and applied/incomplete recovery outcomes remain distinct. An applied booking and its exact identity remain available when independent recovery fails; further changes stay blocked until explicit native recovery retry. The adapters add no backup, deletion or account-administration action.

## Definition of ready and tested boundaries

The [civil input and replacement contract](../native-schedule-civil-intent-contract-review.md) was approved before dependent implementation. Q112 covers production Intent invocation through Apple's dependency manager with disposable actual Planner storage; Q96 already covers the shared native clock-input value. No new test target, injected resolver, test-only clock, confirmation hook, package, Core/MCP form or backup format is added.

## Qualification

The final hosted invocation passes **68 tests, 0 failures and 0 skipped**: 20 new creation/replacement/safety cases and 48 affected Schedule read, end, zone, removal, provider and clock regressions. Its original packet retains selected commands, the actual result summary, source hashes and verified fixture closure.

The new cases establish:

- All four creation paths save and return exact identities, current owner titles and the requested form. Rich shared content, independent completion contexts, estimates and existing bookings survive reopening.
- New York skipped/repeated minutes and Lord Howe's half-hour transition obey explicit occurrence choices. Start and End resolve independently; an earlier clock label can be a later valid instant. Invalid/partial dates, unsupported precision, contradictory fields and non-later ends leave the saved graph unchanged.
- Inclusive all-day ranges, explicit single-day ends and omitted ends persist without a timezone. Invalid, incomplete, non-Gregorian or reversed all-day input rejects together.
- Both replacements preserve the Schedule and real owner through conversions, clear omitted endpoints and retain unrelated bookings, fractional instants and independent owner edits.
- Missing, wrong-kind, removed, precancelled and unavailable selections fail without substitution, resurrection or partial changes.
- Actual precommit recovery-filesystem faults leave each of the six actions unapplied. Actual post-save obstruction retains each whole result, blocks later changes and repairs its original operation without duplicating or reapplying the booking.

Metadata verifies six new actions returning Schedule entities, required typed targets, native date/dateTime kinds, optional ends and no occurrence defaults. All previous 75 action contracts, entity properties, queries, enums and four discoverable shortcuts remain unchanged; the Earlier/Later enum is the sole new enum. Mac, Simulator and unsigned-device builds and extraction report 81 actions from the same 1,056 hashed source inputs. Strict lint on six affected Swift files, documentation lint and whitespace checks pass. Final validation retains their commands and exits.

## Red/green evidence

Missing-action compiler reds precede each creation/replacement family and its green run. The first timed Item red also produced cascading type-inference diagnostics, corrected with an explicit expected form type. A separate contradictory-fields red demonstrated a real adapter validation gap: a mismatched weekday could create a booking. Exact supplied-field comparison fixes it while continuing to ignore the embedded timezone. The original failed run remains failed and has separate verified disposal of its closed fixture. Subsequent input and final suites pass.

Each early green receives only its actual selected-case credit. No passing compiler result, declared metadata or store fixture is represented as actual system Shortcuts invocation.

## Remaining acceptance

Actual Shortcuts picker rendering, civil-field serialization, system invocation, background/locked launch and physical-device entry remain open. In particular, direct DateComponents tests do not establish that a real system picker preserves an invalid entered clock value before handing it to Planner. The existing Customer-build system-testing rejection remains unresolved; no result here establishes that paid signing fixes it.

The current-form hash is forwarded to Core's existing edit guard. This suite does not control an actual system invocation's interleaving between reads and submission. Signed/shared storage, CloudKit/account transitions, installed Share, physical performance, actual Mac window journeys and final whole-app polish retain their separate map gates. This local slice closes no prototype issue.
