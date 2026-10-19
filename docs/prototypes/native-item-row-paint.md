# Native Item row painting

Status: the apparent blank-row observation is resolved by original-file pixel verification. Two sampled native paint routes pass. No production rendering defect was established, and production UI is unchanged.

## Context and expected result

The [complete native traversal](native-every-item-traversal.md) verifies 5,000 titles and source identities on phone and tablet. The scaled preview of its dark iPad capture was initially interpreted as showing blank rows while Item 00001 remained in details. Original-file inspection below corrects that interpretation. A shorter page-boundary capture at Item 00129 and the subsequent selected-detail capture also paint normally. Accessibility labels alone cannot establish pixel readability.

The investigation starts with a suspected rendering observation without a repeatable paint failure. Its goal is to establish whether the original image actually lacks text before changing production code. Original-file verification resolves the suspicion; no production fix is needed.

## Readiness and test boundary

Use the existing Q34 native UI boundary and Q52 dedicated fixture target, with disposable real Planner storage and the unchanged 5,000-Item fixture. Signing, Mac automation and CloudKit are unnecessary for this local investigation. No new production interface, test hook, fixture control, dependency or target is introduced.

The focused diagnostic selects Item 00001, keeps its detail visible, and scrolls its catalog toward the last page. It samples an actual hittable, unselected source control in the middle of the visible catalog, away from floating bars. A known painted control before scrolling verifies the screenshot-to-window coordinate conversion and pixel measurement. In the controlled dark appearance, the sample must retain a mostly dark background and contain bright title pixels. The diagnostic records initial and settled counts, waits up to five seconds without changing selection, and preserves original screen captures. This is a sampled paint signal, not OCR, a full contrast audit or all-row pixel coverage. Light appearance and compact platforms are explicitly outside this diagnostic's scope.

The five-second observation allowance belongs to the test; it changes no app, network or agent timeout. A Core unit test cannot reproduce native cell drawing. Existing Core identity/window tests remain separate evidence, and no shallow model test substitutes for this UI check.

## Initial observations

The first focused fixture build passes. Its first native trial passes the positive control on Scale Item 00008: 1,458 bright pixels, 17,957 dark pixels, 21,409 total. The trial then fails in 151.040 seconds because 200 high-velocity gestures do not expose the last Item. It never reaches the final paint assertion and is not a rendering red. A later read-only Simulator screenshot shows SpringBoard after test teardown, so it does not establish the failed controller's catalog position.

The next controller revision uses the SDK's standard fast gesture and logs observed tail titles. It reaches Item 00917 at its 80th logged gesture. That progress cannot reach Item 05000 within the trial's 200-gesture cap, so the owned trial is deliberately interrupted. It supplies no rendering red or complete result.

The installed public XCUIAutomation header declares pointer scrolling on iOS 15 and later. A diagnostic revision uses that API on a real hittable row. Its first negative-delta event completes but leaves the visible tail at Item 00014. The owned setup probe is interrupted and the next revision reverses direction. No production scrolling, selection or style code changes. Interrupted bundles receive no completed-xcresult credit. These setup attempts establish no rendering failure.

## Reduced-route results

The positive pointer direction reaches Item 05000 in one event. The native diagnostic passes in 148.312 seconds with zero failures or skips. Item 00001 stays in details. The sampled unselected Item 04994 has 1,454 bright pixels and 18,002 dark pixels out of 21,488, both initially and after the noninteractive wait. This route does not reproduce the blank-looking original capture.

A second route returns through nearby rows using twelve ordinary touch drags, confirms the last Item leaves the viewport, and touches back to the end. It passes in 227.311 seconds with zero failures or skips. The initial measurement now uses the original controller-checkpoint screenshot, captured before hierarchy inspection, so later accessibility reads cannot substitute a newer frame. Item 04994 again has 1,454 bright and 18,002 dark pixels immediately and after waiting. These are sampled native paint results, not closure of the original hour-long route. Original captures and exact source/product epochs are retained.

A repeat of the original exhaustive touch route briefly starts with first-frame instrumentation. It is deliberately stopped after the independent original-file analysis below resolves the apparent symptom. That interrupted run receives no completion credit. The redundant full-route instrumentation is removed; the completed identity oracle is preserved.

## Original-file verification and outcome

The apparent blank rows came from a mistaken reading of the scaled preview. Independent Pillow decoding of the untouched original PNG finds 1,454 bright pixels in Item 04994's title/metadata region, exactly matching both passing native captures and the CoreGraphics measurement. A full-resolution inspection crop shows its title and duration.

All fourteen visible row regions from Item 04987 through Item 05000 contain bright glyph pixels. Each region's decoded RGB bytes are identical across the original capture, the pointer-route capture and the touch-cycle checkpoint. Their exact rectangles, original-file hashes, RGB-region hashes and counts are retained in native-item-row-paint-validation/original-pixel-verification.json beside the original evidence. The original PNGs are not edited or replaced; the derived inspection crop stays local.

This contradicts the initial missing-paint interpretation. There is no established production rendering failure to fix, so production hypotheses and style changes are unnecessary. The existing row-paint test retains its real native positive control and sampled offscreen-selection/touch checks. The interruption is a verification cleanup, not a product rollback or successful long repeat. Full-scene contrast/accessibility and physical-performance gates remain separate.

## Completion evidence and limits

- Independent decoding resolves the original observation. All fourteen captured row regions already contain glyph pixels; a scaled preview was misread.
- Two sampled native routes pass while the original selection remains offscreen. No production probe or fix is justified by the evidence.
- The final test target compiles after removing redundant instrumentation from the unrelated exhaustive traversal. The executed paint test and helpers remain identical to the passing touch-cycle epoch.
- Original captures, exact commands, source/product epochs and unsuccessful setup attempts are retained. Scoped Swift and Markdown lint pass.

Physical performance, complete scene/accessibility review, Mac runtime, signed integrations and final whole-app acceptance stay on the map.
