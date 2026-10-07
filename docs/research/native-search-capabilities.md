# Native search capabilities

Research for [Native search capabilities](https://github.com/dvcol/planner/issues/19), verified **2026-10-08** against primary Apple documentation and installed Xcode 27 SDK declarations. Product context is the [confirmed duration and search choices at cf4985c](https://github.com/dvcol/planner/blob/cf4985ca1e5a512e21695a9c4f4fc5a0d65b2764/docs/duration-and-search.md) and the [nine-item fixtures](../search-fixtures.md).

**Recommendation for the human:** retain a native Foundation lexical matching path over current canonical item fields, with the approved cumulative filters. Evaluate SwiftData predicates for fetching suitable candidates. Treat Core Spotlight indexed/semantic results as an optional extension with separate acceptance examples and freshness handling. No external library is necessary for the accepted lexical behavior; no fuzzy dependency is selected.

This is documentary research and SDK inspection, not a search prototype. No Swift source, executable fixture tests, index operations, performance measurements, or device tests were created or run. Duration conversions, exact maximum/unknown behavior, picker precision, sorting, dataset scale and latency remain human decisions. The confirmed native estimate pickers are UI requirements, not search engines.

## Installed evidence and availability

Read-only commands used a per-command `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; the global selected developer directory remained `/Library/Developer/CommandLineTools`. Observed tools:

- Xcode **27.0**, build **27A266a**.
- Apple Swift **6.4**, `swiftlang-6.4.0.34.1`, target `arm64-apple-macosx27.0.0`.
- iPhoneOS SDK: `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk`.
- macOS SDK: `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk`.

The SDK-path commands succeeded with sandbox file-event/cache warnings. They did not compile or execute an application. Apple's [Xcode requirements](https://developer.apple.com/xcode/system-requirements) independently document the OS 27 SDKs and Swift 6.4. iPadOS uses the inspected iPhoneOS framework declarations; no separate iPad device execution is claimed.

| Capability | Introduced: iOS/iPadOS; macOS | Inspected declaration | Boundary |
| --- | --- | --- | --- |
| SwiftUI `searchable(text:placement:prompt:)` | 15; 12 | SwiftUI interfaces, iPhoneOS line 7091 / macOS line 7272 | Creates a bound search field; the app conducts the search. [Search interface](https://developer.apple.com/documentation/swiftui/adding-a-search-interface-to-your-app) |
| Foundation `localizedStandardContains` | 9; 10.11 | `Foundation.framework/Headers/NSString.h:398`, both SDKs | Case/diacritic-insensitive, locale-aware substring matching. [Matcher](https://developer.apple.com/documentation/foundation/nsstring/localizedstandardcontains(_:)) |
| Foundation explicit comparison/folding options | Predates the OS 27 baseline; diacritic folding is 2; 10.5 | `NSString.h:48–77,811`, both SDKs | Select case/accent options and locale explicitly; folding is an internal representation. [Folding](https://developer.apple.com/documentation/foundation/nsstring/folding(options:locale:)) |
| `NLTokenizer` word units | 12; 10.14 | `NaturalLanguage.framework/Headers/NLTokenizer.h:28–29`, both SDKs | Native linguistic token boundaries; not fuzzy matching. [Tokenizer](https://developer.apple.com/documentation/naturallanguage/nltokenizer) |
| Foundation `Predicate`, `StringLocalizedStandardContains`, `SequenceAllSatisfy` | 17; 14 | Foundation interfaces; named expression types in both SDKs | Macro representation and evaluation support do not prove every persistent-store translation. [Predicate operations](https://developer.apple.com/documentation/foundation/predicate) |
| SwiftData `FetchDescriptor` | 17; 14 | SwiftData interfaces `:941–949`, both SDKs | Has typed `Predicate`, sort descriptors, pending-change inclusion, limit/offset and relationship prefetch properties. [FetchDescriptor](https://developer.apple.com/documentation/swiftdata/fetchdescriptor) |
| `CSSearchableIndex` | 9; 10.11 | `CoreSpotlight.framework/Headers/CSSearchableIndex.h:29–56`, both SDKs | On-device index; check `isIndexingAvailable`; asynchronous maintenance. [Index](https://developer.apple.com/documentation/corespotlight/cssearchableindex) |
| `CSSearchQuery` | 10; 10.12 | `CoreSpotlight.framework/Headers/CSSearchQuery.h:40–73`, both SDKs | Attribute query grammar and cancellable asynchronous results. [Query](https://developer.apple.com/documentation/corespotlight/cssearchquery) |
| `CSUserQuery`, `CSSearchQueryContext.filterQueries` | 16; 13 | `CSUserQuery.h:23–54`, `CSSearchQuery.h:28–33`, both SDKs | Human-entered search and context filters over indexed values. [User query](https://developer.apple.com/documentation/corespotlight/csuserquery), [filterQueries](https://developer.apple.com/documentation/corespotlight/cssearchquerycontext/filterqueries) |
| Semantic disable flag, ranked-result limits and `prepare()` | 18; 15 | `CSUserQuery.h:31,40–52`, both SDKs | Optional semantic behavior; SDK presence is not proof of availability/quality on every OS 27 device. [Semantic flag](https://developer.apple.com/documentation/corespotlight/csuserquerycontext/disablesemanticsearch) |

No recommended declaration in this table was absent from either inspected SDK.

## Required lexical behavior

The human has fixed all typed words matching across title, subtitle, notes, current category/tag names, link labels/URLs, and saved location text. List names are not accepted searchable fields. Text and other groups combine with AND; label/list selections retain their own Any/All semantics and stable IDs. Search engines must preserve those choices rather than infer them from a control or ranking API.

Foundation supplies the matching primitive. `localizedStandardContains` performs case/accent-insensitive substring matching using the current locale. The installed header cautions that “standard” uses system defaults whose exact options can evolve; it recommends `range(of:options:range:locale:)` when more control is needed. **Recommendation:** choose explicit case/accent options and an agreed locale policy when fixing query semantics; use the standard convenience method if system-default behavior is accepted. An ASCII lowercase or accent-stripping implementation is unnecessary. [Foundation matching](https://developer.apple.com/documentation/foundation/nsstring/localizedstandardcontains(_:)), [Range comparison](https://developer.apple.com/documentation/foundation/nsstring/range(of:options:range:locale:))

For an all-words query, the conceptual condition is: for every query token, at least one accepted current field of the item matches that token. This composes native string matching with the already-approved AND/OR relationship; it is not a fuzzy algorithm. A single contiguous search of `vegetarian menu` in one field would fail the approved A fixture. Fields can remain separate; an implementation need not persist one flattened search string.

Token boundaries remain a product question. Whitespace splitting and native `NLTokenizer(unit: .word)` are different policies for punctuation, URLs, hyphenated tags, apostrophes, scripts without spaces and mixed languages. Apple documents word/sentence tokenization and requires one tokenizer instance to be used on one thread/queue at a time. Its API does not choose Planner's query grammar. [Tokenization](https://developer.apple.com/documentation/naturallanguage/tokenizing-natural-language-text)

Unicode comparison and locale are also distinct. Foundation folding supports case, diacritic and width options; its documentation gives different English/Turkish results for `I`. Folded strings are for internal processing, not display. Width insensitivity, transliteration, stemming and synonyms have not been approved. If any derived folded values are cached, category/tag renames and locale/policy changes must invalidate them. [Folding rules](https://developer.apple.com/documentation/foundation/nsstring/folding(options:locale:))

This baseline can read current local data without a system index or remote service. Its identity set is deterministic for the same snapshot and resolved matching policy. The confirmed `cafe`/`CAFÉ` results do not approve every broader locale-dependent equivalence: devices or interfaces using different locales need not return identical sets. SwiftUI, App Intents and MCP must share the chosen locale/token policy. No timing or cross-locale parity has been measured.

## SwiftData: fetch support versus matching semantics

Foundation's `#Predicate` supports Boolean operations, optionals, `contains`, `contains(where:)`, `allSatisfy`, and `localizedStandardContains`. It rewrites the closure into expression types; arbitrary loops, nested declarations and mutation of captured variables are excluded. In-memory `Predicate.evaluate` and persistent SQL execution are different stages. A custom matching function cannot simply be placed inside the macro. [Predicate](https://developer.apple.com/documentation/foundation/predicate)

Apple's SwiftData sample combines a text `.contains` expression and date constraints and centralizes that predicate so related views return the same set. It demonstrates ordinary dynamic filtering, not a guarantee that every combination of token arrays, optional location objects and to-many category/tag/link relationships translates correctly. `FetchDescriptor` expects Foundation's typed `Predicate`, not an interchangeable string-based `NSPredicate`. [SwiftData filtering sample](https://developer.apple.com/documentation/swiftdata/filtering-and-sorting-persistent-data)

**Recommended investigation path:** test the resolved public query against a real temporary SwiftData store, including representative insensitive expressions and optional/to-many relationships. Use proven store predicates to narrow canonical candidates, then native lexical matching where needed. Do not impose an early fetch limit that can discard later text matches; determine pagination/limits only with the approved ordering/completeness contract. No complete public store-translation support matrix or measured performance guarantee was established by the reviewed sources.

The common query must be a Planner operation used by SwiftUI, App Intents and MCP. `@Query` can drive UI refresh but does not itself define matching for the other interfaces. The exact shared interface and storage strategy remain with Core architecture.

## Core Spotlight: full-text/indexed and semantic alternatives

Core Spotlight can index app metadata and run in-app queries. `CSSearchableItemAttributeSet` supports standard and custom attributes; select fields matching the actual content instead of indexing unrelated list names or every provider value. An index's metadata is a projection of Planner data, not the canonical item. [Searchable attributes](https://developer.apple.com/documentation/corespotlight/cssearchableitemattributeset)

`CSSearchQuery` supports attribute comparisons, numeric/date ranges, parentheses, `&&`/`||`, case-insensitive `c`, diacritic-insensitive `d`, word-boundary `w`, and wildcards. Word boundaries and substring wildcards differ. Its grammar can express AND across query terms and OR across selected indexed fields, but this does not establish equivalence to Foundation's locale-aware matcher. Construct queries with safe literal handling rather than interpret raw user input as this grammar. [Indexed query grammar](https://developer.apple.com/documentation/corespotlight/searching-for-information-in-your-app)

`CSUserQuery` accepts human-entered terms, suggestions and ranked/unranked results. Since iOS 18/macOS 15, it supports semantic matches that need not contain the original words. `disableSemanticSearch` defaults to **false**, enabling that broader behavior. Semantic similarity, substring matching, prefix matching and typo tolerance are separate concepts. The reviewed Apple APIs do not specify a bounded edit-distance or transposition contract for Planner's proposed typo cases. Enabling semantic search is not evidence that `cfae`, `caffe`, or `vegitarian` must produce a particular result. [CSUserQuery](https://developer.apple.com/documentation/corespotlight/csuserquery), [Semantic behavior](https://developer.apple.com/documentation/corespotlight/csuserquerycontext/disablesemanticsearch)

The installed `CSUserQuery.h` states a default `maxRankedResultCount` of 100. Limiting indexed candidates before applying canonical filters can omit otherwise eligible results. Ranking, truncation and candidate completeness must therefore be tested against the approved sort/dataset policy. Apple's `prepare()` documentation also describes extra startup work and memory use; it is not a free latency guarantee. [Search interface and preparation](https://developer.apple.com/documentation/corespotlight/building-a-search-interface-for-your-app)

### Freshness, offline use, privacy and cancellation

Apple says Core Spotlight indexes remain on the device, private to its owner, and are neither sent to Apple nor synchronized between the user's devices. The app maintains each device's index after local and CloudKit-imported changes. On-device storage supports an offline candidate, but cold/warm search, resource availability and semantic behavior must still be exercised on physical devices. Check `CSSearchableIndex.isIndexingAvailable()` and handle unavailable/error paths. [Framework privacy](https://developer.apple.com/documentation/corespotlight), [Availability check](https://developer.apple.com/documentation/corespotlight/cssearchableindex/isindexingavailable())

Indexing and deletion callbacks acknowledge **journaling**, not completed query-visible updates. The installed headers specify retry/reindex responsibilities. Items also have expiration dates and the system may request reindexing. Each changed shared label can affect many items; reindexing only the label entity would not update copied label text in item documents. [Index submission](https://developer.apple.com/documentation/corespotlight/cssearchableindex/indexsearchableitems(_:completionhandler:)), [Deletion acknowledgement](https://developer.apple.com/documentation/corespotlight/cssearchableindex/deletesearchableitems(withdomainidentifiers:completionhandler:)), [Index maintenance](https://developer.apple.com/documentation/corespotlight/adding-your-app-s-content-to-spotlight-indexes)

**Architecture consequence:** resolve returned UUIDs to current items and reapply current structured filters and required lexical semantics. That blocks stale false positives, including deleted/archived items or an old category name. It cannot recover a fresh matching item absent from the index. Immediate accepted lexical results need a canonical matching path, or a proven complete fallback/overlay protocol. A journal callback alone cannot provide that guarantee.

Indexed content can appear in system Spotlight as well as Planner; “private to the device owner” does not mean “visible only inside Planner.” Define which notes, URLs, location text and archived items may be exposed before indexing them. Named indexes and protection classes can restrict data availability; the SDK comment identifies custom protection classes for iOS. Do not assume identical lock-state behavior on native Mac. [Index protection](https://developer.apple.com/documentation/corespotlight/adding-your-app-s-content-to-spotlight-indexes)

Queries are one-shot objects. Cancel obsolete queries, create a new object for changed text, and reject late results whose query generation is no longer current. Debouncing is recommended by Apple, but its delay is not a product decision made here. The same cancellation principle applies when structured filters or shared metadata change. [Cancellation](https://developer.apple.com/documentation/corespotlight/cssearchquery/cancel())

## Optional fuzzy behavior and remaining choices

There is a viable native baseline for every confirmed lexical fixture. Core Spotlight supplies a native indexed/semantic candidate, not a documented deterministic typo rule. No external-library investigation is warranted until the human specifies a gap that this native path must fill. Permission to use a widely used, well-tested library is not proof that a particular dependency has suitable Unicode behavior, maintenance or test quality.

Duration and search still needs:

- Query tokens: punctuation/URL/hyphen handling, substring versus complete-word/prefix behavior, language and locale policy.
- Whether optional fuzzy results are allowed, when they appear, and concrete inclusion/exclusion examples. Distinguish typo tolerance from semantic synonyms.
- Exact duration normalization/boundaries/unknown behavior, ordering/ties, acceptance-test dataset and latency/scrolling budget.

Core architecture/system integration needs to decide whether an index earns its maintenance cost, how it remains complete, and which data can appear in system search. These choices do not change the already-approved lexical result sets or independent completion/archive state.

## Required later verification

Before implementation, confirm public query and duration-comparison seams under `/tdd`; work one red behavior and its minimal green implementation at a time. These are obligations, not passing tests.

| Layer | Scenarios and expected outcomes |
| --- | --- |
| Lexical unit behavior | `cafe` and `CAFÉ` produce C in ordinary scope; all states produce C/G for `cafe`. `vegetarian menu` matches A across notes/link label. `Ginza` matches A. Every typed word must match; missing words exclude an item. Global membership does not duplicate an item UUID. |
| Structured intersections | Reproduce every approved set in the committed choice record: AND across groups, selected-label Any/All, independent completion/archive filters, Inbox and list scope. Duration boundary/unknown results wait for approval. |
| Current shared text | Rename Food to Dining: category-ID filters retain the same items; current `Dining` text matches A–E in ordinary scope and A–E/G/I in all states. `Food` does not match merely because a list retains that word. A stale search projection must not override these results. |
| Unicode/token policy | Test precomposed/decomposed accents, case variants, English/Turkish `I`, punctuation, URLs, hyphens, Japanese and mixed scripts. Record exact expected sets only after locale and token policy are chosen. Original display text remains intact. |
| Persistent integration | Save/reopen the real fixture store; test each chosen predicate on actual relationships, nil fields, pending changes, local edits and imported remote changes. SwiftData query results must agree with the canonical public query. |
| Optional index | Delay or fail index updates; query immediately after create, rename, archive and delete; force reindex/expiration/unavailability paths. Required fresh lexical hits remain available; stale UUIDs never resurrect or bypass filters. Exercise truncation beyond the SDK's default ranked cap. |
| Optional fuzzy/semantic | Separately test `cfae`, `caffe`, `vegitarian`, and semantic `meal`/`Food` examples. Results, ranking and false-positive exclusions are pending human approval; lexical completeness stays required. |
| UI and device | Native controls expose the same groups and scope on iPhone, iPad and Mac, with VoiceOver/keyboard access. Rapid text/filter changes cancel obsolete work and prevent late results. Test offline cold/warm searches, protected/locked states where relevant, and approved dataset/latency budgets on physical OS 27 devices. |

## Evidence reproduction and document validation

The SDK observations above are reproducible with `xcodebuild -version`, `xcrun --sdk iphoneos --show-sdk-path`, `xcrun --sdk macosx --show-sdk-path` and `xcrun swift --version`, using the per-command developer directory shown earlier. Inspect the named headers/interfaces in those SDKs; no installation or global toolchain switch was performed.

Selected SHA-256 fingerprints identify the files inspected, without copying Apple SDK contents into this repository:

| SDK source | iPhoneOS / macOS SHA-256 |
| --- | --- |
| `Foundation.framework/Headers/NSString.h` | Both: `05794c89d6a8aa19fd27b0bcade8a686ccb83ab3685be865080e7b01f480aae4` |
| `CoreSpotlight.framework/Headers/CSUserQuery.h` | Both: `014b24631350ebd1014a5a8611766b6730959e782694e663fcd58505e62609c3` |
| `CoreSpotlight.framework/Headers/CSSearchableIndex.h` | Both: `c564e132e73ff5d5ecd2e0e5b72bd9db4f80e42bc9d513c5d199e9cb0da657f9` |
| `Foundation.swiftmodule/arm64e-apple-ios.swiftinterface` | `b2addb99e4a4a4fbdc8e10a3b911deb119efd820b9b18fd756b313b700b69352` |
| `Foundation.swiftmodule/arm64e-apple-macos.swiftinterface` | `9434abc2b4f28dfb0c3f7cad3a069447597fe5cb4bbf254927221af86e0b98d0` |
| `SwiftData.swiftmodule/arm64e-apple-ios.swiftinterface` | `5ce00a8f9a6571d3e62da8bdeff9998c56bfa9ba182980c4d1cf968346a590f8` |
| `SwiftData.swiftmodule/arm64e-apple-macos.swiftinterface` | `d7c1b0d3ff9dab0884426f98027410adab7c7cea6d92d10be043d066b1806d80` |

Document checks: affected Markdown lint, local-link/primary-source destination checks, whitespace inspection and committed-artifact verification. Swift type checks and application tests are inapplicable to this documentation-only change. Publication evidence is returned to the map owner; this report does not close the ticket or resolve remaining human choices.
