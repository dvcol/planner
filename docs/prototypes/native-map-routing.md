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
native inputs. The [final journeys](evidence/native-map-collection/multi-place-routes-final-2026-10-28/result.json)
pass on a light iPhone in 211.034 seconds and a dark portrait iPad in 139.073
seconds. Both create Hotel → Museum → Garden → Hotel through ordinary native
creation controls: four appearances at three distinct coordinates. They verify
three actual walking results and three actual driving results, the transit
explanation/fallback, exact original Museum bookmark and all three hittable pins.
Both original walking captures are inspected and show native street/path geometry:
[phone](evidence/native-map-collection/multi-place-routes-final-2026-10-28/phone-light-walking.png)
and [tablet](evidence/native-map-collection/multi-place-routes-final-2026-10-28/tablet-dark-walking.png).
Simulator appearances are restored afterward. Mac width/growth, physical routing,
maximum accessibility text, positive transit ETA and controlled directions-provider
failure/cancellation remain unqualified.

The existing direct controller-test target is Mac-only. Its earlier Simulator
attempt began building Mac dependencies and was stopped without test execution.
After the observed Mac restart, a fresh signed Mac build succeeds in 362.665
seconds against 1,172 matched native inputs. The current
[real-storage controller case](evidence/native-map-collection/route-controller-2026-10-28/result.json)
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

The [final dark-tablet journey](evidence/native-map-collection/map-pane-width-2026-10-28/result.json)
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

The [final scoped evidence](evidence/native-map-collection/adaptive-route-controls-2026-10-28/result.json)
records one passing iPad test, zero failures and zero skips, in 176.906 seconds.
It checks Walking, Driving and Public transport in both orientations at the
largest accessibility text size with dark appearance and Increase Contrast.
Every control stays inside the Map pane, meets the 44-point target, and remains
hittable without overlapping its neighbors. The counted pin stays completely
inside the visible Map. Route details retain Same location and the full transit
guidance, then return to the exact selected Item's notes. All six original
captures and their actual selected-mode labels are inspected. The retained
[landscape](evidence/native-map-collection/adaptive-route-controls-2026-10-28/final-transit-landscape.png)
and [portrait](evidence/native-map-collection/adaptive-route-controls-2026-10-28/final-transit-portrait.png)
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

The [matching checkpoint](evidence/native-map-collection/mac-pane-lifecycle-2026-10-29/result.json)
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
[selected-pane capture](evidence/native-map-collection/mac-pane-lifecycle-2026-10-29/mac-selected-1200.png)
records it. Passing containment and width checks do not close that visual issue.
The [phone capture](evidence/native-map-collection/mac-pane-lifecycle-2026-10-29/phone-maximum-pins.png)
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

The [matching final evidence](evidence/native-map-collection/camera-resize-2026-10-29/result.json)
passes one Mac case in 155.551 seconds and one maximum-text, dark, increased-
contrast phone case in 193.538 seconds, with zero failures or skips. Mac's
1200/1600-point checks now require each distinct marker to remain readable
without intersecting another marker, as well as contained and hittable beside
bounded details. Both original captures are inspected: the
[1200-point view](evidence/native-map-collection/camera-resize-2026-10-29/mac-neighborhood-1200.png)
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
[before](evidence/native-map-collection/viewport-follow-up-2026-10-29/mac-before-860.png)
and [after](evidence/native-map-collection/viewport-follow-up-2026-10-29/mac-after-860.png)
captures are retained.

At maximum text size, the phone's landscape search drawer leaves the Map with
zero height. Toolbar placement alone does not fix it. Map mode now uses Apple's
[minimized Search behavior](https://developer.apple.com/documentation/swiftui/searchtoolbarbehavior/minimize)
in Items, Inbox, Lists and Itineraries; ordinary List-mode search keeps its
presentation. The existing phone journey additionally requires the pin's whole
frame to fit inside the Map. Its [final landscape capture](evidence/native-map-collection/viewport-follow-up-2026-10-29/phone-maximum-landscape.png)
has a 74-point Map containing the 57.67-point pin. Search entry itself is not
newly qualified by this layout check.

The [execution record](evidence/native-map-collection/viewport-follow-up-2026-10-29/result.json)
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
