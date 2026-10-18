# Native maximum-duration filters

Status: implemented, with passing represented phone/iPad journeys, existing real-store regressions and both platform compiler checks. This is the missing native criterion from [Duration and search](../duration-and-search.md), not a new Core query contract. Actual Mac interaction and physical acceptance remain open.

## Context, goal and starting state

Core and MCP already accept a duration constraint. The native Filters panel exposes completion, archive, scheduling, labels, Lists, address and links, but has no duration control. Its Item/Inbox, standalone List and Itinerary query builders omit the existing duration argument. Estimate editing and duration sorting do not supply this filtering behavior.

The goal is a native inclusive maximum, selected with the existing quantity/unit controls, and an explicit Include unknown estimates option. An enabled two-hour maximum matches 119 and 120 minutes, excludes 121 minutes, and excludes unknown estimates unless explicitly included. Clearing only duration preserves other criteria and search. Full container progress, estimates, Manual order and source data remain unchanged.

## Readiness and agreed test boundaries

[Issue 8](https://github.com/dvcol/planner/issues/8) and the accepted cumulative Filters workflow settle the behavior. Use the existing native UI journeys and public Core query tests. No additional controller boundary, production test callback, package, target or public query/backup format is needed. Q108 remains a separate pending choice about direct asynchronous Undo-history tests.

First observe the absent native control through the ordinary saved application's Filters panel. Then use native creation pickers to save 119-, 120- and 121-minute Items, an unknown Item and a second searchable group. Verify the inclusive boundary, unknown inclusion, cumulative text, independent clearing, both Item/Inbox surfaces and unchanged saved identities/estimates after relaunch. Follow with contextual List/Itinerary checks for hidden children and full progress. Preserve the existing Q75 rule that an Item-only restriction cannot match a List header by itself.

## Required checks and definition of done

- Native quantity/unit controls support the existing fixed elapsed estimate units and preserve one-minute precision. No raw duration text input is introduced.
- Every native Item query surface passes the same typed duration constraint to Core. Unknown inclusion is effective only while the constraint is enabled.
- Existing full-scope progress and contextual completion survive filtering. Turning off duration or clearing all filters performs no saved-data command.
- Record the actual failing native observation, corrected-source executed results and inspected original captures. Run strict affected Swift/Markdown lint and Simulator/Mac compiler checks. Keep actual Mac runtime and physical responsiveness/accessibility gates separate.

## Implementation

The shared Filters form now has Maximum duration and an explicit unknown-estimate Toggle. The existing estimate component accepts a presentation purpose, preserving its activity/manual labels and quantity/unit arithmetic while adding filter wording. Item/Inbox, standalone List and Itinerary window requests all pass the existing typed duration argument. Active summaries include the maximum and explicit unknown inclusion. Disabling the maximum supplies no duration constraint; Clear Filters resets the whole native filter value.

This changes native presentation/query inputs only. It adds no saved-data command, Core/MCP contract, backup format, package or target. Itinerary metadata already recognizes duration as an Item-only restriction, so a matching List title cannot retain a branch whose children do not match.

## Observed results

| Run | Executed result |
| --- | --- |
| `phone-native-duration-control-red` | Fails in 16.723 s at the missing native maximum-duration control. The original screenshot was inspected. |
| `phone-native-duration-first-journey` | Fails in 144.542 s after passing inclusive/unknown checks, because the controller assumes the native collapsed Search field already exists. Its correction reveals Search using the established native gesture. No production change is credited for this observation correction. |
| `phone-native-duration-catalog-and-itinerary-qualified` | Both functions pass: Item/Inbox in 200.007 s and the affected Itinerary cumulative-filter/header/independent-completion/relaunch journey in 356.113 s. Total 556.120 s, zero failures. Dark appearance is restored afterward. |
| `tablet-native-duration-list-and-editor-qualified` | Both functions pass, 180.006 s for full List progress/order/local completion/relaunch and 112.281 s for the reused estimate editor's remainder/unit/Cancel/Save/relaunch regression. Total 292.287 s, zero failures. Dark mode and Increase Contrast are restored afterward. |
| `native-duration-existing-query-regression` | All three existing real-store duration tests pass in 0.302 s, including inclusive/unknown behavior, rejected invalid bounds and full List progress/Manual order. |
| `native-duration-contextual-final-mac-build` | Final affected source and tests compile under the existing local ad hoc configuration. Compiler evidence only. |

The initial restricted build exits 74 because Xcode cannot write its standard package/module caches. Its qualified retry succeeds. The first implementation build then catches Swift argument ordering in the existing query initializer; the corrected-source Simulator builds succeed. These failed builds remain in the evidence and supply no native behavior credit.

Three original dark/increased-contrast iPad captures were inspected. The filtered List keeps its full estimate, 1-of-3 progress and separate Showing 1 of 3 count. After relaunch, all three appearances retain the completed/unfinished distinctions. The native popover capture shows legible quantity/unit controls at its recorded scroll position; its section heading is partly behind the native bar and the unknown Toggle is partly below the viewport. The journey separately reveals and uses that Toggle. This is not whole-popover or whole-app visual acceptance.

Passing phone originals show the inclusive result rows and all four Museum rows returning when only duration is cleared while text search remains. The latest of the three Itinerary restriction captures corresponds to duration by the loop order and recorded timestamps. Its unmatched List branches are absent while full 1-of-3 progress remains. Faint composition/empty-state captions remain a final-polish finding. The [visual record](evidence/navigation/native-duration-filters/final-validation/visual-review.json) identifies all ten directly inspected originals and separates partial failed-journey captures from final passing evidence.

The [run index](evidence/navigation/native-duration-filters/final-validation/observed-results.json) retains failed and successful invocations. [Production comparisons](evidence/navigation/native-duration-filters/final-validation/production-source-comparison.json) distinguish the five pre-feature paths, the three incorrect argument-order paths and the final matching production. Test durations above are execution times, not responsiveness measurements.

## Remaining completion gates

Strict affected lint, source comparisons, whitespace checks and evidence hashes are retained in the validation packet. Actual Mac interaction, complete accessibility/layout review, physical responsiveness and final whole-app polish stay on their owning gates. Q108 and signing/account setup remain unchanged.
