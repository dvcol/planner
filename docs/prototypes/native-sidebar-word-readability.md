# Readable sidebar destination names

Native checkpoint, 29 October 2026. The existing maximum-text catalog journey
passes on current sources while its original capture still shows “Itin- / eraries”
and “Cal- / endar”. Functional navigation alone does not close that finding.

## Correction

At accessibility text sizes, the five primary sidebar destinations use native
title-only labels and smaller horizontal row insets. Full font scaling remains;
there is no text-size cap, fixed row height or custom navigation control.
Ordinary text retains the native icon-and-title labels. Saved List rows keep
their existing presentation, identities and metadata.

The shared destination view preserves all NavigationLink values, accessibility
identifiers, order and foreground styles. Core, persistence and synchronization
are unchanged. The [before](evidence/native-sidebar-word-readability/before-maximum-tablet.png)
and [final maximum-text capture](evidence/native-sidebar-word-readability/maximum-tablet.png)
show complete destination words after the correction.

## Diagnosis and test scope

Title-only labels alone let Calendar fit but still split Itineraries. That
probe's test also assumes the native button exposes a StaticText child; the
actual hierarchy shows a combined Button, and that new query fails. The failed
execution and its original capture remain separate from passing results.

The final existing journey checks every destination's complete accessible label,
hittability and row height relative to the native single-line Lists row. Those
are button bounds, not independent glyph measurements. Original screenshots
are inspected separately for complete words, spacing and retained icons.
The journey continues through Settings, labels, sort, archive modes, creation
and the same saved List identity/options after relaunch.

A zero-inset intermediate check passes, followed by an ordinary-text pass.
The final version retains a small inset and is requalified separately; those
earlier source epochs do not supply final-version credit.

## Final native results

| Native boundary | Result |
| --- | --- |
| Dark iPad, maximum accessibility text | Pass, 88.342 seconds |
| Dark iPad, ordinary text | Pass, 72.285 seconds |
| Light iPhone, maximum accessibility text | Pass, 72.074 seconds |
| Mac app and Share target | Compilation passes |

The iPad Air 11-inch M4 and iPhone 18 Pro runs all use Increase Contrast.
The five iPad destination rows are 85.5 points high at maximum text and 52 at
ordinary text, with complete accessible labels. Inspected originals show each
full word on one line and retained icons at ordinary size. The phone also passes
the function's native text-clipping audit. Toolbar, bottom tabs, sorting and
saved identity remain usable. Mac compilation adds no UI-runtime credit.

The final mobile cohort is three passes, zero failures and zero skips across
one existing test function. All three runs match the same 911 selected
source/configuration inputs and the final changed-source snapshots. Native
runtimes are iOS 27.0, built with Xcode 27.1; the simulator SDK is 27.1 and Mac
SDK is 27.0. Settings are restored to their actual initial values, and both
simulators return to their original shutdown state.

The [evidence](evidence/native-sidebar-word-readability/result.json) preserves
the baseline, failed probe, intermediate and final results, commands, source
epochs and native attachments. Six selected original captures are inspected.
Strict affected Swift lint and whitespace checks pass.

Xcode registers its temporary Mac product during compilation. Its observed path
mentions fall from three to zero after scoped unregistration; the unregister
command returns 1, so the final registry observation establishes removal.
Installed Planner's inspected files are unchanged and its registration is
restored. Build products and original result bundles remain available.

The generic iPad clipping audit, search-field warning, actual VoiceOver,
additional window/text-size states, Mac interaction and whole-app acceptance
remain open. No audit suppression is added. Private synchronization still
awaits Q164; this correction makes no cloud-storage change.
