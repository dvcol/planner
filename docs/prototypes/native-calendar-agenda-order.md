# Native Calendar agenda order

## Context and goal

The Month agenda discovers saved Schedule identities through Core's catalog. That catalog deliberately orders Schedules by UUID; it does not promise chronological presentation. Before this step, Calendar displays that catalog order unchanged. After this step, the agenda presents all-day assignments by their civil start dates and timed assignments by their fixed start instants, with stable identity ties. All-day assignments remain ahead of timed appointments. No Schedule is rewritten or copied.

## Definition of ready

Q60/Q61 approve the main Calendar destination and Day/Week/Month planning. Inclusive all-day civil dates, fixed timed instants and optional ends retain their existing contract. Core's catalog default remains unchanged under the [adapter contract](../adapter-contract.md). The accepted native UI seam provides the ordering regression; existing Core Schedule tests qualify saved forms and identities.

## Definition of done for this step

- Calendar ordering follows saved dates rather than the catalog's UUID order. Equal starts use Schedule identity as a deterministic tie.
- All-day comparisons use civil year/month/day fields. Timed comparisons use their stored instants, without manufacturing an end or using activity estimates.
- The native journey creates two overlapping assignments through the actual Item and Schedule forms, then makes their date order opposite to their identity order. Selecting their common day must show the earlier assignment first while retaining both original Schedule identities.
- Run the new journey on phone and tablet, the existing four Calendar journeys, strict lint and the Mac app/test-host build. Record actual outcomes and inspect native captures before commit.

## Tests and qualification

The native ordering regression failed at its exact identity-order assertion before the agenda implementation changed. It then passed one function on each simulator. Final qualification passes five native functions in two suites on each simulator, with no failures or skips. Strict lint passes two Swift files; the Mac app and test host build with no Mac runtime functions. Both source review axes report no confirmed findings. Execution evidence records final source hashes, actual result trees, commands and two inspected original captures. This new journey proves overlapping all-day order; timed multi-event, mixed-form and tie fixtures remain open. The existing Month qualification remains historical evidence for [the initial destination and source details](native-calendar-month-agenda.md). This step will record its own final revision and results.

## Remaining work

Day/Week grids, Month event overview/overflow, timed overlaps and DST/travel fixtures, display-zone overrides, paging/performance, accessibility/keyboard, external deletion/refresh and Mac runtime remain open. Maps HTTP lookup separately awaits Q78. Apple Calendar export stays outside this map.
