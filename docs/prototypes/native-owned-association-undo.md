# Native grouped link and label Undo

Status: the represented Item and Itinerary journeys pass on dark iPhone, light iPad and, in the 21 October follow-up below, actual Mac windows. Seven native history-controller functions and thirteen real HTTP functions retain their recorded results. Final whole-app polish and the broader signed/physical gates remain open.

## Context, goal and starting state

The [approved Q111 contract](../native-compound-association-undo-contract-review.md) and [Core checkpoint](core-owned-association-undo.md) provide one atomic inverse for the links and label associations removed by one Item or Itinerary Save. Native editors previously returned only success/failure, dropping the companion before the window history could register it.

After an applied Save, pass its actual result to the existing per-window history. Register one action named Remove Links, Remove Labels or Remove Links and Labels according to the removed kinds. Keep edited notes and independent content outside that inverse. Creation, rejected saves and edits without removals add no removal action.

## Readiness and implementation

Q108 approves the production history-controller tests. Q110 and Q111 approve grouped issuance, native result propagation, naming, lifecycle guards and the existing native UI journeys. No new test seam, package, target or production test parameter is introduced.

Both native store edit methods now return `PlannerOperationResult?` through the existing truthful result handler. The forms forward only applied responses from their original dataset namespace. Item editing retains its success dismissal; Itinerary editing retains its recovery-alert behavior. The owning view registers the response with its existing UndoManager/history. Naming and deduplication remain in that history, shared by both callers. Normal text editing and association Redo scope remain unchanged.

## Executed observations

The actual dark-phone regression removes two links and a Tag in one Save and preserves its edited notes, then fails because no Undo control appears. That function fails in 95.954 seconds. An earlier runner invocation supplies an incomplete compiler-evidence path and stops before any test executes; its restored Simulator settings and diagnostic are retained separately.

The first native compile catches a callback declaration placed on the draft wrapper instead of its form. After correction, the new controller function passes in 0.917 seconds across all six Item/Itinerary and Links/Labels/both cases. Each receives the real native Save response, registers it twice to check deduplication, verifies its specific Foundation UndoManager name, restores original public link identities and labels, preserves current notes and advertises no Redo.

The final controller invocation passes seven functions in 1.696 seconds. Thirteen actual HTTP functions pass in 1.099 seconds, retaining forbidden agent restoration and administration admission. Existing native Undo queue, retry, separate-history and ordinary-manager-target regressions pass. Logs retain disposable-store teardown diagnostics also present in the preceding Move checkpoint; production shutdown is outside this check.

The first iPad run stops before editing because the test helper assumes phone tabs while the native sidebar is closed. The corrected driver reveals the sidebar and uses the saved section identities, retaining phone navigation. The first phone Item and Itinerary journeys both pass. Final source-bound results and inspected originals follow below.

The next iPad runs expose an Add Link activation failure before Undo. Waiting for keyboard dismissal does not resolve it. A differential native probe shows XCTest's default element tap leaving one link, while tapping the visible leading label immediately creates the second. Both original captures are inspected. With that diagnostic fallback, the complete Item group/Undo/relaunch journey passes in 133.188 seconds. One preceding probe is explicitly interrupted after repeated sixty-second XCTest keyboard-animation waits, and only the task's iPad simulator is rebooted without erasing data.

A candidate expands the native Button label and its hit shape. Both iPad journeys still fail, so that unproven production change is reverted. Tapping the row center after the first failure succeeds, but tapping that center first also fails. The computed hit point therefore does not explain the observations.

Same-run native geometry then shows the sheet moving between locating and tapping Add Link. Its Form starts at y=219.5 and ends at y=260, a 40.5-point move. The preceding label field remains focused after the software keyboard disappears. Sending native Return to finish that field's editing before the next Add leaves the Form at y=260 and the button at y=848; the complete probe passes in 112.055 seconds. Original before/after captures and hierarchies retain that diagnosis. The final driver uses ordinary native element activation, with no coordinate override, retry tap or production Button change.

The first final mobile build cannot access Xcode's normal caches and CoreSimulator services inside the filesystem sandbox and exits before compiling. The same authorized build runs with the required service/cache access in a separate evidence epoch. No source correction is attributed to that environment failure.

The next final Item journeys pass on both devices, and the phone Itinerary journey also passes. The iPad Itinerary journey reaches its saved links, then stops because the driver expects Edit Itinerary directly in the toolbar. Its actual hierarchy shows a 371-point content pane and the system More button. The helper now opens that native overflow menu when necessary. This changes the test's navigation, not the production editor or toolbar.

## Final local qualification

The final source-bound native journeys pass with zero failures:

| Destination | Item editor | Itinerary editor | Total |
| --- | --- | --- | --- |
| iPhone, dark | 109.508 s | 94.996 s | 204.504 s |
| iPad, light | 115.270 s | 96.882 s | 212.152 s |

Each journey saves two links and a Tag, removes them in one editor Save while changing notes, requires the single named native Undo action, and verifies restoration of the exact original bookmark identities/order and Tag. Current notes survive Undo and relaunch. Relaunch clears the editing history without reversing saved data. Appearance and contrast settings return to their original values after each invocation. These timings describe automated execution, not physical-device responsiveness.

Final native Mac app/UI-test and mobile compiler epochs pass. The seven app-hosted Mac history functions exercise real Foundation and durable storage; they do not qualify actual Mac windows, focus or text editing. No signing account, team or capability setup changes are made.

## Evidence and visual review

The [observed-results index](evidence/navigation/native-owned-association-undo/final-validation/observed-results.json) retains all forty-nine native compiler/runtime epochs, including environment failures, failed drivers, probes and the interrupted invocation. The [source comparison](evidence/navigation/native-owned-association-undo/final-validation/source-comparison.json) distinguishes historical inputs from the five final compiler/runtime epochs, which match the complete current source. The [validation packet](evidence/navigation/native-owned-association-undo/final-validation/checks.json) records affected strict Swift/Markdown lint, whitespace and local links. The [manifest](evidence/navigation/native-owned-association-undo/final-validation/evidence-sha256.json) binds the exact evidence files; bounded credential scanning reports no findings.

All twelve original passing captures were inspected and hashed in the [visual review](evidence/navigation/native-owned-association-undo/final-validation/visual-review.json). The phone's [single Undo action](evidence/navigation/native-itinerary-window-compatibility/phone-owned-group-native-final-qualified/EB878FCE-ED14-4C81-A190-638A113C60E6.png) is above its native bottom tabs. The tablet's [restored Item](evidence/navigation/native-itinerary-window-compatibility/tablet-owned-group-native-final-qualified/E013313F-D2F2-403C-BB31-904CF82649CB.png) and [restored Itinerary](evidence/navigation/native-itinerary-window-compatibility/tablet-owned-group-native-final-qualified/ED34297C-9BD0-41E0-AC8F-94BA1FCA4EE7.png) show both link labels, Indoor and the retained notes. Identity checks come from the native assertions, not pixels.

Provider previews can be loading or unavailable without hiding the saved links. The phone's lower link content lies behind the floating tabs at the captured scroll position. Keep that readability observation and the earlier List-title clipping on the final UI pass; these Undo journeys do not establish scroll clearance, contrast ratios, Increase Contrast or complete accessibility acceptance.

## Definition of done and remaining gates

The represented native journeys, controller/HTTP outcomes, Mac/mobile compilers and affected lint now bind to the final source. Both editors restore the removal group while preserving saved notes and original public bookmark identities/order across relaunch. Only the current-run history expires. The existing Core checkpoint separately qualifies anchor conflicts, recreated relationships, fresh lifetimes, rollback, recovery and replay; this does not claim a native UI run for every guarded variant.

At the initial checkpoint, actual Mac window/focus/text-field interaction remained unqualified. The follow-up below supplies the represented Mac restoration and relaunch journeys. No signing/account setup, protected Agent Control, physical CloudKit/account/Share, scale or whole-app polish acceptance is claimed. The earlier phone List-title clipping remains on the UI polish map. The grouped Core report retains its own 47-function qualification and broader sync limits.

## Mac follow-up, 21 October 2026

After native execution recovered, reuse the existing Q111 UI boundary and current compiled app/test products. No production or test source change is needed for these two journeys. The [actual Mac invocation](evidence/navigation/native-itinerary-window-compatibility/native-owned-group-mac-after-readiness/) passes both cases with zero failures/skips: Item in 97.023 seconds and Itinerary in 65.729 seconds.

Each journey creates two links and a Tag, removes those associations in one Save while changing notes, then invokes ordinary Command-Z. Native reads require the two original bookmark identities in their original order, the restored Indoor label and the new notes. The restored content survives app termination and relaunch. All four original own-window captures were inspected. Unavailable provider previews leave saved bookmarks visible and usable.

The runner verifies frozen source and compiled product hashes before and after execution. The validation packet reconciles those tracked inputs with the current repository and records the actual two-case result. This establishes real Mac grouped restoration and saved-data relaunch behavior. The journey's absent mobile Undo button after relaunch does not establish the state of Mac's Edit menu; no such menu-expiry assertion is credited here. Wider guarded inverses, ordinary text Undo and separate-window history retain their own Core/controller/native evidence.
