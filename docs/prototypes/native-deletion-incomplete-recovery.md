# Applied deletion with incomplete recovery

Status: the focused retained-dialog journey passes on iPhone and iPad. Mac fixture app/test compilation passes; Mac runtime remains open. This is a follow-up to the [selection report](native-deletion-selection.md), independent of Q93 ordinary creation.

## Context and expected state

A confirmed deletion can commit locally while publishing its independent recovery copy fails. The app must retain the truthful applied outcome. Its dialog stays open with a useful error, a disabled Delete action and a Close action. Closing it cannot restore the source or claim that the action was cancelled. Further mutations remain blocked until recovery is established.

Previously the retained dialog still called its dismissal action Cancel and had no form-local applied-state guard. The form now records an applied result, changes Cancel to Close, disables Delete and rejects another submission. Rejected or unverified outcomes do not set that flag. Existing Store recovery and save guards remain responsible for blocking writes.

## Definition of ready

Q89 and A15/A18 already require this native behavior. The accepted public Core commands, production native UI and real post-save filesystem obstruction supply the boundaries. The fixture reuses the existing recovery obstruction against an isolated temporary dataset. No new domain command, schema, persistence injection, account action or Q93 adapter is introduced.

The fixture seeds two ordinary Items with complete recovery, then observes the actual configured store's next native save and obstructs recovery publication. On process relaunch it restores filesystem access while retaining the saved database and its incomplete operation evidence. Its surviving Item prevents reseeding. This environmental repair is distinct from the user's subsequent checkpoint retry.

## Required checks and definition of done

- Confirm deletion of Delete museum while Keep hotel survives. Require the retained recovery message, disabled Delete, enabled Close and truthful labels after the actual save failure.
- Close the dialog. The deleted identity is absent; the survivor retains its identity and notes. Recovery is visibly incomplete and further creation is disabled.
- Relaunch before retry. Keep the deletion and mutation block; Settings must offer checkpoint-only retry for the known applied operation.
- Retry recovery, establish Saved on this device and unblock changes. Neither the deleted source nor an extra survivor may appear.
- Make a later global completion edit to the survivor and relaunch again. Preserve its identity, notes and completed state, with the deleted source still absent and recovery complete.
- Run the native journey on iPhone and iPad, inspect original own-app captures, record literal source/result epochs, strict affected lint and Mac compiler evidence. Mac runtime, wider Q89 matrices and physical sync/account/Share remain separate gates.

## Results

| Isolated candidate run | Result |
| --- | --- |
| iPhone, `phone-isolated-candidate` | One journey passed, 79.967 s; zero failures/skips |
| iPad, `tablet-isolated-candidate` | One journey passed, 79.060 s; zero failures/skips |
| Mac, `mac-isolated-compile` | Fixture app and test targets compile; no runtime credit |

The qualified source is a clean export of committed base `b29a26f02830f3a59d52fcb4f09ca3547d311a5f` plus exactly five declared source overlays. The 233 source inputs match across both simulator runs and Mac compilation. Both simulator app/test product hashes match. The unrelated default callback argument, pending Item editor and selection changes are excluded. The final commit's five source files must match these tested overlay hashes.

All six named original own-app captures were individually inspected. They show the retained failure message with disabled Delete and enabled Close, the checkpoint-only retry after relaunch, and the survivor's completed state and unchanged notes after the later edit and another relaunch. Assertions additionally check stable identity, no duplicate survivor, the deleted identity/title remaining absent and the write block clearing only after recovery. These examples do not prove arbitrary concurrent submissions, restoration or every deletion source kind.

Two earlier phone attempts reached the later independent edit but failed to operate the actual native switch. Their observed view still showed the survivor with completion off. The controller was tapping the outer accessibility row; the corrected iOS controller targets its real child Switch and checks hittability. No product selection or recovery code was changed to resolve that controller failure. A root-working-tree phone rerun then passed in 76.133 s; the final qualification above replaces it with source-isolated evidence. These controller failures are not product red-green evidence.

The [evidence packet](evidence/navigation/native-deletion-incomplete-recovery/) retains commands, compressed original logs, source/product hashes, candidate isolation checks, exact named images and separate historical attempts. Strict Swift lint passes for the five candidate source files; the two report files pass Markdown lint. Independent Standards and Spec reviews found no actionable source issues; the evidence review is recorded in the packet.

No Core command or behavior changed, so this slice adds native regression coverage at the production UI and real post-save filesystem boundary. It cannot complete the full map, Q93 creation, wider Q89 refresh/transition matrices, Mac runtime, physical qualification, accessibility, performance or final UI polish.
