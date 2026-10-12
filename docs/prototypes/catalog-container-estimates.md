# Catalog container estimates

## Context and starting state

Lists and Itineraries already have qualified full/remaining budgets, manual controls and contextual List-entry previews. Their catalogs still showed names and archive state only. Calling a separate source read for each row would repeat graph loading and encourage clients to calculate their own totals.

## Goal and expected end state

Native and agent catalog rows expose the same full, calculated and remaining totals as source reads. Native rows show compact clock captions, a Manual label and an uncertainty warning where needed. Repeated Itinerary branches retain their own completion. Filters and paging select containers without shrinking each container's full plan.

## Definition of ready

- Q59–Q76 settle full/remaining metrics, manual budgets, repeated appearances, archive retirement and missing-finished upper bounds.
- The agreed /tdd interfaces remain public Core query/read/execute, actual HTTP and native UI journeys. Source budget and contextual branch fixtures already pass.
- Storage schema 15 and portable format 2 contain manual estimates. Derived row values require no new persisted fields or backup format.

## Contract and implementation

`PlannerRowRead.manualEstimate` and `containerEstimates` are present for List/Itinerary sources. Item estimates keep their existing meaning; other row kinds have nil container fields. HTTP emits exact decimal minutes and the existing typed exact/lower/upper/unavailable totals, with null container fields for other kinds.

Core batches the selected window's entry/membership graph. Estimate projections request scalar identity, lifetime, estimate and completion/archive fields. Source and catalog reads share the same calculation methods. Catalog reads avoid per-row source-read calls and retain generation validation. This is implementation evidence, not a 5,000-Item performance qualification.

Native catalogs use SwiftUI Label, Text and SF Symbols. Both metrics remain separately named. The accessible row value includes exact minutes, manual status and missing-estimate information; zero remaining with an exceeded manual budget includes its warning. Existing archive narration remains the first part of a List row's value. Details retain their duration controls and full warnings.

## Definition of done and required /tdd

- Real-store List windows retain manual 240, calculated lower bound 120 with one missing estimate, and remaining 120. Archive retirement produces zero, reopen retains identity/content, and an old generation fails instead of mixing new data.
- Itinerary catalogs prove manual 600, calculated 510, and remaining 480 → 360 → 120 → 0 as a repeated branch finishes, both branches retire and the direct Item finishes. Catalog reads preserve hashes/timestamps; the saved start-only Schedule stays unchanged.
- Actual HTTP verifies catalog manual values and upper bounds, plus null container fields on Item rows. Recheck existing row/schedule behavior.
- Phone and tablet journeys inspect catalog captions, independent repeated budgets, upper-bound warnings, relaunch and Active/Archived List visibility. Inspect real native captures. Record failed bundles separately.
- Run strict affected Swift/Markdown lint and app/test-host compilation. Keep native Mac runtime, further context/scale fixtures, Calendar, administration/restoration, signed physical sync/account/Share and whole-app polish open.

## Execution so far

Twenty-five Core functions pass across ten focused suites, with twenty-eight case executions. Twenty-four actual HTTP functions pass across two suites, with twenty-five case executions. The List red lacked public row fields; the executed Itinerary and HTTP reds exposed missing summaries. An initial Itinerary test used incorrect public argument/property names and is excluded from runtime red evidence.

The broader HTTP run found an old assertion that treated Itinerary scheduling as unsupported. Running the unchanged `2c18cab` source in a temporary copy reproduced the same code/path failure. The expectation now checks the missing Itinerary identity; the corrected current suite passes. No schedule production behavior changed.

Three functions are qualified on each simulator. The first phone bundle passes all three; the corrected phone uncertainty journey also passes. The initial tablet bundle passes Archive and fails two estimate journeys. One inspected control had a hit point of -1,-1 after catalog navigation; the other showed a SwiftData error while the host disk was full. The temporary baseline build cache was removed, preserving source/results/logs. A separate corrected tablet bundle passes both estimate journeys. That rerun establishes success after cleanup; it does not prove the SwiftData error's underlying cause.

The initial native captures show both metrics, manual status and upper bounds. Their narrow tablet sidebar also exposed wrapping caused by a separate Manual badge. The final layout lets Manual flow with the caption text. The final layout passes both estimate journeys on phone and tablet. Their separate bundles and inspected captures qualify this caption layout. The final tablet run took 1,647 seconds with repeated XCTest animation-completion timeouts; responsiveness and their cause remain unqualified.

Mac app/UI host compilation and strict lint of nineteen changed Swift files pass. Native Mac runtime remains unqualified. The [execution evidence](evidence/navigation/catalog-container-estimates/) retains raw summaries, source hashes and captures as qualification completes.

Parallel review found no documented coding-rule violations. Spec review found that a valid manual budget hides calculated overflow in the catalog warning and accessibility value. Core correctly returns an unavailable calculated total while retaining exact manual full/remaining values. The next native fixture regression must expose that state and qualify the warning fix; this checkpoint leaves that edge case open.
