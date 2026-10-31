# Controlled native link outcomes

## Context and starting state

Q52 requires image, no-image and error evidence through the production preview boundary. The controlled image fixture is qualified, while native error recovery currently relies on an unreachable live endpoint. The fixture provider returns successful no-image content for every URL except its image fixture; it cannot force a failed request and successful Retry.

## Goal and expected end state

One real fixture Item owns Plain website and Recoverable website bookmarks. A successful no-image result stays useful. A deterministic first-attempt provider failure shows native Retry; Retry returns a no-image result. Owned notes, URLs, identities and global completion survive both transitions and relaunch. Provider results remain temporary.

## Definition of ready

- Q50/Q52 accept the external-I/O provider boundary, native UI seam and dedicated fixture target.
- Seed through public Core commands in its scenario-specific local-only dataset, preserving the production cache and views.
- Existing fixture reopening supports a stable dataset identifier. A fresh provider after relaunch can demonstrate that recovered metadata was not saved as owned data.

## Definition of done and required /tdd

- Execute the native red for the absent controlled failure after reaching a useful no-image card and unchanged owned records.
- Implement first-attempt failure and subsequent success only for the fixture URL.
- Qualify no-image success, visible failure, Retry recovery, unchanged owned records/completion and fresh failure after relaunch on phone and tablet.
- Inspect failure/recovered captures, run affected Swift lint and Mac fixture compilation, and retain raw summaries, commands and source hashes.
- Keep native address ambiguity/delayed results, Q58 loading, broader Mac runtime, physical sync/account/Share and whole-app polish open.

## Execution

The executed phone red passed the plain card's No image check and owned URL/notes/completion checks, then failed at the absent Preview unavailable state. The controlled failure now lives only in the fixture provider. Its first exact retry-URL request throws a connection error; later requests return the existing no-image content. Provider instance state persists through Retry and resets when the fixture app relaunches. Other fixture URL behavior and all production app/provider sources remain unchanged.

The final phone and tablet runs each pass two functions with zero failures or skips: this outcome journey and the existing controlled image regression. The outcome journey checks useful no-image content, visible failure and Retry recovery, original URLs/labels, source/link identities, notes and global Todo. Relaunch reopens the same saved dataset but receives a fresh provider failure, verifying that recovered preview results did not become owned saved data. The separate initial phone green passes this outcome function alone.

Inspected phone failure, phone recovery, tablet failure and tablet recovery show the native fallback and controls. The phone's recovered card extends behind its floating tab bar in the initial scroll position; reading its lower text requires scrolling. These captures do not qualify whole-app polish.

The Mac fixture/test host compiles with zero qualified Mac UI runtime functions. Three affected Swift files pass strict format lint, Markdown lint and whitespace checks pass, and the separate Standards and Spec reviews report no actionable findings. Machine-readable evidence retains red/initial/final summaries, commands, source hashes and limits. Address ambiguity/delayed-result fixtures and the broader map gates remain open.
