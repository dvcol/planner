# Local Planner test storage cleanup

On 21 October 2026, temporary test results filled the local disk during native UI qualification. The user requested cleanup after another chat identified this session's footprint. The cleanup removes completed, agent-created raw xcresult bundles while retaining reviewable evidence.

Thirty-seven completed bundles were removed, with 8,324,321,280 bytes of nominal allocated storage, or 7.75 GiB. The final cleanup measured 56.78 GiB free. APFS free-space changes also reflect concurrent work and shared allocation.

- [Initial five bundles](evidence/navigation/native-itinerary-window-compatibility/native-local-result-reclamation/reclamation.json) retained committed summaries/logs and hash-verified attachments.
- [Next five bundles](evidence/navigation/native-itinerary-window-compatibility/native-completed-result-cleanup/reclamation.json) verified every selected attachment, command, outcome, log and summary against its committed Git blob.
- [Remaining 27 bundles](evidence/navigation/native-itinerary-window-compatibility/native-completed-result-cleanup-extended/reclamation.json) performed the same retained-file verification and exported each actual structured result summary before removal. An open-file check excluded in-use results.

Each deletion was restricted to a nonsymlink Planner xcresult directory directly under `/private/tmp`, matching its recorded completed command. Failed invocations retain their failure status. Current compiler products, active results, Simulator data, source, Git history and user datasets were retained. The audit directories contain the exact recipes and per-bundle records.

Old command records still name their original temporary result paths; those raw bundles are no longer available. The repository's retained captures, logs and reports remain available. Future qualification should retain the required evidence before reclaiming its completed temporary results.
