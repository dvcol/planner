# Native dataset status read

## Context, before and goal

At `eab4840`, Core exposes per-operation evidence, independent recovery inspection and known-applied checkpoint repair. The approved native status request and observation values are absent. An editor cannot read the current checkpoint and recovery block through the declared facade. Local compilation/runtime still use only the localOnly store mode; account and store-scoped cloud event observation are not established.

The goal is the approved native `read(session:request: .status)` result, with recovery, account and cloud observations from that authorized dataset. Empty recovery has no invented checkpoint. A known committed action with missing recovery appears in incomplete operation IDs and the mutation block. Unavailable evidence is reported usefully, without false saved/uploaded/all-devices-current claims. Unsaved/in-flight editor state remains the editor's responsibility. MCP's read union excludes this native request.

## Definition of ready

- Q33 accepts the facade/native observation packet. The [adapter contract](../adapter-contract.md#native-status-and-administration) specifies the exact fields and truthful presentation.
- Tests use the approved public Core, real-store/reopen and configured external file boundaries; they do not query private models or inject status factories/events.
- Current localOnly configuration justifies unknown account/cloud observations, with null store/event/time/reason. Actual observed account/cloud events remain a separate physical/store-scoped integration requirement.

## Definition of done

- Empty, complete, known applied/incomplete and subsequently repaired recovery return the real checkpoint/incomplete IDs/block through the native status read.
- Repeated status/reopen preserves current content, timestamps, hashes, query rows, operation evidence and checkpoints.
- Missing/unreadable/malformed recovery or missing committed store yields unavailable recovery without creating a replacement store or claiming empty/saved state. Invalid dataset sessions fail before observations.
- Prepared-only proposals never become known applied/incomplete IDs from their existence alone. Other datasets remain independent.
- Account/cloud remain explicitly unobserved under localOnly. No idle/uploaded/account identity or event is guessed.
- Native app/MCP enum callers compile, and actual HTTP rejects native status input without altering saved data. Focused checks and source/execution records pass; native UI, event streams, signed account/CloudKit and manual administration remain open.

## Required /tdd

First bootstrap an empty local dataset and require known recovery with no checkpoint, no pending known commit and no block, while account/cloud are unknown. Save Hotel/Original notes through the public writer; require checkpoint 1 with no pending commit. Reopen and reread status, preserving the Item and original operation evidence. A query row generation from before status reads must stay valid.

After this tracer passes unchanged, observe a genuine post-save recovery obstruction, the known pending operation and successful repair; then verify missing/unreadable/malformed evidence, prepared-only input and foreign/separate datasets. The external file fixtures qualify local evidence, not real account changes or fabricated cloud event injection.

## Qualification

The [execution record](evidence/navigation/core-native-status-read.json) retains exact commands, source epochs, package logs and native summaries/test trees. The approved declaration's unavailable body supplies the executable red; the unchanged tracer passes after projecting actual evidence. One implementation compile failed because optional chaining selected String sequence flatMap; parenthesizing the optional checkpoint fixed it before the first green. Core production bytes remain fixed after that green.

| Qualified surface | Functions | Suites | Invocations | Failures/skips |
| --- | ---: | ---: | ---: | ---: |
| Mac Core package | 28 | 11 | 47 | 0/0 |
| iOS 27 native Core host | 28 | 11 | 47 | 0/0 |
| Mac authenticated HTTP | 13 | 2 | 16 | 0/0 |

Four new Core functions cover ten invocations. Empty storage has no invented checkpoint. A complete Hotel creation reports checkpoint 1. A genuine post-save recovery obstruction first makes recovery unreadable; after file access returns, status retains checkpoint 1 and identifies only the actual known pending operation, with the mutation block. Reopen preserves that observation. Checkpoint repair produces checkpoint 2 and clears pending IDs/block while the original query rows remain valid.

Obstructed/malformed recovery, wrong ownership, inconsistent acknowledged receipt and missing committed store return unavailable recovery. The missing-store status request does not create replacement storage. Foreign facade sessions reject before observations; a separate dataset remains empty. A declared prepared-only archive input remains unverified and never becomes a known pending commit or changes the current Hotel. These external inputs qualify local reads, not process termination/account-reset behavior or general missing-store writer admission.

The status read uses the authorized dataset's writer gate, current committed evidence and validated independent archive. It checks receipt uniqueness/ownership and acknowledged payload/result consistency. Reads insert/publish no domain data or checkpoints. Account/cloud are unknown in the current localOnly configuration, with no guessed store/event/time/reason; non-unknown account/cloud variants and event streams remain unimplemented integration work. Core status does not infer editor drafts or claim uploads.

The actual HTTP native-status request rejects at `/request/kind`, returns no account/cloud/recovery observations, and leaves Hotel and its acknowledgement unchanged. The advertised read schema contains only source, appearance and rows. Native enum callers compile and unexpected native status cannot be serialized by the MCP result handler. Seven affected Swift files pass strict lint. Mac app compilation and HTTP runtime pass; native Mac UI runtime remains zero. All 296 native qualification source/configuration hashes remain fixed. Schema 14, portable format 1 and local-only mode are unchanged.

Native UI status/unsaved/in-flight composition, event streams, signed account/cloud observation, manual restore/import/export and broader missing-store admission remain open. Interruption/process proof, lineage/convergence, physical sync/Share and whole-app polish retain their gates. Calendar/estimate choices await Q59-Q61; groups/loading await Q57/Q58.
