# Native restoration of a referenced Item

## Context and starting state

Core has real-store restoration-family coverage, and native UI has a restored originating-List draft journey. Native file tests now cover complete empty import and nonempty owner conflicts. They do not yet demonstrate explicit restoration after deleting an Item shared by two Lists, an Itinerary and a Schedule.

## Goal and expected end state

Import the existing portable graph through Files. Confirm deletion of Museum 101. Attempt ordinary Overwrite from its original backup without authorizing restoration. The app must show the actual rejection and must not claim the import applied or resurrect Museum. The archived Ramen Item remains available.

Select the backup again, choose Overwrite and explicitly enable Restore previously deleted data. Review one restored source and confirm. After relaunch, Museum has its original public identity, notes, global Todo state and Schedule 701. Membership 401 in Tokyo Food is locally Done; membership 403 in Wishlist remains Todo. Tokyo Weekend retains its independent three appearances and one archived finished appearance.

## Definition of ready

Separate restoration authorization, retained public identities, fresh internal lifetimes and independent contextual completion are accepted. Use the already approved native UI/file-import and real saved-data seams, with the unchanged committed portable fixture. No additional test boundary, production hook, target, schema or signing setup is proposed.

## Required tests and definition of done

- Drive real import, confirmed Item deletion, unauthorized Overwrite rejection and explicit reviewed restoration through native controls.
- After rejection, wait for the surviving archived Item's actual catalog row, then prove Museum is absent. A failure message alone is insufficient evidence of an unapplied mutation.
- After restoration and relaunch, check the original Item, Schedule and membership identities plus their independently specified content/completion outcomes. Full progress includes the archived appearance.
- Inspect original phone and dark iPad captures, run affected strict lint and compile the native Mac app/UI target. Preserve failed attempts and frozen inputs separately.
- Keep internal restoration-family/lifetime proof, complete delivered-file equality, other deleted source kinds, failure/recovery paths, actual Mac interaction and signed/physical tests at their own boundaries. Native visible state does not replace that evidence or close the map.

## Execution

The initial phone journey passes in 175.399 seconds. Dark iPad then reproduces a native presentation failure after the expected unauthorized-restoration error: Cancel and Settings Done are invoked, but the subsequent Items action is not hittable. That invocation fails in 114.522 seconds.

Explicit dismissal observations do not correct it; the second iPad invocation fails in 114.192 seconds. A temporary hidden-sidebar test-helper change also fails, in 116.823 seconds. Its separate whole-owner Skip/Overwrite regression passes in 170.203 seconds and its delivered files match, but the bundle remains failed. All three failed restoration attempts retain their actual results and inputs.

The original recording shows Review Backup still visible near failure, despite accessibility snapshots describing underlying pages. A retained frame at 106 seconds of the 108.59-second recording includes extraction command and source/frame hashes; the video is not published. This rules out claiming that a successful sidebar tap or an absent accessibility element alone establishes visual dismissal.

The review displays rejected-save errors from the shared store. Leaving that message set makes it eligible for the main window's alert when Settings closes. The production review now consumes that displayed message on disappearance. This does not change saved data, mutation authorization or recovery-blocking flags. The unsuccessful sidebar-helper experiment is fully reverted.

The corrected iPad journey passes in 220.402 seconds. Its 1043 inputs are identical to the second failed invocation except for the one production dismissal line; the test and original sidebar helper are byte-identical. The final phone journey also passes, in 165.474 seconds. Both require the actual rejection, a surviving archived Ramen row with Museum absent, explicit restoration, relaunch and retained Item/Schedule/membership identities with independent completion.

The twelve final restoration captures were individually inspected. They show the rejection, returned catalog, explicit review and restored content/scopes. They do not establish whole-app visual acceptance or internal restoration-family/lifetime equality. The captured phone and tablet Schedule previews retain the one-hour booking separately from the two-hour activity estimate.

## Final validation and limits

The affected dark iPad whole-owner import/export regression passes in 171.525 seconds. Both actual delivered files match every typed field and all eleven complete record collections against their independent expectations. Their Skip/Overwrite hashes remain identical to the earlier qualification. These are three final passing invocations across two functions, with zero final failures/skips. Earlier passing attempts and the three failed restoration invocations remain separate.

Mac app and native UI-target build-for-testing succeeds with the existing local ad hoc configuration. All four final epochs match the same 1043 source/configuration/fixture inputs. Strict affected Swift/Markdown lint and whitespace checks pass. The only production change is consuming the displayed review error on disappearance; existing tests/helpers, Core, persistence, schema and agent interfaces are unchanged. No new target, hook, dependency, account setup or Core/HTTP invocation is added.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `native-backup-restoration-*` inputs, commands, original results, failed probes, recording-frame provenance, exact red/green comparison and original captures. Sixteen final captures were individually inspected, including the successful-import regression. Three staged Files inputs are removed only after hash verification; Planner datasets and delivered exports remain.

This qualifies the represented native authorization, Cancel/retry navigation and restored public identities/scopes. Internal family/lifetime correctness retains the [real-store restoration evidence](core-native-import-restoration.md); no additional family matrix or restored-graph delivered-file comparison runs here. Other deleted source kinds and persistence/recovery failures through native UI, actual Mac interaction, signed CloudKit/account/Share, physical performance, pending feature choices and final whole-app polish remain open. No issue is closed.
