# Itinerary Map routes

## Requested behavior

The Map should use spare window width rather than growing an empty Item detail
pane. A three-place itinerary must keep every location reachable and connect
adjacent visible stops in saved order. The user requests Walking, Driving and
Public transport choices.

## Implementation in progress, 28 October 2026

Wide Map mode now uses the main content area with optional bounded Item details.
The tablet correction and its native controls pass below. The preceding attempt
only supplied 280–420-point detail-column preferences and removed the collection's
800-point maximum; its portrait iPad still gave the Map about 340 points and
details about 479 points. Those ineffective preferences are replaced. Actual Mac
resizing remains unqualified for this change.

`SavedMapDirections` uses native `MKDirections` sequentially for adjacent stops
and draws returned walking/driving geometry with `MapPolyline`. It keeps repeated
appearance identities and unresolved-location gaps. Changing mode or leaving Map
cancels the current request and discards old geometry; generation checks reject
late results. Each leg has a ten-second cancellation deadline and a native Retry
action. Failed legs remain visible in route details. The mode and all provider
results are temporary presentation state, outside saved estimates and backups.

Apple's [transit transport type](https://developer.apple.com/documentation/mapkit/mkdirectionstransporttype/1452697-transit)
supports ETA rather than route geometry. Public transport therefore shows ETA
results and an explicit Open in Maps action for each leg. It never substitutes a
walking/driving path or a straight line for a transit route.

The final scoped Simulator build succeeds in 33.582 seconds with 1,172 matched
native inputs. The final journeys
pass on a light iPhone in 211.034 seconds and a dark portrait iPad in 139.073
seconds. Both create Hotel → Museum → Garden → Hotel through ordinary native
creation controls: four appearances at three distinct coordinates. They verify
three actual walking results and three actual driving results, the transit
explanation/fallback, exact original Museum bookmark and all three hittable pins.
Both original walking captures are inspected and show native street/path geometry:
phone
and tablet.
Simulator appearances are restored afterward. Mac width/growth, physical routing,
maximum accessibility text, positive transit ETA and controlled directions-provider
failure/cancellation remain unqualified.

The existing direct controller-test target is Mac-only. Its earlier Simulator
attempt began building Mac dependencies and was stopped without test execution.
After the observed Mac restart, a fresh signed Mac build succeeds in 362.665
seconds against 1,172 matched native inputs. The current
real-storage controller case
passes in 0.240 seconds, with the full runtime exiting zero in 6.603 seconds.
It preserves repeated appearance identities/order, avoids lookup for identical
adjacent coordinates, leaves gaps at unknown stops, clears legs on mode change
and Cancel, and leaves exported content unchanged. This case contacts no
directions provider. The request initializer now copies mode/retry from the
controller; the earlier mobile epoch predates this interface refactor.

No SQLite unlink diagnostic occurs. The app host exits, but macOS refuses the
external cleanup tool's read of its owned fixture marker. That one closed fixture
is retained; no disposal is claimed. Generated app registrations are removed
after the run, preserving the canonical installed host. No test target,
production test hook, public Core contract or storage format is added.

## Framing correction

The same initial routing build fails on the dark portrait iPad after 119.768
seconds: Museum's custom marker crosses the narrow Map pane edge and is not
hittable. Its final recording frame shows the native walking paths and all three
places; this is a viewport failure, with no passing iPad acceptance credit.
The initial failure-time hierarchy was captured before the final layout and
still showed List; the recording's later frame establishes the actual Map state.

Keeping automatic fitting active through geometry changes alone also fails.
The final correction fits the coordinate and returned-route bounds with padding,
caps marker width relative to the actual pane, and retains only a user-positioned
camera. Single-place default framing and the user-camera refresh protection
remain. The final light-phone/dark-tablet journeys above pass with every marker
inside the pane. This corrects camera framing; width dominance remains open.

Earlier driver failures and the actor-isolation compilation failure receive no
acceptance credit. The final evidence records them separately and includes the
exact source snapshot used for the successful mobile runs.

## Map width and selected details

A retained tablet regression reproduces the empty-detail problem on the routing
commit: the Map is 340 points wide in an 820-point window. The layout now uses a
two-column native split view in wide Map mode. With no selected Item, the Map
uses the main area. Selecting an exact appearance opens bounded details: an
iPad native inspector or a Mac native split pane. A native Item details toggle
hides the pane; selecting the same pin reopens its original saved context.
Phone navigation and the guarded New Item editor retain their existing layout.

The extracted collection body exactly matches the preceding implementation
apart from whitespace. List selection cleanup remains shared across both
layouts. A compiler-limit failure is corrected by splitting the lifecycle view
expression. The first width-correct run then exposes a missing inspector
toolbar; placing details in a native NavigationStack restores that control.
Neither failed attempt receives passing acceptance credit.

The final dark-tablet journey
passes in 158.429 seconds with one test, zero failures and zero skips. The Map
exceeds 60 percent of the window before selection. Selected details occupy at
most 421 points, remain beside the Map, and are narrower than it. Hiding details
increases Map width; selecting the same pin preserves its exact bookmark
identity and original URL. The journey also rechecks all three walking/driving
legs and the transit explanation/fallback. Both retained original captures are
inspected. Simulator appearance, text size, contrast and boot state are restored.

The matching Mac application/Share/UI-test build passes in 46.067 seconds. Actual
Mac route UI, split-divider behavior, physical layout and broader accessibility
acceptance remain open. Two additional dark-tablet regressions pass in 81.130
and 95.179 seconds: Items retain exact pin/unlocated-note navigation, and a
standalone List retains local completion independently of its source Item.
Both exercise portrait/landscape changes and restore the selected bookmark.
Their full command exits zero in 203.002 seconds, with settings restored.
Two light-phone regressions also pass in 70.378 and 114.369 seconds: exact
pin/unlocated-note navigation and repeated itinerary List branches independent
of the standalone List. The command exits zero in 213.514 seconds and restores
Simulator settings and boot state. All five mobile executions use the same
1,172-input snapshot; later changes to the Mac-only installed-Share test are
separate. The inactive generated Mac app is unregistered and removed after
signature/process checks, preserving the canonical installed app and avoiding
another Share entry. Actual Mac UI remains its own gate.

A final matching Mac rebuild succeeds in 10.143 seconds after the Mac-only Share
test cleanup is added. The one prepared Map resizing runtime exits 65 in 68.583
seconds: XCTest times out while enabling automation mode before any case starts.
It receives no Mac route/width acceptance credit. Keep manual automation
authentication; another unchanged runtime needs human prompt readiness rather
than a signing or code change.

## Adaptive route controls at maximum text

The dark iPad accessibility run exposes a real footer defect: stacked travel
controls leave too little visible Map for its pin. A first adaptive row passes
Walking, but extending the journey to Public transport reproduces clipping in
landscape. The final shared footer uses native ViewThatFits, keeps the travel
picker at its natural width when it fits, and uses an accessible icon-only
Routes button. The duplicate inline transit paragraph is removed; its complete
guidance remains reachable in route details.

The final scoped evidence
records one passing iPad test, zero failures and zero skips, in 176.906 seconds.
It checks Walking, Driving and Public transport in both orientations at the
largest accessibility text size with dark appearance and Increase Contrast.
Every control stays inside the Map pane, meets the 44-point target, and remains
hittable without overlapping its neighbors. The counted pin stays completely
inside the visible Map. Route details retain Same location and the full transit
guidance, then return to the exact selected Item's notes. All six original
captures and their actual selected-mode labels are inspected. The retained
landscape
and portrait
captures show the final Public transport controls. This repeated-coordinate
fixture performs no directions-provider lookup.

The matching ordinary light-phone multi-place journey passes in 148.535 seconds,
with three walking and driving legs, transit fallback and exact saved-bookmark
selection. Its runtime exits zero in 177.467 seconds. The iPad runtime exits zero
in 202.637 seconds. Both restore Simulator settings, and a separate actual
inventory read verifies their original boot states. Final fixture, app and Mac
builds pass in 14.001, 18.722 and 21.101 seconds against the same 1,170-input
snapshot. Strict affected-file formatting and diff checks pass.

The evidence retains failed candidates separately, including one setup race
while the independent writer was still preparing. Waiting for its existing
readiness controls fixes that test setup; it receives no footer acceptance
credit. Actual Mac interaction still needs its startup authentication gate
resolved. Physical routing, VoiceOver, maximum-text phone layout, positive
transit ETA and controlled directions-provider failure/cancellation remain open.
The maximum-text summary can scroll beneath the native toolbar; this footer
slice does not establish whole-screen accessibility acceptance.

## Mac pane lifecycle and stationary controls, 29 October 2026

The user's foreground run starts the native case, clearing the startup gate for
that attempt, then reproduces a real Opening Itinerary loop. Scoped temporary
logging records 624 lifecycle events: the same loaded window disappears, clears
its metadata and reloads repeatedly. Giving the Mac native split one stable
VStack collection child stops this cycle. The loader's cancellation safeguards
remain in place; the diagnostic logging is removed.

The next failures expose a moving Routes target. Its separate calculation row
changes footer height while XCTest is synthesizing the click. Sheet sizing and
fresh-presentation-identity probes do not correct it and are removed. Progress
now overlays the existing Routes icon, preserving control geometry and supplying
an accessible Calculating routes value. On the maximum-text phone, compact Map
labels retain full accessibility names and a 44-point target; full titles still
scale in Locations. The existing driver scrolls to each native route section
before reading results and waits for each sheet dismissal.

The matching checkpoint
passes one Mac case in 152.718 seconds and one dark, maximum-text, increased-
contrast phone case in 191.076 seconds, with zero failures or skips. Both verify
all three walking/driving legs, transit fallback and the exact saved bookmark.
Mac additionally verifies 1200/1600-point resizing, bounded details and width
recovery. Phone verifies initial pin containment and native route-list scrolling.
Its settings and original boot state are verified restored. Matching Mac and
Simulator builds pass in 27.870 and 27.350 seconds against 1,170 identical inputs.
Strict affected-file formatting and diff checks pass; authentication policy and
saved-data contracts are unchanged.

Inspected captures also expose a remaining camera-framing defect: selected-detail
resizing on Mac zooms out too far and bunches nearby labels together. The
selected-pane capture
records it. Passing containment and width checks do not close that visual issue.
The phone capture
retains the represented maximum-text state. Camera fitting, physical routing and
the broader assistive review remain open.

## Camera fitting through native resizing, 29 October 2026

The newly added separated-pin check reproduces the zoom-out above. Diagnostic
events show 43 zero-height layouts among 86 geometry updates, with no
user-positioned or preserved-camera event. Fitting directly in the geometry
callback can apply the request before the native view finishes resizing.
Positive-size guards and a viewport-shaped rectangle alone do not correct the
captured outcome; those failed epochs receive no acceptance credit.

The Map now tracks both viewport dimensions, ignores invalid sizes and fits its
padded bounds to the current viewport proportions. A cancellable SwiftUI task
defers the size-triggered fit, rejecting obsolete measurements after yielding.
The existing user-camera branch remains. No fixed delay, new module, test hook
or saved-data change is introduced; temporary diagnostic logging is removed.

The matching final evidence
passes one Mac case in 155.551 seconds and one maximum-text, dark, increased-
contrast phone case in 193.538 seconds, with zero failures or skips. Mac's
1200/1600-point checks now require each distinct marker to remain readable
without intersecting another marker, as well as contained and hittable beside
bounded details. Both original captures are inspected: the
1200-point view
stays around the nearby stops instead of the wider metropolitan area.
Both platforms retain all walking/driving legs, transit fallback and the exact
bookmark. Simulator settings and boot state are verified restored.

Mac and Simulator builds pass in 18.009 and 30.439 seconds against the same
1,170 inputs. This closes the represented automatic camera-fit defect. Manual
pan/zoom persistence is not newly exercised by this fixture; physical routing
and the broader assistive review retain their separate gates.

## Single-location framing and compact Search, 29 October 2026

The Items and standalone-List Mac journeys both pass their navigation assertions,
but inspected captures expose another framing defect: a single location starts
near its pin, then zooms out to continent scale after resizing. An explicit
native camera centered on that location at a 3,000-meter distance replaces its
region request. The final 860/1200-point captures retain neighborhood framing,
the exact bookmark and independent local completion. The original
before
and after
captures are retained.

At maximum text size, the phone's landscape search drawer leaves the Map with
zero height. Toolbar placement alone does not fix it. Map mode now uses Apple's
[minimized Search behavior](https://developer.apple.com/documentation/swiftui/searchtoolbarbehavior/minimize)
in Items, Inbox, Lists and Itineraries; ordinary List-mode search keeps its
presentation. The existing phone journey additionally requires the pin's whole
frame to fit inside the Map. Its final landscape capture
has a 74-point Map containing the 57.67-point pin. Search entry itself is not
newly qualified by this layout check.

The execution record
contains four passes, zero failures and zero skips: Mac Items and List in 65.840
and 79.140 seconds, maximum-text phone List in 109.538 seconds, and maximum-text
iPad Items in 96.217 seconds. Both mobile runs use dark appearance and Increase
Contrast, restore settings and verify their original boot states. All final
portrait/landscape and narrow/wide captures are inspected. The iPad test reuses
the established detail-scroll helper before checking a bookmark below the fold;
its earlier failure had already selected the correct Item. No production test
hook or new test boundary is added.

Final Mac and Simulator builds pass against 1,170 matching inputs. The phone
execution precedes that one helper call in the separate Items test; every other
input is identical. Both tested source epochs and the exact difference are
retained. Physical Map acceptance, manual pan/zoom persistence and the broader
assistive review stay open. A separate physical readiness retry still stops
at the first Save, as recorded in the shared-storage follow-up.

## Native Map Search lifecycle, 29 October 2026

Real iPhone checks expose a minimized-Search failure beyond the preceding layout
pass: querying and clearing work, but the native Close leaves Search active.
An explicit presentation binding, centered taps, automatic placement and toolbar
content preferences do not restore it. A matching [Apple developer discussion](https://developer.apple.com/forums/thread/845737)
includes an Apple engineer reproducing a similar hang. This is supporting platform
evidence, not a substitute for Planner's actual failed checks.

Standard iPhone search closes successfully, but its expanded field leaves the
largest-text landscape Map with zero height. Moving the default item to the
bottom makes Search unavailable in the tested tab layout. Dynamically hiding or
minimizing that item does not qualify a reliable Close/toolbar return. Those
probes receive no acceptance credit.

Phone Map modes now share a native toolbar Search button and a NavigationStack/
Form sheet. The sheet edits its own query and applies it when dismissed; Clear
empties that query. Editing directly through the collection binding loses typed
text in the Items recording. Staging the value and anchoring the sheet outside
the toolbar button avoids refreshing its host during input. An active query
uses a filled Search symbol and exposes its complete value to accessibility.
iPad keeps its native searchable control; Mac and ordinary List-mode search
retain their existing presentation. No provider, Core command, saved-data format,
package, target or test hook changes.

The execution record
contains five passes, zero failures and zero skips against 1,171 matched native
inputs. Phone Items, standalone List, repeated direct stops and repeated List
branches retain query/clear/reopen behavior, exact bookmarks and independent
completion. The iPad Items case retains native Search and portrait/landscape
details. All use the largest accessibility text size, dark appearance and Increase
Contrast; settings and original boot states are verified restored. Original
Search-sheet,
landscape
and iPad
captures are inspected. The phone landscape Map again has 74 points of height
and contains its complete 57.67-point pin.

An earlier cohort fails while revealing the second nested appearance before
Map opens. The isolated final case passes in 184.778 seconds; that earlier
attempt supplies no Map acceptance, and no base-branch classification is claimed.
Final strict Swift lint passes. A syntax-only correction spells the same sheet
initializer with a named content closure after the UI runs; its exact one-block
difference and both input manifests are retained. Matching final Simulator and
signed-device builds pass in 13.083 and 12.960 seconds. The app and runner pass
strict signature verification with access to macOS signing trust services.
Physical execution still awaits the pending stopped-playback/stationary-device
readiness answer. No physical Map, manual pan/zoom or broader assistive acceptance
is claimed by this slice.

Scoped Markdown lint finds no introduced issues; the same 165 line-length
findings remain in the unmodified HEAD implementation map. Duplicate exported
attachments are removed after curation, preserving original xcresults, the
canonical installed app and pending physical-test products.

## User camera through detail-pane changes, 29 October 2026

The existing three-place iPad journey now pinches and drags the actual Map before
hiding details and reopening Museum through its pin. It proves that both gestures
move the camera, then compares horizontal placement normalized by pin spacing.
Hiding details widens the Map from 460 to 820 points. Reopening restores its
original viewport, horizontal position and zoom within the declared tolerances,
without changing the exact saved Museum bookmark. Production code is unchanged.

The execution record
records one pass in 171.633 seconds, zero failures and zero skips against 1,171
matched inputs. It also rechecks three walking and three driving results, transit
fallback and distinct-pin framing. Original
hidden-details
and reopened-details
captures are inspected. Simulator settings and the actual original boot state
are restored. Strict Swift lint and the affected build pass.

Two earlier test-driver failures receive no acceptance credit: the first queried
the Map as a button; the second expected a direct toolbar toggle after it moved
into native overflow. The final journey uses the existing pin-reopening workflow.
This qualifies horizontal pan and zoom through this iPad pane change, not scene
remounts, Mac gestures, heading, pitch or the broader assistive review.

The physical retry stops before installation: a normal device query reconnects
the paired iPad, but its current lock-state response requires a passcode. A fresh
unlock is requested. Signing is ready; no physical Map acceptance is claimed.

## Filtered appearance through List/Map switches, 29 October 2026

Two existing iPad journeys now select the second Todo appearance while the first
is locally Done, then apply the Done filter. Switching to List and back to Map
keeps that valid, filtered-out Todo detail and its exact bookmark. The List shows
one completed row; Map shows one matching location. Clearing the filter restores
the counted marker for both appearances without changing the selected status.
Both repeated direct stops and repeated List branches pass.

The execution record
records two passes in 221.631 and 235.253 seconds, zero failures and zero skips,
with 1,171 matched inputs. The affected build and strict Swift lint pass.
Simulator settings and actual original boot state are restored. Inspected
original List
and Map
captures show the retained Todo detail beside the filtered collection.

The initial pair fails when the test queries the portrait collection toolbar
after native navigation collapses it. Its failure hierarchy retains the correct
Todo detail. The final driver uses the existing Show Sidebar workflow before
querying collection controls. No production, public contract or saved-format
change is needed. This qualifies these representation switches on light iPad
Simulator at standard Large text; physical, Mac, VoiceOver and arbitrary scene
restoration retain separate gates. The physical retry still needs the requested
fresh iPad unlock.

## Physical automation startup, 29 October 2026

After the user's fresh unlock confirmation, the prepared signed iPad retry
passes its lock and strict signature checks. The runner launches, then fails its
60-second automation-mode handshake before any application test case starts.
The execution record
reports exit 65 and zero started cases. XCTest's one failed result record is the
runner-initialization error, not an executed Map assertion.

Post-run device queries report unlocked, Developer Mode enabled, a connected
tunnel and no remaining Planner test-runner process. Recorded diagnostics retain
the same timeout without establishing its deeper cause. A later diagnostic
collector warning cannot find devicectl; it occurs after the startup failure.
The pending human question asks whether a permission prompt appeared on Mac or
iPad before another attempt. Authentication policy and global Xcode selection
remain unchanged.

All 1,171 inputs match the previously committed final signed-build manifest.
Current production inputs remain identical; only the later Simulator test
extensions differ from this prepared runner. No physical Map acceptance is
claimed. No signing or iCloud setting change is made.

## Physical iPad route and pane check, 29 October 2026

The user reports the on-device automation prompt. The next signed retry starts
the actual journey and passes in 147.338 seconds: one case, zero failures and
zero skips. It creates Hotel → Museum → Garden → Hotel through native controls,
checks every distinct pin, three actual walking results, three driving results
and the public-transport explanation/external-Maps fallback.

The execution record
also qualifies Map width before selection, bounded selected details, Hide and
pin reopening with the exact original Museum bookmark. Inspected original
walking
and selected-details
captures show all three places, native street/path geometry and separate panes.

This runs on the authorized iPad with iPadOS 27.0.1 and disposable local data.
All 1,171 inputs match the committed prepared-build manifest; current production
inputs are identical. The later Simulator gesture/representation extensions are
absent from this runner and receive no physical credit. Dark appearance is
observed without changing device settings. No permanent authentication-policy
change is made. CloudKit, account transitions, sync, physical scale, VoiceOver,
positive transit ETA and full UI acceptance remain separate gates.

## Accessible route controls, 31 October 2026

At maximum text size, oversized icon-only controls and the stacked travel-mode
fallback compress the Map enough that tapping Museum opens Garden. Routes and
Locations now cap only their icon sizing. The full mode name stays at the user's
text size, using a native Menu label around the same Picker so wrapped text
contributes its actual height. The mode and Routes share one row. Camera logic,
provider requests, saved content and exact appearance identities are unchanged.

The existing three-place journey now checks usable pin centres before routes
and after returning from Public transport, then opens the original Museum
bookmark. Rounded marker frames can still overlap; this does not claim every
label rectangle is disjoint. Final dark-phone execution passes in 194.417
seconds, including three walking legs, three driving legs and transit fallback.
The global Items Map journey also passes in 162.811 seconds, preserving exact
pin, search and unlocated-Item selection at the same maximum text size.

The existing iPad fixture journey passes in 155.930 seconds with dark mode,
maximum text and Increase Contrast. It checks all three modes in portrait and
landscape, 44-point controls, route-sheet access and retained Item details.
Inspected original phone,
portrait iPad
and landscape iPad
captures keep the mode text clear of the count. An intermediate functional pass
is rejected because visual review catches its native Picker caption overlapping
that count. The review packet
separates those trials from final credit. All 254 phone inputs match the iPad's
307-input epoch and the final workspace.

Affected strict Swift lint, whitespace, simulator/Mac/signed-mobile builds and
deep/strict signature checks pass. Scoped Markdown lint retains 162 baseline
issues with no introduced diagnostics. The two task-owned simulators are deleted;
all three preserved installed-Mac hashes match. Mac runtime, physical installation,
VoiceOver and final whole-app acceptance remain separate. No additional iCloud
test or installed Mac replacement is performed.
