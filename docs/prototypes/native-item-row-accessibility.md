# Readable Item rows at accessibility sizes

## Local readability checkpoint, 25 October 2026

Shared native Item rows now allow titles and estimates to wrap at accessibility text sizes. Ordinary text retains its two-line title and one-line estimate. The iPad itinerary's scrollable name is capped at one-quarter of the content height at accessibility sizes; short names still fit their natural height. No Core data, public API or recovery declaration changes.

The existing native UI boundary reproduces three distinct problems:

- A title receives 125.5 points although the native body font needs about 187 points for the complete name.
- The one-line estimate receives 51.5 points although the complete estimate needs two lines. Native Label can place subsequent lines beneath its icon, so its available row width is the correct measurement bound, rather than an individual accessibility text fragment.
- Once rows wrap, the long-name landscape layout leaves a 291-point viewport for a 294-point row. Reducing the name cap from one-third to one-quarter corrects that physical constraint.

The new journey reads actual native text bounds, requires the row to clear pinned headings and opens Activity002's exact saved notes. The existing long-name journey checks both orientations, the same appearance identity, native name scrolling and reachable controls. Its driver now searches toward the retained row after rotation and starts gestures in the unobscured route, rather than the name's separate scroll area. An accidentally changed notes assertion was restored before qualification.

| Executed boundary | Evidence and result |
| --- | --- |
| Dark iPad, largest accessibility text | [Qualified native journeys](evidence/native-membership-consolidation/native-activity-text-qualified-tablet/test-summary.json): two pass, zero fail/skip. Original row/details captures and native text bounds are retained. Rotation-entry captures precede final row positioning; the subsequent native bounds/identity assertions establish the final layout. |
| Dark iPad, ordinary text | [Native regression cohort](evidence/native-membership-consolidation/native-activity-text-qualified-normal-tablet/test-summary.json): itinerary collapse/independent completion and selected List/contrast pass. Global Item selection fails before its contrast audit; see the separate finding below. |
| Light iPhone, largest accessibility text | [Existing Item/List journeys](evidence/native-membership-consolidation/native-activity-text-qualified-accessibility-phone/test-summary.json): two pass, zero fail/skip, including actual notes and native contrast audits. |
| Mac app and Share | [Matching compiler check](evidence/native-membership-consolidation/native-activity-text-qualified-mac/execution.json) passes. This supplies no actual Mac interaction evidence. |

These are six passing native checks and one failed invocation across the three mobile cohorts, rather than a claim that every cohort passes. Simulator text settings are restored. Strict Swift formatting/lint and whitespace checks pass. The [validation record](evidence/native-membership-consolidation/native-activity-text-readability-validation.json) reconciles the checkpoint inputs and records the retained product digests.

## Separate ordinary-iPad Item-selection finding

The global Items journey twice reports a computed hit point of `{-1, -1}` for the visibly present first row and never reaches its notes. An actual native coordinate tap also fails. The [committed-source comparison](evidence/native-membership-consolidation/native-activity-text-base-item-coordinate/base-comparison.json) reproduces that outcome at b34e3e32 and restores the in-progress readability sources exactly afterward. This confirms that the readability change did not introduce the defect; it does not close the defect. Its original result, hierarchy and recording-derived frame remain retained. Correcting native Item selection is the next local slice.

Earlier red, measurement, wrong-notes and scrolling-driver failures retain their original status and result bundles. The measured landscape-space failure is separate from those driver failures. Duplicate attachment exports and plain source manifests may be removed only after retained originals and lossless compressed manifests verify; failed result bundles and stores remain untouched.

Actual VoiceOver, Mac keyboard/windows, physical devices and whole-app scene acceptance remain open. Signing stays deferred. Q161 A/Q162 A are approved separately and still need their Core implementation.
