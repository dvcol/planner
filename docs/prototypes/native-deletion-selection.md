# Native deletion selection

Status: Q89 implementation is present in the working tree. Represented phone/tablet paths pass; final Mac qualification remains open. This is partial evidence, not completion of Navigation prototype or the map.

## Context and starting state

Confirmed deletion previously cleared the selected Item/List and left its detail pane empty. Q89 instead requires the first visible survivor under the current filters and sort on regular layouts, with compact layouts returning to the containing catalog. A selected List's replacement must also select its first visible child. Valid selections hidden by a filter retain A3 behavior.

## Goal and definition of ready

Use production native views and disposable local datasets. Keep each replacement's own source/appearance identity and command scope. Do not infer deletion from an ordinary failed read. The shared native Store, reviewed deletion command and current query boundaries are available; no Core command, schema, account or signing contract changes are needed for this slice.

## Required tests and definition of done

- Global Items: create an archived Zzz plus Bravo, Zulu and Delta, select descending order, cancel Delta deletion and retain it, then confirm. Regular details select Zulu; compact navigation returns to the catalog without pushing another Item. Preserve surviving identity and exclude archived Zzz.
- Lists: create Alpha before Zulu, put Willow before Birch in Zulu, explicitly sort Zulu's children by Title and the catalog descending, then delete selected Middle. Select Zulu and Birch on regular layouts. Compact layouts return to the catalog. Mac also deletes an unselected Extra in another window without changing Middle, then deletes selected Middle from that other window.
- Contextual Items: select Deleted inside List Context, then delete its source from another Mac window. Select surviving Birch inside Context, preserving its membership identity; never substitute the unrelated global Alpha outside Item.
- Preserve source epochs, literal function results and original named own-app/window captures. Run strict affected lint and compiler checks. Keep failed setup/controller attempts separate from product red-green evidence.

Final Mac runtime and delayed-refresh/dataset-transition matrices remain open. The [empty-result follow-up](native-deletion-empty-results.md) qualifies deletion of the last visible Item/List while archived records remain hidden, including their retained identities after relaunch. The [incomplete-recovery follow-up](native-deletion-incomplete-recovery.md) qualifies the retained one-shot deletion dialog, checkpoint repair and a later saved edit on iPhone/iPad using source isolated from this working-tree selection implementation. These examples do not establish every Q89 edge case or cross-device CloudKit behavior.

## Implementation and witnessed failures

Replacement requests bind the dataset namespace, context and selection generation. Fresh catalog/child reads apply them only after current query, revision and selection checks; layout is checked again after awaiting. New user selections or drafts cancel a pending replacement. A replacement child already bound to its new List survives the List-selection observer.

The first global Item test fails at missing survivor details in 64.665 seconds. The first complete List fixture fails at missing replacement context in 96.817 seconds. A strengthened two-window fixture then fails at the original window's missing `In Zulu` context in 143.119 seconds. Its explicitly captured original-window hierarchy shows List unavailable and a Planner alert while the deleting window itself has selected Zulu. This distinguishes the product gap from earlier window-query/controller failures.

Applied native source deletions now publish an in-process notice before revision-driven reads restart. Each window checks its namespace, clears only affected selections and requests a replacement in its own context. Rejected/unverified operations do not publish. The deletion form becomes one-shot after an applied result, including incomplete recovery, so replay cannot emit another deletion notice for a subsequently restored identity.

The contextual Item test fails in 113.561 seconds after the other window deletes its source. Its removed-appearance branch now requests the first visible child in that same List and supplies its own deletion explanation. Compact handling returns to List contents.

## Represented runtime results

| Platform / source epoch | Function | Result |
| --- | --- | --- |
| Phone, `phone-both-qualified` | Global Item replacement | Pass, 76.335 s |
| Phone, `phone-both-qualified` | Selected List deletion returns to catalog | Pass, 118.214 s |
| Tablet, `tablet-both-qualified` | Global Item replacement | Pass, 85.113 s |
| Tablet, `tablet-list-native-overflow` | Sorted List and child replacement | Pass, 146.442 s |
| Mac, `mac-list-original-window-green`, before the later contextual-Item correction | Sorted List/child replacement across windows | Pass, 139.585 s |
| Mac, latest contextual-Item correction | Combined three-function qualification | Not started successfully; pending |

The phone run executes two functions with zero failures/skips. The first tablet run executes two functions: Global Item passes and List setup fails at the Add-menu controller, before deletion. Its app hierarchy shows the correct List pane, but native toolbar overflow exposes the title Add without the original toolbar identifier. The corrected shared helper uses the observed Add/List actions titles inside that native overflow. The focused List rerun passes. No product selection code changes between these phone/tablet runs; their two source differences are test controllers only, and both production app executable hashes match exactly. Their controller/source epochs remain separate.

Mac's combined qualification first fails local ad hoc signing with an internal Code Signing subsystem error. The retry signs successfully but times out enabling UI automation before any function starts. Disk exhaustion is subsequently observed; removing eight obsolete task-owned DerivedData caches frees approximately 4.6 GiB while preserving current builds, packages and test results. The next Mac attempt still times out before test execution. The registry reports an on-console session but supplies no lock-state value. macOS rejects a scoped desktop XCTest service restart while System Integrity Protection is enabled; no protection or permission settings are changed. A fresh unlocked/awake availability check is pending from the user. These setup failures are not counted as test assertions or passes.

## Evidence, review and limits

[The packet](evidence/navigation/native-deletion-selection/) retains exact commands, original compressed logs, exit results and source/product hashes for every attempt. Five named original own-app/window captures from the represented rows were individually inspected. They show the compact catalog return and regular replacement selection with the correct List context. Automatic failure/desktop captures are not published.

Independent Standards and Spec source reviews report no remaining confirmed Q89 findings after the contextual correction. Final strict lint passes for all 19 affected native Swift files, including the tablet controller correction. Report Markdown lint also passes. Native compilation succeeds for both platforms; Mac test initialization remains an independent missing runtime gate.

Creation UI in these working-tree epochs still uses a provisional Capture adapter. It must not be released or credited as Q88 completion: ordinary repeated bookmarks require the pending [Q93 ordinary creation contract](../create-item-in-list-contract-review.md). Q92 saved-link maps are separate work. Signing, physical sync/account/Share, accessibility, performance and final whole-app polish remain open.
