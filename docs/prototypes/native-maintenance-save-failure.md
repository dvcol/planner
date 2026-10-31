# Maintenance native-save failure

Q155 A requires a failed maintenance save to remain unapplied, retain any surviving preparation as unverified, and inspect current live data before attempting maintenance again. This Mac checkpoint exercises that policy through the existing real-filesystem fault boundary and public Planner interfaces. Production code remains unchanged.

The isolated child arms the existing RLIMIT_FSIZE obstruction at ModelContext.willSave. A zero soft file-size limit prevents the actual SQLite save; the original limit and signal handling are restored before assertions. The parent enforces a 45-second deadline. No production test hook, new target or internal behavioral assertion is added. Native model access constructs independent input memberships only.

The waiting Tag command rejects with maintenanceRequired. The acknowledged checkpoint and all original recovery files stay unchanged. The surviving preparation declares preparedUnverified; retryMaintenanceRecovery rejects it as maintenanceNotApplied, and operationStatus reports no execution evidence for the waiting command. A read-only status request continues to require maintenance.

An independent third native membership then arrives. A fresh bootstrap creates a different maintenance identity and includes all three contributions in its canonical history, while preserving the original shared source content and timestamps. The failed preparation's bytes remain unchanged and never gain a maintenance acknowledgement. Its old retry still rejects after the new attempt succeeds. The waiting command can then execute exactly once under its original operation identity.

The final focused cohort passes 12 functions in four suites, totaling 42 invocations. It includes the existing canonical membership, maintenance-envelope and native-status regressions. No failures, skips or SQLite lifetime diagnostics occur. The boundary verification checks 805 frozen Core inputs, both actual test products, strict formatting and unchanged existing common test bodies. The added function and Darwin import are Mac-only; this does not claim an iPhone native-save fault test.

Actual child transcripts are retained for the first runtime trial, the independent-input follow-up and the final cohorts. The initial test-macro compilation failure executes no tests and is kept separately. After test-host and SQLite-handle closure checks, 84 distinct owned fixture directories from these passing runs are removed. Physical reclaimed bytes are not measured.

Preparation-write failure, process termination/interruption, prepared-maintenance inspection and native UI, strict Remove/Add observations, exact retired-alias actions and versioned command evidence remain open local work. Physical/shared/cloud qualification remains separate, with signing deferred.
