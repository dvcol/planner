# Native preview boundary qualification

## Context and scope

Q50 accepts a production cache/provider boundary for temporary native previews, controlled external responses, and separate Apple SDK and UI checks. Core exposes the dataset ownership namespace, source identity and source lifetime needed to bind each request. Previously there was no native provider/cache module for saved website bookmarks.

`PlannerPreviews` now loads a requested bookmark lazily and caches its image/title or failure. The complete key contains ownership namespace, source identity/lifetime, bookmark identity and exact original URL. Requests for the same key share work. A changed URL, namespace or source lifetime has an independent result; a late response cannot replace its successor. A disappearing SwiftUI caller cannot cancel work another row/detail needs. Retry explicitly clears the failure for that key.

The module uses a bounded memory cache, limited to 128 entries and 32 MiB of image bytes. It stores no owned content, credentials, backup data or device preferences. Apple's current `LinkMetadata` API supplies title and optional image data through a native Transferable image representation. An absent image remains a successful preview. Failed metadata retrieval is a retryable preview failure; the original bookmark remains an input, never a provider rewrite.

The boundary commit qualifies the link cache and Apple adapter. The subsequent UI integration also qualifies website cards and row thumbnails on the iPhone/iPad simulators. The address boundary separately qualifies controlled candidate and stale-response behavior. Q50 remains incomplete until the remaining native address presentation and invalidation checks pass. Compile-only Mac builds are not runtime UI evidence.

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
- Qualify native ambiguous/empty/error address presentation and address-change invalidation; the provider boundary covers controlled zero/one/multiple candidates and stale-result isolation.
- Keep physical CloudKit, account recovery and Share validation in their existing signed-device gates.

## Address boundary

The address cache/provider now accepts an immutable source namespace/identity/lifetime and the exact owned address. It returns zero, one or multiple temporary candidates without selecting one or changing owned content. A failed request remains retryable; an empty successful result is distinct from failure. Equal requests share work and cached results. Address, namespace, source identity and lifetime changes isolate late callbacks. The shared fetch survives a disappearing caller. The memory cache retains at most its configured 128-entry target and has no persisted representation.

`AppleAddressPreviewProvider` uses Apple's [MKGeocodingRequest](https://developer.apple.com/documentation/mapkit/mkgeocodingrequest) and modern `MKMapItem.location`, identifier and address representations. Invalid coordinates are excluded before presentation. The adapter test executes the real service against the known public Apple Park address and verifies a candidate near Cupertino with a formatted address. Zero/multiple/error and delayed cases use controlled responses at the production provider boundary; that live address test does not prove those cases.

The combined preview package passes ten functions in four suites, including fifteen case invocations and both real Apple SDK tests enabled. Mac and iPhone app/test bundles compile with zero runtime UI functions in these builds. The [address boundary evidence](evidence/navigation/native-address-boundary.json) records commands, source hashes and compile red/green history. The initial missing-adapter red also produced a cascading expression type-check error; the implemented adapter resolves both.

This boundary milestone does not itself qualify native address detail, candidate selection or location editing. The subsequent saved-address slice below qualifies a sole live result. Q51 still asks how an address edit should affect an existing owned pin. No schema, backup or agent administration interface changes are introduced.

## Saved address presentation

Before this slice, the Item editor offered title, subtitle, notes and bookmarks. An address without saved coordinates remained text in Item/List details. The goal is staged location editing and a useful native pin preview while retaining owned data and independent completion.

DoR is the accepted Q42/Q50 contract, the qualified public Core location-edit command, and dataset/source lifetime binding. The native journey first failed because the address field was missing. After integration it passed Save, Cancel, live List detail and relaunch. A second red failed at the missing List-row location summary; the compact caption then passed in the final source epoch.

The grouped Item form now stages a place name and address for locations without owned coordinates. Its existing guarded Save applies location alongside other changed fields; Cancel discards the draft. Clearing both fields clears that textual location. An Item with owned coordinates retains its existing location and readonly map until Q51 is settled. This is a limited editing slice, not completion of the full location editor.

Saved Item and List appearance details use the shared temporary address cache. A sole candidate displays a native MapKit map and marker. Empty/error results retain the saved address with a native label and Retry; multiple candidates offer a native Picker without an automatic selection. These controls are implemented, but their controlled native UI journeys remain open. Request identity resets the temporary choice when address/source ownership changes. Existing owned coordinates take precedence and do not invoke address lookup. Provider candidates never enter the Core edit command.

Rows show a small location label, preferring the owned place name, then address, then a generic Location label for coordinate-only content. Accessibility retains the full owned address alongside the caption. This row presentation does not start geocoding.

Two affected native functions pass on each iPhone/iPad simulator: the address Save/Cancel, row caption, completed List detail and relaunch journey, and the bookmark validation/edit/order/removal regression. Original captures were inspected for the painted map marker, owned address, compact caption and contextual completion. The two affected Core location functions also pass. Mac app/UI-test bundles compile with zero runtime UI functions. Strict affected Swift lint and whitespace checks pass. The raw native builds retain the AppIntents metadata-extraction warning.

[Saved address evidence](evidence/navigation/native-address-ui.json) records commands, source hashes, red/green outcomes and original captures. The [iPhone row](evidence/navigation/layouts/phone-saved-address-row.png), [iPhone contextual pin](evidence/navigation/layouts/phone-saved-address-context.png), [iPad row](evidence/navigation/layouts/tablet-saved-address-row.png) and [iPad contextual pin](evidence/navigation/layouts/tablet-saved-address-context.png) establish this local simulator presentation. Native ambiguous/empty/error and address-change invalidation, existing-pin editing, Mac runtime, physical devices and whole-app polish remain open. Q48/Q49 estimate choices and Q51 existing-pin behavior remain unanswered.
