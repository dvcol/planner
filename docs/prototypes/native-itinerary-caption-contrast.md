# Native Itinerary summary contrast

Status: corrected and qualified at the existing native UI boundary. The light-mode failures reproduce before the correction; the expanded count journey and unfiltered contrast audit pass afterward on light/dark phone and iPad, including iPad Increase Contrast. This resolves the faint composition/filtered-count finding retained in the [UI review inventory](../native-ui-scene-inventory.md). Final whole-app polish remains open.

## Context, goal and starting state

Recent passing duration and Undo journeys retain dark screenshots with pale Itinerary composition and matching-count text. The earlier selected-row correction qualifies Item/List rows, not these summary captions. Source inspection finds hierarchical secondary styling in the Itinerary's native List summary, but that alone does not establish a contrast failure or its cause.

Before this diagnostic, the captions had visual observations without a native audit result. The goal is to determine whether the ordinary saved scene fails XCTest's unfiltered contrast audit, identify the actual flagged elements, and make a minimal native correction only if the evidence establishes a defect. Full progress, filters, independent completion and appearance identities must remain correct.

## Readiness and required checks

Use the accepted native UI boundary, ordinary saved data and the same unfiltered `performAccessibilityAudit(for: .contrast)` mechanism already used for native row qualification. No new production interface, fixture control, target or test callback is introduced. Pending Q108/Q109/Q110 do not change this diagnostic's boundary or authorize their dependent implementation.

The initial focused journey creates Museum, a List referencing Museum, and an Itinerary containing both direct and List appearances. Complete only the direct appearance, then filter Todo. Require the independent List appearance, full 1-of-2 progress, composition of one direct Item and one List, and Matching 1 of 2. The expanded reproduction adds Hotel to the List, completes both Museum appearances, and requires full 2-of-3 progress, root Matching 1 of 3 and nested Matching 1 of 2. Capture the actual screen before the native contrast audit. Keep every reported contrast issue; do not suppress unrelated elements to obtain a pass.

If the audit fails, retain its original element captures and rank falsifiable causes before probes. Change one variable per diagnostic, then rerun the original scene. A passing audit alone is scoped evidence, not complete visual, VoiceOver, keyboard or physical-device acceptance.

## Definition of done

Record the actual executed result, source/product hashes and inspected originals. Any correction must pass the original native audit and affected completion/filter/count checks, strict Swift/Markdown lint and both platform compiler checks. No saved-data command change is proposed. Keep unavailable Mac runtime, complete scene/accessibility review, physical performance, signing and final whole-app acceptance on their existing gates.

## Observed baseline and hypotheses

The initial two-appearance scene passes the unfiltered audit on dark iPad with Increase Contrast in 79.549 s and dark iPhone in 76.763 s. Light iPad fails in 82.189 s. A repeat fails in 81.360 s, and light iPhone independently fails in 76.646 s. Each light invocation reports three contrast failures.

The original light iPad full screen and all three flagged element captures were inspected. They identify the composition caption, root matching caption and Entries heading. All are fully visible, so these failures are not attributed to text beneath system chrome. Each issue says the contrast is insufficient unless the font is larger. A passing dark audit therefore cannot establish light-mode readability.

The three-appearance iPad reproduction fails in 106.956 s with four contrast issues. All four original element captures were inspected. The additional failure identifies the nested List's Matching 1 of 2 caption, alongside the same composition/root matching/Entries failures. The fixture's full progress is 2 of 3 while only Hotel remains visible.

Ranked hypotheses were inherited hierarchical secondary styling, the resolved secondary color itself at these text sizes, and typography requiring more contrast. The first probe changed only the flagged foreground presentation to explicit native semantic colors, retaining fonts, layout and controls. Its passing result establishes a sufficient foreground correction without changing typography. It does not prove an Apple-internal color-resolution mechanism.

## Correction and resulting state

The production correction uses `Color.primary` explicitly for the composition, root matching and nested matching captions. Entries keeps a native Section with an explicit primary Text header. The change preserves caption/header typography, layout, disclosure controls, progress, accessibility labels, filter semantics and saved-data commands. It adds no component abstraction, raw color, package or target.

The same three-appearance journey and unfiltered audit qualify the correction. No issue handler suppresses failures. A unit test for color/padding constants would not establish readability and is not added; the native rendered audit and actual captures supply the relevant boundary.

## Executed checks

All runtime rows execute `SavedItineraryBulkJourneyTests.testItineraryCompositionAndFilteredCountsPassNativeContrastAudit`. The initial two-appearance diagnostic and expanded three-appearance regression have separate archived source hashes. The expanded regression executes both before and after the production correction.

| Before correction | Scene | Result | Duration |
| --- | --- | --- | --- |
| iPad dark, Increase Contrast | Two appearances | Pass | 79.549 s |
| iPhone dark | Two appearances | Pass | 76.763 s |
| iPad light | Two appearances | Fail, three contrast issues | 82.189 s |
| iPad light repeat | Two appearances | Fail, same three issues | 81.360 s |
| iPhone light | Two appearances | Fail, same three targets | 76.646 s |
| iPad light | Three appearances | Fail, four contrast issues | 106.956 s |

| After correction | Scene | Result | Duration |
| --- | --- | --- | --- |
| iPad light | Three appearances | Pass | 107.009 s |
| iPhone light | Three appearances | Pass | 95.872 s |
| iPad dark, Increase Contrast | Three appearances | Pass | 106.365 s |
| iPhone dark | Three appearances | Pass | 97.062 s |

Every final invocation verifies the original appearance identities, independent Museum completion, full 2-of-3 progress, only Hotel visible, one direct Item and one List, root Matching 1 of 3, and nested Matching 1 of 2. All four native audits report no contrast failures. Each run restores its Simulator appearance/contrast settings.

The mobile target compiles at each diagnostic source epoch and after correction. The Mac target compiles both before and after correction using the existing local ad hoc setup. This adds no actual Mac runtime or signing qualification. Strict affected Swift/Markdown lint, whitespace, local report links and evidence integrity checks pass. The bounded credential-pattern scan reports no findings. Core/MCP tests are not repeated for four native foreground presentations.

## Evidence and visual review

The observed results index all fifteen build/runtime epochs, including failures. Each packet retains its command, result, logs, source/product hashes and available original attachments. The source comparison verifies 149 production Swift inputs per epoch. Before-correction packets differ from the final source only in `SavedItineraryViews.swift`; corrected packets match it.

Seventeen original captures were inspected directly and recorded with hashes in the visual review. That review includes all four expanded red element captures, the unobscured full scene and all four corrected full scenes. It does not claim every exported attachment was inspected.

Compare the expanded light baseline with the corrected iPad light scene. The same composition, counts and Entries heading are now readable in primary text. The native List hierarchy, progress and visible Hotel remain intact. The empty detail pane is intentional because this journey selects no Item.

The corrected phone light, iPad dark with Increase Contrast and phone dark preserve clear captions and an unobscured Hotel row. The evidence manifest binds the retained files.

## Remaining acceptance

This closes the represented Itinerary caption/heading contrast defect. Actual Mac runtime, complete scene/accessibility and keyboard review, physical performance, signing and final whole-app acceptance retain their existing gates. Pending Undo decisions remain independent. No architectural change is needed for this foreground correction. Qualifying the light scene alongside dark mode would have exposed this defect earlier; the regression now covers both appearances in the recorded runs.
