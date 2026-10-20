# Native backup graph conflicts

## Context and starting state

Native backup tests qualify full-graph empty import/export and Tag-only Skip/Overwrite. They do not yet establish whole-owner conflict handling for List membership completion and its history alongside shared Item content.

## Goal and expected end state

Import the existing portable graph, then review a second fixed backup. Its Museum has Incoming museum notes, its Tokyo Food List is renamed Revised Tokyo Food, and membership 401 plus its retained completion-change record are Todo. One new, unassociated Item 103 is named New backup stop. All other graph fields are unchanged.

Skip must import Item 103 while retaining Original notes, Tokyo Food, membership 401's Done state and its original completion history. Overwrite must replace the reviewed Museum and List owners with the incoming values. It must preserve identities and the independent Wishlist/Itinerary contexts. Both actual delivered exports must match the full expected graphs, retaining every field and collection. Relaunch must retain the addition and overwritten notes.

## Definition of ready

Skip and whole-owner Overwrite are approved, including preserving existing container contents under Skip. Reuse the existing native file-picker, public review, confirmed writer, delivered-file and relaunch seams. No production hook, format change, new test boundary, target or signing setup is proposed.

## Required tests and definition of done

- Drive the production app through original import, Skip and Overwrite using fixed Files inputs and explicit confirmation.
- Check one addition and two skipped owner conflicts; after Skip, review zero additions and two Overwrite replacements.
- Verify membership 401 retains its exact identity, with Done under Skip and Todo after Overwrite. Archived lunch still finishes its appearance without rewriting completion.
- Compare both actual native Save destinations with independent literal expected graphs, allowing only the documented version-1 migration. Preserve typed field values, duplicate counts, ranks and nested ordering.
- Verify represented native phone/tablet layouts, original captures, affected strict lint and Mac compilation. Retain failed attempts separately. Signing, physical synchronization, Mac UI runtime, other import failures and final whole-app polish remain separate gates.

## Execution

The first phone invocation fails in 103.924 seconds after its Skip export and List checks. The new controller tries to open Settings from a pushed List page. A second attempt switches to Items, but Settings belongs to the Lists catalog toolbar; it fails in 91.930 seconds. Both actual Skip files independently match the expected graph. Neither attempt reaches Overwrite, and both remain recorded as failures.

The final controller keeps both reviews and exports in Settings, then checks the overwritten List. It changes no shared helper or existing test body. The phone journey passes in 115.995 seconds; dark iPad passes in 171.169 seconds, with zero failures/skips in these two final invocations. This qualifies existing production behavior; the controller failures do not establish a missing production feature or functional red.

Both devices deliver identical results. Skip exports 12,995 bytes with SHA-256 `165c2c033bacedddc38288029faa5cc24682cdfe4789ccbd2db91c2c687df9b1`; Overwrite exports 13,012 bytes with SHA-256 `480c437b9738a97aca18bace8f10dbd536f13da0434461a21d5ccd6e61c08166`. Every typed field in all eleven complete record collections matches the independent expected graph. The only allowed migration is format version 1 to 2 and null manual-estimate fields on List/Itinerary content. Comparisons retain duplicate counts, saved ranks and nested ordering; only top-level table order is treated as representation.

Skip retains the original Museum notes, List name, membership 401 Done flag and completion-change value, while adding Item 103. Overwrite changes those reviewed values and preserves the independent Wishlist and expanded Itinerary completion, source identities/lifetimes, labels, bookmarks, schedules and deletion metadata. The second import retains one Item 103, with eight total sources. These scope assertions come from the actual delivered files, rather than a separate storage read or an export-success label.

Eight final original captures were individually inspected. They show two reviewed owner conflicts/replacements, the renamed List with the same appearance identity now Todo, archived lunch finishing one of two appearances, and Incoming museum notes after relaunch. The iPad returns to its original light appearance.

## Validation and limits

Affected strict Swift/Markdown lint and whitespace checks pass. A single long test call was wrapped after the passing phone run; an exact before/after comparison proves that only this line break changed. The tablet and Mac build match all 1043 final source/configuration/fixture inputs. The phone matches every other input and retains its original source plus that explicit formatting comparison. Existing test/helper text and all production inputs remain unchanged.

Mac app and native UI-target build-for-testing passes with the existing local ad hoc configuration. No Mac UI runtime, new Core/HTTP run, signing/account setup or production data-format change is claimed. The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `native-backup-conflicts-*` commands, results, source epochs, failures, actual delivered JSON and verification recipes. Four staged Files inputs are removed only after hash verification; Planner datasets and delivered exports remain.

This qualifies the represented nonempty graph's Skip/Overwrite owner conflicts and retained-association state. It does not establish arbitrary reference additions/removals, restoration families/deleted lifetimes, stale review, read/save/termination failures or incomplete recovery through native UI. Actual Mac interaction, signed CloudKit/account/Share, physical performance, pending feature choices and final whole-app polish remain open. No issue is closed.
