# Build12 late-save recovery scan diagnosis — 3 November2026

The installed build12 save sample identifies repeated historical recovery header parsing, not itinerary materialization, as the dominant captured work. No source/app/store changes were made.

Primary evidence: [raw sample](/private/tmp/tokyo-library-import/build12-late-save-profile.txt), [matching symbolicated sample](/private/tmp/tokyo-library-import/build12-late-save-profile.symbolicated.txt). The dSYM came from `/private/tmp/Plan2DoUpdate12-Mac-PersistentAgentPerformance-Final.xcarchive`, matching PID17189/build12/load address0x104188000.

| Disjoint frame | Samples / save-worker1091 | Share |
| --- | ---: | ---: |
| Checkpoint header JSON decode, PlannerRecovery.swift:774 |786|72.0%|
| Proposal header JSON decode, PlannerRecovery.swift:799 |131|12.0%|
| Checkpoint Data reads, PlannerRecovery.swift:773 |83|7.6%|
| Proposal Data reads, PlannerRecovery.swift:798 |8|0.7%|

The scanner frames under header decoding include Foundation JSONScanner.scan/scanValue/scanObject/scanString. Extracting a small Decodable header does not avoid scanning the larger document. The sample's5.3GB footprint is an observation, not proof of a leak.

An edit calls `latest()` directly, calls `proposals()` which calls `latest()` again, reloads `latest()` after possible canonical maintenance, then calls `proposals()` in the edit implementation. [Admission/source flow](/Users/dinh-van.colomban/Workspace/private/planner/Packages/PlannerCore/Sources/PlannerCore/PlannerCore.swift:1308), [edit prepared-evidence check](/Users/dinh-van.colomban/Workspace/private/planner/Packages/PlannerCore/Sources/PlannerCore/PlannerCore.swift:9887), [checkpoint scan](/Users/dinh-van.colomban/Workspace/private/planner/Packages/PlannerCore/Sources/PlannerCore/PlannerRecovery.swift:758), [proposal scan](/Users/dinh-van.colomban/Workspace/private/planner/Packages/PlannerCore/Sources/PlannerCore/PlannerRecovery.swift:791).

The measured candidate is a bounded, thread-safe, process-local cache of decoded lightweight headers only. Check a fresh device/inode/size/mtime+ctime nanosecond fingerprint on every use, following symlink targets. Always enumerate fresh, rerun existing owner/evidence/version/schema/filename validation, and fully reload/validate the selected head and unresolved proposals. Tie cache entries to stable bytes when populating; replacements must never be authorized by a mismatched cached header. No Data, head/status selection, completed-operation set, pruning, schema migration or durable sidecar belongs in this change.

A smaller lifetime variant is a per-command header-read scope shared by the archive's repeated scans. It avoids redundant work within one command but still reparses all history on every new command. Simple memoization of complete latest/proposals results is unsafe: canonical maintenance can publish a new head between reads. The process-local cache has the same required file-invalidation guarantees but can also remove repeated parsing across successive commands. Neither option makes the first cold scan or directory/stat work disappear.

Existing recovery head/proposal/status/change-stream suites should pass. New regressions must warm reads before atomic replacement, same-inode same-size/mtime-restored edits, symlink retargeting, cross-instance appends and payload-only corruption; selected heads and unresolved proposals must retain full validation. A synthetic cold/warm public-call benchmark and a later installed-command measurement are still required before claiming latency savings.

Full evidence, exact lines, alternatives, invariants and test plan: [diagnosis JSON](/private/tmp/tokyo-library-import/build12-late-save-diagnosis.json). No itinerary hot-path claim is supported by this capture; that work may occur outside the sampled interval.



## Build 13 follow-up implementation and validation

The local candidate now implements a bounded, typed process-local header cache. Each lookup opens and fingerprints the current file with device/inode/size plus nanosecond modification and change times, and verifies the current path. Header owner/filename/version checks run on every use; selected heads and unresolved proposals receive fresh complete validation. There is no durable cache, payload cache, pruning or schema change.

A separate installed-build sample found background PrivateSync snapshot projection repeating Item label validation. The source-restoration projection now owns one fresh label scope and fixed retirement sets for its synchronous Item batch.

Validation passed: 47 tests across eight recovery/status/maintenance/change suites; 61 tests across seven shared-label/restoration suites; strict Swift formatting and diff checks; Mac and iOS Release archives/exports and signature/identity checks. Test groups may overlap. The same 151-checkpoint public-status fixture measured a repeated read at 21.855ms with reuse disabled and 8.386ms with reuse enabled (2.606×). This is synthetic evidence, not a measured installed-app save improvement.

Both 1.0.0 (13) packages are local and await upload/Personal-group approval. Production iCloud container and App Group match the existing app. Cold startup still scans history; live updated-app timing and physical CloudKit roundtrip await installation. Machine-readable evidence is retained in the task artifact directory as build13-performance-validation.json, header-cache-benchmark.json and build13-source-manifest.json.
