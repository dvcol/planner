# Local Planner test storage cleanup

On 21 October 2026, temporary test results filled the local disk during native UI qualification. The user requested cleanup after another chat identified this session's footprint. The cleanup removes completed, agent-created raw xcresult bundles while retaining reviewable evidence.

Thirty-seven completed bundles were removed, with 8,324,321,280 bytes of nominal allocated storage, or 7.75 GiB. The final cleanup measured 56.78 GiB free. APFS free-space changes also reflect concurrent work and shared allocation.

- [Initial five bundles](evidence/navigation/native-itinerary-window-compatibility/native-local-result-reclamation/reclamation.json) retained committed summaries/logs and hash-verified attachments.
- [Next five bundles](evidence/navigation/native-itinerary-window-compatibility/native-completed-result-cleanup/reclamation.json) verified every selected attachment, command, outcome, log and summary against its committed Git blob.
- [Remaining 27 bundles](evidence/navigation/native-itinerary-window-compatibility/native-completed-result-cleanup-extended/reclamation.json) performed the same retained-file verification and exported each actual structured result summary before removal. An open-file check excluded in-use results.

Each deletion was restricted to a nonsymlink Planner xcresult directory directly under `/private/tmp`, matching its recorded completed command. Failed invocations retain their failure status. Current compiler products, active results, Simulator data, source, Git history and user datasets were retained. The audit directories contain the exact recipes and per-bundle records.

Old command records still name their original temporary result paths; those raw bundles are no longer available. The repository's retained captures, logs and reports remain available. Future qualification should retain the required evidence before reclaiming its completed temporary results.

## Shared-header result follow-up

A further [32 completed raw bundles](evidence/navigation/native-itinerary-window-compatibility/native-shared-header-result-cleanup/reclamation.json) were removed after the unified List-header checkpoint, reclaiming 2,562,351,104 nominal allocated bytes, or 2.39 GiB. Before deletion, every raw structured summary matched its committed retained summary, all 125 retained original attachments matched their recorded hashes, retained evidence was unchanged from Git, and an open-file check excluded active results. Passing and failed outcomes remain recorded as executed.

Only the exact nonsymlink List-test result paths from their completed commands were eligible. Current RGB-panel qualification, build products, source roots, Simulator data and Planner user datasets were retained. The record includes the executed recipe and per-bundle checks. Superseded unpublished header diagnostics were separately relocated to local scratch storage; that relocation reclaimed no disk space.

## Calendar result follow-up

After the committed Mac Calendar read/resize-diagnosis checkpoint, [18 completed raw Calendar bundles](evidence/navigation/native-itinerary-window-compatibility/native-calendar-result-cleanup/verification.json) were removed. Their files total 2,677,880,569 nominal bytes, or 2.49 GiB. This number is the removed files' logical size; it does not promise an equal APFS free-space increase. Every actual structured result summary matched its retained original, and 152 original exported attachments matched their recorded hashes. All candidate handles were closed immediately before removal.

Only the recorded nonsymlink xcresult directories directly under private temporary storage were removed. Committed scoped evidence, private failed-probe packets and original exports remain available. Source, products, package caches, Simulator state and user datasets remain untouched. Compact diagnostic records preserve failed outcomes; no failed Calendar resize journey receives passing credit. Moving unpublished probe packets to private scratch was a separate relocation and is not counted as reclaimed storage.

## Label-file result follow-up

After the committed cross-platform label-file checkpoint, [12 completed raw result bundles](evidence/navigation/native-itinerary-window-compatibility/native-label-file-result-cleanup/verification.json) were removed. Their files total 1,170,465,230 nominal bytes, or 1.09 GiB. Every raw structured summary matched its retained original, 126 selected or excluded original attachments matched their recorded hashes, and the exact candidate directories had no open handles before removal. Passing and failed outcomes remain recorded as executed.

All 16 small test-created JSON inputs/exports remain available for local reruns and review, totaling 204,024 bytes. Their content was also hash-verified. Current source, products, package caches, Simulator state, Planner datasets, original attachment exports and private diagnostic packets remain untouched. The audit contains the exact preflight and removal recipes. Relocating unpublished iteration packets to private scratch is separate from this reclamation.
