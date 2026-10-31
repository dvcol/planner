# Native Shortcuts optional Item creation

## Scope

The [title-only creation checkpoint](native-shortcuts-create-ui.md) qualifies the
required Title prompt and cancellation. This follow-up uses the existing native
UI boundary to edit Subtitle and Notes and choose a List in Apple's installed
Shortcuts editor. A fresh prototype dataset contains System destination and
Other destination. The main app must remain running in the background before
submission. No production code, dependency, module, target, account or signing
setting changes.

## Diagnostic attempts

The first editor probe exposes the real Title, Subtitle, Notes and List controls.
Its test-owned workflow is subsequently renamed and removed through native UI.
The first positive attempt selects the native List but leaves the field editor's
variable bar active. Its expected result window is absent, and an unconditional
screenshot request masks the missing-result assertion. It supplies no persisted
creation credit.

The next attempt closes that input bar and adds Show Content. Its capture shows
the actual Created confirmation, while the test incorrectly waits for the later
entity display before dismissing the confirmation. A separate cleanup journey
dismisses both displays and deletes that exact test-owned workflow. Those driver
failures remain failures; neither justifies a production change.

The first iPhone persisted readback then passes. iPad exposes Run Shortcut
instead of play, so its first run stops before submission. Its cleanup also
incorrectly expects an All Shortcuts Button after reopening directly in that
folder. A later actual hierarchy/capture inspection shows the All Shortcuts
navigation bar and the removed workflow's absence. Both failed cleanup assertions
remain failures, with no creation credit. The final driver accepts the observed
Run labels and verifies the actual All Shortcuts navigation bar.

The final journey uses only the Created confirmation and ordinary Planner
readback. It waits for both native List choices before capturing them, closes
the input overlay, and removes its uniquely named workflow through native
controls. Shortcuts sometimes waits about sixty seconds for its menu animations
before proceeding; the runner retains a fixed deadline.

## Final local checkpoint

The final iPad
and iPhone
journeys pass, two actual executions with no failures, skips or SQLite-unlink
warnings. They assert one Todo appearance in the selected List, complete
subtitle/notes, the same appearance identity and values after app relaunch, and
an empty Other destination. The app remains backgrounded before submission.
Only the new journey and native UI helpers are added; existing tests remain
byte-identical.

The validation record
reconciles all 1160 native inputs, final source overlays, products verified
before reuse and eight inspected original captures. The existing native UI target
compiles and executes this source on both devices. Production interfaces and sources are unchanged;
no unexecuted Mac UI or additional system-action credit is claimed.

The final iPad originals show both native List choices, selected inputs and
readable contextual details. Its Created confirmation is captured during an
animation, with blurred platter text; the exact response is asserted through
native accessibility. That frame supplies no settled-alert layout or contrast
credit. The final iPhone sheet shows both native choices, and its remaining originals
show the selected inputs, readable Created confirmation and complete contextual
content. The earlier iPhone picker-opening frame retains its own limited scope.
These represented scenes do not close full accessibility or whole-app UI review.

The diagnostic archive
retains ten prior execution epochs and their original pass/failure counts. All
149 members were read and hash-compared before duplicate removal. Final packets
stay separate, and compressed source manifests retain their decoded hashes.
Strict Swift formatting, Markdown lint and diff checks pass. Only these completed
diagnostic runs' raw test caches are removed after retention; final raw results,
compiled caches and all Planner stores remain.

## Remaining acceptance

This is warm-app, local-store system execution. Other actions, remaining system
picker/property/confirmation behavior, Siri, cold/locked invocation, external
plan opening, protected/shared stores, installed Share, CloudKit/accounts, Mac
runtime and physical-device behavior keep their separate gates. The independent
Customer-build test-framework restriction is unchanged. Signing stays deferred.
