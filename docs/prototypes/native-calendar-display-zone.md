# Native Calendar display time zone

## Context and goal

Before: Calendar follows the device time zone and has no display override. Q9 requires both behaviors. After: a native Calendar control lets this device follow its zone or choose another zone; the choice survives relaunch. Saved timed instants, planning zones and all-day civil dates stay unchanged. This is a local view preference, excluded from Planner data and backups.

## Definition of ready

Q9 accepts following the device with an optional display-zone override. A2 keeps Calendar display preferences per device. Reuse the native time-zone chooser and the existing dataset/ownership preference namespace. Core query/read/store and native UI are the approved /tdd boundaries. No Core contract or scheduling policy change is required.

## Definition of done

- Offer native follow-device and zone selection controls from Calendar. Use local preferences; do not add synced fields or backup records.
- Apply the selected zone consistently to queries, native date selection, labels and time grids. Keep the original planning zone in source details.
- Qualify changing zone and relaunch through native UI, proving that the saved start-only form is unchanged. Then qualify all-day dates independently across the same display change.
- Run affected Calendar journeys, strict Swift lint, scoped Markdown lint and the affected Mac app/test-host build. Preserve the separate Mac runtime, temporal, accessibility, scale and physical-device gates.

## Implemented behavior

Calendar now offers a native toolbar action and Form for following the device time zone or selecting an override. The override reuses the existing searchable native planning-zone chooser. AppStorage remembers the choice in the existing dataset/ownership preference namespace. No schedule, Core contract, schema or backup field changed.

The effective zone controls the shared date-window query, native date controls, agenda captions and Day/Week grid. The original source Schedule retains its planning zone and saved form. The all-day journey selects the original civil date after changing the display zone, then returns to following the device and verifies relaunch and source details.

## Validation

The first native /tdd tracer failed at the absent display-zone control. After implementation, the saved start-only journey passed on phone, including override selection, changed Calendar caption, persistence after relaunch and unchanged source Schedule description. A separate all-day journey passed on phone, preserving its original date decoration and description across override, reset and relaunch.

Review found that the Mac test selected a date identifier the native Month control never exposed. The test now uses its existing formatted accessibility label. A private test helper consolidates the repeated native chooser interactions; assertions about each schedule remain in their own journeys.

All seven affected phone Calendar functions passed. On tablet, the six Month/inspector/Day/Week regressions passed, while both timezone journeys failed to open the chooser. The recorded hierarchy and video show that the inner-switch tap left the native Toggle on. Whole-row activation, mobile frame removal and dataset view-identity changes did not fix it. Temporary diagnostics were removed, and the speculative identity change was reverted.

The settings now use the same default native Form sheet presentation as the working Schedule editor. Removing the custom medium/large detents lets the tablet switch turn off and open its chooser. The fixture waits for that false state and selects the chooser by its actual accessibility identity. That journey then exposed active search covering the settings toolbar after returning from the chooser.

The shared chooser now uses Apple's [dismissSearch action](https://developer.apple.com/documentation/swiftui/environmentvalues/dismisssearch) inside the searched results view, then pops the chooser. This ends search and releases keyboard focus before returning to the native Form. Item and Itinerary scheduling reuse that chooser, so their existing Cancel/Save/relaunch journeys join the affected qualification. The final runs use stable source; the other Calendar journeys are unchanged.

Both final timezone journeys pass on phone and tablet. The shared Item and Itinerary planning-zone journeys also pass on both devices, including staged Cancel, Save, identity/instant preservation and relaunch. Together with the unchanged Calendar regressions, nine distinct phone functions and ten tablet functions are qualified. The Calendar regressions preceded the settings presentation and shared search correction; their ordinary Month/inspector/Day/Week paths were unchanged by those corrections. An earlier phone sizing attempt was interrupted and supplies no qualification.

The final Mac app and native test host compile. Four affected Swift files pass strict lint; scoped Markdown and whitespace checks pass. Standards and Spec reviews have no remaining confirmed findings. Core contracts, schemas, commands and HTTP routes are unchanged, so this step reuses their earlier qualification.

| Native check | Phone | Tablet |
| --- | --- | --- |
| Display override, caption change, relaunch and unchanged start-only source form | Pass | Pass |
| All-day original civil date, return to following device and relaunch | Pass | Pass |
| Item planning zone, Cancel/Save, unchanged instant and relaunch | Pass | Pass |
| Itinerary planning zone, Cancel/Save, unchanged owner/instant and relaunch | Pass | Pass |

The [execution record](evidence/navigation/native-calendar-display-zone/execution.json) retains actual result summaries/trees, failed diagnostic attempts, source/product hashes and original native captures. [Phone](evidence/navigation/native-calendar-display-zone/phone-civil-date.png) and [tablet](evidence/navigation/native-calendar-display-zone/tablet-civil-date.png) captures show the retained all-day date under the override. Phone agenda captions can extend beneath the floating tab bar until scrolled; the whole-app polish gate retains that layout concern.

## Remaining gates

Mac runtime remains unqualified after the earlier runner startup failure. Short/long-day Week alignment, repeated-hour descriptions, physical travel, keyboard/VoiceOver/Dynamic Type, responsive layouts and storage-scale performance remain separate Calendar gates. Signing, physical sync/account/recovery/Share and whole-app polish remain open on the map.
