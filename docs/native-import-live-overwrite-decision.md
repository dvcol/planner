# Older-backup Overwrite after restoration

Status: Q128 is pending. This document proposes behavior; it does not approve a policy or weaken the current gate.

## Context and starting state

An Item has public identity X and lifetime A. A manual backup contains X's title, notes, owned links and schedules. Delete closes A. An explicitly confirmed restoration creates live lifetime B under the same public X identity. You later edit B's notes or reference B from another List.

Skip of the older backup now preserves B and its complete current graph. Overwrite still rejects the older A record. The accepted contracts settle whole-owner Overwrite, deletion precedence, separately confirmed restoration and authorized candidate resolution, but do not specify deliberate replacement of B's content from its closed predecessor A. A20's stable initial candidate rule does not answer this case.

The current gate must remain until this choice and its dependent concrete contract are settled. Incoming candidate-family consolidation is a separate already-accepted implementation requirement, and known open-family external references continue independently.

## Q128 options and impact

### A, recommended: apply the older values to the current live version

The explicit Overwrite preview targets B. Keep X and B's lifetime, replace the represented whole-owner values with the incoming values, and retain unrelated current sources and their references to B. Do not revive A or redirect any obsolete reference merely because X is live.

An owned link or Schedule that is still closed does not return under ordinary Overwrite. Its restoration needs the existing separate restoration choice and identified impact, with a fresh authorized lifetime under its original public identity. Without that authorization the whole import remains unapplied. The concrete contract must enumerate represented association bindings and the before/after summaries before implementation.

This gives the manual Overwrite action a useful meaning for an older backup while protecting current references and deletion history. It adds deliberate current-version replacement rules; it is not automatic stale-data acceptance.

### B: require another explicit restored version

An older backup cannot replace B in the ordinary Overwrite path. A dedicated reviewed action would close or replace B and create a fresh authorized lifetime for X. Before implementation, another decision round must define the new family's predecessor and what happens to current references owned by other Lists or Itineraries. This makes the restored snapshot's version change explicit, but requires broader cross-owner impact and more history handling.

### C: reject this older-version Overwrite

Keep the whole import unapplied with a useful explanation when a represented source names a closed predecessor of a currently live version. Skip stays available. To replace B, use a backup containing B's current lifetime or edit its values directly. This is the smallest final policy but prevents an older backup from restoring values over an already-restored record in one operation.

## Definition of ready

- Select the intended Q128 behavior rather than infer it from the different same-family candidate rule.
- Preserve public identity, complete-owner modes, no automatic resurrection, separate closed-data restoration authorization and omitted-source preservation.
- Write the selected option's concrete literal graph and before/after result contract, including closed owned references and current references from omitted owners.
- Use the already approved public Core decode/review/execute/export/recovery/replay boundaries. A changed public result form or additional test boundary needs its own review; none is proposed here.

## Required /tdd and definition of done

For A, real Create, Backup, Delete, Restore and Edit must first expose the unsupported path. The reviewed result must target B, preserve its public identity/lifetime and current incoming references, apply precisely the represented values, retain closure metadata, and import eligible independent data. A closed owned reference must require separate restoration authorization. Stale review, cancellation and precommit failure leave the whole action unapplied. Verify full export, recovery, reopen, exact replay and repeated import, including all five source kinds and affected association/history forms before calling the complete feature done.

For B, review and approve the family and cross-owner reference contract first, then prove those literal outcomes through the same public interfaces, including late B edits and references after the replacement. For C, prove the useful whole-action rejection and unchanged complete graph while preserving Skip and valid current-lifetime Overwrite.

Every choice still requires affected import/deletion/lineage regressions, native presentation checks and platform compilation. Physical convergence, signing and final whole-app acceptance remain separate gates.

The [grilling skill](/Users/dinh-van.colomban/.agents/skills/grilling/SKILL.md) says, "The decisions are the user's: put each to them and wait." This is an unresolved behavior choice, so its dependent implementation waits for the user's answer. Known-family binding work proceeds under the already accepted A20 rule.
