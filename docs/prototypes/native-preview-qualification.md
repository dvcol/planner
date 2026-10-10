# Native preview boundary qualification

## Context and scope

Q50 accepts a production cache/provider boundary for temporary native previews, controlled external responses, and separate Apple SDK and UI checks. Core exposes the dataset ownership namespace, source identity and source lifetime needed to bind each request. Previously there was no native provider/cache module for saved website bookmarks.

`PlannerPreviews` now loads a requested bookmark lazily and caches its image/title or failure. The complete key contains ownership namespace, source identity/lifetime, bookmark identity and exact original URL. Requests for the same key share work. A changed URL, namespace or source lifetime has an independent result; a late response cannot replace its successor. A disappearing SwiftUI caller cannot cancel work another row/detail needs. Retry explicitly clears the failure for that key.

The module uses a bounded memory cache, limited to 128 entries and 32 MiB of image bytes. It stores no owned content, credentials, backup data or device preferences. Apple's current `LinkMetadata` API supplies title and optional image data through a native Transferable image representation. An absent image remains a successful preview. Failed metadata retrieval is a retryable preview failure; the original bookmark remains an input, never a provider rewrite.

This qualifies the link boundary and Apple adapter. It does not complete Q50. The actual native rich-card rendering gate remains open, as do address lookup, ambiguous candidate selection and address invalidation. Existing compile-only Mac builds are not runtime UI evidence.

## Tests and evidence

Five test functions in two affected package suites pass, including three parameterized stale-response cases, for seven case invocations. The Apple adapter test is enabled with a local fixture server and exercises the actual SDK against image and plain HTML pages. Without that environment variable it is skipped, so a default package run cannot establish SDK integration.

The tests cover exact-key reuse, no eager work, image/no image, failure/retry, changed URL/ownership/lifetime, late results and caller cancellation. The cancellation regression failed before the module took ownership of its fetch task, then passed after that change. Compile red runs for new interfaces and the initial image representation failures are recorded separately from runtime red evidence. The initial flat-color fixture did not produce image metadata through Apple's service; the detailed fixture does. That observed fixture behavior is not a guarantee about arbitrary websites.

The [machine-readable evidence](evidence/navigation/native-link-boundary.json) contains source hashes, commands, logs and qualification limits. Package sources and the fixture script match the source epoch of the passing run. Core's separately committed [source lifetime evidence](evidence/navigation/preview-source-binding.json) establishes the binding metadata without changing schema 7 or portable format 1.

## Open gates

- Paint the image in actual Item and List appearance details, with the original bookmark, notes and independent completion preserved.
- Qualify native loading, failure and no-image presentation on iPhone and iPad; keep Mac runtime and human layout review open until executed.
- Add the address provider and prove zero/one/multiple candidates and stale-result isolation.
- Keep physical CloudKit, account recovery and Share validation in their existing signed-device gates.
