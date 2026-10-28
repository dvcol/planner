# Itinerary Map routes

## Requested behavior

The Map should use spare window width rather than growing an empty Item detail
pane. A three-place itinerary must keep every location reachable and connect
adjacent visible stops in saved order. The user requests Walking, Driving and
Public transport choices.

## Implementation in progress, 28 October 2026

Map-mode detail columns request a 280–420-point width, with 360 points preferred.
The collection column can grow beyond its former 800-point maximum. List-mode
widths remain as before. These preferences do not yet solve the width request:
the final portrait iPad still gives the Map about 340 points and details about
479 points. Actual Mac resizing is also unqualified for this change.

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
