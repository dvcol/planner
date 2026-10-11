# Prepared recovery proposal selection

## Context, before and goal

At `123e5ba`, Core lists validated prepared proposals but the approved native `inspectRecovery(request: .proposal)` request returns unavailable. A prepared proposal records intended data, not acknowledged saved data. A database commit can survive without its independent checkpoint, or both committed receipt sources can be lost while the proposal remains.

The goal is a Core-issued immutable selection for the requested retained proposal, with its namespace, recorded dataset/owner, proposal/original-operation IDs, unverified evidence and data-only bytes plus decoded backup. Selection neither mutates the active dataset nor acknowledges, retries or restores the original action. Reviewed restoration, checkpoint retry and native administration screens remain separate map work.

## Definition of ready

- Q33/Q36 accept the public Core facade, native recovery selection and real on-disk configuration. The [portable contract](../portable-data-contract.md#native-import-delete-and-recovery-forms) already declares this request/result.
- Tests observe bootstrap, execute, read, operation status and recovery inspection. Real configured recovery-file obstruction supplies the fault at the existing external I/O boundary; no private database queries or production test-only dependency are added.
- Expected content and evidence come from literal inputs and the accepted distinction between acknowledged snapshots and unverified proposals.

## Definition of done

- A retained unacknowledged proposal can be selected by its exact namespace/proposal identity after facade reopen.
- Selected evidence is preparedUnverified, checkpoint generation is absent, proposal/original-operation bindings match, and portable data contains Planner data without internal receipt/control fields.
- The accompanying decoded backup preserves the proposed content and stable identities. Existing acknowledged data and active content remain unchanged by selection.
- Unknown, inconsistent, malformed or ownership-invalid selection fails usefully. A proposal covered by acknowledged completion cannot be selected as an unverified proposal.
- Focused real-store tests, affected strict lint and native target compilation pass with recorded red/green, counts and source epochs. This slice supplies no physical account-transition, mirrored convergence or native administration UI proof.

## Required /tdd

First create Hotel with Original notes and a complete checkpoint through the public writer. At the native save I/O boundary, obstruct recovery while changing its notes to Monday booking. Restore recovery access; the operation is known applied with incomplete recovery, and its prepared proposal remains separately discoverable. Reopen the facade and select that proposal. Require its unverified evidence, exact operation/proposal/dataset/owner binding, no checkpoint, the same Hotel identity and Monday booking. The acknowledged checkpoint still contains Original notes; inspection does not change the current Hotel or its operation status.

After this tracer passes unchanged, qualify invalid/unknown/acknowledged proposals one scenario at a time, retaining unchanged current reads and acknowledged recovery. A separately configured empty dataset sharing the recovery root must remain empty after inspecting the old namespace. No selection automatically imports, retries or uploads old data.

## Qualification

The [record](evidence/navigation/core-recovery-proposal-selection.json) retains exact commands, source epochs, native result summaries/test trees and the package logs. The functional tracer failed at the explicit unavailable proposal-selection response, then passed with unchanged test bytes. Production remains fixed after that first green; later admission tests extend the same public/file boundary.

| Qualified surface | Functions | Suites | Invocations | Failures/skips |
| --- | ---: | ---: | ---: | ---: |
| Mac Core package | 19 | 7 | 29 | 0/0 |
| iOS 27 native Core host | 19 | 7 | 29 | 0/0 |
| Mac authenticated HTTP command routing | 12 | 1 | 14 | 0/0 |

The new suite has four functions and twelve invocations. It covers a genuine post-save recovery obstruction, facade reopen, immutable unverified selection, retained acknowledged content, separate empty-dataset inspection, and removal of the disposable committed store. Missing proposal/namespace, wrong owner/dataset/evidence, malformed input, duplicate proposal identity, unresolved owned-link binding and acknowledged-proposal inputs fail without changing current content or the prior checkpoint. The acknowledged case writes a coherent envelope at the configured I/O boundary; it establishes reader/filter behavior, not checkpoint-retry execution.

The shared archive path validates ownership, evidence and the complete supported backup graph before selection. Selection rejects multiple matches, encodes only the selected data snapshot, and leaves checkpoint/proposal bindings distinct. The existing graph validator still rejects unsupported lineage groups; this change does not establish restoration/consolidation or the complete import/export implementation.

The initial package launch could not write the sandboxed module cache. A subsequent compile caught two test setup mistakes: an undeclared identity member and equality on non-Equatable Item content. They were corrected before the functional red and are recorded separately. The first HTTP function filter discovered zero tests and supplies compilation evidence only; the established suite filter then executed all twelve command-routing functions, including three native-only administration rejection cases.

Strict Swift lint passes for the three affected files. The Mac app compiles and its authenticated HTTP tests execute; native Mac UI runtime remains zero. The 290 source/configuration hashes remain fixed throughout final qualification. Schema 14, portable format 1 and local-only mode are unchanged. No recovery administration path is added to MCP or App Intents, and no provider or presentation state enters selected portable data.

Reviewed restore/import/export, known-applied checkpoint retry, native recovery/status forms, controlled native save failures, lineage and physical account/sync/Share proof remain open. Calendar/estimate choices await Q59-Q61; groups/loading await Q57/Q58. Whole-app accessibility, responsiveness and visual polish remain required. This local recovery read is not proof of a coherent mirrored account transition.
