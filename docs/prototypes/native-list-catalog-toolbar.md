# Native Lists catalog toolbar

The Lists catalog crowded its native navigation title on compact layouts.
At the largest accessibility text size, the original phone toolbar failed
Apple's text-clipping audit.

On compact iPhone and narrow iPad sidebars, the existing native More menu now
groups Manage labels, Settings and Sort. Add and the archive filter remain
directly available. Wider layouts retain direct secondary controls. The shared
catalog archive control uses an icon with its full current state as the
accessibility label and checked menu choices. Mac retains its existing action
placement and Settings shortcut.

No Core, storage, recovery, schema, command, package or target changes are added.
Existing UI callers use shared native navigation helpers to reach the grouped
actions. Export/import callers only receive that navigation adjustment; their
post-MVP features and qualification are not expanded.

## Local qualification

The final phone and iPad journeys pass at the largest accessibility text size
in dark mode with Increase Contrast. They exercise the actual native controls
for Settings, labels, sorting, archive selection and List creation. The same
saved List identity and descending sort survive relaunch. Archive returns to
its existing per-run Active setting; no new persistence policy is introduced.

The existing Settings/labels regression also passes through the shared native
navigation helper. Cancellation creates no Tag; Settings and the toolbar edit
the same Tag identity, with its renamed value preserved after relaunch.

The existing catalog-sort regression passes through both catalogs, relaunch,
a separate dataset's alphabetical defaults and return to the original choices.
Its fixture-only driver corrections have their own executed source epoch and
Mac compilation. Production and shared navigation inputs remain unchanged
across the four passing UI executions.

The phone passes the text-clipping audit. The iPad journey checks primary
control bounds and actual interactions. A separate retained iPad audit still
flags the native Planner title even when the narrow sidebar omits its visible
title. That finding remains open; no iPad whole-window audit success is claimed.
Large-text sidebar word wrapping also remains visible in the captures.

The affected Mac app, Share and native UI/fixture targets compile. This provides
no credit for actual Mac interaction or signed shared storage. Strict Swift
formatting covers all affected Swift files.

The execution evidence retains failed
diagnostics separately from final qualification. Native menu scrolling must
target the menu rather than the catalog, and dismissing an iPad menu can also
hide its overlay sidebar. The corrected UI driver follows those native states.

## Remaining release gates

Finish the broader search-clipping, contrast, scene and resizing review in the
[core MVP queue](../implementation-map.md#remaining-implementation-and-acceptance).
Actual Mac UI, installed Share, physical-device performance and synchronized
storage remain separate gates. Signing stays deferred. Advanced export/import
and manual restoration remain post-MVP.
