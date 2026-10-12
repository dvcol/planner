# Controlled native address recovery

## Context and starting state

Q52 requires controlled native address error and sole-result evidence. [Empty and ambiguous candidates](native-controlled-address-candidates.md) are qualified, but the fixture provider cannot force an address failure followed by a single match. Live Apple geocoding cannot reliably produce that sequence on demand.

## Goal and expected end state

A real fixture Item owns a place name and address without saved coordinates. Its first lookup fails visibly with native Retry. Retry recovers one candidate and immediately displays its named MapKit pin without an ambiguity picker. The native editor retains the original text, no saved pin and disabled Save. Relaunch reopens the same Item but resets the temporary provider/cache, yielding a fresh initial failure; identity, notes, location and global completion remain unchanged.

## Definition of ready

- Q50/Q52 approve the production provider-I/O boundary and native journey seam.
- The fixture app uses production views/cache and public Core commands in its scenario-specific local-only dataset.
- Exact fixture address and candidate data are deterministic. Provider attempt state belongs only to the fixture app.

## Definition of done and required /tdd

- Execute the missing-error red after reaching the saved Item and checking owned data.
- Implement first-failure/Retry-success only for the fixture address.
- Qualify the failure, enabled Retry, sole named map pin, absence of ambiguity controls, unchanged editor/no saved coordinates and fresh failure after relaunch.
- Qualify phone/tablet separately, inspect failure/map/editor captures, run affected lint and Mac fixture compilation, and retain raw summaries/source hashes.
- Keep delayed address/link callbacks, Q58 loading, broad Mac runtime, physical sync/account/Share and whole-app polish open.

## Execution

The executed red reached the saved source and passed its owned-data checks, then failed because Address preview unavailable was absent. The fixture now fails once for its exact retry address and supplies a single deterministic candidate on Retry. Its provider instance resets on app relaunch. Other fixture outcomes retain their behavior; production views, storage and preview-cache code are unchanged.

The initial recovery function passes separately on phone and tablet, one function each with zero failures or skips. Standards review found duplicated unchanged-editor assertions shared with the ambiguous-candidate journey. The review-stage extraction places only that invariant in a private test helper; navigation, captures, Cancel and relaunch remain in each caller. Standards and Spec rechecks find no remaining defects.

Final phone and tablet runs each pass two functions with zero failures or skips: address recovery and the affected ambiguous-candidate regression. Recovery verifies the enabled native Retry, the sole named marker inside the actual map subtree, absence of ambiguity controls, unchanged owned editor fields/no saved pin/disabled Save, and a fresh failure after reopening the same dataset. Original location, notes, global Todo and source identity survive. The separate initial passes are retained, rather than substituted for final-source evidence.

The final Mac fixture/test host compiles with zero qualified Mac UI runtime functions. Three affected Swift files pass strict format lint; Markdown lint and whitespace checks pass. [Machine-readable evidence](evidence/navigation/native-controlled-address-retry/execution.json) records both source epochs, raw red/initial/final results and commands. Inspected [phone failure](evidence/navigation/native-controlled-address-retry/phone-failure.png), [recovered pin](evidence/navigation/native-controlled-address-retry/phone-recovered.png) and [owned editor](evidence/navigation/native-controlled-address-retry/phone-editor.png), plus [tablet failure](evidence/navigation/native-controlled-address-retry/tablet-failure.png), [recovered pin](evidence/navigation/native-controlled-address-retry/tablet-recovered.png) and [editor](evidence/navigation/native-controlled-address-retry/tablet-editor.png), retain the original native captures. Delayed address/link callbacks and the broader map gates remain open.
