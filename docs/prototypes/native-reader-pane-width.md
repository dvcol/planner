# Native reader sidebar width changes

The existing native history journey now opens a linked page, rotates iPad to
landscape and toggles the system sidebar twice. The actual webpage width changes
from 839 to 559 points, then returns to 839. Its linked Garden page remains
visible, Return stays reachable, and native Back, Forward and Reload still work.
Returning to the Item preserves the exact saved bookmark identity and original
URL.

Two executions pass: dark iPad with the new width checks, and the ordinary light
phone history/return regression. All 1160 native inputs match Mac app,
Share-extension and UI-test compilation. Production code, provider fixtures and
Core are unchanged. No new test function, target or injected control is added.
Simulator settings restoration is verified; the iPad test restores portrait
orientation during teardown. Affected strict
Swift and Markdown lint pass.

The structured results
retain actual executed identifiers. Three inspected originals show both iPad
widths and the phone reader; their hashes and dimensions are in the
inspection record.
The raw native width attachment is retained in the
execution archive.

The narrow iPad capture also shows the sidebar's Planner title truncated to
"Pl…" beside its controls. That is a remaining toolbar-polish finding, not a
reader-width failure or a whole-window visual pass. The phone's compact webpage
title also truncates beside its history controls; the page heading is readable.

The subsequent [sidebar-title correction](native-sidebar-title.md) closes the
represented iPad app-title crowding with a native toolbar modifier and reruns
this reader journey. The observations above retain their original source epoch.

This loaded-page transition does not qualify hidden-detail/compact remounts,
multitasking windows, arbitrary websites, full accessibility or actual Mac
resizing/keyboard behavior. Physical and signed/shared-store gates remain open.
Signing stays deferred; advanced portability remains post-MVP.

## Mac width checks prepared, 28 October 2026

The existing history journey now also resizes the Mac window to 860 and 1200
points while its linked Garden page is open. It checks actual webpage width,
window bounds and reachable Return/Back/Forward/Reload controls before exercising
history, reload and exact bookmark return. The existing List-header resize
interaction moves to the shared native-element helpers, serving the reader,
header and rich-draft journeys.

The signed Mac build and Simulator build pass with 1,169 matching inputs each.
All six production Mac executable paths remain unchanged. Only three UI-test
files change. Affected strict Swift formatting passes. The
build checkpoint
retains both compiler outcomes and source overlays.

Runtime qualification is pending the user's manual UI Automation readiness.
The prepared batch includes the existing header regression, reader history/width
checks and pending-load Return journey. Compilation supplies no resizing or
page-retention credit. Signing is available; authentication remains required.
Other lifecycle, installed Share, physical and synchronization gates remain open.

## Mac runtime qualification, 28 October 2026

With the user ready for manual automation approval, the reader history/resize
journey passes in 54.291 seconds and pending-load Return passes in 37.605
seconds. The webpage grows from 359 to 699 points when the native window grows
from 860 to 1200 points. The linked Garden page survives both widths, Back,
Forward and Reload, and Return preserves the exact saved bookmark. Closing a
pending request leaves the Item intact; releasing that response does not reopen
it, and reopening the guide starts fresh history.

The original width assertion incorrectly required every browser action to be
directly visible. A retained diagnostic shows macOS moving Forward and Reload
into native toolbar overflow at the narrow width. The corrected journey opens
that menu, checks the disabled Forward and enabled Reload actions, then verifies
the ordinary history/reload workflow at the wide width. No production reader
change is needed. Width restoration uses local `defer`; a live sample of the
first interrupted failure had shown XCTest waiting in asynchronous teardown.

All 1,169 native inputs are recorded. The exact two test-source overlays are
retained against `bcd90f64`; product hashes remain stable within the represented
runtime. Main, embedded Share and runner signatures pass, and automation still
requires user authentication before and after execution. Four original reader
captures are inspected and three retained. The owned-window overflow capture
clips the part of the native menu outside that window; menu access and state
are established by the actual native assertions.

The verified execution record
keeps the initial interrupted failure and diagnostic separate. Its four-test
cohort has three passes and one itinerary failure; it is not an all-green batch.
The reader passes do not qualify that itinerary failure or whole-app, installed
Share, CloudKit, accessibility or third-party website acceptance. Itinerary
selection receives its [own correction and targeted pass](native-mac-itinerary-selection.md).
