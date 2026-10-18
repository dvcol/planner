# Native Item creation and contextual navigation

Status: rich creation and guarded navigation have native evidence on Mac, iPhone and iPad at their recorded epochs. The current iPad continuation qualifies archived, deleted and freshly restored originating Lists, and repairs selection after saving into a restored List. Current Mac UI startup, wider platform/accessibility review and physical gates keep Q88–Q91/Q93 and the Navigation prototype open.

## Context and expected state

List creation previously opened Add existing Item from its toolbar and placed text/link capture in another menu. Full New Item used a modal with limited fields. Confirmed deletion could leave an empty detail column despite surviving visible records.

The native Add menu now offers New Item, Add existing Item and From Link or Text. New Item opens a native Form in the detail column on Mac and wide iPad, with compact navigation on iPhone. It includes title, subtitle, notes, native estimate pickers, shared labels, place name/address and authored bookmarks. Existing location/link editors are reused.

A draft holds its operation identity, fields, originating dataset and immutable List identity. List-bound Save uses the [approved ordinary creation command](../create-item-in-list-contract-review.md), creating one local Todo membership atomically and preserving repeated URLs. Capture retains its separate deduplication policy.

The draft retains the original List name-field hash. Save prepares a Core review, compares a fresh source read with that original hash, then applies the reviewed command. Rename or replacement requires explicit Use This List confirmation without losing the fields. Missing or archived destinations reject; they never turn creation into a global action. Failed validation preserves the draft. An applied result closes it even if its independent recovery copy is incomplete.

Edited drafts require Save, Discard or Keep Editing before navigation. An untouched blank draft closes directly. The draft remains the same object when columns adapt. Deletion selection follows [Q89's separate implementation and historical evidence](native-deletion-selection.md), preserving the current query, dataset, source/appearance scope and compact navigation behavior.

## Definition of ready and required runtime checks

The human approved the creation/navigation decisions and the public Core, HTTP and native UI boundaries. Core and HTTP qualification are recorded in their [Core report](core-item-in-list-creation.md) and [MCP report](mcp-item-in-list-creation.md).

Rich-content, dirty-navigation and Mac renamed-destination journeys have executable native fixtures and passing invocations. The [layout and compatibility continuation](native-layout-compatibility.md) records the later source, resizing checks and deletion crash correction. The archive/delete/restored-origin continuations below qualify represented iPad destination changes; Mac and physical acceptance remain separate gates. Required production native journeys include:

- Cancel a changed List draft without creating a source or membership. Save full content, two separately labeled identical URLs and a local Todo membership; preserve their identities after relaunch and leave another List unchanged.
- Keep Editing, reject an invalid navigation Save, then save successfully before leaving. Preserve fields and destination through column resizing/collapse.
- Rename or restore the originating List while a draft is open. Require explicit refreshed destination review and retain the authored content. Reject an unavailable destination without fallback.
- Retain Add existing and From Link or Text behavior, rich saved details/maps and the affected deletion-survivor journeys.

## Native runtime and dialog correction

The user approved restarting the stale current-user CoreSimulator service, then confirmed that the Mac was unlocked and idle. The task iPhone and iPad simulators became available, and Mac UI automation subsequently started tests. No account signing or physical-device qualification is inferred.

The [runtime packet](evidence/navigation/native-item-creation-runtime/) retains source snapshots, commands, compiler links, binary hashes, results and named Planner-only captures for each attempt. Its [run index](evidence/navigation/native-item-creation-runtime/historical-run-index.json) separates whole passing batches from individual passes inside failed batches. The [earlier packet](evidence/navigation/native-rich-creation/) retains provisional Capture-backed and compiler-only epochs; they do not replace ordinary-command runtime checks.

The rich journey starts with Origin, an empty second List and no matching Item. Discard creates neither source nor membership. Saving creates one source and one local Todo appearance in Origin, with subtitle, notes, owned address/place name and two separately labeled identical URLs. It verifies exact URL values, distinct ordered bookmark identities, the untouched second List and retained source/membership/bookmark identities after relaunch. Native Form content is lazy: the test scrolls the actual detail column to reveal links instead of treating offscreen rows as missing data. Named saved-detail captures also show the native address map and pin; live provider availability remains separate from deterministic data assertions.

The navigation journey closes an untouched draft directly, offers all three explicit choices for an edited draft, retains fields after Keep Editing, rejects a blank-title navigation Save without losing notes, then creates the source and originating List appearance before leaving after valid Save.

Runtime inspection exposed an extra default OK button on Mac. A native UI regression witnessed four buttons instead of the required three. Keep Editing now has the cancel role on Mac, replacing that default dismiss action. iOS retains its ordinary explicit button because Apple's regular-width confirmation dialog may omit a cancel-role action. See [Apple's confirmation dialog documentation](https://developer.apple.com/documentation/swiftui/view/confirmationDialog%28_%3AisPresented%3AtitleVisibility%3Aactions%3A%29). The same navigation journey asserts all three labels on every platform and exactly three buttons on Mac.

| Platform | Passing rich creation | Passing guarded navigation | Recorded runs |
| --- | --- | --- | --- |
| Mac, local ad hoc signing | 125.703 s | 61.890 s | `mac-destination-rich-and-capture-qualified`, `mac-final-creation-navigation` |
| iPhone simulator | 141.295 s | 87.210 s | `phone-current-rich-creation`, `phone-final-creation-navigation` |
| iPad simulator | 158.634 s | 113.573 s | `tablet-bookmark-visibility-qualified`, `tablet-final-creation-navigation` |

These are passing individual invocations with zero skipped functions. The Mac destination/capture batch and the first final iPad batch contain failures in other invocations and remain recorded as failed. The [source comparison](evidence/navigation/native-item-creation-runtime/runtime-source-equivalence.json) verifies that production inputs and each selected test's executed functions and helpers matched its recorded passing invocation at that qualification epoch. Changes elsewhere in a test file do not imply another runtime pass. Original source and binary hashes remain attached to every invocation.

The Mac two-window rename journey passes in 97.776 s in `mac-window-scoped-review`. It retains the original List identity and authored fields, requires refreshed destination review after another window renames the List, preserves an unsaved draft after Keep Editing, and makes Use This List update only the reviewed destination. A subsequent explicit Save creates one local Todo appearance; relaunch preserves the List/appearance identities and one source Item.

The Mac Google Maps journey passes in 30.097 s in `mac-destination-rich-and-capture-qualified`. It renders a native saved-link map labeled Search location rather than a resolved business, retains the exact original URL and fragment, and reopens the same source and bookmark after relaunch. That four-function batch also contains two controller failures and is not a wholly passing batch.

The Mac originating-List capture journey passes in 56.868 s in `mac-list-window-evidence-qualified`. It changes a selected destination and cancels without creating an Item, reopens capture with the originating List selected again, then saves one source and contextual appearance. The appearance remains local Todo, retains its original URL/bookmark identity after relaunch, and opens contextual rather than global actions. Its test uses the actual native switch row and scroll wheel. The earlier 57.251 s pass remains recorded, but its desktop-wide screenshot is excluded; the final run captures only the Planner window.

## Failed attempts and limits

- Initial simulator attempts could not start with the stale service. The approved restart resolved that setup failure.
- The first Mac automation retry timed out before starting any function. The unlocked/idle retry subsequently passed navigation.
- Initial rich-content failures exposed test-controller issues: lazy Links below the map, an invalid Mac application-wide swipe and opening a toolbar before the reselected List finished loading. The corrected controller retains the original data assertions and adds exact URL checks.
- The standalone dialog regression first failed at the intended four-versus-three assertion. Its first fixed batch later passed rich creation and the existing navigation journey, but that standalone setup failed before finding the editor. The failed batch is retained as failed, without inventing a cause or full-batch pass. The exact-count oracle is now integrated into the existing navigation journey.
- A later iPad rich run scrolled Tickets out of the lazy hierarchy while revealing Garden guide, before checking Tickets. Smaller steps, visible-row checks and reading each exact URL immediately resolve that controller failure; the corrected rich run passes.
- The first Mac Google Maps run rendered its map, then failed its title lookup after relaunch. Inspection showed that the legacy text helper prepended the desired title to Saved link. Native Command-A replacement now asserts the exact field value before Save, and the journey follows the source identity and exact saved title across relaunch. It passes without a production change. Its old desktop-wide screenshot is excluded from committed evidence; current captures use the Planner window.
- The new two-window journey initially used an application-wide actions query, which matched both windows. Its actions query is now scoped to the editing window. Mac List-capture also needed native toolbar overflow, exact field replacement and the actual named-row Switch hierarchy. The corrected native destination-control journey subsequently passes.
- A sandboxed compiler attempt could not write normal Xcode caches. An authorized build with normal cache access succeeded. Two overlapping compiler-only attempts shared a temporary export; sequential final builds replace them for runtime qualification.

Strict lint passes all four affected Swift files. Both final app/UI-target builds succeed. Independent Standards and Spec rechecks cleared the platform-specific fix after raising and resolving the iPad cancellation-role concern. Production Core and HTTP behavior is unchanged in this slice; their focused qualification remains in the linked reports.

The [layout and compatibility continuation](native-layout-compatibility.md) supersedes the resize and represented Add/Capture/deletion runtime gaps for its recorded source and tests. The origin continuations below qualify represented iPad destination changes. Other platform equivalents, wider label/estimate and adaptive-layout acceptance, broader Mac Maps journeys, physical sync/account/Share, accessibility, performance and whole-app polish remain open. These reports do not close the overall feature or map gates.

## Archived originating List continuation

The native `testNewItemDraftRetainsFieldsAndDestinationAcrossOriginatingListArchive` passes on regular-width iPad in dark mode with Increase Contrast in `tablet-origin-draft-dismisses-sidebar-qualified`, 106.046 s. Archiving the original List preserves the unsaved title and notes. Save reports the unavailable/archived destination and creates no fallback. After unarchiving the same List identity, explicit Save creates one local Todo appearance there. Relaunch retains the appearance and notes; the Items catalog contains one source and the other List stays empty.

Two earlier invocations fail at error observation because touching Save dismisses the native sidebar overlay. The original pre-Save capture confirms the dimmed editor behind that overlay. The corrected controller dismisses it through the detail heading before Save. No production correction is credited. Original after-error and saved-detail captures were inspected for readable fields and stable destination context.

The archive/unarchive journey does not establish Mac interaction, physical synchronization or final whole-app acceptance. Deletion and fresh-lifetime restoration are qualified separately below.

## Deleted originating List continuation

`tablet-deleted-origin-all-states-qualified` passes in 88.515 s on regular-width iPad, dark mode with Increase Contrast. Confirmed List deletion preserves the title and notes of its unsaved Item draft. Save rejects the unavailable destination. Discard creates no Item, the unrestricted Items catalog remains empty after relaunch, the deleted List stays absent, and the surviving List stays empty.

The first invocation passes deletion, preserved fields and rejection, then fails an empty-state text expectation: the catalog's default Active filter reports No matching items. The corrected controller explicitly clears every filter before requiring No Items yet, so its empty-catalog proof includes all completion/archive states. Production behavior is unchanged. The fresh-lifetime native continuation below qualifies restoration separately.

The [caller/draft checkpoint index](evidence/navigation/native-itinerary-window-compatibility/origin-draft-and-caller-checkpoint-validation/observed-results.json) preserves individual passing functions, failed attempts and compiler-only epochs. Final mobile and Mac app/UI targets compile; strict lint passes both affected Swift files and both reports. Recorded production Swift inputs match checkpoint `99b17596`. That continuation changes native test observations and adds qualification; its production behavior remains unchanged.

## Restored originating List continuation

The new native journey creates a real backup through Files, opens a List-origin draft, deletes its List, then imports that backup in Overwrite mode with explicit restoration enabled. It reviews exactly one restoration and preserves the draft through the Settings/import sheets. The restored List keeps its public identity and name, but must receive fresh destination review before the draft can save.

`tablet-restored-origin-fresh-review` reaches the correct Use This List review, accepts it and saves, then fails in 123.767 s because the panes still show List deleted. The captured native hierarchy and save path establish the product defect: deletion cleared `selectedListId`, while successful List-bound Save selected the new membership without reselecting its owning List. The correction reattaches the draft's immutable List identity before loading the saved context. It does not change data creation, restoration, backup or review contracts. The corrected source shows the new appearance immediately after Save, then its first follow-up invocation stops at a hidden-sidebar locator after relaunch. Its captured hierarchy has Choose a List and Show Sidebar, with no storage failure. The controller now explicitly opens Lists before selecting the restored row. Ordinary rich Item creation passes on iPhone in 136.107 s and the affected real backup Skip/Overwrite journey passes in 91.813 s. The final `tablet-restored-origin-reviewed-relaunch-qualified` journey passes in 127.184 s on iPad with dark mode and Increase Contrast. It requires fresh review despite the unchanged List name, keeps the draft until a separate explicit Save, displays the saved local appearance immediately, then verifies the original public List/appearance identities, notes and local Todo after relaunch.

Final mobile and Mac app/UI targets compile for the selection repair. The actual Mac UI startup limitation remains; compiler success supplies no window-interaction credit. This closes the represented iPad archive, deletion and fresh-lifetime draft cases, while other platform, accessibility, physical synchronization and whole-app acceptance remain with their owning gates.

The final restored-context capture was inspected: the restored List is selected, its local Todo appearance is visible with 0-of-1 progress, and the detail pane retains the authored notes and List context. The [restored-origin evidence index](evidence/navigation/native-itinerary-window-compatibility/restored-origin-checkpoint-validation/observed-results.json) distinguishes the qualified product red, subsequent relaunch-controller failure, final passing journey and two affected passing phone regressions.
