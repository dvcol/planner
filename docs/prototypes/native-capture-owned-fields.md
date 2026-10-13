# Native capture owned fields

## Context and goal

The native text/link review already saved a reviewed Item, supported exact reuse and remembered global List destinations. Its create-new form exposed only title and notes. Links were read-only, and the form could not supply subtitle, shared labels, an estimate or an independently entered address.

This slice adds those owned fields to the same native review. It reuses the existing Item label picker, activity duration controls and bookmark editor. Add submits one reviewed Core action; Cancel discards the draft. Choosing an existing Item keeps its content and states, adding only missing links and selected List memberships.

## Definition of ready

- [URL and Share capture](../url-and-share-capture.md), especially C2, C3 and C12–C16, fixes review, provenance, editable drafts and reuse behavior.
- Q33/Q34 accept native UI journeys against the real disposable saved dataset. Existing Core tests qualify the typed draft edit/apply commands.
- The shared label, duration and bookmark components already serve native Item editing. Reuse their native controls and preserve bookmark identities.
- This slice does not depend on pending Q78–Q81. Provider intake, lookup, new pin selection, Calendar layout and physical Share deployment retain their separate gates.

## Definition of done for this slice

- Create-new review edits title, subtitle, notes, Category/Tag associations, optional duration, independent place name/address and ordered bookmark URL/label values.
- The form uses native grouped sections, label navigation, duration Toggles/Pickers/Steppers and existing bookmark menus. A draft-owned coordinate is preserved; this slice does not add coordinate selection or copy provider preview coordinates.
- Existing-Item reuse preserves its owned fields, global/archive/local states and existing references. New bookmark edits retain Core-issued identities; later candidates refresh without silently changing an invalid selected existing Item into Create new.
- Removing a sole link refreshes its untouched automatic title. It cannot turn an unedited fallback into owned text on a second Add. An explicitly edited title remains editable independently.
- Native saved-data journeys cover owned fields and bookmark identity after relaunch, labels through their pushed pickers, cancellation, and sole-link removal. Affected bookmark and capture regressions pass.
- Affected strict Swift lint and mobile/macOS builds pass. Simulator results remain distinct from native Mac UI runtime and physical-device evidence.

## TDD and qualification

The first owned-field journey failed at the absent Subtitle control before implementation. Later attempts exposed a gesture that did not move the native Form and an incorrect duration accessibility identifier. The expanded form also made the existing reuse journey's List destination require scrolling. On iPad, Manage Labels needed sidebar navigation, and lower fields needed revealing before waiting for existence. The final helpers navigate through native controls and scroll the Form; their assertions remain unchanged.

Both review axes identified the same automatic-title defect after sole-link removal. The first regression attempt did not reveal the offscreen title. The corrected red run reached it and failed on the stale value. After the fix, the same journey passed: the untouched automatic title clears and Add stays disabled until valid owned content is supplied. A differing user title is preserved.

Each simulator qualified nine distinct functions in four suites, with nine selected passing invocations and no selected failures or skips. Qualification uses separate runs: the iPhone's unchanged bookmark/plain-text passes, three green capture regressions and four green owned-field journeys; the iPad's five unchanged regression passes and four green owned-field journeys. Earlier failed outcomes are retained as diagnostics and excluded from the qualified selection. This is not a claim that either initial full run passed.

The four owned-field journeys prove subtitle, duration, independent address and bookmark label/identity after relaunch; shared labels through Cancel/Add and relaunch; sole-link removal without promoting automatic text; and invalidated reuse with disabled Add, explicit retained selection and unchanged original data. The regressions cover Done/Archived reuse and remembered destinations, ordinary reviewed cancellation, untouched link/plain-text capture and native bookmark validation/order/removal.

Four affected Swift files passed strict lint. The final macOS app and test host built successfully; Mac UI runtime was not executed. Both source review axes found no remaining confirmed findings. [Execution evidence](evidence/navigation/native-capture-owned-fields/execution.json) contains the source hashes, actual per-run outcomes, qualified selections and original screenshots. Source hashes were checked after all build/test processes exited. The pending Maps lookup work was excluded.

## Remaining map work

The direct-input path still needs native provider intake/preview/retry, explicit pin selection, fuller existing-candidate inspection, List-context capture, interrupted-operation presentation, Share/Intents and physical-device qualification. Q78–Q81 remain unanswered. Full Calendar modes and whole-app native polish remain open.
