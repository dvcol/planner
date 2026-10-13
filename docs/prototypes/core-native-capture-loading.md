# Native capture URL and text loading

`PlannerNativeCaptureLoader.load(providers:)` loads supported native URL/text representations into immutable `PlannerLoadedCaptureInputs`. `Planner.prepareCapture(input: .loaded(...))` creates one transient review draft through the existing Core preparation boundary. Provider descriptions remain held data; loading does not save an Item. Storage schema remains 18 and portable format remains 2.

## Context and goal

[Reviewed capture apply](core-capture-apply.md) could save direct, reviewed capture values, but native `NSItemProvider` input had no implemented loading boundary. Callback order, failed loads and provider prose could not yet be checked through the public facade.

This step implements the URL/text part of the accepted [native capture contract](../adapter-contract.md#capture-preparation-and-apply). Before it, native input could not produce a draft. After it, supported native representations produce stable ordered links and explicit held/ignored/failed input observations. Native map-object loading, external provider retries and capture UI remain separate open work.

## Definition of ready

Q33 confirms the public Core/native boundary. C1/C8-C10 distinguish independent content from provider descriptions and require stable mixed-input handling. Contract Q15-Q17 set 32 attachments, four simultaneous loads, a ten-second total deadline, 1 MiB of decoded UTF-8 text and 128 distinct links. Existing cancellation, removal, review and apply commands retain their accepted behavior. Tests register real Foundation providers at the approved external I/O boundary; no test-only production injection or dependency was added.

## Definition of done for this step

- Load at most 32 attachments. Within attachment order, retain URL before the preferred text representation. Prefer explicitly declared UTF-8, then UTF-16, then generic plain text. Sort returned values by their assigned indices, regardless of callback order.
- Generic text uses Foundation encoding detection with lossy conversion disabled. Explicit UTF-8/UTF-16 data follows its declared encoding. URL strings preserve supplied spelling. A separate usable web URL survives when the same provider advertises a file URL; file/image representations are never loaded, and unsupported input is reported.
- Run at most four representation loads simultaneously. The overall deadline starts at entry. Cancellation/deadline cancels native `Progress` and completes waiting continuations once. Late callbacks cannot mutate the returned immutable value or an existing draft.
- Enforce the decoded-byte budget across URL and text representations, including held descriptions. Oversized input is discarded with a blocking issue; extra attachments are not loaded. The shared Core parser enforces exact-original link deduplication and the distinct-link limit. Supported load/decode failures block Add until removal or fresh preparation.
- Native provider text may supply detected links, but its prose cannot supply owned title, notes or location. It is displayed as held description data. Link-only drafts use the existing Saved link fallback. Reparse, own edits and reviewed save preserve classification; provider descriptions stay outside saved content and backups.
- Preparation writes no domain data. Explicit removal of a blocking overflow input preserves accepted links and can enable Add. Existing direct independent-text behavior remains covered by the affected Core tests.

## Tests and review

Eleven native-boundary functions cover 27 invocations. Real registered providers exercise duplicate URL/text links, reversed callbacks with four concurrent loads, cancellation followed by controlled late delivery, the actual ten-second deadline, 31/32/33 attachments, decoded-byte boundaries for UTF-8/UTF-16, 127/128/129 links, failures, invalid declared encoding, unsupported binary/file input, held text-only input and empty input. They also exercise held descriptions through retry, owned edits and reviewed save.

Review found two regressions. Generic plain text assumed UTF-8; the added UTF-8/UTF-16/UTF-32 fixture failed for UTF-16/32 before native nonlossy detection was implemented. A provider's file URL suppressed its separately registered web URL; the mixed-provider fixture failed before retaining the URL lane and reporting the ignored file. Both Standards and Spec rechecks found no remaining confirmed findings.

The typed `NSString` loading probe handled generic UTF-8 but could not coerce the generic UTF-16 fixture. Native encoding detection supplies that supported decoding boundary. The first blanket file fixture incorrectly forbade loading the separate URL representation; it is retained as diagnostic evidence, and the corrected fixture forbids the file representation while allowing non-web URL data to be rejected normally. Earlier concurrent deadline/cancellation test interference is also retained; this timing-sensitive suite now runs serially.

## Qualification

Mac and iPhone Simulator each passed 170 affected Core functions in 70 suites, covering 450 invocations. Native HTTP passed 16 functions in four suites, covering 22 invocations. Failures and skips were zero. Four affected Swift files passed strict lint; the Mac navigation app and test host compiled successfully. [Execution evidence](evidence/navigation/core-native-capture-loading/execution.json) records source hashes, exact narrow commands, completed results and regression traces. No native UI runtime or physical Share execution is established by these provider fixtures.

## Remaining map work

The opaque loaded value has no caller-writable classification flags. Raw providers stay with the main-actor loader; only immutable Sendable values enter Core. The existing draft Retry reparses retained input. Reloading an actual failed native provider requires the upcoming provider registry/lifecycle work; this step does not claim that capability.

Native `MKMapItem` loading and permitted provider references, bounded Maps lookup and obsolete network callbacks, transport encoding/advertisement, native capture review and Share/Intents/MCP flows remain open. Native `loadDataRepresentation` may materialize supplied bytes before the callback; post-load bounds do not prove peak allocation safety. Actual sender payloads, extension lifetimes and memory budgets require physical-platform evidence.

Genuine database-save/cleanup failure and termination proof remain [capture apply gates](core-capture-apply.md#remaining-map-work). Import reconciliation/forms, Calendar, scale/paging, filtered drag/group/duration behavior, physical sync/account recovery and final native UI polish remain required.

## Primary API references

Foundation's [data representation loader](https://developer.apple.com/documentation/foundation/nsitemprovider/loaddatarepresentation(fortypeidentifier:completionhandler:)) supplies the asynchronous data and native progress boundary. Foundation's [string encoding detection](https://developer.apple.com/documentation/foundation/nsstring/stringencoding(for:encodingoptions:convertedstring:usedlossyconversion:)) supplies generic-text decoding. The installed macOS 27 SDK headers were also checked for their signatures and lossless-conversion options.
