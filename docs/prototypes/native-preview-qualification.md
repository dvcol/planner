# Native preview boundary qualification

Status: the original milestones below retain their source epochs. Q48/Q49/Q51 are resolved in the [decision register](../open-decisions.md); later [candidate](native-controlled-address-candidates.md), [Retry](native-controlled-address-retry.md), [delayed-result](native-delayed-address-result.md) and [pin-editing](native-pinned-address-editing.md) reports supersede the initial mobile UI gaps. The iOS SDK and saved-app follow-ups below add separate package and native runtime evidence without closing Mac UI, physical or final-polish gates.

## Context and scope

Q50 accepts a production cache/provider boundary for temporary native previews, controlled external responses, and separate Apple SDK and UI checks. Core exposes the dataset ownership namespace, source identity and source lifetime needed to bind each request. Previously there was no native provider/cache module for saved website bookmarks.

`PlannerPreviews` now loads a requested bookmark lazily and caches its image/title or failure. The complete key contains ownership namespace, source identity/lifetime, bookmark identity and exact original URL. Requests for the same key share work. A changed URL, namespace or source lifetime has an independent result; a late response cannot replace its successor. A disappearing SwiftUI caller cannot cancel work another row/detail needs. Retry explicitly clears the failure for that key.

The module uses a bounded memory cache, limited to 128 entries and 32 MiB of image bytes. It stores no owned content, credentials, backup data or device preferences. Apple's current `LinkMetadata` API supplies title and optional image data through a native Transferable image representation. An absent image remains a successful preview. Failed metadata retrieval is a retryable preview failure; the original bookmark remains an input, never a provider rewrite.

The boundary commit qualifies the link cache and Apple adapter. The subsequent UI integration also qualifies website cards and row thumbnails on the iPhone/iPad simulators. The address boundary separately qualifies controlled candidate and stale-response behavior. Q50 remains incomplete until the remaining native address presentation and invalidation checks pass. Compile-only Mac builds are not runtime UI evidence.

## Tests and evidence

Five test functions in two affected package suites pass, including three parameterized stale-response cases, for seven case invocations. The Apple adapter test is enabled with a local fixture server and exercises the actual SDK against image and plain HTML pages. Without that environment variable it is skipped, so a default package run cannot establish SDK integration.

The tests cover exact-key reuse, no eager work, image/no image, failure/retry, changed URL/ownership/lifetime, late results and caller cancellation. The cancellation regression failed before the module took ownership of its fetch task, then passed after that change. Compile red runs for new interfaces and the initial image representation failures are recorded separately from runtime red evidence. The initial flat-color fixture did not produce image metadata through Apple's service; the detailed fixture does. That observed fixture behavior is not a guarantee about arbitrary websites.

The machine-readable evidence contains source hashes, commands, logs and qualification limits. Package sources and the fixture script match the source epoch of the passing run. Core's separately committed source lifetime evidence establishes the binding metadata without changing schema 7 or portable format 1.

## Native presentation

Saved Item rows lazily load the selected owned website bookmark and show a small native image when available. Item and List appearance details load each visible website card; Apple/Google Maps bookmarks retain their existing owned-link presentation. The same source/lifetime/bookmark/URL key shares cached work across those contexts. Removing the selected bookmark removes its old thumbnail/card and selects the surviving bookmark without changing notes, global completion or the List appearance's local completion.

Cards use SwiftUI `Link`, `GroupBox` and `Image`, with native `ProgressView`, failure text and Retry controls. The original `LPLinkView` bridge passed metadata-availability checks while still painting a loading placeholder. A stronger regression checks that the controlled colorful image actually paints in both Item and List details. Layout, provider and metadata-update probes did not resolve the bridge's integration failure; small native harnesses rendered the same input successfully. The root cause within that bridge is not established. Rendering the decoded bytes directly removes the additional asynchronous image-loader path and passes the actual app journey.

Three affected native functions pass per simulator: rich/plain previews with removal/relaunch and independent completion, provider failure/retry preserving the owned link, and the existing bookmark validation/edit/order/removal regression. The iPhone image journey executes separately from its two regressions; iPad executes all three together. The final Mac app/test build passes with zero runtime UI functions. Raw native logs retain the AppIntents metadata-extraction warning. Affected Swift strict format lint and whitespace checks pass; source changes remain fixed during each native test epoch.

Native website UI evidence records commands, result counts, source hashes and original inspected captures. The iPhone contextual card, plain website, iPad contextual card and row thumbnail and failure/Retry state show the resulting native controls. These are app-owned simulator captures, not physical-device or Mac UI qualification.

## Open gates

- Qualify Mac runtime, keyboard/accessibility behavior, window resizing, long-list performance and final human layout review.
- Qualify native ambiguous/empty/error address presentation and address-change invalidation; the provider boundary covers controlled zero/one/multiple candidates and stale-result isolation.
- Keep physical CloudKit, account recovery and Share validation in their existing signed-device gates.

## Address boundary

The address cache/provider now accepts an immutable source namespace/identity/lifetime and the exact owned address. It returns zero, one or multiple temporary candidates without selecting one or changing owned content. A failed request remains retryable; an empty successful result is distinct from failure. Equal requests share work and cached results. Address, namespace, source identity and lifetime changes isolate late callbacks. The shared fetch survives a disappearing caller. The memory cache retains at most its configured 128-entry target and has no persisted representation.

`AppleAddressPreviewProvider` uses Apple's [MKGeocodingRequest](https://developer.apple.com/documentation/mapkit/mkgeocodingrequest) and modern `MKMapItem.location`, identifier and address representations. Invalid coordinates are excluded before presentation. The adapter test executes the real service against the known public Apple Park address and verifies a candidate near Cupertino with a formatted address. Zero/multiple/error and delayed cases use controlled responses at the production provider boundary; that live address test does not prove those cases.

The combined preview package passes ten functions in four suites, including fifteen case invocations and both real Apple SDK tests enabled. Mac and iPhone app/test bundles compile with zero runtime UI functions in these builds. The address boundary evidence records commands, source hashes and compile red/green history. The initial missing-adapter red also produced a cascading expression type-check error; the implemented adapter resolves both.

This boundary milestone does not itself qualify native address detail, candidate selection or location editing. The subsequent saved-address slice below qualifies a sole live result. Q51 still asks how an address edit should affect an existing owned pin. No schema, backup or agent administration interface changes are introduced.

## Saved address presentation

Before this slice, the Item editor offered title, subtitle, notes and bookmarks. An address without saved coordinates remained text in Item/List details. The goal is staged location editing and a useful native pin preview while retaining owned data and independent completion.

DoR is the accepted Q42/Q50 contract, the qualified public Core location-edit command, and dataset/source lifetime binding. The native journey first failed because the address field was missing. After integration it passed Save, Cancel, live List detail and relaunch. A second red failed at the missing List-row location summary; the compact caption then passed in the final source epoch.

The grouped Item form now stages a place name and address for locations without owned coordinates. Its existing guarded Save applies location alongside other changed fields; Cancel discards the draft. Clearing both fields clears that textual location. An Item with owned coordinates retains its existing location and readonly map until Q51 is settled. This is a limited editing slice, not completion of the full location editor.

Saved Item and List appearance details use the shared temporary address cache. A sole candidate displays a native MapKit map and marker. Empty/error results retain the saved address with a native label and Retry; multiple candidates offer a native Picker without an automatic selection. These controls are implemented, but their controlled native UI journeys remain open. Request identity resets the temporary choice when address/source ownership changes. Existing owned coordinates take precedence and do not invoke address lookup. Provider candidates never enter the Core edit command.

Rows show a small location label, preferring the owned place name, then address, then a generic Location label for coordinate-only content. Accessibility retains the full owned address alongside the caption. This row presentation does not start geocoding.

Two affected native functions pass on each iPhone/iPad simulator: the address Save/Cancel, row caption, completed List detail and relaunch journey, and the bookmark validation/edit/order/removal regression. Original captures were inspected for the painted map marker, owned address, compact caption and contextual completion. The two affected Core location functions also pass. Mac app/UI-test bundles compile with zero runtime UI functions. Strict affected Swift lint and whitespace checks pass. The raw native builds retain the AppIntents metadata-extraction warning.

Saved address evidence records commands, source hashes, red/green outcomes and original captures. The iPhone row, iPhone contextual pin, iPad row and iPad contextual pin establish this local simulator presentation. Native ambiguous/empty/error and address-change invalidation, existing-pin editing, Mac runtime, physical devices and whole-app polish remain open. Q48/Q49 estimate choices and Q51 existing-pin behavior remain unanswered.

## Exact request identity

The original synthesized request equality used Swift String comparison. [Swift documents Unicode canonical equivalence](https://docs.swift.org/swift-book/LanguageGuide/StringsAndCharacters.html#String-and-Character-Equality), so composed and decomposed accents can compare equal despite different UTF-8 bytes. A local Foundation probe resolves the two raw URL paths to `caf%C3%A9` and `cafe%CC%81`. The preview boundary originally reused the first cached result for both inputs, violating its exact-input key contract.

Separate public provider regressions failed for raw URL paths and addresses. Both now pass after immutable request keys retain the original UTF-8 bytes alongside their Strings. Repeating an identical request still shares work; a byte-distinct input gets its own result. Provider inputs and owned content are not normalized by this change.

The raw-path example exercises the reusable preview API. Core's current strict bookmark validation rejects those unescaped paths, so this is not evidence that the saved Item form accepts them. Saved address text permits Unicode. Controlled address responses prove isolation without assuming that Apple's service returns different candidates for equivalent spellings.

Twelve preview functions in four suites pass, with seventeen case invocations and both Apple SDK tests enabled. The iPhone's existing saved website and address journeys also pass, including actual image painting, completed List detail and reopening. Mac app/test bundles compile with zero runtime functions. Affected strict Swift/Markdown lint and whitespace checks pass. Exact-request evidence records both red/green pairs, commands, source hashes and these qualification limits. Native controlled address presentation/invalidation, Mac runtime and signed-device gates remain open; schema 7 and portable format 1 are unchanged.

## iOS SDK follow-up, 22 October 2026

Before this follow-up, recorded preview-package runs exercise the real Apple adapters on Mac, while simulator presentation has its own represented live/controlled-provider results. The goal here is direct current-package runtime on both iOS simulator form factors, with both existing SDK tests enabled. Q50 already approves this production provider/cache and external I/O boundary. No production/test source, package, target, dependency, signing or security change is needed.

The unchanged fixture server binds an ephemeral loopback port and serves its existing detailed PNG, image HTML and plain HTML. The existing opt-in environment variables enable the real `LinkMetadata` adapter against those pages and the real `MKGeocodingRequest` adapter against 1 Apple Park Way, Cupertino, CA. The generated xctestrun copies supply these test-host variables. No Planner store or device-location request is involved. SDK geocoding may use service caches; this does not measure a fresh network round trip.

The package build passes. Both iPhone and iPad execute 18 functions across five suites, with 28 invocations per device and zero failures/skips. The suite takes 2.456 seconds on phone and 1.993 seconds on tablet, excluding build/runner setup. Each native link case verifies the literal image-page title, an ImageIO-decodable image, the plain-page title and absent plain-page image. Each native geocoding case verifies nonempty named/identified candidates, a coordinate inside the expected Cupertino bounds and a formatted Cupertino address. The other cases cover controlled link/address/Maps cache keys, retry, stale results and shared-request cancellation.

All 751 recorded inputs match both epochs and the current workspace; compiled products remain unchanged. Both SDK test names appear as actually passing in the native logs and structured results, so the optional tests are not counted from a default skipped run. Strict affected Swift and Markdown lint pass. The wrappers' provisional exit records remain separate from explicit qualification files.

The server record records two observed image-page, image-PNG and plain-page GETs. Optional icon requests return the fixture's expected 404s. Those counts are scoped observations from the live tool output, not an original retained server stdout log. After both runtimes finish, only the verified owned listener is terminated; its intentional exit 143 is not a test outcome.

This adds real iOS adapter and controlled-cache evidence. It does not qualify arbitrary public websites, actual saved-app integration with these live results, original Maps sender/URL binding, installed Share, physical memory/latency, signed sync/account transitions, Mac keyboard/window behavior or final whole-app UI acceptance. Prior UI captures and source epochs retain their own limits.

## Saved-app SDK follow-up, 22 October 2026

The package SDK checks above do not establish the saved application's current integration. This follow-up reuses four existing public native journeys in `PlannerNavigation`, with disposable local datasets and the app's ordinary Apple link/address providers. It does not use the controlled-provider fixture application. Website metadata comes through Apple's SDK from the repository's local HTML/image server; the address journey uses the live Apple Park lookup. The goal is actual rendered previews, useful failure handling and preserved saved identities/state across List references and relaunch.

The initial iPhone image/plain and Retry journeys pass. The iPad image journey fails before preview loading while adding its second bookmark. A second, instrumented invocation reproduces the failure. Original AX captures and the synthesized event show Add moving down 40.5 points: the event uses y=833.5, while the button subsequently starts at y=848. The previous Label remains focused and only one URL field exists. The native driver now submits that single-line Label with Return before continuing; the complete iPad image journey then passes. The native framework's underlying repositioning cause is not established, and no production layout change is inferred from the missed event.

The affected regression exposes the same unfinished-entry problem after editing Title, plus an Address-field assertion made before its lazy Form row is revealed. Submit the edited Title before Add and reveal Address before asserting its existence. No existing content, identity, validation, paint, completion, ordering, Cancel or relaunch assertion is removed. These are test-driver corrections, with no production API, provider, package, target, signing or persisted-data change.

| Existing native journey | iPhone | iPad |
| --- | --- | --- |
| Painted image and plain cards, live List thumbnail, independent completion, removal and relaunch | 133.856 s | 136.886 s |
| Unavailable provider retains the owned URL and native Retry | 42.398 s | 43.392 s |
| Rejected invalid bookmark, stable link identities/order, Cancel, removal and relaunch | 180.006 s | 193.473 s |
| Cancelled/saved owned address, real MapKit pin, live completed List and relaunch | 86.590 s | 104.065 s |

These are eight passing executions of four functions on each iOS 27.0 simulator. They come from separate recorded epochs. The iPad Retry pass belongs to a three-case invocation whose other two cases fail; their corrected validation/address journeys pass in the final invocation. The complete history is twelve passes, four failures and zero skips across sixteen executions, including the earlier successful iPhone runs and failed probes. Native result trees and original logs determine these classifications; a diagnostic wrapper returning zero cannot turn its recorded native exit 65 into a pass.

The qualification and source reconciliation binds every accepted case to its exact result and duration. All 1,060 other source/configuration inputs, including production code, remain unchanged. Between the successful preview/Retry epoch and final source, only the two rerun test functions change; every other test and helper is byte-identical. All 1,061 inputs and current products match both final mobile and Mac builds. The Mac build supplies compiler evidence only, with no new Mac UI execution. Strict affected Swift/Markdown lint and whitespace checks pass.

The packets retain 22 inspected original PNGs, selected native hierarchies/event data, complete test outcomes, compressed logs and source/product hashes. Selected attachment hashes verify their unchanged bytes. The server record distinguishes observed baseline stdout chunks from the complete follow-up stream. Image/plain requests succeed; optional icon requests return 404. Only the verified owned listener is stopped after dependent tests finish; exit 143 is intentional shutdown, not test success.

Phone captures establish represented light states; iPad captures establish represented dark states, both at Large text without Increase Contrast. They do not qualify every appearance/text-size combination, arbitrary websites or address accuracy, Mac keyboard/window behavior, physical allocation/latency, installed Share, signed sync/account recovery or final whole-app UI acceptance. Mid-scroll captures also do not establish final-row clearance beneath floating bars. Those gates remain open.
