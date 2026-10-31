# Native map capture loading

The native capture boundary recognizes `MKMapItemTypeIdentifier` and retains a temporary Apple Maps preview. Provider names, addresses and coordinates never become owned Item content merely because they loaded. Storage schema remains 18 and portable format remains 2.

## Context and goal

Before this step, native capture could load URL/text but reported a shared map object as unsupported. After it, a supported map representation can provide a preview within the same draft, preserve owned edits, and recover through explicit Retry or Remove. A map object's business website is not the original shared Maps URL and is never invented as a bookmark.

## Definition of ready

Q33 and Q50 approve the public Core facade and actual native provider I/O as test boundaries. C8-C10 require held provider data and original-link retention; Q17 requires failed supported inputs to block Add until retry or removal. Q77 B selects an 8 MiB encoded map cap while retaining the existing 1 MiB aggregate decoded budget. The [Apple API investigation](../research/native-map-item-loading.md) distinguishes the iOS provider protocol from native Mac secure decoding.

## Definition of done for this step

- Load only the exact declared native MapItem representation. Decode through the public platform API, with an 8 MiB encoded admission check. Malformed or oversized supported inputs produce blocking issues rather than a binary fallback.
- Keep immutable candidate data separate from owned content, bookmarks and backups. A supplied Apple place identifier is a temporary provider reference; it does not establish a source identity or original share URL.
- Include candidate strings in aggregate decoded-byte admission and Retry reservations. Keep existing input order, four concurrent loads and the ten-second overall deadline.
- Preserve the candidate through owned capture edits. Remove drops it; explicit Retry reloads its retained native lane. Cancelling or superseding loading retains the existing obsolete-result safeguards.
- Treat a current-location MapItem as uncertain, without a fixed coordinate. Do not access its unused location when constructing that preview.
- Prove these behaviors through real registered providers and public prepare/edit/export/review/apply reads. Qualify the affected Core tests on Mac and iPhone Simulator, the affected HTTP routes, strict source lint and the Mac navigation build.

## Test fixtures

Native objects use current MapKit location/address construction. iOS fixture bytes come from MapKit's provider writer; Mac fixtures use the public secure archiver. Neither fixture represents an observed physical Maps sender or a genuine positive Apple place-ID lookup.

The encoded boundary uses invalid bytes just below, at and above 8 MiB. Below/at reach the decoder and fail as invalid data; above is rejected as oversized. A separate Mac fixture has a normal MapItem plus unrelated data encoded through public secure-archiver APIs, proving encoded size and extracted metadata size are distinct. Its padding is deliberately constructed test data, not a claim about sender serialization.

An earlier diagnostic used an exceptionally long MapItem name. Apple's native decoder rejected that archive, independently of Planner's admission limit. That fixture is not accepted-content evidence. Mixed normal MapItem metadata and text exercise the exact decoded budget instead.

## Qualification

Mac passed 183 affected Core functions in 70 suites, covering 482 invocations. iPhone Simulator passed 182 functions in the same 70 suites, covering 481 invocations; the extra Mac function covers secure-archive padding. HTTP passed 16 functions in four suites, covering 22 invocations. Failures and skips were zero. Six changed Swift files passed strict lint; the Mac navigation app and test host compiled. Both review rechecks found no confirmed actionable issues. Completed commands, source hashes, results and diagnostic provenance are recorded in execution evidence. Native UI runtime and physical Share execution remain unqualified.

## Remaining map work

One [genuine Apple reference fixture](genuine-native-map-reference.md) is subsequently qualified on Mac. Original-link binding, an iPhone/iPad positive-ID payload, actual physical sender compatibility and extension peak allocation remain required. The encoded cap is checked after the provider returns bytes, so it does not prove a maximum allocation inside Apple loading or decoding.

Bounded Maps lookup, capture transport/native review/Share/Intents flows, import reconciliation/forms, genuine save-failure/termination checks, Calendar, paging/performance, filtered drag/group/duration interactions, physical sync/account recovery and whole-app native UI polish remain open. This loading step does not close the parent prototype tickets.
