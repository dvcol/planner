# Native schedule civil-time input

Status: Q96 implementation is in progress at the approved app-internal value-module seam. Eight real-Foundation value-module tests pass, including exact saved retention and planning-zone changes. A ninth test passes through real Core persistence, guarded rejection and store reopening. The integrated form has two passing iPad Start-input journeys. Supplied End, phone, scheduling regressions and broader qualification remain required. The integrated form uses neutral civil-minute DatePicker values and the same production input module for Start and supplied End. Native correctness is still under qualification.

## Context and starting state

The [approved contract](../native-schedule-time-input-contract-review.md) requires retaining entered civil fields, rejecting nonexistent local times and asking for an explicit repeated-time occurrence. Earlier native probes establish that direct DatePicker bindings normalize a gap and do not provide that occurrence choice. Core correctly accepts resolved instants, so this correction belongs before native Save.

## Goal and expected end state

Use the same production value module for Start and supplied End. Keep native DatePicker, Form and Picker controls. A missing or unchosen time stays entered and disables Save. A supplied End must resolve after Start. Preserve exact unchanged saved instants, including fractions, when unrelated fields or only the planning zone change. Keep all-day dates, source/Schedule identity, Core/MCP contracts and backups unchanged.

## Definition of ready

Q96 A approves SavedScheduleTimeInput and its observable operations before its real-Foundation tests in the existing app-hosted target. Core persistence and native UI are already accepted boundaries. No package, target, test-only initializer or provider mock is needed.

## Required tests and definition of done

Implement one behavior after its failing test. Qualify New York's missing minute and two repeated occurrences, Lord Howe's half-hour repeat, explicit current-candidate selection, stale-candidate rejection, same-minute normalization, exact saved fractional retention and planning-zone changes. Resolve Start and End independently, including an earlier-looking later occurrence. Follow with real Core save/readback and native controls that actually enter missing/repeated fields. Run affected lint/compiler checks, inspect original native captures and review Standards/Spec separately. Mac runtime, physical qualification, signing and whole-app polish retain their existing gates.

## Executed module results

The direct runner loads the exact compiled app debug library and embedded XCTest bundle with a sanitized environment. It uses the same approved production interface and real Foundation as the app-hosted target, without a new target or alternate resolver. It does not qualify the stalled Xcode IDE-session workflow or native UI interaction.

| Behavior | Genuine failing result | Subsequent result |
| --- | --- | --- |
| New York 2026-03-08 02:30 remains entered and unresolved | One test, one assertion, 0.261 s: unavailable instead of nonexistent | Same test passes, 0.008 s |
| New York repeated minute requires explicit current occurrence | Two functions, ten assertions, 0.264 s | Both functions pass, 0.018 s |
| Lord Howe has two occurrences separated by half an hour | Three functions, five assertions, 0.266 s | All three functions pass, 0.018 s |
| Unchanged saved occurrence retains fractions until an explicit edit | Four functions, five assertions, 0.327 s | All four functions pass, 0.017 s |
| Zone changes distinguish unchanged saved authority from new/rescheduled input | Five functions, eleven assertions, 0.239 s | All five functions pass, 0.020 s |
| Ordinary input, unavailable-input correction and unresolved zone reinterpretation | Qualification of existing behavior, no artificial failure | All eight functions pass, 0.034 s |

The first resolver uses Foundation strict matching and exact civil-field round trips. Construction supplies an approximate day only; a normalized construction result is never accepted as the requested time without that round trip. An initial strict-format check found guard indentation; formatting is corrected before the next compiled epoch. No native form or persisted-outcome credit is inferred from this first module pass.

The real Lord Howe regression confirms that strict first/last calls alone return the same earlier candidate on this Mac runtime. Discovery now also checks offsets at the actual calendar day's bounds, constructs candidate instants from the neutral civil value and validates every candidate's exact round trip. It assumes neither a fixed day length nor a one-hour correction. The new/changed New York minute remains unresolved until an explicit current choice; stale candidates leave it unchanged. Saved fractional authority now survives a same-minute setter and zone-only changes. Explicit minute or occurrence changes clear that authority. Native integration and platform qualification remain open.

## Value-module review

Standards and Spec reviewers independently examined the immutable value-module snapshot and approved contract. Both reported no confirmed findings. Spec verified its three snapshot hashes. Their scope covers the eight-test value slice only; it supplies no native form, endpoint persistence, Mac UI or physical qualification. The subsequent Core readback test is a separate qualification slice.

## Core persistence qualification

The nine-test run passes in 0.107 seconds. Its additional test creates a real local-only Planner store, selects earlier New York 01:45 as 05:45Z and later 01:15 as 06:15Z, then saves and reads the resulting timed Schedule through public Core commands. Selecting earlier 01:15 produces an invalid edit; Core rejects it and preserves the form and field hashes. A subsequent exact fractional form survives a same-minute setter, a Paris zone-only replacement, an unrelated Item notes edit and a new Planner instance reading the same store. Source and Schedule identities remain equal. This qualifies the resolved-instant/Core boundary, not native input or device synchronization.

The first compiler attempt could not write Xcode's normal user caches under the workspace sandbox. The identical focused retry with cache access compiled successfully. The direct test runner uses a sanitized environment, verifies source/product hashes before and after execution, and removes the dedicated temporary store only after the runner process exits. No account or CloudKit store is involved.

The subsequent immutable integrated-form snapshot also has no confirmed Standards or Spec findings. Spec verified all five hashes. That review covers independent endpoints, actual-instant ordering, optional end, all-day separation, exact retention and approved test boundaries. Native runtime qualification is still pending and is not inferred from this review.

## Native form integration under qualification

The real Item/Itinerary form now binds native date/time controls to neutral Gregorian civil-minute carriers, then uses the shared input module's resolved instants for Save. It shows endpoint-specific missing/unavailable messages and a native occurrence Picker with date-specific zone abbreviation and UTC offset. Save requires a resolved Start and, when included, a resolved End strictly after Start. The all-day path remains civil-date based; toggling modes carries the visible date without saving a neutral carrier as an appointment. Zone-only changes go through the module rather than reconstructing stored minutes.

Both simulator and Mac app-hosted test compilations pass with the integrated form. The selected native missing/repeated Start journeys now pass on iPad, with the narrower results below. Mac uses only local ad hoc compilation, with UI runtime and account signing still pending.

### First native controller attempt

The first iPad run reaches the form but both functions fail before selecting the target date, at a test-only attempt to parse the first compact date-control button's label. Formal durations are 151.010 and 146.985 seconds, including native teardown. These are controller failures with no missing/repeated-time correctness or saved-outcome credit. The corrected driver reads the open native calendar's displayed month, navigates from it and still verifies the requested literal date and clock after selection. Production form code is unchanged by that correction. The Mac integrated epoch separately passes all nine Foundation/Core functions in 0.108 seconds.

### Qualified iPad Start input

Both final iPad functions pass, in 184.003 and 209.993 seconds, 393.996 seconds total including native teardown. The controller uses the open calendar's actual month value. A retained hierarchy confirms why parsing the first compact button failed: it is a wrapping "Date and Time Picker" button, with the actual date/time buttons inside it.

The missing-time journey enters and verifies 8 March 2026 02:30 in New York, requires the visible validation message and disabled Save, then cancels and relaunches the Item with no Schedule. The repeated-time journey enters 1 November 2026 01:30, requires disabled Save before a choice, then explicitly saves UTC-04:00 and UTC-05:00. It parses each real saved row against literal 05:30Z/06:30Z expectations and relaunches after each choice, retaining one Schedule identity and the same description. Editing an existing occurrence permits Save without requiring another choice.

All nine retained original PNGs were individually inspected, along with the entered-field hierarchies. The actual native Form, DatePicker, Picker and saved rows agree with these assertions. This is a focused iPad Start-input result; supplied End, invalid saved edits, Lord Howe native input, phone and existing all-day/optional-end/zone-only regressions remain open. Mac UI, physical devices, signing and whole-app polish remain separate gates. No ticket is closed by this checkpoint.
