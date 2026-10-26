# Full List names in mobile content

Q113 A keeps the full List name in the content when the compact native bar
cannot fit it. The Mac toolbar consolidation had also removed that mobile
heading. A real phone journey reproduced an empty List showing only the
truncated bar title, with no full name in its content.

The correction adds a wrapping native heading to the existing iPhone/iPad
summary in empty, populated and Map representations. It scales with Dynamic
Type and exposes the heading accessibility trait. Mac keeps its single unified
toolbar title. Itinerary presentation and saved data are unchanged.

## Local qualification

Five final native executions across two functions pass:

- Empty-to-populated List creation on ordinary light iPhone and maximum-text
  dark iPhone/iPad with Increase Contrast. The full name stays within the pane;
  progress remains `0 of 1 item done`, and scrolling reaches the new Item.
- The existing List Map journey on light iPhone and dark iPad. Pin selection
  retains local Done, global Todo and the original bookmark. Tablet viewport
  transitions retain the selected context.

All 1160 native inputs match the workspace and Mac app/Share/UI-test compilation.
Strict affected Swift and Markdown lint pass. Eleven final original title,
scroll and Map captures are inspected. These are scoped interaction and visual
checks, not a whole-app accessibility audit.

The original failing reproduction remains recorded. Two intermediate driver
failures are also retained: a container queried as a Button, and a lazy row
queried before scrolling at maximum text. Neither is reported as a passing run.
[Final verification](evidence/native-mobile-list-heading/final-validation.json)
lists the matching final cohorts. Execution records are compacted with read-back
hash verification; original captures remain directly viewable.

## Remaining gates

Actual Mac UI, broader scene/assistive review and physical/signed-store checks
remain open. Signing stays deferred. Advanced export/import and manual
restoration remain post-MVP under the amended release scope.
