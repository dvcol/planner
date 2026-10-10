# Native preview boundary qualification

## Context and scope

Q50 accepts a production cache/provider boundary for temporary native previews, controlled external responses, and separate Apple SDK and UI checks. Core exposes the dataset ownership namespace, source identity and source lifetime needed to bind each request. Previously there was no native provider/cache module for saved website bookmarks.

`PlannerPreviews` now loads a requested bookmark lazily and caches its image/title or failure. The complete key contains ownership namespace, source identity/lifetime, bookmark identity and exact original URL. Requests for the same key share work. A changed URL, namespace or source lifetime has an independent result; a late response cannot replace its successor. A disappearing SwiftUI caller cannot cancel work another row/detail needs. Retry explicitly clears the failure for that key.

The module uses a bounded memory cache, limited to 128 entries and 32 MiB of image bytes. It stores no owned content, credentials, backup data or device preferences. Apple's current `LinkMetadata` API supplies title and optional image data through a native Transferable image representation. An absent image remains a successful preview. Failed metadata retrieval is a retryable preview failure; the original bookmark remains an input, never a provider rewrite.

The boundary commit qualifies the link cache and Apple adapter. The subsequent UI integration also qualifies website cards and row thumbnails on the iPhone/iPad simulators. Q50 remains incomplete because address lookup, ambiguous candidate selection and address invalidation are still open. Compile-only Mac builds are not runtime UI evidence.

## Tests and evidence

Five test functions in two affected package suites pass, including three parameterized stale-response cases, for seven case invocations. The Apple adapter test is enabled with a local fixture server and exercises the actual SDK against image and plain HTML pages. Without that environment variable it is skipped, so a default package run cannot establish SDK integration.

The tests cover exact-key reuse, no eager work, image/no image, failure/retry, changed URL/ownership/lifetime, late results and caller cancellation. The cancellation regression failed before the module took ownership of its fetch task, then passed after that change. Compile red runs for new interfaces and the initial image representation failures are recorded separately from runtime red evidence. The initial flat-color fixture did not produce image metadata through Apple's service; the detailed fixture does. That observed fixture behavior is not a guarantee about arbitrary websites.

The [machine-readable evidence](evidence/navigation/native-link-boundary.json) contains source hashes, commands, logs and qualification limits. Package sources and the fixture script match the source epoch of the passing run. Core's separately committed [source lifetime evidence](evidence/navigation/preview-source-binding.json) establishes the binding metadata without changing schema 7 or portable format 1.

## Native presentation

Saved Item rows lazily load the selected owned website bookmark and show a small native image when available. Item and List appearance details load each visible website card; Apple/Google Maps bookmarks retain their existing owned-link presentation. The same source/lifetime/bookmark/URL key shares cached work across those contexts. Removing the selected bookmark removes its old thumbnail/card and selects the surviving bookmark without changing notes, global completion or the List appearance's local completion.

Cards use SwiftUI `Link`, `GroupBox` and `Image`, with native `ProgressView`, failure text and Retry controls. The original `LPLinkView` bridge passed metadata-availability checks while still painting a loading placeholder. A stronger regression checks that the controlled colorful image actually paints in both Item and List details. Layout, provider and metadata-update probes did not resolve the bridge's integration failure; small native harnesses rendered the same input successfully. The root cause within that bridge is not established. Rendering the decoded bytes directly removes the additional asynchronous image-loader path and passes the actual app journey.

Three affected native functions pass per simulator: rich/plain previews with removal/relaunch and independent completion, provider failure/retry preserving the owned link, and the existing bookmark validation/edit/order/removal regression. The iPhone image journey executes separately from its two regressions; iPad executes all three together. The final Mac app/test build passes with zero runtime UI functions. Raw native logs retain the AppIntents metadata-extraction warning. Affected Swift strict format lint and whitespace checks pass; source changes remain fixed during each native test epoch.

[Native website UI evidence](evidence/navigation/native-link-ui.json) records commands, result counts, source hashes and original inspected captures. The [iPhone contextual card](evidence/navigation/layouts/phone-saved-preview-context.png), [plain website](evidence/navigation/layouts/phone-saved-preview-plain.png), [iPad contextual card and row thumbnail](evidence/navigation/layouts/tablet-saved-preview-context.png) and [failure/Retry state](evidence/navigation/layouts/tablet-saved-preview-failure.png) show the resulting native controls. These are app-owned simulator captures, not physical-device or Mac UI qualification.

## Open gates

- Qualify Mac runtime, keyboard/accessibility behavior, window resizing, long-list performance and final human layout review.
- Add the address provider and prove zero/one/multiple candidates and stale-result isolation.
- Keep physical CloudKit, account recovery and Share validation in their existing signed-device gates.
