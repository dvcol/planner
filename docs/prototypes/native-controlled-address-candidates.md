# Controlled native address candidates

## Context and starting state

Q52 requires a dedicated fixture app with controlled native address outcomes. The production view already distinguishes empty results, a sole result and multiple candidates, but the fixture provider returns no candidates for every address. The live Apple Park journey cannot reliably force an empty or ambiguous result. The [controlled link image](native-controlled-link-image.md) and [link outcomes](native-controlled-link-outcomes.md) slices retain their separate native qualification.

## Goal and expected end state

Two fixture Items own textual locations without saved coordinates. Unmatched place shows No matching places and a useful Retry while preserving its owned location. Ambiguous place offers two native choices without automatically selecting either. Choosing a candidate displays its MapKit pin; clearing the choice removes that preview. The Item's owned name, address, notes, completion and identity remain unchanged. The native editor retains those original values and has no saved pin; relaunch resets the temporary candidate selection.

## Definition of ready

- Q50/Q52 accept the real preview-provider I/O boundary and production native UI seam.
- The fixture target seeds scenario-specific local-only data through public Core commands and can reopen the same dataset.
- Candidate identities, names, addresses and coordinates are deterministic fixture data. Native maps still use Apple's MapKit component.

## Definition of done and required /tdd

- Execute an absent-ambiguous-picker red with the original empty provider.
- Qualify an empty result, repeated Retry and relaunch without changing owned data or inventing a pin.
- Qualify multiple matches with no default selection, both explicit candidates, clearing selection, the owned-data editor and relaunch reset.
- Inspect real native map/empty/editor captures. Verify phone/tablet separately, affected strict lint and Mac fixture compilation; preserve failed/setup results and source hashes.
- Keep sole/error/delayed controlled address cases, Q58 loading, broad Mac runtime, physical sync/account/Share and whole-app polish open.

## Execution

The executed red passed the empty-address journey and failed at the missing ambiguous picker. The fixture provider now supplies two deterministic candidates only for its exact ambiguous address; other addresses retain the existing empty-result behavior. Production views, Core storage and preview-cache sources are unchanged.

Initial phone and tablet bundles each pass two functions, with zero failures or skips. The ambiguous journey verifies no default selection, both named pins within the native map accessibility subtree, clearing selection, original owned editor fields with no saved pin and disabled Save, and selection reset after reopening the same dataset. The empty journey retains its address, notes, global Todo and source identity through Retry/relaunch.

Spec review found that the empty test tapped Retry once despite the required repeated-Retry coverage. The review correction taps twice, checking the empty result, absent map and enabled Retry after each. That revised function passes separately on both simulators, one function each with zero failures or skips. The ambiguous journey and all private helpers are byte-identical to their passing initial runs; all fixture and production source hashes are unchanged. These rechecks are not represented as a full-suite rerun. Standards review found no actionable issues, and Spec recheck closes the Retry coverage gap.

Inspected phone North pin, phone owned editor and phone empty state, plus the tablet South pin, tablet editor and tablet empty state, show the actual native controls. Four original captures per simulator are retained. The editor captures preserve the source text and have no saved-pin controls; candidate metadata remains temporary.

The final Mac fixture/test host compiles with zero qualified Mac UI runtime functions. Three affected Swift files pass strict format lint; Markdown lint and whitespace checks pass. Machine-readable evidence records separate red/initial/repeated-Retry results, both source epochs and commands. Controlled sole/error/delayed address cases and the broader map gates remain open.
