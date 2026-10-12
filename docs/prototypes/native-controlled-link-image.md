# Controlled native link image

## Context and starting state

Q52 accepts a dedicated fixture app using production views and controlled preview providers. Live Apple adapter and native link journeys already have separate evidence, but they cannot reliably force every provider outcome. The fixture app currently returns no image for every link and has no saved-link image scenario.

## Goal and expected end state

A fixture Item owns a website bookmark with its original URL and label. Its controlled provider supplies a deterministic bundled image through the production preview module. The native Item row paints a thumbnail, and selecting it paints the same image in the existing link card. Provider metadata stays temporary and does not replace owned notes, label or URL.

## Definition of ready

- Q50/Q52 approve the production external-I/O provider boundary and native UI journeys.
- The fixture app and scheme reuse production views and real local Core data.
- The existing Apple integration fixture script creates a deterministic detailed color bitmap. Reuse it without introducing a new image dependency or a live server requirement.

## Definition of done and required /tdd

- Execute a native red because the controlled image is absent.
- Seed the saved bookmark through public Core commands. Supply the image only from the fixture provider, outside ordinary Planner targets.
- Assert a row thumbnail, unchanged owned bookmark URL/label and a native card reporting an image.
- Check actual rendered pixels inside both preview frames, and inspect real native captures. Accessibility availability alone does not prove painting.
- Qualify phone and tablet separately, run strict affected lint and relevant compilation. Retain failed/setup runs separately.
- Keep no-image, failure/retry, address ambiguity and delayed-result fixture journeys, broad native Mac runtime, physical sync/account/Share and whole-app polish open.

## Execution

The executed phone red reached the seeded Item and failed because its thumbnail was absent. The fixture provider now recognizes the exact owned fixture URL and loads the existing detailed color bitmap from its own app bundle. All other URLs retain the fixture's no-image behavior; the ordinary app's Apple provider is unchanged.

The final controlled journey passes one function on each simulator, with zero failures or skips. It verifies painted pixels in both the row thumbnail and native card, plus the unchanged bookmark URL, label and notes. The [phone card](evidence/navigation/native-controlled-link-image/phone-owned-link-card.png) and [tablet row/card](evidence/navigation/native-controlled-link-image/tablet-owned-link-card.png) are inspected app captures. This qualifies rendering, rather than merely an “Image available” accessibility value. The phone's floating tab bar covers the card's lower text in this initial scroll position; whole-app layout polish remains open.

Review found duplicated screenshot sampling in the new and existing journeys. The review-stage extraction uses their already shared native test helpers, preserving the old journey's geometry and twenty-second wait and the fixture's full-visibility guard and ten-second wait. Standards and Spec rechecks found no remaining defects. The final Mac fixture/test host compiles with zero qualified Mac UI functions.

[Machine-readable evidence](evidence/navigation/native-controlled-link-image/execution.json) retains raw red/final summaries, source hashes and commands. Pre-extraction passes remain separate. The affected Apple-service rich/plain website journey also passes one function per simulator with zero failures or skips, retaining live List appearances, removal and relaunch behavior. Its local HTML server and evidence remain separate from the controlled provider. This slice does not close the other Q52 cases or the broader map gates.
