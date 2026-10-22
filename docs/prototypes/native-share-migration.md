# Native Share migration-required journey

## Context and expected end state

A5 requires the main app to initialize and migrate shared Planner data. Share must refuse capture before that work is complete and must never claim a save it did not make. Production already maps `mainAppMigrationRequired` to the instruction to open Planner and update its shared data. Existing native journeys cover first setup, missing configuration, recovery and ordinary capture, but not the distinct migration-required state.

Before this follow-up, genuine historical-schema Core tests prove Share's migration refusal and preservation of old data, while the native presentation and subsequent capture path remain unqualified. The goal is an actual native journey through refusal, main-app migration, Share capture and relaunch using that same historical dataset.

## Definition of ready

Use the accepted explicit-configuration Share fixture and real production `PlannerShareCaptureView`, provider loader, capture form, Core and main-window views. Reuse the immutable committed schema-1 store from `PlannerCoreStoreTests/Fixtures/SchemaV1`. Copy it to a unique disposable dataset, preserving all original bytes before opening it. No production injection, migration simulator, new target or entitlement emulation is added.

The test app's existing resource phase now references that original folder. Its 14 bundled files match the source hashes exactly. The ordinary Planner app does not contain this resource. A fixture-only launch flag skips the fixture's usual main-app bootstrap before presenting Share; after cancellation, the ordinary main-window opening path owns the actual migration. Relaunch keeps the migrated dataset rather than reinstalling the old store.

## Required tests and definition of done

Through the existing public native UI boundary:

1. Launch Share over the genuine old schema. Require the update instruction and absence of capture title, review and Save controls. Record the actual native screen.
2. Cancel Share, open Items in Planner and explicitly choose All archive states for the historical archived Item. Require the original Hotel source identity `1E549C08-3282-4A8C-88E3-A61D49CB3E9D` and its original notes. The migration must not create the shared capture.
3. Relaunch Share against the same dataset. Require actual capture review, explicitly name a new Item and save it. Verify a distinct stable source identity, one visible Item, the exact original bookmark and retention of Hotel.
4. Relaunch again, cancel the offered reuse review, and require both retained source identities without duplicate creation.
5. Run the affected existing Share journeys on phone and tablet, inspect original captures, qualify the represented appearance states, compile Mac compatibility and strictly lint the affected Swift/project/docs. Keep source/resource/product epochs explicit.

The new test uses ordinary controls and expected identities from the existing historical fixture. It does not test private migration state or create another production test seam. Core migration qualification remains separate evidence; this native journey is not a replacement for it.

## Build and runtime record

The initial build uses the ordinary navigation scheme and passes normal-app compilation. It does not compile or qualify the new fixture journey. The corrected [fixture-target build](evidence/navigation/native-itinerary-window-compatibility/native-share-migration-fixture-build/) passes and records the copied-resource hashes and normal-app exclusion. No feature-red credit is assigned to either preparation build.

The first completed phone invocation reaches the genuine native migration warning but fails when the navigation helper checks for tabs before sheet dismissal finishes and falls back to a nonexistent sidebar. Its original capture and failure hierarchy are retained. The helper now waits at its existing public tab boundary on phone. The next completed invocation reaches Items, but its new test incorrectly expects the archived Hotel under the default Active filter. The native hierarchy explicitly records that filter. The journey now selects All archive states after each main-window opening. These are controller/fixture corrections, not production migration fixes or passing migration qualification.

Native execution results are recorded only after the exact live runner reaches a terminal state. No saved native capture or migration preservation is inferred from the warning alone or from compilation.

## First passing phone checkpoint

The [corrected single phone journey](evidence/navigation/native-itinerary-window-compatibility/native-share-migration-archive-phone/) passes one function in 196.021 seconds, with zero failures or skips. All 1,062 source/configuration inputs match the workspace, the frozen products remain unchanged, and all 14 bundled historical-schema files match their immutable sources.

Its three original light-mode captures were inspected individually. They show the genuine update instruction, the retained archived/completed Hotel with its Original notes and two-hour estimate, and the newly saved Migrated museum with its original bookmark. The journey checks Hotel's exact historical identity, the distinct new Item identity, one Museum row, exact `https://example.com/museum` link, and both identities after another relaunch without duplicate creation. The [existing real-store schema-1 migration test](evidence/navigation/native-share-migration-core-v1-check/) also passes separately. Neither result substitutes for installed Share capabilities.

## Full regression follow-up

The [full phone invocation](evidence/navigation/native-itinerary-window-compatibility/native-share-migration-full-phone/) passes all six distinct Share functions, with zero failures or skips. The three original migration captures are inspected again. All 1,062 frozen inputs and products match the represented source epoch. The runtime includes substantial test-service startup/cleanup time and makes no performance claim.

The [tablet invocation](evidence/navigation/native-itinerary-window-compatibility/native-share-migration-full-tablet/) fails overall: five existing Share functions pass, while the new migration function stops at the archive-filter interaction. It reaches the genuine migration-required warning and opens Items, but the expected archive picker is absent after the filter tap. The retained failure hierarchy still shows the Items filter as Active. No tablet migration-preservation or new-capture credit is assigned to this partial journey. Its original warning capture and failure hierarchy are retained; the five passing cases do not turn the invocation into a pass.

The [current Mac fixture compilation](evidence/navigation/native-itinerary-window-compatibility/native-share-migration-final-mac-build/) succeeds against the same 1,062 inputs. Its 14 original historical-schema resource files match. The [new Mac fixture attempt](evidence/navigation/native-itinerary-window-compatibility/native-share-migration-first-mac/) reaches the runner but ends at its 720-second controller deadline, followed by 20 seconds of interruption handling. Its incomplete result cannot supply a usable case summary or fresh native capture, so it receives no runtime credit. The source and products remain unchanged. Mac runtime and the tablet interaction remain open; this outcome does not establish a signing cause and does not justify repeating the same startup attempt. These runs use the `85520780` production/test epoch; the later independent Core import correction does not rewrite their source claims.

This checkpoint does not close the full definition of done or installed/physical Share. Swift/project/Markdown checks pass for the represented source.

## Limits

This remains a disposable local Share-role fixture. It does not establish installed extension invocation, App Group provisioning, real sender envelopes, physical extension memory/lifetime, signing, CloudKit/account ownership or system Shortcuts behavior. No signing or security setting is changed. Whole-app polish follows feature completion.
