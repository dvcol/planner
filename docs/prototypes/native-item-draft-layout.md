# Native Item draft layout

The New Item page hides native tab navigation while it is presented on mobile.
Back and Save remain in its native navigation bar. Saving restores normal tab
navigation. This gives the draft its full reading area and removes the floating
tab bar over the Form. The Mac presentation is unchanged.

The existing phone Dark navigation journey passes at maximum accessibility
text with Increase Contrast (121.079 seconds). It explicitly verifies the tab
bar is hidden before editing and visible after Save, then checks destination
navigation, landscape completion and the same saved Item through relaunch.
The Light draft-guard journey passes at normal text size (79.297 seconds): an
untouched draft closes, Keep editing preserves changes, invalid Save stays open,
and explicit Save retains the Item and its original List appearance.

The evidence packet
retains commands, source hashes, results and inspected original captures.
Simulator, Mac and signed mobile builds pass; the mobile build is prepared,
without a physical-device installation. Mac runtime and physical/assistive
acceptance are not inferred from compiler checks.

The separate unfiltered editor contrast diagnostic still flags native Save.
Its detailed report is `Contrast failed for SwiftUI.AccessibilityNode`, without
a ratio or color pair. Default, prominent and opaque semantic-color probes did
not establish a fix. Every temporary palette change and extended diagnostic
audit is reverted. The permanent audit helper retains descriptions and returns
false for every reported issue, preserving normal audit failure behavior.

Fresh direct-launch and XCTest captures genuinely render Dark; the Light
captures also match their requested appearance. This provides current native
appearance evidence without claiming a proven cause for the older Simulator's
mismatch, a passing Save contrast audit or final human UI acceptance.
