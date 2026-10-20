# Native Schedule reads

Status: implemented and locally qualified. Signing remains deferred. The wider map remains open.

## Context, starting state and goal

At `f4d34ea0`, Calendar, Core and MCP support stable Schedule identities, fixed timed instants with a planning timezone, and inclusive all-day civil dates. Shortcuts has no Schedule entity or Schedule read actions. The accepted [scheduling rules](../itineraries-and-scheduling.md) and [Calendar window contract](../calendar-window-contract-review.md) govern this adapter; no Core signature or scheduling policy changes.

Expose one native Schedule entity across both saved forms, preserving its UUID when a form changes. Return the live owner title, source type, All day flag, exact optional timed Start/End, optional all-day Start day/End day, and the optional saved planning timezone. Timed values remain Date instants. All-day values remain complete Gregorian year/month/day DateComponents rather than device-local midnight instants. Inapplicable fields are absent; a missing end remains absent. Readable picker context uses native Foundation date formatting and is separate from these saved values.

Add typed reads for a Schedule, an Item's direct Schedules, an Itinerary's Schedules, a Schedule's optional Item/Itinerary owner, and an inclusive Calendar date window. Parent reads return owned Schedule records, not invented inherited records. An Item scheduled through an Itinerary retains that Itinerary's Schedule identity. Source title and form changes remain live; deleted/missing/wrong-kind sources cannot redirect by cached names or produce a successful fabricated result.

Use the existing generation-bound Schedule catalog and Calendar pages rather than mixing unvalidated rows and forms. Return Core's stable identity order for collections; do not introduce a new chronological query default. Exact-identity resolution preserves requested order, deduplicates repeated requests and omits absent identifiers. Source/read failures propagate. Native arrays and the current Core identity capture do not establish bounded total memory or physical performance.

Schedule picker search uses Foundation's localized standard comparison against current owner titles, including case and diacritic handling. Separate bookings with the same owner remain separate Schedule identities. The stored result fields are fresh at action/query execution; they do not become deferred properties.

| Action | Result |
| --- | --- |
| Find Planner Schedules | All Schedule forms overlapping an inclusive date window in the selected display timezone |
| Get Planner Schedule | Current form and live title for one saved Schedule UUID |
| Get Item Direct Schedules | Only that Item's owned bookings, including retained bookings on archived Items |
| Get Itinerary Schedules | Only that Itinerary's owned bookings, without its children's direct bookings |
| Get Schedule Item | Current typed Item owner, or no value for a valid Itinerary Schedule |
| Get Schedule Itinerary | Current typed Itinerary owner, or no value for a valid Item Schedule |

## Native timezone values

The installed public SDK supports Date/optional Date and date-only DateComponents/optional DateComponents parameters and entity properties. TimeZone itself does not conform to its native value protocol, and the installed AppIntents interface supplies no built-in timezone entity. Use the existing native EntityStringQuery pattern around real Foundation timezone values. Suggestions include known identifiers and common/current aliases; exact resolution and search also accept any identifier accepted by TimeZone(identifier:), including valid values omitted from the suggestion catalog. Preserve original identifier spelling, distinct aliases and localized Foundation names.

The Calendar-window action uses native date-only inputs and an optional typed display timezone, defaulting to the current device timezone at execution. Read civil date fields without travel conversion. Reject incomplete/non-Gregorian/unsupported-era input and impossible Gregorian leap-month flags instead of silently guessing another day; let Core validate the Gregorian dates and inclusive window. This does not change the app's independently remembered display preference or any saved appointment.

## Definition of ready

All temporal behavior above is already accepted. Q112 approves production Intent invocation and EntityQuery methods through Apple's dependency manager and disposable real storage in the existing app-hosted target. Stored result fields are observed through those existing interfaces. No deferred property getter, direct private-helper test, test-only factory, extra target/package or system bypass is introduced. The Foundation-only timezone query uses the same EntityQuery boundary without Planner storage. Q115 estimate input and Q117 deferred content properties remain separate pending choices.

SDK compiler probes for Mac/iOS 27 confirm the native date types and negative TimeZone conformance result. These facts do not prove actual system picker precision, serialization, civil-date rendering or invocation. Those remain explicit system qualification gates.

## Required tests and definition of done

Work in failing-then-passing vertical slices at the declared production interfaces. Verify valid/unlisted/invalid timezone identities, aliases, exact-lookup order/deduplication, search and cancellation. Through real saved data, cover timed fractional seconds, optional/overnight ends, inclusive single/multi-day all-day forms, mixed Item/Itinerary owners, source renames, archived owners, repeated source bookings and form changes without identity replacement.

Verify direct versus inherited schedules, exact typed owner reads, Calendar window boundaries, display-zone changes, DST short/long days and duplicate local clock times. Reject invalid windows and unavailable storage, and preserve original data on precancellation. Validate every page generation, including empty and final reads; never silently truncate a stale collection. Reopen storage and compare public saved values before/after reads. Reads during incomplete recovery must retain the real applied values without acknowledging or repeating mutation.

Run affected Schedule/owner/Calendar regressions, strict Swift/Markdown lint and Mac, Simulator and unsigned generic-device compilation. Inspect the new native parameters, date/array/entity result types and preservation of existing contracts. Record actual commands/exits/source epochs and dispose marked stores only after host exit and closed SQLite handles. Actual system invocation/pickers, physical performance, shared/account-bound storage, CloudKit, Agent Control, installed Share and final whole-app polish remain open. Apple Calendar export remains outside the map.

## Local qualification

The production adapters add two entities/queries and six actions. Fifteen new Schedule cases and two timezone cases exercise the approved production invocation/query boundary. The final affected run also includes the existing Item and Itinerary adapters and two actual Calendar MCP HTTP tests.

| Check | Actual result |
| --- | --- |
| [Final Mac run](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-reads-final-clean/test-results-summary.json) | 45 passed, zero failures/skips: 43 XCTest cases in 21.804 seconds and two HTTP cases |
| [Fixture lifecycle](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-reads-final-clean/fixture-lifecycle-report.json) | All 41 marked fixtures disposed after verified host exit and closed database handles |
| [Mac source/contract evidence](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-reads-final-clean/extracted-intent-identifiers.json) | 63 actions, ten entities/queries, four AppEnums; prior action parameters/results, entities, queries and enums preserved |
| [Simulator compilation](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-reads-mobile-final-clean/exit.json) | App and existing native UI target compile successfully; no tests or system pickers invoked |
| [Unsigned device compilation](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-reads-device-final-clean/embedded-products-verification.json) | App and exactly one embedded mobile Share extension build for arm64; no installation or launch |
| Source equality and diagnostics | All three platform packets contain matching 1033 input hashes and zero compiler warnings/errors; the prior 1029 inputs remain unchanged |
| [Strict lint](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-reads-final-clean/strict-lint.json) | All four added Swift files pass strict swift-format lint |

Compiler-red packets establish the missing timezone/Schedule interfaces before their implementation. The subsequent date-validation run reproduced acceptance of an impossible Gregorian leap-month flag. The timezone-cancellation run reproduced an empty exact-identity request ignoring precancellation. Both fixes pass in the final run. The failed date-validation run remains recorded as failed; its 13 fixtures were removed only after host/database closure. The Foundation-only timezone runs used no Planner storage.

The final cases cover exact fractional instants and absent ends, an overnight overlap whose start precedes the requested day, exclusion of a span ending at the window boundary, inclusive all-day dates, display-zone membership changes, New York's 23/25-hour days and distinct repeated 01:30 bookings. They also cover live renames, form changes with stable UUIDs, typed current owners, archived owners, direct versus inherited bookings, 73-record catalog paging, empty windows, invalid Gregorian inputs, wrong-kind/missing/removed identities, unavailable storage and precancellation. Real recovery-directory obstruction proves that reads retain applied values without acknowledging or repeating the interrupted edit.

The Calendar HTTP regressions verify Core's issued-page invalidation through the real protocol. The native adapter validates its generations through final reads, but these tests do not force every possible concurrent change between its awaits. Actual Shortcuts serialization, picker precision and date presentation remain system qualification work.

## Remaining work

This slice completes Schedule reads only. Schedule mutation actions, richer native content, capture/bulk coverage and other open map features remain. [Q115 estimate input](../native-estimate-intent-input-review.md) and [Q117 deferred content properties](../native-deferred-content-read-contract-review.md) still await decisions. These stored Schedule fields do not implement Q117's deferred getters.

No enrolled-team signing, physical installation, actual Shortcuts/Siri execution, account-bound shared storage, CloudKit synchronization or Agent Control qualification was performed. The generic-device product proves compilation and extension embedding only. Installed Share, physical memory/performance, accessibility/layout qualification and the feature-complete whole-app UI polish remain open.
