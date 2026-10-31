# Rich New Item drafts through native layout changes

Status: the represented iPhone and iPad journeys pass on the final source. Mac compilation passes, with Mac runtime still open. Q94 label presentation and developer-account signing remain separate gates. Whole-app native SwiftUI polish follows feature completion.

## Context and starting state

The [existing layout journey](native-layout-compatibility.md) qualifies title, subtitle, notes and the original List through measured Mac resizing and simulator rotation. [Item shortcuts](native-estimate-shortcuts.md), [List shortcuts](native-container-estimate-shortcuts.md) and [ordinary creation](native-item-creation.md) retain their own source epochs. Those checks do not prove that a staged estimate, owned address and bookmark survive the same view transitions before the first Save.

## Goal and expected end state

Keep one New Item draft in Origin with its title, subtitle, notes, twelve-hour estimate, place name, address and Visit guide bookmark. Preserve every authored value and the bookmark draft identity through the represented layout transitions. Explicit Save creates one shared Item and one local Todo appearance in Origin. Relaunch retains that appearance, exactly 720 saved minutes and the saved bookmark's identity and original URL. The owned place name and address remain available in Edit; Other stays empty.

## Definition of ready

Q90/Q91 approve the detail-column/pushed editor, explicit Save and guarded navigation. Q93 and the accepted owned-content rules govern rich creation and its originating List. The approved boundary remains production native UI with disposable real local stores. Existing Core, persistence and HTTP contracts are unchanged. This qualifies existing authoring behavior, so it does not fabricate a missing-feature red or add a public command or test-only injection seam. Categories and Tags remain outside this independent journey while Q94 is pending.

## Required tests and definition of done

- Author a twelve-hour estimate, owned place/address and one labeled bookmark alongside title/subtitle/notes before any Save.
- Verify all values and the same bookmark draft identifier after each represented layout change. Keep the native Save control available without a leaving prompt caused by layout alone.
- On Mac, the existing driver measures 860/1200-point widths and hides/shows the sidebar. On the simulators, require the actual Planner window to reach landscape, portrait and landscape. Rotation does not prove iPad split-screen or a size-class transition.
- Save once into Origin, retain one Todo appearance after relaunch, verify exactly 720 saved minutes, the saved bookmark's identity and original URL, the owned address/name in Edit, one global Item and an empty Other List.
- Recheck the existing rich-creation journey, including Discard, two separately identified bookmarks with the same URL, original membership/completion and retained content after relaunch.
- Compile the affected app/UI targets on both platforms, lint changed Swift and the report, and retain literal native outcomes, frozen source/product hashes and individually inspected named Planner-window captures. Mac compiler evidence does not satisfy its runtime requirement.

No new domain logic, command or wire contract requires a Core unit/HTTP test in this slice. The required interaction and persistence checks run through the existing native boundary.

## Current results

| Platform | Rich draft through layout changes | Rich-creation compatibility | Outcome |
| --- | --- | --- | --- |
| iPhone 18 Pro Simulator, iOS 27.0 | Pass, 256.366 s | Pass, 129.555 s | One passing two-function batch |
| iPad Air 11-inch M4 Simulator, iOS 27.0 | Pass, 210.364 s | Pass, 142.368 s | Two separate passing invocations |
| Native Mac | Not run on this source | Not run on this source | Affected app/UI compiler pass only |

The iPad's passing layout invocation reaches the native Edit Item Form after Save and relaunch, then verifies the exact owned place name and address. The compatibility invocation verifies Discard creates nothing, rich Save creates one contextual appearance, duplicate-URL bookmarks retain distinct identities, and the source/appearance/content survive relaunch. The phone batch and both tablet invocations have zero failures or skips. The phone layout function checks the same rich fields through landscape, portrait, landscape, Save and relaunch; its compatibility function retains the same creation and persistence oracles. XCTest durations include fixture and automation work; they do not measure physical responsiveness.

## Controller diagnosis and correction

The initial phone invocation fails in 64.133 seconds before estimate selection. Application-wide swipes do not reveal Quick estimate. Its own-app recording still shows New Item and the authored text fields before teardown, so this does not establish draft loss. That source also predates the explicit post-Save and post-relaunch Todo assertions.

The window-scoped phone probe fails in 67.491 seconds. Its immediate capture shows the Form at Location with Quick estimate above the viewport. Full-page flicks can skip the intermediate row. Sharing the existing smaller trailing-edge drag produces a passing phone function in 244.859 seconds on that earlier source epoch. It is historical evidence, not final-source qualification.

The first iPad batch fails the expanded layout journey in 72.655 seconds and existing rich creation in 70.756 seconds while revealing fields. Immediate own-app hierarchies and window captures show New Item still open. The software keyboard and input accessory cover the window-normalized drag start. The controller now activates the observed native Hide keyboard control only when it exists and is hittable.

The first dismissal probe fails the layout function in 87.352 seconds because it wrongly requires that button to stop existing. The native hierarchy records a zero-height Keyboard at y=820, while Hide keyboard remains at y=1083 outside the 820-point window. Its rich-creation function also exceeds the six-minute allowance after repeated animation-notification waits. The corrected controller waits for an absent or empty keyboard frame, preserving all field and identity assertions.

The keyboard-frame invocation reaches the final post-relaunch Edit verification, then fails in 238.139 seconds. Its screenshot and hierarchy show the centered Edit Item sheet at x=300...880, while the window-normalized drag starts at x=1133 outside it. A last-CollectionView probe fails the same check in 247.081 seconds because accessibility order selects the background full-window collection, rather than the front sheet.

The final correction gives the existing Edit Item Form the stable accessibility identifier `saved.item.edit.form`, following the existing Filters/Import convention. The iOS helper targets that named native collection for its short drag. New Item and saved details retain their window-scoped gesture; the Mac wheel path is unchanged. This adds an accessibility identity without changing presentation, navigation, authored content or persistence.

The first identified-Form invocation times out during repeated sixty-second animation-notification waits around the URL field, before the final Edit check. It receives no function pass credit. The runner has already shut down the test iPad when the reset begins, so the redundant shutdown command fails with that explicit state. A fresh inventory verifies Shutdown before booting only that same device without erasing data. The unchanged-source retry passes in 210.364 seconds. That sequence does not establish the cause of the earlier waits.

Every failed or timed-out invocation remains separate from passing functions in the run index.

## Evidence and remaining gates

The evidence packet records commands, source epochs, source/product hashes, literal outcomes, native window captures and separate source reviews. The final builds archive 945 inputs per platform. Runtime wrappers freeze 469 source/configuration inputs and verify six product hashes before and after each invocation. Later builds can replace live products; historical hashes retain their original epochs.

All seventeen retained original named Planner-window PNGs were individually inspected; eight belong to final-source passing invocations. The selected final phone/tablet captures show readable estimate, location and bookmark controls in the native editor at both orientations. The saved rich-creation captures include an address map, while the example bookmark cards show the native unavailable/Retry fallback. These visual observations are not controlled provider-success or whole-app polish qualification.

Strict lint passes both affected Swift files and this report. Independent Standards and Spec source reviews have no remaining confirmed findings. These checks do not replace runtime evidence.

Mac runtime, iPad split-screen/Stage Manager and other adaptive layouts, Q94 labels, other feature compatibility, physical sync/account/Share, accessibility, memory/hitches and physical latency remain open. Signing remains deferred. No overall Navigation, feature or map gate is closed. Whole-app native SwiftUI polish follows the remaining feature work.
