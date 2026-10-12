# Native delayed link result

## Context and starting state

Q52 requires a slow website preview response arriving after its owned URL changes. [Controlled link outcomes](native-controlled-link-outcomes.md) qualifies no-image success and Retry; [delayed address results](native-delayed-address-result.md) qualify the corresponding location journey. The native fixture currently cannot hold a link response across a saved URL edit.

## Goal and expected end state

A real saved Item has one owned bookmark. Its preview stays pending while the human edits that bookmark's URL through the native form. The new lookup releases the old no-image result, then returns the bundled image. Only an actual release can produce that image. The current native card must paint it without changing the bookmark identity, owned label, notes or completion. Relaunch reopens the same saved Item and URL with fresh no-image provider metadata.

## Definition of ready

- Q50/Q52 approve controlled native providers using production cache and views.
- The fixture seeds and reopens real local-only Core data through public operations.
- Reuse the bundled image and native pixel predicate. Hold the old lookup with a checked continuation and release it from the new lookup, without timers or production hooks.

## Definition of done and required /tdd

- Execute the absent-loading-state red after reaching the owned bookmark and checking its data.
- Implement deterministic release at the fixture provider boundary.
- Qualify native loading, normal URL Save, preserved identities, current painted image, and fresh metadata after relaunch on phone and tablet.
- Inspect original pending/current/reopened captures, run affected strict lint and Mac fixture compilation, and retain commands, source hashes and failed runs.
- Keep Q58 loading/scale, import/recovery, Calendar, broad Mac runtime, physical sync/account/Share and whole-app polish open.

## Execution

The executed red passed the owned bookmark/source checks and failed at absent Loading preview. The fixture now holds that URL in a checked continuation. The current-URL lookup clears and resumes the old no-image result before returning its image. That image is available only through the actual release path; a fresh process returns Reopened website with no image. The passing image state and painted-pixel assertion therefore establish that the obsolete response was delivered after the saved edit without replacing the current card.

The first green attempt failed before Save because deleting from the tapped cursor position left a URL suffix. The native Select All command corrected the test interaction. Its original failed bundle, log and attachments remain recorded. The final phone and tablet runs each pass one function with zero failures or skips. They qualify pending loading, a normal saved URL edit, stable bookmark and source identities, owned label/notes/global Todo, the current painted card and fresh temporary metadata after reopening the same dataset. Production UI, Core and preview-cache code are unchanged.

Standards and Spec reviews report no actionable findings. Mac fixture/test-host compilation succeeds with zero qualified Mac UI runtime functions. Three affected Swift files pass strict lint, and Markdown/whitespace checks pass. [Machine-readable evidence](evidence/navigation/native-delayed-link-result/execution.json) records commands, source hashes, failed runs and result counts.

Original [phone pending](evidence/navigation/native-delayed-link-result/phone-pending.png), [current image](evidence/navigation/native-delayed-link-result/phone-current.png) and [reopened metadata](evidence/navigation/native-delayed-link-result/phone-reopened.png) captures are inspected and retained, alongside [tablet pending](evidence/navigation/native-delayed-link-result/tablet-pending.png), [current image](evidence/navigation/native-delayed-link-result/tablet-current.png) and [reopened metadata](evidence/navigation/native-delayed-link-result/tablet-reopened.png). The tablet capture also shows the refreshed row thumbnail. The phone floating tab bar overlaps the card's lower text; whole-app polish remains open. These results qualify this controlled delayed-link journey, with broader map gates retained.
