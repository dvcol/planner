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

### Manual authentication is the selected policy

The user chooses to retain per-run authentication. Announce the next Mac UI
run while the user is ready, then let the user authenticate the native “Enable
UI Automation” prompt during XCTest's approximately 60-second startup wait.
Do not enable authentication-free automation. Apple's status tool may report
Automation Mode disabled between runs; authentication must remain required.

No certificate change, iCloud change, protected-service restart or SIP change
is indicated by this diagnosis. No permission or security preference has been
changed during the investigation.

The [focused diagnosis](evidence/native-development-signed-mac-ui/automation-diagnosis/result.json)
and [broker timeline](evidence/native-development-signed-mac-ui/automation-diagnosis/timeline.json)
retain the read-only facts. Successful execution of the unchanged native test
after the user's action is established below.

## Passing manual-approval retry

On 27 October, the user is ready to approve the native prompt. The unchanged
`testLongListTitleSharesTopToolbarAndUsesAvailableSpace` starts and passes in
67.622 seconds, with one passing test and zero failures. The complete command
exits 0 in 71.302 seconds without an external interruption. All 1164 native
inputs, nine actual products and three strict signatures match before launch.

The journey creates a disposable List with a long title, resizes the window
to widths 860 and 1200, checks title placement, available title width, toolbar
controls and estimate spacing, creates an Item and repeats the narrow/wide
checks with selected details. All four original screenshots are inspected.
They show the title and controls within the top toolbar, with more title space
when the window widens. No production or test-source change is required.

Apple's tool reports authentication required both before and after the run.
No Planner or test-runner process remains. No security policy, iCloud setting,
signing resource or protected service is changed. The startup gate is cleared
for this execution; future runs retain manual prompt coordination.

The [passing result](evidence/native-development-signed-mac-ui/manual-approval/result.json)
and [Xcode summary](evidence/native-development-signed-mac-ui/manual-approval/test-summary.json)
record the actual execution separately from both failed attempts. Original
captures cover [empty narrow](evidence/native-development-signed-mac-ui/manual-approval/empty-narrow.png),
[empty wide](evidence/native-development-signed-mac-ui/manual-approval/empty-wide.png),
[populated narrow](evidence/native-development-signed-mac-ui/manual-approval/populated-narrow.png)
and [populated wide](evidence/native-development-signed-mac-ui/manual-approval/populated-wide.png).
Other Mac UI journeys, Calendar resizing, keyboard/Undo and full acceptance
remain open. Account-transition testing remains separately deferred.

## No visible prompt during the 28 October Map run

The user reports that no Enable UI Automation prompt appeared in the latest
core Map attempt. Its retained runtime exits 65 before any test starts. Logs
between 22:12:57 and 22:13:58 JST show testmanagerd requesting automation mode,
requiring authentication, and creating the corresponding LocalAuthentication
context. The authentication agent reports makeKeyAndOrderFront and then a
GotFocus transition to Active. Those internal events do not prove that the
dialog was visible to the user or explain the missing presentation.

The active console session matches the execution user; authentication remains
required and Automation Mode is disabled between runs. A read-only window probe
after the timeout finds no corresponding window, which cannot establish where
it was during startup. Disabled debugger authorization, companion warnings and
Mac Share discovery are not established causes of this failure. Mac Share is
now explicitly post-MVP.

The [compact diagnosis](evidence/native-development-signed-mac-ui/no-visible-prompt-2026-10-28/result.json)
retains these distinctions. The next bounded diagnostic is the existing core
Map journey started by the user in a foreground Terminal, after saving drafts
and quitting the installed Planner. Its prepared launcher verifies the frozen
source and signed test products before launch. A read-only probe samples display
and authentication-window geometry during startup, without capturing screenshots,
window titles or credentials. Metadata visibility is itself limited and cannot
guarantee that a secure window will be reported.

This foreground attempt is prepared, not executed or a proven fix. It retains
manual native approval and changes no authentication policy, protected service,
iCloud setting or signing resource. A successful build is not Mac interaction
acceptance, and another restart or unchanged background retry is not the next
diagnostic.
