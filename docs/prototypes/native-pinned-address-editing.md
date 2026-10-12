# Native pinned address editing

## Context and starting state

Q51 accepts staged Keep saved pin / Remove saved pin under the Item editor's Save/Cancel. The current editor hides place-name/address fields when owned coordinates exist, and returns the original location unchanged. Pinned Items therefore cannot edit those fields or deliberately remove their pin through the native form.

## Goal and expected end state

Allow place-name and address edits while keeping the saved pin by default. Offer a native explicit pin choice only when the Item already has one. Removing the pin preserves the edited name/address, and nothing is saved until Save. Cancel restores the original owned location. Address lookup never silently replaces owned coordinates.

## Definition of ready

- Q51 B is settled in the decision register.
- The agreed /tdd seams include native UI and the public Core field-edit contract. Core already guards location patches and validates coordinates.
- The dedicated fixture app uses production views and real temporary local stores. A pinned-address scenario can supply the otherwise unreachable saved-coordinate starting state.

## Definition of done and required /tdd

- Execute a native phone red showing the missing explicit pin control.
- Use native Form/TextField/Picker and the existing map component. Keep the choice staged under the same Save/Cancel and guarded location patch.
- A native journey proves Cancel after Remove retains the map, name/address Save with Keep retains it, and explicit Remove plus Save removes it while preserving name/address and notes.
- Opening a pinned Item with an explicitly empty saved name leaves Save disabled. A notes-only edit preserves the untouched location values.
- Relaunch retains the same Item identity and the saved unpinned location. Reopen uses a stable fixture dataset UUID; scenario and UUID keep fixture stores separate from normal Planner data.
- Run the same journey on tablet. Recheck the prior overflow fixture after its dataset setup changes. Inspect actual native captures.
- Run strict affected Swift/Markdown lint and app/test-host builds. Native Mac runtime, Q52 provider cases and physical sync/account/Share remain separate open gates.

## Fixture setup

The fixture app accepts `--fixture pinned-address` and `--fixture-dataset` followed by a UUID. It bootstraps a real local Core store and checks the public catalog before seeding. A nonempty fixture dataset opens its saved content instead of reseeding it. Omitting the arguments retains a fresh catalog-overflow fixture. These options belong only to the dedicated fixture entry point.

## Execution

The actual phone red reaches the editor and fails on the absent pin control. An earlier fixture setup used unsupported Item discovery through the generic catalog; the fixture now uses the supported public Items query. That setup failure is excluded from feature red evidence.

Review found that reconstructing a pinned location could replace an untouched empty string with nil. A separate native red proves that merely opening such an Item incorrectly enables Save. The location draft now preserves each original optional string until that particular text changes. Spec review confirms the fix; native green qualification is in progress.

Two affected public Core location-edit functions pass, covering persistence, stale/invalid compound patches, hash guards and replay after location clearing. The first phone green attempt passes overflow but cannot open the pin menu because its picker lies below the visible form. The corrected journey reveals the complete control before tapping. This navigation correction does not change production behavior.

A mixed phone bundle passes overflow and the main pin journey, including identity retention after relaunch. Its empty-name journey passes the unchanged-editor Save check but fails an exact notes assertion: the native caret inserted text before the original notes rather than replacing it. The corrected test explicitly inserts a known phrase and checks the saved notes for that phrase. It does not infer an undocumented caret position. Final bundles are recorded separately.

The final phone bundle passes all three affected native functions with no failures or skips: pin Save/Cancel/relaunch, untouched-empty-name notes editing, and the prior overflow fixture. Mac fixture/UI host compilation passes after regenerating the failed generated runner artifact. The ordinary Mac build also passes. The mixed tablet bundle passes the empty-name and overflow functions. Its main pin journey cannot initially find a location control below the visible form; a subsequent attempt reveals the picker but stops at the similarly hidden place-name field. The final controller reveals each required control before acting. These failed bundles remain separate from passing qualification.

The final tablet pin journey passes separately, including Cancel, keeping the pin while saving name/address edits, deliberate removal and retained identity after relaunch. Together with the two earlier passing tablet functions, three distinct affected functions are qualified. The mixed bundle remains labeled Failed. The final adaptive controller also passes on phone. The final Mac fixture app/UI host compilation passes; native Mac runtime remains unqualified. Qualification source hashes and exact final results are retained in the [execution evidence](evidence/navigation/native-pinned-address-editing/).
