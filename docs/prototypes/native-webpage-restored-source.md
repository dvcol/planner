# Browser Return after source restoration

Status: the represented source-lifetime and affected Return journeys pass on phone and dark iPad, with matching Mac compilation. Q141 already requires rejection of an old reader context when its Item has a fresh lifetime. Q150 concerns restored associations with an unchanged Item and remains independent.

## Existing test boundaries and expected outcome

Reuse the production-source PlannerFixtures UI boundary, its independent real Core writer and the existing loopback BrowserJourneyServer. A fixture-only action exports its disposable graph, performs reviewed Delete, explicitly reviews/applies restoration, and verifies through public reads that Hotel retains its public identity with a different source lifetime. It adds no shipping command, launch flag, target, dependency injection or test boundary.

The native journey opens Hotel's actual saved guide before replacement, keeps reading through Delete/Restore, then requires the unavailable-origin explanation and the actual Items collection. The restored Hotel row retains its public identity. Explicitly opening that row afterward must recover its original notes and bookmark. The old reader must never reopen that fresh Item lifetime automatically. The shipping implementation is unchanged for this first qualification.

Actual Mac interaction, restored-association policy Q150, other parent/path lifetimes, physical account behavior and whole-app polish remain separate gates. Signing stays deferred.

## First native executions

The [first phone function](evidence/native-webpage-restored-source/browser-restored-source-phone/boundary-validation.json) completes actual Delete/Restore, keeps reading and reaches the required unavailable-origin explanation. It fails at an immediate `isHittable` check on the generic collection container. Its whole result remains failed.

The corrected test retains the collection-identity check, waits for the actual Hotel row to be hittable and explicitly opens it. The [complete phone journey](evidence/native-webpage-restored-source/browser-restored-source-phone-row-qualified/boundary-validation.json) passes in 44.066 seconds, including original notes and exact bookmark identity/value. Both original captures are inspected. Shipping production is unchanged. Dark-iPad execution, affected regressions and matching Mac compilation remain in progress.

## Final local checkpoint

The [dark iPad cohort](evidence/native-webpage-restored-source/browser-restored-source-dark-tablet/boundary-validation.json) passes restoration, deleted-source and removed-membership journeys in 33.297, 25.466 and 35.915 seconds. The [phone regression cohort](evidence/native-webpage-restored-source/browser-restored-source-phone-regressions/boundary-validation.json) passes the affected deletion/removal functions in 27.949 and 38.601 seconds. Together with the restored-source phone function, this is six passing native executions across three functions, with zero failures/skips in the accepted runs. Fourteen original captures are retained; seven are inspected, including both restored-source reading/return states on each device and representative removed/deleted returns. The earlier failed function remains failed.

The [final reconciliation](evidence/native-webpage-restored-source/final-reconciliation.json) verifies identical 1,094 inputs across these native runs and the [Mac build-for-testing](evidence/native-webpage-restored-source/browser-restored-source-mac-compiler/boundary-validation.json). Mac compilation passes in 5.820 seconds, and all nine retained product hashes are verified before reuse. Native products are separately checked before each mobile output reuse. Strict Swift lint, Markdown and whitespace checks pass. Shipping production, Core/MCP declarations, backups and account signing are unchanged.

This closes the represented fresh Item lifetime case. Q150's restored-association decision, other parent/path transformations, actual Mac UI, accessibility/resizing and physical account behavior remain open. The retained iPad List capture also confirms that its narrow regular-width toolbar can hide Add behind automatic overflow; that local presentation correction remains separate from browser Return.
