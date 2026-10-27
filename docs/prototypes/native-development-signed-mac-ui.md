# Development-signed Mac UI retry

Local checkpoint, 27 October 2026. Account-transition testing remains deferred.
No iCloud setting or account is changed by this independent check.

The existing local-only Planner app, embedded Mac Share and native UI runner
build successfully in 13.585 seconds using the existing Apple Development
certificate. Manual signing requests no provisioning update or new App ID.
Strict deep verification passes for all three wrappers under `Y6HV37KJ2G`.
Their bundle IDs retain the unconfigured `org.example.PlannerMCPPrototype`
prototype family. None has CloudKit entitlements, and the app's configured App
Group remains empty. This supplies no installed App Group/Share acceptance.

The build and actual products match all 1164 current native inputs. Nine product
hashes include the actual debug libraries, embedded Share, test bundle, runner
and `.xctestrun` file. No preexisting Planner process is open before the trial.
The existing title/resizing journey selects its own disposable local dataset.

## Actual runtime outcome

`testLongListTitleSharesTopToolbarAndUsesAvailableSpace` is selected through the
existing UI boundary. No journey body starts within the bounded 120-second
setup window. The runner is interrupted and exits 75 at 121.276 seconds.
Xcode's summary contains one canceled runner failure and zero passing tests;
this is not an executed title assertion or proof of a product defect.

No owned app or UI runner remains afterward. No user app or system test service
is terminated. The prior Mac startup gate therefore persists despite working
development signing; do not repeat this unchanged startup path or count its
successful compilation as UI execution.

[Evidence](evidence/native-development-signed-mac-ui/result.json) retains exact
source/product hashes, signature checks, commands, build/runtime results and a
verified 21-member archive. The
[result summary](evidence/native-development-signed-mac-ui/test-summary.json)
keeps the cancellation scope visible. The execution Mac's provisioning identifier
is redacted from retained logs/summary. Production code is unchanged.

Actual Mac resizing, Calendar panes, keyboard, Undo and final UI acceptance remain
open. Account-transition testing is deferred by the user; production CloudKit
integration still requires its ownership/reset evidence. Independent local and
Simulator work does not require that account-state experiment.

## User-requested retry

A second trial on 27 October reuses the same signed build after rechecking all
1164 source inputs, nine product hashes and three strict signatures. The runner
exits 65 after 85.392 seconds with “Timed out while enabling automation mode.”
No test body starts. Xcode reports one runner-initialization failure and zero
passing tests; the external setup deadline does not interrupt this trial.

The runtime log contains no explicit approval request or permission denial.
An unseen system prompt is not ruled out, but this result does not establish
that user approval is required. No Planner or test-runner process remains.
No permissions, system services, signing resources or iCloud settings change.

The [retry result](evidence/native-development-signed-mac-ui/retry-2026-10-27/result.json),
[redacted runtime log](evidence/native-development-signed-mac-ui/retry-2026-10-27/runtime.log)
and [Xcode summary](evidence/native-development-signed-mac-ui/retry-2026-10-27/test-summary.json)
retain this outcome separately from the first interrupted trial. Production
code and the open Mac UI acceptance gate remain unchanged.
