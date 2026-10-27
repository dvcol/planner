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

## Confirmed authentication gate

A read-only system-log investigation on 27 October identifies the missing
evidence from the runner log. The actual `testmanagerd` events show:

| Time, Asia/Tokyo | Event |
| --- | --- |
| 17:05:23 | Requires authentication; requests “Enable UI Automation”. |
| 17:06:22 | XCTest times out while enabling automation mode. |
| 17:06:46 | Authentication succeeds after the test has failed. |
| 17:06:46 | The expired test releases its client; automation disables. |

Authentication completes 23.625 seconds after the runner's timeout. This
establishes a real user-authentication gate in this attempt. It supersedes the
earlier uncertainty based only on the runner log, and does not establish that
every historical IDE-session stall has this cause.

Apple's installed `/usr/bin/automationmodetool` independently reports:

```text
Automation Mode is disabled.
This device requires user authentication to enable Automation Mode.
```

The current user owns the active console session. Xcode 27.1's first-launch
check succeeds. Global `xcode-select` points to Command Line Tools, but the
failed test explicitly selected the full Xcode installation. Changing that
global selection is not required to address the observed authentication wait.
`DevToolsSecurity` concerns debugger authorization; its disabled status alone
does not prove an additional UI-test requirement.

### User action

For repeatable agent-run tests on this development Mac, run in Terminal:

```sh
sudo /usr/bin/automationmodetool enable-automationmode-without-authentication
/usr/bin/automationmodetool
```

Enter the Mac administrator password locally when Terminal requests it. The
second command must report that authentication is not required. Automation
Mode itself can remain disabled while no UI test is running. This supported
setting permits test tools to enable UI automation without a per-run password
prompt; it changes a machine security preference. The installed Apple manual
documents both this setting and its inverse:

```sh
sudo /usr/bin/automationmodetool disable-automationmode-without-authentication
```

Alternatively, retain the current policy and authenticate the native “Enable
UI Automation” prompt promptly during the next test's 60-second startup wait.
No certificate change, iCloud change, protected-service restart or SIP change
is indicated by this diagnosis. No permission or security preference has been
changed during the investigation.

The [focused diagnosis](evidence/native-development-signed-mac-ui/automation-diagnosis/result.json)
and [broker timeline](evidence/native-development-signed-mac-ui/automation-diagnosis/timeline.json)
retain the read-only facts. Successful execution of the unchanged native test
after the user's action remains the completion check.
