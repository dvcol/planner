# Native recovery with an unavailable store

## Context, before and goal

The native unavailable screen already offers Recovery Copies without requiring a live dataset session. Existing recovery journeys use readable current databases, so they do not prove that retained snapshots remain accessible when the initialized database is missing. The initial direct journey proves phone inspection/export access, but original captures show a disabled Review Restore action without an explanation. The goal is truthful native recovery access and a clear explanation that restoration needs an available destination, without silently initializing a replacement dataset.

## Definition of ready

R13/R20 and the accepted recovery contract require independent saved recovery and explicit restoration with useful native errors. Q52 authorizes real local fixtures with production views. Use the existing public Core save/recovery and native UI boundaries. The small native footer uses the existing readiness state and grouped Form. No new production injection, command, account behavior or schema is proposed. Q85 catalog sorting is independent and remains pending.

## Required TDD and definition of done

- Save an Item, a shared Tag and their association through public Core with complete recovery. Retain the entire original SQLite directory elsewhere in the disposable fixture, leaving the initialized writer identity and independent recovery intact.
- Open the production unavailable screen. Retry must remain unavailable, without creating a replacement current dataset or claiming a successful save.
- Open Recovery Copies and inspect the acknowledged saved Item/Tag identities, saved generation and association count. Without a ready current dataset, Review Restore stays disabled; Export stays available.
- Before changing production, execute a failing UI check for the missing explanation. Add a native Form footer: Restore is unavailable while Planner cannot open its saved data. You can still inspect or export this copy. Ready-store recovery must retain its existing Restore behavior.
- Open the native exporter, dismiss it to cancel, and return to the same recovery selection without a delivered-file success claim.
- Dismiss, relaunch and inspect the same snapshot and source identities. The fixture must not reseed or restore the missing database on relaunch.
- Run the focused journey on phone/tablet, affected existing retained-recovery compatibility checks, strict lint and the Mac fixture/test-host build. Inspect original captures and record actual commands, results and hashes.

Initial inspection/export checks qualify existing behavior and are not a missing-feature red. The later explanation check is the intended functional red for the footer. Keep compile-only and controller failures separate from both. Actual delivered-file contents, recovery into a replacement dataset, Mac runtime, physical account/sync/Share and broad accessibility/scale/polish remain separate gates.

## Execution

The production change is a seven-line footer in the existing recovery Form. A new disposable fixture saves a Tag, Item and association through Core, then retains the original SQLite directory elsewhere. It leaves the initialized writer identity and independent recovery intact. Relaunch does not reseed or restore that database.

The [evidence packet](evidence/navigation/native-unavailable-store-recovery/) separates the original behavior probe, the missing-explanation red and controller corrections. The functional red executed one failing journey before the footer existed. Its hierarchy records the missing explanation; its sole manual image shows the unavailable screen, not the failed footer assertion. Earlier selected-copy captures show the disabled Restore action without a reason. Two compilation failures executed no journeys and receive no TDD credit.

Final qualification uses the same five frozen Swift files:

| Boundary | Executed result |
| --- | --- |
| iPhone 18 Pro simulator, iOS 27 | Two functions in two suites passed, zero failures or skips. |
| iPad simulator, iOS 27 | Two functions in two suites passed, zero failures or skips. |
| Ordinary Mac app | Build succeeded. |
| Mac fixture and UI test host | Test build succeeded. No native Mac journey ran in this slice. |
| Strict Swift formatting | Five affected Swift files passed. |

Each final pair runs the new unavailable-store journey and the existing reviewed Cancel/Restore journey. The new journey checks retry, exactly one saved snapshot, generation 2, retained Item/Tag identities and one label association. It verifies disabled Restore with the new explanation, enabled Export, native exporter cancellation without success, and the same recovery generation and identities after relaunch. The existing journey preserves its review, cancellation, explicit restoration and current/restored identity assertions. It now waits for observed main navigation at both launches.

Controller failures are retained separately. They exposed native accessibility roles, duplicate controls across stacked sheets, read-only rows that are visible but not hittable, and an iPad Form row partly covered by the navigation bar. Final lookup scopes the foreground Form and checks full visibility below the actual bar. The iPad exporter has a native Cancel button; phone cancellation uses the system sheet-dismiss gesture when that button is not exposed. An earlier compatibility failure reached the generic sidebar fallback before recovery. Its underlying startup cause is unproven; it is not dismissed as external or pre-existing.

Both final bundles' eight original captures were inspected individually. Within each bundle, three selection captures are byte-identical, giving six distinct images. They show the unavailable-state guidance, explanation, retained data, native exporter and ready-store review/result/relaunch. Screenshots support the UI observations; the test assertions establish generation and identity continuity.

## Remaining gates

The exporter was canceled. Delivered-file contents and recovery into a replacement dataset remain unqualified. This fixture uses local-only storage and does not prove physical account transitions, CloudKit convergence or Share lifecycle behavior. Mac compilation supplies no Mac runtime credit. The separate [bounded Mac probe](native-mac-membership-probe.md) was explicitly interrupted before any journey began, with no established cause.

Broader accessibility, adaptive layouts, moving-window scale and whole-app polish remain open. Core/HTTP/schema behavior is unchanged, with no new Core or HTTP test credit. Q84 retains its accepted query-generation policy. Q85 catalog sorting still requires a human choice.
