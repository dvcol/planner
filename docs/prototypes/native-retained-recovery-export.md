# Native retained-dataset export

## Context, before and goal

The saved-copy export journey proves delivery of a Tag from the current dataset. It cannot distinguish selecting a retained copy from accidentally exporting current data. R20 requires independent recovery, with no automatic merge into another dataset.

The goal is native inspection and delivery of a retained dataset's own Item and Tag while the current dataset has different content and identities. Current content must stay separate after export and relaunch.

## Definition of ready

Q52 approves the dedicated fixture scheme using production views. R20 and the portable recovery contract approve native discovery, selection and manual export. The native UI and delivered public file remain the agreed test boundaries. Seed two real local stores through public Core commands with separate store/control directories and a common recovery directory. This is a local isolation fixture, not an iCloud account transition.

## Required qualification and definition of done

- Verify the current Item/Tag before inspection and the absence of retained content.
- Discover two saved copies and select the one containing the retained Item/Tag. Capture its actual source identities through native accessibility.
- Export through the system picker. Verify its filename identifies that saved namespace and generation. Read the delivered public JSON and compare its identities/names with the native-observed expectations; current sources must be absent.
- Relaunch and verify the current Item/Tag identities and retained-source absence.
- Inspect original phone/tablet captures, run affected strict lint and compile the Mac fixture app/test host. Record functions, failures and limits exactly.

This adds qualification for an existing feature, not a new production behavior. No functional red is claimed. Core/HTTP/schema/portable-format behavior is unchanged. Exact selected-byte fidelity, full graph, unverified proposals, failure/cancellation, reviewed restore, checkpoint retry, physical account/sync/Share, Mac runtime, accessibility/adaptive/scale and whole-app polish retain separate gates. Q83 remains pending.

## Execution

The fixture seeds a retained Item/Tag and a different current Item/Tag through public Core commands in separate store/control directories. Both datasets publish independently acknowledged copies to one recovery directory. Relaunch reopens the current dataset without reseeding it.

The initial phone journey failed before recovery selection because it tried to open Settings while in Items. Settings is exposed from Lists. The corrected test opens Lists first; the initial failure is retained separately and is not a functional feature red or a passing qualification.

The final journey passes once per simulator, with zero failures or skips. It discovers two copies, selects by retained content rather than namespace order, verifies current sources are absent from that selection, and exports through the native file picker. The successful filename contains the selected namespace and generation 2. After relaunch, the current Item/Tag retain their original native-observed identities and retained content remains absent from current views.

The actual delivered phone file is 919 bytes and tablet file 921 bytes. Both use portable format 2 and contain exactly the retained Item/Tag identities and names observed in native selection. Current source identities are absent; every other portable data group is empty. Both roots contain exactly the permitted data fields, without internal recovery envelopes, receipts, control/account credentials or UI state. These are semantic output checks, not a byte comparison with a separately issued Core selection or full-graph fidelity.

All eight original selection, picker, delivery and post-relaunch captures were inspected. The final fixture app/test host compiles on Mac, with zero Mac runtime functions. Strict affected Swift/Markdown lint and whitespace checks pass. Frozen source/product hashes are unchanged across the final phone/tablet runs. Core, HTTP, production views, schema and portable format are unchanged; no new Core/HTTP runs are credited.

Execution evidence retains the exact commands, initial failure and final results, complete attachment manifests, original captures, delivered public files/provenance and source/product hashes.

## Remaining gates

This qualifies the represented local retained-dataset inspection/export and current-data separation. It does not qualify iCloud sign-out/reset or account switching. Exact selected-byte fidelity, full graph, proposals, cancellation/read/write failure, reviewed restoration and checkpoint retry remain open. The approved `restoreRecovery` command is specified but is not yet implemented in Core or native forms. Physical sync/account/Share, Mac runtime, accessibility/adaptive/scale and whole-app polish remain open. Q83 Calendar alignment is still unanswered.
