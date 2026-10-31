# Native Shortcuts Item creation

## Scope and starting evidence

The installed Shortcuts catalogs and warm iPhone Find action have the
[existing native UI checkpoint](native-shortcuts-system-ui.md#final-local-checkpoint).
The next existing system boundary is Create Item, including its real required
Title prompt and persisted Item readback. Signing stays deferred.

Production CreatePlannerItemIntent executes in the main app and uses the same
SavedPlannerStore registered by PlannerApp. The existing prototype launch
argument opens a fresh disposable local store. First inspect the actual native
Title prompt and cancel it without supplying a valid title. Before a later
positive submission, require the prototype app to remain running in the
background; verify the exact created Item through normal Planner UI and relaunch.
This is a warm-app slice, not cold launch or protected/shared storage.

Use the existing native UI target and installed Shortcuts app. No production
hook, new module, target, account or signing change is proposed. Preserve the
original AppIntentsTesting unavailable case. A passing title prompt does not
qualify creation until a positive system submission and saved readback execute.

## Native prompt and diagnostic probes

The first phone probe opens the actual required Title input, inspects its native
Cancel and Done controls, and cancels without submitting a valid title. The first
positive attempt queries Done by identifier/label shorthand, which selects the
keyboard's offscreen Done key. XCTest rejects scrolling to that control before
synthesizing its tap. The dialog's exact Done label resolves the ambiguity.
A later cleanup probe finds no remaining Title input and fails its expectation;
that probe is removed from the permanent tests rather than counted as cleanup.

With the exact native dialog button, actual phone creation, source row identity,
unfinished completion and app relaunch pass. The returned service text is
Created followed by the unique submitted title. The final tests also assert one
saved row and a separately edited-and-cancelled input leaving an empty catalog
through relaunch. A shared helper reveals the actual iPad sidebar controls before
opening the provider action. Its first compiler attempt incorrectly requests a
query property on one element; it executes zero tests and qualifies no new
products. The query-type correction is kept separate from system execution.

The first combined phone run passes positive creation and relaunch, but its
cancellation check expects No Items yet while native filters are still active.
The actual failure hierarchy shows No matching items and the ordinary empty
catalog guidance. The cancellation test now clears every criterion through the
existing native Filters control, checks its All label, and asserts the unfiltered
empty catalog before and after relaunch. This strengthens the readback without
changing production filter defaults or cancellation behavior.

## Final local checkpoint

Both final functions pass on iPhone
and iPad,
four actual executions with no failures, skips or SQLite-unlink diagnostics.
The final validation
reconciles all 1160 shared workspace inputs, actual built products, source overlays
and six inspected original captures. Existing discovery, Find, lookup helpers
and the original AppIntentsTesting case remain byte-identical. The additions
compile in the existing iOS native UI target; production is unchanged.

Cancellation fills the native required Title field, selects Cancel, clears all
Item filters through the normal UI and proves an empty catalog through relaunch.
Positive submission checks the exact Created confirmation, one matching saved
row, its public Item identity and unfinished completion, then reads that same
identity and state after relaunch. The prototype app remains in the background
before submission and uses its ordinary registered main-app store. No saved
Shortcut, production test hook, account or signing change is added.

The six final originals show the empty unfiltered catalog, actual Created dialog
and saved Item details after relaunch on both devices. These represented light
scenes do not replace whole-app accessibility, dark-mode or physical acceptance.
Earlier diagnostics retain their original results in a lossless archive,
including the zero-execution compiler failure with no new products qualified.
Every member was read and hash-compared before duplicate removal. Final packets
stay separate and source manifests retain their decoded hashes after compression.

This closes the represented warm-app, title-only Create workflow and edited
cancellation. Optional inputs, selected-List creation, other system mutations,
pickers/properties/confirmation, Siri, cold/background launch, locked devices and
external plan opening remain separate work. Mac runtime, protected/shared stores,
CloudKit/accounts and physical-device gates remain open. The Customer-build test
framework restriction is unchanged. Crossed-family recovery follows its separate
decision review. Signing remains deferred.
