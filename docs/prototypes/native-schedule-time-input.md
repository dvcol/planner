# Native schedule civil-time input

Status: Q96 is implemented at the approved app-internal value-module seam. Nine Foundation/Core functions pass. Missing/repeated New York Start, Lord Howe Start and supplied-End journeys pass on both mobile layouts, as do three existing scheduling regressions on each. Rich-draft resizing, selected-deletion replacement and Inbox compatibility pass on phone and tablet. Two Itinerary caller regressions pass on tablet and in the separate current-source iPhone follow-up below. Mac runtime, physical checks and broader native acceptance remain open. The integrated form uses neutral civil-minute DatePicker values and the same production input module for Start and supplied End.

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

### Supplied-End and resizing follow-up, first phone attempt

The new End case fails in its test's button-only lookup of the Include end Toggle, before entering End, in 175.036 seconds including teardown. Standards review identifies that selector; the corrected source uses the established any-role query. Spec also identifies a masked oracle: moving End to March while Start stays in November would disable Save for ordering alone. The corrected scenario first stages a valid March 8 01:30 Start and requires enabled Save, then enters the nonexistent 02:30 End. A silently normalized 03:30 would be later than that Start, so ordering cannot hide missing-time admission. Both reviewers confirm their respective corrections in the prepared snapshot. Production code is unchanged.

The independent New Item draft-layout journey completes its assertions at 244.57 seconds, including rotation, retained fields, saved estimate/bookmark/source identity, original List association and relaunch, but exceeds its six-minute allowance during teardown. It has no formal passing result. Its rerun uses a longer native test allowance and does not change product timeouts. All three selected original phone PNGs were individually inspected. The expanded draft capture shows the floating TabView overlapping the Add Link area, retained for polish. Neither that capture nor completed assertions override the terminal timeout.

### Qualified phone endpoints and draft resizing

The corrected batch formally passes all three functions, 485.648 seconds total. Draft resizing passes in 249.274 seconds, native Lord Howe input in 87.264 seconds and supplied End in 149.111 seconds. The longer per-function allowance permits native teardown; no product timeout changes. Production source is unchanged from the integrated implementation checkpoint.

Lord Howe input enters 5 April 2026 01:45 and requires a choice before Save. UTC+11:00 saves the literal 4 April 14:45Z; UTC+10:30 saves 15:15Z. Both reopen after relaunch with one unchanged Schedule identity. The supplied-End journey selects New York 1 November 01:45 EDT as 05:45Z. End 01:15 EDT is rejected, while 01:15 EST saves as 06:15Z. A later edit first establishes valid 8 March 01:30 Start, then enters nonexistent 02:30 End, requires its warning and disabled Save, and cancels. Relaunch retains the original November span and identity.

The draft journey retains fields through compact and expanded layouts, then saves the 12-hour estimate, bookmark identity, owned location and shared Item into the originating List. Relaunch confirms the same Item identity, one global Item and no membership in the other List. All thirteen original PNGs in [the final phone epoch](evidence/navigation/native-schedule-time-input/phone-clock-endpoint-qualified-attempt/selected-captures.json) were individually inspected. Its landscape capture still shows floating tabs overlapping the Add Link area. Functional resizing passes; whole-app readability and spacing remain polish work.

### Existing phone scheduling compatibility

All three existing regressions pass, 190.361 seconds total: inclusive all-day editing in 68.742 seconds, optional End clear/cancel/save in 52.433 seconds and staged timezone selection in 69.187 seconds. They preserve native readback and relaunch behavior after the new civil-time input integration. All eleven original PNGs in [the compatibility epoch](evidence/navigation/native-schedule-time-input/phone-schedule-compatibility/selected-captures.json) were individually inspected. The all-day warning, inclusive dates, native zone choices and retained schedule rows agree with the assertions.

Each native epoch verifies its repository source and compiled-product hashes before and after execution. These focused results do not close Itinerary caller, Mac UI, physical, signing, accessibility or final-polish gates. XCTest startup and teardown durations are not responsiveness measurements.

### Existing iPad scheduling and draft compatibility

All four functions pass, 409.376 seconds total: draft resizing in 215.400 seconds, inclusive all-day editing in 70.830 seconds, optional End in 53.740 seconds and staged planning-zone selection in 69.405 seconds. All thirteen original PNGs in [the iPad compatibility epoch](evidence/navigation/native-schedule-time-input/tablet-schedule-and-draft-compatibility/selected-captures.json) were individually inspected. Draft fields remain present across portrait and landscape; the List origin and editor remain separate. Saved all-day, optional-end and timezone rows retain their source context after relaunch. Stacked top navigation, duplicate titles and technical footer wording remain polish items.

Final Standards review identifies duplicated native occurrence-selection code in the shared Start helper. It now calls the existing selection helper. Both separate review axes verify all seven final snapshot hashes and report no remaining confirmed findings. Production and value/Core test sources are unchanged. The affected native caller runs against a separately compiled epoch; review itself supplies no runtime credit.

### Reviewed phone Start and catalog compatibility

The rebuilt phone batch passes all four functions, 533.435 seconds total. Missing Start passes in 59.662 seconds and repeated New York Start in 87.993 seconds, including literal UTC expectations and Schedule identity after each relaunch. The reviewed shared occurrence helper is exercised by that repeated-Start run. Selected-deletion replacement passes in 67.938 seconds and Inbox membership/filter/sort/source-state compatibility in 317.843 seconds. These catalog cases use the integrated presentation-window sources.

All thirteen original PNGs in [the reviewed phone epoch](evidence/navigation/native-schedule-time-input/phone-clock-and-catalog-compatibility/selected-captures.json) were individually inspected. Compact deletion returns to the surviving catalog without opening another Item's detail. Inbox excludes listed Items, reveals an archived completed Item only through the cumulative filters, then restores an Item after its final membership is removed without promoting its local completion to global completion. Relaunch retains the descending sort and default visibility filters. The missing/repeated clock controls and saved rows agree with their assertions. Native animation-idle waits contribute to the duration; this is no physical responsiveness measurement.

### Final iPad endpoints, Itinerary caller and catalogs

All six functions pass, 854.909 seconds total: selected-deletion replacement in 76.627 seconds, Inbox compatibility in 314.127 seconds, Lord Howe input in 93.475 seconds, supplied End in 160.979 seconds, Itinerary planning-zone edits in 89.543 seconds and Itinerary conversion/removal in 120.158 seconds. Source/product guards pass against the reviewed mobile build. Production remains unchanged from the integrated implementation checkpoint.

All twenty-two original PNGs in [the final iPad epoch](evidence/navigation/native-schedule-time-input/tablet-clock-itinerary-and-catalog-compatibility/selected-captures.json) were individually inspected. Regular-layout deletion opens the first surviving source's own notes automatically. Inbox retains cumulative filters and independent source completion. Lord Howe and both End occurrences match the literal instant assertions, including saved-span preservation after the missing-End draft is canceled. Itinerary zone-only Save preserves its owner and instant; all-day conversion reloads its inclusive form. Confirmed removal retains the owner and its other appointment after relaunch.

This completes the recorded focused mobile clock-input and compatibility slice. The Itinerary caller has tablet qualification here; no phone Itinerary, Mac UI, physical-device, full accessibility or whole-app acceptance is inferred. Existing performance and final native-polish gates remain open. The inspected Itinerary captures also retain a larger toolbar gap below the floating tabs than the Item catalog, for the explicit spacing review.

### Current iPhone Itinerary follow-up

The two existing Itinerary callers now pass on iPhone 18 Pro Simulator, iOS 27.0 build 24A434, with dark appearance and Increase Contrast. Planning-zone Cancel/Save/relaunch passes in 202.007 seconds; timed-to-all-day conversion and confirmed removal passes in 227.989 seconds. The invocation executes exactly two tests with zero failures or skips. Native teardown contributes to those durations; they do not measure app responsiveness.

This closes the phone caller gap left by the preceding tablet checkpoint. The existing Q34 native UI boundary uses disposable real local datasets and unchanged production code. No additional test interface, target or fixture control is introduced. [The current epoch](evidence/navigation/native-itinerary-window-compatibility/phone-itinerary-clock-followup/) links the exact compiled app/test products and source hashes at `4b148a31`, with no source differences. Guards pass before and after runtime; appearance and contrast return to their original values.

The zone journey retains the Schedule and Itinerary identities, notes and start-only form through Cancel, Save and relaunch. Its parsed displayed times agree across the selected zones at the row's minute precision. Exact fractional-second retention remains the earlier Foundation/Core evidence, not a stronger claim from formatted UI text. The conversion journey reloads the saved all-day controls, cancels staged conversion without changing the saved timed form, removes only the confirmed selected assignment and retains the other appointment and owner after relaunch.

All seven original captures were checked. Native Save/Cancel, planning-zone explanation, inclusive all-day dates, scoped removal confirmation and retained saved details are readable in the represented dark/contrast state. Original-file RGB comparison also confirms matching title/notes/schedule regions across the timezone-save and relaunch captures, and identical app-content pixels across the removal-save and relaunch captures. Original PNGs remain unchanged. The packet retains inspection findings, exact commands, summary, hashes and restored appearance. Markdown and whitespace checks pass; no Swift changes require a new compiler epoch.

The separate Archive Intent green check still awaits a working Mac XCTest IDE session. Q113, Mac interaction, shared/account-bound storage and CloudKit implementation, installed Share, system Intents/clients, physical performance and feature-complete whole-app polish remain open. Signing stays deferred.
