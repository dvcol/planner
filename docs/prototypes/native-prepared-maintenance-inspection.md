# Prepared maintenance recovery copies

Q155 A requires surviving maintenance preparations to remain inspectable without treating them as evidence that maintenance or a waiting user command ran. This slice extends the existing native recovery inspection and manual review workflow. It adds no agent administration action or signing requirement.

Recovery inspection lists unacknowledged preparations separately from saved snapshots and command proposals. Selection returns the represented portable graph with preparedMaintenanceUnverified evidence and the exact maintenance identity. Checkpoint, proposal and original-operation identities remain absent. Acknowledged maintenance is excluded from this list. Inspection can run without opening or creating native Planner storage.

The reader validates the exact preparation fields, ownership, dataset, epoch, rule, evidence and canonical filename. It validates the raw embedded portable graph before typed decoding, so undeclared fields cannot disappear silently. Invalid input rejects inspection and selection without changing recovery files or creating native storage. The tests include thirteen malformed/binding cases, plus unknown root and embedded graph fields.

The native Form presents "Unverified recovery copy", preserves that description in the existing restore review, and keeps technical identities inside Copy details. Export uses the selected portable data and includes the preparation identity in its suggested filename. Restore continues to require fresh manual review. Neither selecting a copy nor canceling its review changes Planner data.

## Qualification

The retained runtime failures demonstrate the missing summary, raw-field validation and selected-copy behavior before implementation. A mislabeled early list run still failed because its reader was not wired into the public view. The initial selection compiler failure executed no tests. Both are retained separately from the actual runtime failures and passing evidence.

The [matched Core cohorts](evidence/native-membership-consolidation/canonical-maintenance-prepared-validation.json) each pass 190 functions in 78 suites, totaling 565 invocations, with 805 identical Core inputs and no SQLite lifetime diagnostics. Both actual test products are verified per platform. The Mac app/Share/fixture builds and four real HTTP/production Intent recovery checks pass. The mobile app and Share build also passes, with six actual products. Strict Swift formatting passes for eleven changed files.

The final [phone cohort](evidence/native-membership-consolidation/canonical-maintenance-prepared-ui-phone-final/) passes three journeys, including existing reviewed restore and committed-command Retry regressions. The [dark-iPad journey](evidence/native-membership-consolidation/canonical-maintenance-prepared-ui-ipad-navigation/) passes the new recovery-copy flow. Mac adapter inputs differ from the final source only in the UI test's corrected element queries and initial-navigation assumption; production client inputs match. The frozen manifests record that test-only difference.

The phone and dark-iPad journey opens the actual native recovery control and review, cancels, then relaunches and verifies the same saved Item identity, single row and notes. Its fixture supplies a valid unacknowledged preparation through the existing fixture-input boundary. It does not fabricate native maintenance execution proof or qualify the committed-maintenance Retry button. Six original screenshots are retained; all six were visually inspected.

The first phone attempt stopped before Recovery at an incorrect Settings route; a later attempt queried a text label as a button. The first iPad attempt assumed the sidebar was initially visible. These are test-navigation/query defects, not feature failures. The corrected journey uses the existing adaptive navigation helper and actual accessibility element types.

After host and file-closure checks, 1,222 distinct marked disposable stores from the completed passing runs were removed. Failed attempts and frozen evidence remain retained. Physical reclaimed bytes are not measured.

Preparation-write failure, process interruption, committed-maintenance Retry UI, strict per-action Remove/Add observations, retired-alias actions, versioned command evidence and broader convergence remain separate local work. Actual Mac interaction, physical/shared/cloud and system Shortcuts qualification retain their existing gates. Signing stays deferred.
