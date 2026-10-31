# Native location inputs and keyboard dismissal

Place name and Address now use native vertical TextFields with one to three
visible lines. New Item, Edit Item, Itinerary and capture-review Forms dismiss
the software keyboard when scrolling. URLs retain standard single-line input
with the native URL content trait. Saved strings, pins, references and Core
contracts are unchanged. No custom keyboard controls or new test boundary remain.

## Local qualification

Three native UI executions pass across two existing functions:

- Largest-text light iPhone and dark iPad rich Item creation preserve the entered
  place/address, both same-URL bookmarks, original List membership and shared
  source through relaunch. Cancel still creates nothing. The phone journey also
  asserts keyboard dismissal after scrolling.
- Ordinary light iPhone Apple Maps capture, owned-address precedence and relaunch
  preserve the original bookmark and display the address map.

All 1160 native inputs match the final workspace and Mac app, Share-extension
and UI-test compilation. Strict Swift lint also passes. The existing rich journey
now scrolls to the global Notes row before asserting its exact content.

The separate phone Itinerary links function fails while waiting for offscreen
Add Link. An exact committed `aa00cc9e` baseline reproduces that failure.
Experimental scrolling then exposes native text-replacement assumptions; those
unproven test-driver edits are removed. At this checkpoint, the function is unqualified and is
not counted among the three passing executions. The complete failed results stay
in the execution archive.

The later [Itinerary follow-up](native-itinerary-link-editor.md) closes that named
phone check and adds dark-iPad coverage. It also fixes a newly exposed competing
validation-alert presenter. Earlier failed results retain their original status.

## Visual review and limits

Four qualified originals show the active/wrapped phone address, the scrolled
phone draft, the dark iPad draft and the owned-address map. Four diagnostic
originals retain the earlier clipping, unbounded growth, duplicated keyboard
controls and wrapped-URL hyphen findings. Their hashes and dimensions are in the
inspection record.

The dark iPad draft shows the full represented address across three lines. A
phone address can remain partly behind the active keyboard until scrolling.
Very long values still need native editing scrolling; URL fields may ellipsize.
The iPad helper uses Apple's Hide keyboard action where available, so this does
not claim a separate iPad drag-dismiss assertion. Unbounded fields, custom Done
controls and multiline URL experiments are removed.

The evidence archive was read back before removing 817,235,858 nominal bytes
of duplicate temporary results, logs and attachment exports. Shared build caches
and user datasets remain. Nominal sizes do not imply the same APFS free-space gain.

Actual Mac interaction, the Itinerary phone driver repair, broader accessibility,
physical Share/sync and final human layout acceptance remain open. Signing stays
deferred. Export/import and advanced restoration remain post-MVP.
