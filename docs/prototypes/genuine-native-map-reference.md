# Genuine native Apple map reference

A native Apple search returned Nezu Museum with identifier `ID40BC454B39E9696`. The same identifier survived MapKit secure serialization and the public Planner capture boundary. It remained temporary after saving an independently owned title and did not appear in the portable backup.

## Context and goal

The [native map loading step](core-native-map-capture.md) used manually constructed MapItems with no Apple identifier. Those fixtures proved metadata handling, but could not prove positive identifier extraction. This qualification obtains a real native result and checks the existing implementation without changing production code.

Before: positive reference preservation was unverified. After: one Mac-native result preserves its actual Apple reference through provider loading and owned capture edits. Reviewed Add stores only the owned title, with no invented bookmark or owned provider location.

## Definition of ready

C1 permits genuine provider references while keeping descriptions temporary. Q33/Q50 approve native provider I/O and the public Core prepare/edit/review/apply/read/export boundaries. The Mac has OS 27, the current MapKit SDK and native search access. The fixture must come from an actual Apple result, with its identity recorded before Planner loads it; a manually assigned test string is insufficient provenance.

## Definition of done for this qualification

- Native `MKLocalSearch` returns a MapItem with a nonnil identifier. The recorded search uses a public museum and fixed Tokyo region, without requesting the device's current location.
- Public secure serialization and readback retain the observed identifier. Register the returned archive under `MKMapItemTypeIdentifier`, then inspect the public capture preview.
- The candidate contains the recorded Apple reference and name. Owned title, location and bookmarks remain empty until an explicit owned edit.
- Editing the title retains the candidate. Reviewed Add creates an Item whose public saved read contains only the owned title; provider name and identifier are absent from backup output.
- The focused integration test executes on the committed Core revision, with zero failures or skips. Strict lint and affected documentation checks pass. No production schema or facade changes belong to this step.

## Fixture and reproduction

The [probe source](evidence/navigation/genuine-native-map-reference/PlannerGenuineAppleMapProbe.swift) runs the native search, requests cancellation after ten seconds, writes its temporary secure archive, and reports the returned reference before Planner sees it. [Probe output](evidence/navigation/genuine-native-map-reference/PlannerGenuineAppleMapProbe.log) records a 23,075-byte archive and identical original/readback identifiers. The archive stays outside the repository; its hash is recorded in the evidence.

Compile/run the probe with the recorded Mac SDK command, then run the focused test with `PLANNER_GENUINE_MAP_FIXTURE` pointing to that temporary archive. The test deliberately expects the recorded identifier rather than copying the decoder's output into its expectation. If Apple's returned identifier changes, review and replace the fixture's provenance and literal expectation together. Do not fabricate an archive identity to keep the test green. The test is disabled when that explicit fixture is absent.

## Qualification and limits

One public-boundary integration function passed on Mac against committed `69f8836` Core. The changed test passed strict lint and compilation; the document passed Markdown lint. [Execution evidence](evidence/navigation/genuine-native-map-reference/execution.json) records the qualified sources, command, result and fixture hash.

This proves one genuine native result and constructed provider on Mac. It does not prove original Maps URL binding, an iPhone/iPad positive-ID payload, a physical Maps Share sender, extension allocation/lifetime or iCloud convergence. Those gates remain open. The separately pending Maps HTTP transport design and its unfinished facade are excluded from this qualification.
