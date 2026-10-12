# Native List archive progress

## Context, before and goal

Core `492b558` derives finished progress from Done and archive retirement. The native List still displays only Done, so an archived Todo child appears excluded from the progress bar. Q68 requires that child to finish the container without changing its completion circle or stored Done flags.

## Definition of ready

- Reuse the qualified public Core counts and the existing native UI seam. No schema or portable-format changes.
- Use a native ProgressView. Display finished/total when archive retirement contributes, with separate Done and archived counts. With no retirement contribution, preserve the existing Done caption.
- Keep full progress independent from search/filters and keep bulk completion local. A globally Done child overrides local Todo display; archive never writes Done flags.

## Definition of done and required /tdd

- Archive one of two Todo children, hide it with Active filtering, and show half finished with zero Done and one archived. Keep its valid detail and identity.
- Bulk Done includes hidden archived children. Bulk Undone clears local flags, while global Done and archive retirement still contribute to full progress. Cancellation leaves state unchanged.
- Global Reopen and relaunch preserve the archived child's contribution, both source identities and retained completion behavior.
- Phone/tablet native journeys, real capture inspection, strict lint and unsigned Mac compilation pass. Mac UI runtime remains a separate gate.

## Execution

The functional red fails on the missing finished caption. The updated native ProgressView uses the disjoint Core counts and a concise Done/archive breakdown. The actual bulk/filter journey passes once on iPhone 18 Pro and once on iPad Air 11-inch, both iOS 27 simulators, with zero failures or skips. Initial runs reached relaunch but contained an outdated zero-progress expectation; those failed attempts are excluded from qualification.

[Phone after relaunch](evidence/navigation/native-list-archive-progress/phone-relaunched.png) shows an unchecked archived Item contributing to half-finished progress. [Tablet with Active filtering](evidence/navigation/native-list-archive-progress/tablet-filtered.png) shows the full progress, one visible row and the valid archived Item's details. The two affected Swift files pass strict lint. The Mac app/UI test host compiles; Mac UI runtime remains zero. The [execution record](evidence/navigation/native-list-archive-progress/execution.json) preserves actual summaries and the matching 62-file native source snapshot.

Native itinerary/branch progress and header matching, aggregate estimates/remaining, Calendar, physical sync/account/Share and whole-app polish remain open.
