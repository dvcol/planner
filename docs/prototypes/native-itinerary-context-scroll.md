# Itinerary context while scrolling on iPad

## Scope

Keep the current itinerary identifiable in a narrow iPad collection pane after scrolling and rotation. Reuse the approved native UI boundary and the existing 132-appearance route fixture. Preserve the accepted single native title on iPhone and the existing Mac presentation. No saved-data, public API or signing change is needed.

## Reproduction and diagnosis

The first compile attempt starts no tests because its accessibility query uses an element where a query is required. The corrected tracer runs on unchanged production and fails after scrolling to Window Activity 020. Its original screenshot shows Filters, Add, More and search, but no itinerary name. The navigation bar retains the Windowed route identifier while its visible title is absent. The content heading has scrolled away.

Evidence is retained in [the runtime failure](evidence/native-membership-consolidation/native-itinerary-heading-scroll-runtime-red-tablet/exit.json). The earlier compilation failure is separately retained and receives no runtime credit.

Ranked predictions before the production probe:

1. A normal heading row scrolls away while the narrow native bar has no room for its replacement. Keeping the existing heading in a native safe-area inset should preserve context.
2. Search and toolbar actions consume the title space independently of scrolling. If the inset also disappears, investigate their layout separately.
3. Refresh replaces the navigation context. If this is the cause, the context may disappear again after rotation despite a pinned heading.

The first probe moves only the existing iPad heading out of the scrolling rows and into a top safe-area inset. The remaining summary stays in the native List. Phone and Mac keep their existing title treatment. The tracer stays unchanged for its first correction run.

## First correction and regressions

The unchanged tracer passes in 50.920 seconds. The [source comparison](evidence/native-membership-consolidation/native-itinerary-context-source-validation.json) records that only SavedItineraryViews changed among its 1,160 captured inputs. Original portrait and landscape screenshots show the readable heading after scrolling. Add opens and cancels normally; the same activity appearance survives both rotations.

The existing title test now locates the readable heading by its accessibility identity rather than requiring it to be a List row. Its full-name and native-action checks remain. The [dark-iPad cohort](evidence/native-membership-consolidation/native-itinerary-context-final-dark-tablet/exit.json) passes three functions with no skips, including List/Map title and Add/Cancel, repeated-List collapse with preserved selected detail and completion, and the new scrolling/rotation check. The [Mac app/Share build](evidence/native-membership-consolidation/native-itinerary-context-mac-compiler/execution.json) also passes, with no Mac interaction credit.

## Final local checkpoint

The [final input/product verification](evidence/native-membership-consolidation/native-itinerary-context-final-validation.json) reconciles all 1,160 inputs across the Mac build and seven passing mobile executions. Three light-phone regressions retain one native title through List/Map/List, native Add/Cancel and repeated-stop completion/detail state. The unchanged new iPad scrolling test also passes in light mode, and the original dark appearance is restored. All final mobile executions have zero failures and skips. Strict formatting passes the three affected Swift files; Markdown lint and whitespace checks pass.

Eight unchanged original screenshots are retained and visually inspected, including the actual failure, scrolled dark portrait/landscape, dark collection/Map, phone List/Map and light landscape. [Duplicate-export cleanup](evidence/native-membership-consolidation/native-itinerary-context-export-cleanup.json) removes five temporary export directories totaling 18,779,744 nominal bytes. Original result bundles, selected images and every failed test input remain. This does not measure APFS free-space gain.

This correction adds fourteen lines to the existing view and no new component, package or data logic. Full native-bar title truncation, long-title/accessibility extremes, actual Mac interaction and final whole-app visual acceptance retain their separate gates. Core and HTTP tests are not repeated for this presentation-only change.
