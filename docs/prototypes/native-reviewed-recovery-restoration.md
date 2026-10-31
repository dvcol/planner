# Native reviewed recovery restoration

## Context, before and goal

Core can explicitly review and restore a selected recovery copy, but the native screen only inspects and exports it. R20 requires an explicit review before merging retained data into the current dataset.

The goal is a native Review Restore action using the immutable selected evidence and the current target dataset. The existing grouped import review provides Skip/Overwrite, exact changes, Cancel, confirmation and applied results. Recovery evidence and destination remain clear. Cancel changes nothing; confirmation preserves existing independent data and restored identities through relaunch.

## Definition of ready

R20 and the [approved native recovery contract](../portable-data-contract.md#native-import-delete-and-recovery-forms) authorize reviewed restoration. Q52 approves the fixture app using production views; native UI and public Core remain the accepted test boundaries. The existing separate local dataset fixture is ready. No new storage schema, agent administration or account selector is introduced.

## Required /tdd and definition of done

- Start at a native missing Review Restore control after selecting an actual retained copy.
- Show saved/unverified evidence and Current Planner as the destination; prepare the exact Core restore command and preview two retained additions.
- Cancel and verify the current Item/Tag identities remain, with retained sources absent.
- Review again and explicitly confirm Restore. Report success only after the existing durable apply path completes; retain actual applied details.
- Relaunch and verify restored Item/Tag IDs/names and independent current IDs/names.
- Preserve file-import behavior, export availability and failure/stale-review handling while reusing the native form. Disabled/unavailable active data must not cause implicit restoration.
- Inspect original phone/tablet captures, run affected lint and compile the Mac app/test host. Separate full-graph/mode/deletion/proposal/error/stale native fixtures, physical account/sync/Share and whole-app polish remain open until qualified.

## Execution

The tracer first reached the retained copy and failed at its missing Review Restore control. The implementation adds that native action and passes the immutable selected evidence into a typed recovery draft. The shared grouped form names the evidence and Current Planner destination, offers Skip/Overwrite and the existing exact change summary, and calls the dedicated Core restoration command. Dataset identifiers stay in collapsed Recovery details. Unverified evidence has its own explanation; its native fixture remains open.

The first implementation reached Restore Result with an applied StaticText label, but the test queried that identifier as a Button. The retained native hierarchy proves the role mismatch. Only that locator changed afterward; production source remains fixed. The initial missing-control red and locator-failure run are retained separately and excluded from final passing qualification.

The final fixture pair has two passing functions per simulator, with zero failures or skips. The new journey reviews two retained additions, cancels and verifies current Item/Tag identities and retained-source absence, then reviews again and explicitly confirms Restore. Its applied result lists the actual additions. Relaunch preserves both restored IDs/names and the independent current IDs/names. The existing export journey still selects and exports retained content while current data stays separate.

The actual delivered retained-copy exports are each 921 bytes. Both have exactly the permitted portable data root, format 2, the native-observed retained Item/Tag IDs and names, empty other data groups, and no current source identities. These semantic checks do not establish exact-byte comparison with a separately issued selection or full-graph native export fidelity.

The unchanged real-file Skip/Overwrite/relaunch function passes once per simulator against the final shared form, separately from the fixture pair. It retains the original Tag identity, shows the skipped conflict and replacement before/after values, applies the selected policy, and preserves the final name after relaunch. There are three unique passing native functions per device across two result bundles, not a single three-function batch.

All 26 original review/result/relaunch, export and real-file captures were individually reviewed. Affected strict Swift/Markdown lint and whitespace checks pass. The final Mac fixture app/test host compiles, with zero Mac runtime functions. Core, HTTP, schema and portable format are unchanged; no new Core/HTTP runs are credited. Frozen fixture/main source and product hashes remain unchanged across final qualification.

Execution evidence retains commands, initial failures, terminal results/trees, complete passing manifests, original captures, actual public outputs/provenance and source/product hashes.

## Remaining gates

This qualifies the represented saved Item/Tag merge with default Skip and cancellation, plus ordinary-file compatibility. The later [native conflict-policy qualification](native-recovery-conflicts.md) covers retained Item/Tag Skip and Overwrite while preserving independent current data. Native empty-target/full-graph, deleted-identity restoration, unverified proposal, stale-review/read/save failure, recovery-blocked/startup-unavailable and checkpoint-retry journeys remain open. The Core qualification for those supported commands is separate from native UI proof. Mac runtime, physical account ownership/cutoff/sync/Share, broader adaptive/accessibility/scale and whole-app polish retain their gates. Q83 remains unanswered.

The later [native checkpoint retry/status qualification](native-recovery-checkpoint-retry.md) covers the represented readable-store recovery block, retry and unavailable-checkpoint cases. The broader recovery-blocked interactions and unavailable-store, unverified, full-graph and physical gates above remain open.

The later [empty-local-dataset plan graph](native-empty-recovery-graph.md) qualification restores six source identities, repeated references and represented state through native review/relaunch. It does not close exact portable-graph, unverified-proposal or physical account proof.
