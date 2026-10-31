# Core Item authoring and Capture navigation

Saving a global Capture now opens the selected Item's details on compact
layouts. Previously it saved correctly and selected the source internally, but
left the compact split view on its catalog. The existing Google Maps journey
reproduced that failure before the correction. One navigation-state assignment
fixes it; capture review, provider data and persistence are unchanged.

The existing rich New Item journey also exposed a test-driver error on the clean
committed base: its swipe began inside the keyboard instead of the Form. The
private native test helper now calculates its drag within the visible area
above the actual keyboard. No production hook, input or test boundary is added.

Four final native executions across two existing functions pass on light phone
and dark iPad. The represented checks cover:

- New Item from a List uses its native detail/page editor. Cancel and Discard
  create nothing. Save retains the address, notes and two separately identified
  bookmarks with the same URL, creates the original List's local Todo appearance
  and keeps one shared Item source through relaunch.
- Google coordinate-search Capture opens saved details and a temporary native
  map. The exact original URL, including its fragment, and the bookmark identity
  survive relaunch. The card labels the search as unverified; it does not claim
  to resolve a business or save provider coordinates.

All 1160 final native inputs match the workspace and the affected Mac app, Share
extension and UI-test compilation. Ten final original captures are inspected.
Owned-address and Google coordinate-search cards both render native Apple maps.
The example.com bookmarks retain useful links and Retry when their image
preview is unavailable. Strict affected Swift and Markdown lint pass.

Verification
and compacted execution records retain both failed diagnoses and the final
runs. The earlier rich-authoring pass predates the Capture fix and is recorded
as intermediate evidence. The four final-source runs supply the completion
claim above.

Actual Mac interaction remains a separate gate. Full accessibility, physical Share/sync
and final human layout acceptance remain open. Advanced export/import and
restoration stay post-MVP; this slice adds no recovery machinery.
