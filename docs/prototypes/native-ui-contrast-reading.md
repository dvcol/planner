# Native contrast and reading positions

The core UI review revisits the contrast findings retained in the
[Item-title checkpoint](native-item-title-wrapping.md). Production controls,
colors, saved content and persistence behavior are unchanged.

## Save warning

The original Item-editor journey reproduces the Save contrast warning with the
button enabled, hittable and fully inside the window. The exported issue
element is the Save button. An explicit adaptive primary foreground does not
remove the warning. The installed SDK's confirmation role also leaves it
unchanged. Both probes are reverted.

The warning remains unresolved. The captured white text on a dark control is
useful visual evidence, but does not establish every state or justify calling
the native audit incorrect. No permanent exception or palette workaround is
introduced.

## Scrollable reading positions

The earlier empty-agenda capture places its heading partly behind the floating
tab bar. The native Calendar scroll view can reveal the whole guidance above
the bar, where the unfiltered contrast audit passes.

The navigation journey now reveals Calendar guidance and landscape completion
guidance fully between the native bars before taking their reading captures.
Short held native drags avoid flinging a target past the viewport. The test
resolves the actual scroll container independently of its lazy rows; requiring
an offscreen Toggle to remain a child made the first driver attempts invalid.
No production scroll behavior is changed.

A complete unfiltered landscape diagnostic reports three other contrast
targets: the List summary under the top bar, the Notes heading near the bottom
bar and Notes text extending outside the window. It reports none on the fully
visible completion guidance. The diagnostic finishes the actual navigation,
completion round trip and relaunch with the same Item identity, notes and
unfinished completion. Its temporary handler records contrast findings instead
of failing on them, so its successful test exit is functional evidence, not a
passing landscape contrast result. The handler is removed afterward.

The permanent journey keeps the existing unfiltered landscape hit-region and
description audits, adds the unfiltered Calendar contrast check, and checks the
guidance's actual visibility. It does not claim whole-window landscape contrast
success.

## Final local checkpoint

The two permanent phone/iPad journeys pass at the largest accessibility text
size in dark mode with Increase Contrast. Native navigation, the completion
round trip and relaunch retain the exact Item identity, notes and unfinished
state. All 1160 inputs match the workspace and final Mac compilation; six
original Calendar, landscape-guidance and reopened-Item captures are inspected.
Every temporary Simulator setting is restored.

The iPad Calendar check collapses the native sidebar to exercise the accepted
wide Calendar reading state. Its separate visible-sidebar run still flags the
Lists heading. That warning remains open, alongside Save and the landscape
window findings. The permanent journeys add no audit exclusions.

The wide iPad capture also shows a compact native month grid with unused space
to its right. Arranging the month and agenda more effectively when width permits
remains UI polish; the passing reading check does not close that layout review.

## Limits

The [execution evidence](evidence/native-ui-contrast/) keeps failed probes and
diagnostics distinct from final permanent checks. Apple describes automated
audits as a starting point and still requires testing with assistive
technologies. [Apple audit guidance](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app),
[automating and investigating audits](https://developer.apple.com/videos/play/wwdc2023/10035/).

Save, clipped search fields, partially obscured labels, broader scene coverage,
actual Mac interaction and physical-device acceptance remain separate work.
Signing stays deferred. Advanced export/import and manual restoration remain
post-MVP; no Core or recovery work is added by this checkpoint.
