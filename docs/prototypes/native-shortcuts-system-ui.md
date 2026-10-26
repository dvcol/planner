# Native Shortcuts system UI qualification

## Existing gate and current facts

Q112's installed AppIntentsTesting service rejects invocation with Customer-build
error 803 before Planner runs. That does not establish the behavior of Apple's
ordinary Shortcuts UI. A current read confirms Shortcuts is installed on the
phone Simulator. The Mac boot and native test broker remain unchanged from the
retained runtime diagnosis, so no unchanged Mac UI startup retry is made.

Use the existing native UI target and actual installed Shortcuts app for a
bounded read-only Shortcuts feasibility trial. First launch Planner with a fresh local
prototype dataset, then capture Shortcuts' actual initial window and hierarchy.
A foreground window proves availability only. It supplies no Planner discovery,
parameter, action execution or storage qualification.

Inspect that actual UI before choosing any next interaction. Do not invoke a
mutating Planner Intent until its storage isolation is established. Do not add
production hooks, another target, a replacement test service, private entitlements
or account/signing changes. Native system behavior retains its own acceptance
boundary, separate from the approved direct Intent/interface tests.

If discovery can run, qualify the actual Planner catalog and preserve its exact
limits. If the environment prevents it, retain the concrete result rather than
claiming that developer membership would fix it. Q163 remains pending.

## Actual system discovery

The installed iPhone Shortcuts app opens without changing signing or accounts.
Its native Library includes Planner. Planner's catalog renders the four approved
App Shortcuts: Create item, Find items, Find lists and Find itineraries. These
are actual system UI observations, separate from direct provider-interface tests.

The discovery does not establish Siri phrases, execution, background or locked
launch, parameter pickers, deferred properties, confirmation or plan opening.
The original AppIntentsTesting error remains a separate gate.

## Read-only invocation investigation

A probe creates a uniquely named Item through Planner's ordinary New Item UI in
a disposable local prototype dataset, then taps Find items in Shortcuts. It fails
its expectation that the Item title will appear automatically. The production
Find action returns entities without a dialog or snippet, so an unchanged catalog
does not establish success or failure of execution. No production change follows
that incorrect observation assumption.

The native Find context menu offers New Shortcut. Choosing it creates one
Simulator-owned workflow named Find items in Planner, initially showing Apple's
description screen. Relaunch returns to All Shortcuts instead of restoring that
editor; the probe expecting automatic restoration fails. The next trial reopens
the observed workflow rather than creating duplicates. A composed workflow with
an explicit result-display action is needed before claiming readable output.
No mutating Planner Intent has been invoked.

## Observed execution and driver corrections

The composed native Show Content action automatically connects to Find Planner
Items output. Actual execution visibly returns the uniquely named Item created
in the currently running disposable Planner dataset. The first output assertion
incorrectly queries the Shortcuts main application, while the rendered result
belongs to Apple's separate Shortcuts UI service. Both SpringBoard and the
observed com.apple.ShortcutsUI hierarchy expose its text and Done control.
A corrected native assertion against that result service passes for the exact
current Item title.

A separate earlier attempt stops before invoking Shortcuts because its driver
queries Planner's completion Switch as a Button. The actual failure hierarchy
shows the saved Item and its unfinished Switch. The driver uses the existing
typed-independent native query afterward. Neither observation defect requires
production changes. Failed attempts retain their failure status.

Only the test-created workflow is renamed and removed through native Delete and
Delete Shortcut controls. The initial Simulator library was empty. No Planner
mutation action, external message or account/signing change is used. Native
context menus repeatedly miss XCTest's animation-complete notification and incur
a bounded one-minute wait; this is recorded separately from action execution.

## Persistent workflow cleanup

The first self-contained run passes catalog discovery and exact Find output, then
fails its immediate deletion assertion. A follow-up native capture still shows
the named card in Planner's app catalog. Relaunching Shortcuts and opening the
actual All Shortcuts library shows No Shortcuts. The native app catalog's stale
card is not treated as a Planner data defect or as proof that deletion failed.
The final test checks the uniquely named workflow's absence in the reloaded
library before continuing to the original Planner Item and relaunch assertions.

The initial iPad discovery probe queries Planner as a Button, matching the phone
Library. Its actual failure hierarchy shows Planner as a native sidebar text row
with four available actions. The shared UI driver now selects the exact Planner
label across native roles. This changes no production navigation or provider.

Reopening Shortcuts on iPad can also leave its sidebar collapsed. The driver
uses the observed Show Sidebar control before selecting Planner. The final iPad
discovery execution passes all four exact title assertions. Its original capture
shows the selected Planner row and count of four with the native sidebar still
open; it does not qualify the entire catalog's visual layout.

## Final local checkpoint

The final shared source passes [two iPhone executions](evidence/native-shortcuts-system-ui/shortcuts-system-iphone-discovery-and-read/boundary-validation.json)
and [one iPad execution](evidence/native-shortcuts-system-ui/shortcuts-system-ipad-discovery/boundary-validation.json),
with no failures, skips or SQLite-unlink diagnostics. Both epochs match all 1160
workspace inputs; their four actual built product paths are verified before reuse.
The [final validation](evidence/native-shortcuts-system-ui/final-validation.json)
checks those inputs, products, source overlays and original capture hashes. The
existing AppIntentsTesting case is byte-identical to the committed original.
The additions are iOS-only and compile through the actual native UI target.

Both native catalogs expose the four exact approved titles. The phone's
self-contained Find journey creates a unique Item through Planner's normal UI,
records its actual row identity, creates and names a native Shortcut, connects
Find output to Apple's Show Content action, and asserts the exact returned title
in the actual result service. It removes its own Shortcut and verifies persistent
absence after Shortcuts relaunch. The same Planner Item identity and unfinished
completion survive return and actual app relaunch. This qualifies warm-app
read execution; no mutating Planner Intent is submitted.

Three final original captures are inspected. The phone catalog and result are
readable. The iPad capture shows the selected Planner sidebar row and count of
four; the sidebar covers its catalog, so this is not full catalog layout
acceptance. Earlier transition captures, wrong-role assumptions and failed
assertions remain separate evidence epochs. Their source, commands and logs use
a [lossless diagnostic archive](evidence/native-shortcuts-system-ui/diagnostics-index.json).
Every archived member was read and hash-compared before duplicate removal.
The index preserves each probe's original pass/fail count; its complete summary,
hierarchy, source and captures remain in the archive. Final run packets and
reviewed originals stay separate. Their source manifests are losslessly gzipped,
with decoded hashes retained.

Production, Core/MCP interfaces, formats, targets and signing configuration are
unchanged. No new Mac UI startup attempt or protected-store qualification is
claimed. Actual mutating Shortcuts actions, system pickers/properties/confirmation,
Siri discovery/phrases, cold/background launch, locked-device behavior and external
plan-opening remain open. Physical, Mac-runtime and signing/shared-store gates
remain separate. The Customer-build test-service error is not resolved by this
ordinary UI path. Q163 remains a policy question; signing stays deferred.
