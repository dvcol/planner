# Native selected-copy export

## Context, before and goal

Native Recovery Copies can inspect an immutable Core-issued selection, but it has no export action. Settings exports current data only. A retained recovery copy needs its own explicit manual export so saved and unverified evidence cannot be confused.

The end state exports the selected `portableData` through the native file picker, with Saved or Unverified in the default filename. It reports successful file delivery only after the system exporter succeeds. Cancel and failure preserve the selection and current planner. It never exports the internal recovery envelope or re-reads the active dataset as a substitute for the selection.

## Definition of ready

R20/Q33/Q36 and the [portable recovery contract](../portable-data-contract.md#native-import-delete-and-recovery-forms) accept native inspection/export and data-only selected bytes. The native UI and delivered public file are the agreed test boundaries. Reuse the existing Transferable backup file and SwiftUI fileExporter. No domain/schema/agent-interface change or test-only production parameter is needed.

## Required TDD and definition of done

- Start with a saved-copy native journey that fails at the missing export control.
- Save the actual selected copy through the system picker. Its filename identifies Saved evidence; exported JSON contains the original Tag name/identity and supported portable format, without internal control/receipt/account credentials or UI state.
- Verify current content remains unchanged after file delivery and relaunch. Recheck the inspection journey after extracting their shared native Tag setup.
- Preserve selection bytes through cancellation/retry. Unverified proposal exports are clearly labeled and need their own native fixture proof.
- Inspect original phone/tablet captures and public output bytes, lint affected files and compile the Mac app/test host. Record scope honestly; full graph, exact-byte comparison to a separately issued selection, proposal/failure/cancellation, separate retained datasets, reviewed restoration and physical account/Mac runtime gates remain open until proved.

## Execution

The tracer first reached a saved copy and failed at the missing export control. The implementation adds a native toolbar Export action and the existing Transferable file exporter. It passes the immutable selection's `portableData` directly, with no active-store re-read or new encoding. Default filenames identify Saved or Unverified evidence and the namespace plus checkpoint/proposal. The existing Settings backup filename remains unchanged through the original initializer.

Only a successful exporter callback reports delivered output. Failure retains the selection and shows its error; cancellation clears the pending file without reporting success. Those failure/cancellation paths are implemented but still need their own native fixture qualification.

The unchanged export tracer and the existing inspection journey both pass on each simulator, with two functions per device and zero failures or skips. The ordinary Settings export/relaunch regression then passes once per device against the same frozen products. It verifies the shared wrapper's original default filename and saved Tag. Native current content and identities survive relaunch in every passing journey.

The actual selected-copy files are each 575 bytes; the ordinary Settings files are each 833 bytes. All four public outputs were read at the delivered file boundary and retained with provenance. Each is portable format 2, has exactly the permitted data root, contains its expected original Tag identity/name and has empty other data groups. Internal recovery envelope, receipt/control/account and UI-state fields are absent. These semantic checks do not establish a byte-for-byte comparison with a separately issued selection or full-graph export fidelity.

Original recovery picker/delivery and ordinary Settings delivery captures were inspected separately on both devices. Strict affected Swift/Markdown lint passes. The final Mac app/test host compiles with zero Mac runtime functions. Core, HTTP, schemas and portable format are unchanged; no new Core/HTTP test runs are credited. The missing-control red remains excluded from passing qualification.

[Execution evidence](evidence/navigation/native-recovery-export/execution.json) retains exact commands, native results/trees, original captures, all four public outputs/provenance and source/product hashes.

## Remaining gates

Unverified proposal export, cancellation/read/write failure, exact selected-byte comparison, separate retained datasets, full graph, reviewed recovery restoration and known-applied checkpoint retry remain open. Physical/account/sync/Share, Mac runtime, accessibility/adaptive/scale and whole-app polish still need their owning evidence. Q83 Calendar alignment remains pending.
