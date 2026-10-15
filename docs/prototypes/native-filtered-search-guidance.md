# Native filtered-search guidance

## Context and goal

Items and Inbox share the production `SavedItemCatalog`. Before this change, an empty search always used SwiftUI's stock search empty state, even when cumulative filters hid an exactly named Item. The large-catalog captures show a valid Todo Item hidden by Done while the description advises checking spelling.

Explain that filters can hide search results. Keep the pre-made native `ContentUnavailableView`, stock search guidance when unrestricted, and existing no-search guidance. Search, filter semantics, identities, completion and stored content do not change.

## Definition of ready

- The existing approved native UI seam exercises production views and Core-backed storage through the fixture app.
- The existing `address-retry` fixture contains one active, globally Todo Item named Retry place, with Original notes and no List membership. It belongs to both Items and Inbox.
- No new provider, persistence, public API or testing seam is needed. Q86 does not affect this slice.

## Definition of done and /tdd

One native journey visits Items and Inbox. Search the exact title, hide the source using Done, and require filter-aware guidance. Restore Todo and require the original source identity. With completion and archive unrestricted, a nonmatching search must retain the native No Results state without filter guidance. Return to the source and verify Original notes and global Todo.

Run that journey before the production fix to establish the actual guidance failure, then after the fix on phone and tablet. Preserve original captures and raw diagnostics. Compile the affected Mac fixture target, run strict Swift formatting checks on the changed Swift files, and lint this report. Review source and evidence before committing.

## Execution

The pre-fix phone run failed the missing-guidance assertion after hiding the exact Todo match, in 38.014 seconds. Its original capture and accessibility tree show `No Results for “Retry place”` and `Check the spelling or try a new search.` The source row was absent as expected. Two assertions beyond that failure were corrected to the existing native labels before the next run.

The first post-fix phone attempt passed both Items guidance states, then failed to find Search Inbox after attempting navigation while search still held the keyboard. Its 91.015-second result is a test-driver failure, not a completed qualification. The controller now submits search and requires the keyboard to disappear before switching catalogs. Its exact source, original captures and diagnostics remain separate from final results.

The production change selects a native `ContentUnavailableView` with `No matching items` and `Change the filters or try a different search.` when search and filters are both active. Unrestricted search still uses `.search(text:)`; the no-search branch is unchanged. No unit test is added because the behavior belongs to the already approved native UI seam and changes no Core logic.

The final phone journey passed in 147.366 seconds, one function with zero failures or skips. All four original captures were inspected: Items and Inbox each show filter guidance for the hidden exact match and stock search guidance when unrestricted. Text is readable above the keyboard. The final source identity is retained in the result attachment.

The final tablet journey passed in 155.378 seconds, one function with zero failures or skips. Its four original captures were also inspected. Both guidance variants fit the narrower catalog column above the keyboard. This is one distinct function executed on two simulator destinations, not separate tests for every assertion or repeated XCTest suite total.

The affected Mac fixture app and test host compile successfully with signing disabled. Strict formatting checks pass on the two changed Swift files. The final simulator runs compile the affected iOS targets. No affected-source compiler warnings were reported. The earlier red and test-driver attempt remain historical evidence, without final qualification credit.

The [evidence packet](evidence/navigation/native-filtered-search-guidance/) retains exact commands, six source hashes per final destination, built-product hashes, raw compressed logs, result summaries, unmodified PNGs and lossless diagnostic attachments. Its execution record distinguishes the two earlier failures from the two final passes. Standards and Spec reviews found zero source or evidence issues. Both audits verified all 64 artifact hashes, source revisions, final products, actual results and qualification limits.

This slice does not qualify Mac UI runtime, landscape/split-window layout, physical-device behavior, localization, whole-app polish or the outstanding map gates. Query/storage behavior is unchanged, so no broad Core suite or repeat of the separate 5,000-Item journey was run. Signing and physical setup remain deferred. Q86 and the concrete catalog-sort contract remain pending.
