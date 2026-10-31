# Core Maps capture lookup

## Context and goal

Before this slice, capture preparation, edits and reviewed Add were available, and the native single-HEAD transport was qualified separately. Core did not orchestrate a selected Maps-link lookup.

The goal is an editable capture with a bounded temporary preview. Lookup must retain the exact original bookmark, preserve independently entered fields, and allow Add before preview completion. Stopping or superseding an attempt must prevent a late response from changing the current draft or saved Item.

## Definition of ready

- C1/C10-C12 and Q18/Q19 establish temporary provider descriptions, explicit link selection, HTTPS eligibility, eight seconds overall, four seconds per request and five redirects/six requests.
- Q78 A approves the production HTTP transport boundary. Core tests use controlled status/headers at that boundary; [native transport qualification](native-capture-http-transport.md) separately exercises Foundation delegates.
- The accepted [capture facade](../adapter-contract.md#capture-preparation-and-apply) supplies lookup/read/edit/cancel/review/apply operations. Tests observe drafts and saved data through these public operations.

## Definition of done for this slice

- Validate the original and every requested redirect against the accepted scheme/host/path policy. Remove only the request fragment; retain the supplied bookmark unchanged.
- Dispatch explicit HEAD hops, stop at loops, unusable redirects, refusal or errors, and pass each request the smaller of four seconds and the remaining attempt budget.
- Bind preview publication to the live dataset session, draft generation and latest attempt identity. Show loading without disabling the draft's save permission.
- Cancel superseded I/O on valid edits, draft cancellation and successful Add. Clear pending feedback when an attempt stops, including a cancelled native-input retry.
- Qualify documented URL interpretation separately from real provider responses. Do not infer a selected place from a map viewport, directions route or opaque path.
- Run affected Core checks, strict Swift/Markdown lint, compile the mobile app target, and review the source and spec before committing.

## TDD and evidence

Public facade tests use disposable native stores and compare exported saved data before and after temporary operations. The controlled transport records outgoing URLs and deadlines, while a bounded response gate can deliberately deliver a result after task cancellation.

The stale-selection test initially failed because an older result replaced a newer preview and pending state was absent. Binding each attempt and publishing loading fixed those failures. A real NSItemProvider retry then reproduced a stranded loading indicator after cancellation. Shared lookup cleanup clears that indicator, and retry cleanup no longer cancels an unrelated newer lookup.

Review found one further race: a lookup may start while native-input Retry is suspended. A two-case test reproduced the missing cancellation when Retry successfully published a new generation. Cancellation now also occurs after final validation, immediately before publication. The control case proves that a cancelled Retry leaves the concurrently started lookup valid.

Documented Apple `/place` name/address/coordinate fields become temporary candidates, with finite coordinate/range checks. Google `api=1` search URLs distinguish coordinate queries from unresolved text-search intent, decode form-style spaces once, and never fabricate an address or Apple identifier. Repeated conflicting fields, viewport/directions URLs, contextual Apple tokens, unsupported forms and HEAD failures retain a usable partial bookmark. Place-ID-only URLs remain bookmarks in this slice; native-object identifier provenance retains its separate qualification.

The final scoped Mac run passed 45 functions in six suites, covering 114 invocations with no failures or skips. Lookup itself covers 16 functions and 40 invocations. Other checks cover capture preparation, edits, reviewed Add/reuse/replay, affected native retries, and the actual Foundation HTTP transport. Three affected Swift files passed strict lint, and the iOS Simulator app target built successfully. Execution evidence records commands, red regressions, final outcomes and hashes.

Review also removed per-function deletion of new native-store fixtures. Their named directories are cleaned only after the test process exits, avoiding unlinking a store while SwiftData still retains its ModelContainer. No production close hook or test-only callback was added. Controlled response gates are bounded and can deliver after task cancellation, so the obsolete-result checks exercise an actual late transport result.

Final source and spec reviews have no remaining confirmed findings. Both independently checked the recorded outcomes and all five source and ten artifact hashes.

## Remaining map gates

The following gates describe this original checkpoint. [Native preview work](native-maps-capture-preview.md) and [later native HTTP qualification](native-capture-http-transport.md#real-socket-follow-up-22-october-2026) record subsequent results, including real sockets and two live long-link observations. They do not qualify every provider, short link or physical lifecycle.

Controlled HTTP responses are not live Apple/Google or socket qualification. Native/agent preview presentation, native explicit Retry journeys, provider-reference-only URL enrichment, physical sender allocations and Share lifecycle remain open. Calendar Q79-Q81 and its proposed Q82 contract, signed-device sync/account recovery, and whole-app UI polish retain their existing owners and completion gates.
