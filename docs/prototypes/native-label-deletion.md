# Native label deletion

## Context and goal

At `30cb885`, Core can review and delete Categories and Tags. Manage Labels can create and rename them but has no Delete action. R7 and Q35 require confirmation whenever a label has an association, including an Itinerary-only association. Distinct labels may have the same name.

The goal is an explicit native Delete review in the existing label editor. It must describe the affected Item and Itinerary uses, preserve their owned data and completion, and return to Manage Labels only after a verified complete save. Cancellation must preserve the label and every association. No Trash workflow is introduced.

## Definition of ready

- Public Core review and execution support both label kinds, including changed-association review rejection, exact receipt replay and independent recovery outcomes.
- The accepted test boundary is actual native controls with a real temporary dataset, as recorded in Q34/Q35. Tests do not seed or inspect a private database.
- Associated-label confirmation includes Itinerary-only uses. The complete removal set comes from Core rather than visible or filtered rows.
- A failed or unverified save cannot be presented as successful deletion. An applied change with incomplete recovery remains applied and blocks later mutations.

## Definition of done

- Existing Category and Tag editors expose a native destructive action; creation forms do not.
- The review identifies the label and reports Item and Itinerary counts separately. Cancel returns to the editor without applying changes.
- Confirmation uses Core's issued review token. A changed removal set requires another explicit confirmation of the refreshed review.
- Confirmed deletion removes the selected label and its associations, retains other labels, and preserves owner identities, content, references and completion across relaunch.
- iPhone and iPad journeys qualify Category use by both an Item and an Itinerary, and Tag use by an Itinerary alone. A same-name surviving label remains distinguishable by identity.
- Affected Swift lint and platform compilation pass. The existing bulk review journey still passes after any shared native adapter change. Mac compilation is reported separately from native runtime qualification.

## Required /tdd and qualification

Write one native associated-Category journey first and establish a functional failure at the missing Delete action. Implement the smallest review/confirm flow, then qualify cancellation, retained owner state and relaunch through the same public controls. Add the Itinerary-only Tag journey to qualify the shared presentation and confirmation rule. Existing public Core and authenticated HTTP results remain recorded at their own source epochs; no private UI helper tests are added.

## Implemented behavior

Manage Labels now offers Delete in existing Category and Tag editors. It prepares the complete Core review before presenting a native sheet with a Form, label name, separate Item/Itinerary use counts, Cancel and Delete. Counts deduplicate owner identities rather than counting repeated Item appearances. New-label forms retain their creation and cancellation flow.

The shared native reviewed-change adapter executes the issued token. A stale removal set replaces the review and explains that its counts changed; it does not automatically confirm the new set. Cancel applies no command. A verified complete deletion dismisses the review and returns to Manage Labels. Rejected, unverified and incomplete-recovery outcomes retain their existing domain distinctions; the latter two block further mutations, and the sheet does not claim successful completion.

The Category tracer uses an Item and an Itinerary with a completed local appearance. The Tag journey uses an empty Itinerary with notes and a Category, plus two distinct Tags named Rain. Both journeys exercise Cancel before confirmation, check the preserved owners after relaunch, and observe only the selected label identity disappearing.

## Qualification

Three native journeys pass on each simulator with zero failures/skips: Category deletion, Itinerary-only Tag deletion and existing bulk completion through the shared adapter. macOS app/test bundles compile with zero native UI runtime functions. Five affected Swift files pass strict formatting lint. Twelve app-owned captures were individually inspected and retained. Their phone route title/toolbar crowding remains a whole-app polish finding.

The iPad runner emitted 400 ignored remote-hierarchy diagnostics while checking Springboard for interrupting elements. The actual journey assertions all passed, with zero animation-idle warnings. These diagnostics remain recorded as an automation limitation; passing the journeys does not establish that the diagnostic has been resolved.

The initial test run stopped on an incorrect plural progress expectation; it is recorded as a setup expectation failure. After correcting it, the functional red reached the missing Delete control in 107.778 seconds. Before green, two checks after that boundary were corrected to reopen the Itinerary after Manage Labels returns to Lists and locate global completion as a native switch. Byte-identical red/green test files are not claimed. The Category journey then passed in 176.490 seconds. The later Tag journey qualifies the shared flow and passed first, without another missing-feature red.

The evidence record retains the expected failed runs, actual result summaries, commands, capture hashes and both 279-file source/configuration epochs. Only the additional Tag test function differs between Category first green and final qualification; reconstructing the earlier file proves its exact hash, and all production/configuration bytes match. Tag, bulk, iPad and Mac qualification share the final frozen epoch. Core and authenticated HTTP code/tests are unchanged from `30cb885`; their existing deletion/recovery/authentication results are reused rather than rerun for this UI change.

## Remaining qualification

Controlled native stale-review/recovery-failure presentation, broad owned-graph stress, native Mac runtime and accessibility remain separate gates. Core's existing changed-association and recovery I/O tests prove the domain transaction, not those native presentations. Signed sync/account/Share and whole-app polish remain open.
