# Native delayed address result

## Context and starting state

Q52 requires a slow provider response arriving after the owned address changes. [Controlled address recovery](native-controlled-address-retry.md) qualifies failure, Retry and a sole match, while the provider boundary separately checks stale keys. The native fixture cannot currently hold an address response across a real saved edit.

## Goal and expected end state

A fixture Item starts with a textual address and no saved coordinates. Its first request remains pending and shows Finding address. The human edits the address through the normal native form and saves. The new-address request releases the older response only after that saved edit, then supplies the current candidate. The current named MapKit pin remains displayed; the outdated candidate cannot replace it or rewrite owned text. The editor confirms that only the explicit address edit was saved, without coordinates. Relaunch preserves the source identity, current address, notes and Todo, while loading fresh temporary provider metadata.

## Definition of ready

- Q50/Q52 approve controlled native provider I/O and production cache/views.
- The dedicated fixture app seeds real local-only Core data through public commands and can reopen the same dataset.
- Use a pending checked continuation at the fixture provider boundary. The new request releases it; no timer-based delay or production test hook is required.
- Current entrance is returned only when that request actually released the pending response. A fresh process returns Reopened entrance, distinguishing temporary metadata from persisted owned data.

## Definition of done and required /tdd

- Execute the missing-pending-state red after reaching and checking owned source data.
- Hold the exact fixture address and release its deterministic outdated candidate from the new-address lookup.
- Qualify native loading, real Save, named current pin, absence of outdated pin/old text, unchanged editor without saved coordinates, and fresh metadata after relaunch.
- Qualify phone/tablet separately, inspect pending/current/editor captures, run affected strict lint and Mac fixture compilation, and retain commands, source hashes and failed/setup runs.
- Keep delayed link callbacks, Q58 loading, broad Mac runtime, physical sync/account/Share and whole-app polish open.

## Execution

The executed red reached the saved source and passed the owned-data checks, then failed at the absent Finding address state. The fixture now holds that exact address in a checked continuation. The new-address lookup resumes the pending outdated result before returning Current entrance. That name is emitted only from the actual release path; without a pending request, a fresh process emits Reopened entrance. The passing initial marker assertion therefore proves that the old request was released after the native saved edit, rather than merely testing a fast replacement lookup.

Phone and tablet each pass one function with zero failures or skips. The journey checks native loading, stages and saves the new address through the production form, verifies the current named marker and absence of the outdated marker, checks the owned editor with no saved pin/disabled Save, and reopens the same dataset. Current address, notes, global Todo and source identity survive while fresh provider metadata replaces the temporary cache. Production view, Core storage and preview-cache code are unchanged; the fixture adds no timers or production hook.

Standards and Spec reviews find no actionable defects and confirm the ordering proof. The Mac fixture/test host compiles with zero qualified Mac UI runtime functions. Three affected Swift files pass strict format lint; Markdown lint and whitespace checks pass. [Machine-readable evidence](evidence/navigation/native-delayed-address-result/execution.json) retains raw red/phone/tablet results, commands, source hashes and limits.

Original [phone pending state](evidence/navigation/native-delayed-address-result/phone-pending.png), [current pin](evidence/navigation/native-delayed-address-result/phone-current.png) and [owned editor](evidence/navigation/native-delayed-address-result/phone-editor.png), plus [tablet pending state](evidence/navigation/native-delayed-address-result/tablet-pending.png), [current pin](evidence/navigation/native-delayed-address-result/tablet-current.png) and [editor](evidence/navigation/native-delayed-address-result/tablet-editor.png), are retained. Delayed link callbacks and the broader map gates remain open.
