# Native Retry for committed maintenance recovery

Automatic membership consolidation can finish its local save while publication of its recovery copy fails. Planner must keep the saved data readable, block further changes and offer Retry after relaunch. The existing Retry implementation already handles committed maintenance, but its native button and explanatory footer checked only pending user-command identities. A maintenance-only failure therefore displayed “Recovery copy incomplete” without the recovery action.

The shared store now derives incomplete recovery from either command or maintenance identities. The existing native recovery section uses that value for its button and footer; readiness, review and saving guards remain in effect. The command, maintenance Retry implementation, public interfaces, formats and schemas are unchanged. An unverified preparation still requires manual review and never offers committed Retry.

## Real failure input and native behavior

The separate fixture target creates an Item, List and membership through public Core commands, then supplies an independent native membership in a real schema-19 store. Existing filesystem obstruction at the native-save boundary causes actual automatic maintenance to commit while its recovery publication fails. Public reads verify one incomplete maintenance, no incomplete command and no reliable evidence that the waiting Tag command ran. The fixture does not manufacture maintenance evidence or inject UI state. Its read-only variant makes the actual recovery namespace unwritable for Retry.

The successful native journey relaunches before Retry, verifies the original Item identity, completes recovery, creates another List through the ordinary native editor, then relaunches again and checks one original Item and its saved note. The failure journey receives the real write error, retains an enabled Retry and blocked changes, then verifies readable unchanged content after relaunch. The existing prepared-copy journey also checks that committed Retry is absent. The existing user-command recovery journey remains a regression check.

## Qualification

The verification record checks the actual executed functions, structured results, source manifests, products, formatting and inspected captures. The attempt index retains each phase separately.

- The original phone run fails at the missing Retry button on unchanged production. A later diagnostic lookup error is retained separately and establishes no signing cause.
- Four initial phone functions pass after the visibility fix. Two subsequent iPad failures expose test navigation assumptions: List creation needs the existing overflow-aware helper, and a covering sidebar must be dismissed before opening Recovery. Those failures and hierarchies remain retained; the production fix is unchanged.
- Both corrected dark-iPad functions and all four final phone functions pass: six final executions across four distinct functions, with 1,150 identical native inputs and identical actual UI product hashes. There are no skipped functions or SQLite lifetime diagnostics.
- Mac app, Share and fixture compilation and seven existing real HTTP regressions pass. Their production inputs match the final source. The only later source difference is the corrected iOS-only test driver; this grants no actual Mac UI credit.
- The 809 Core inputs, 514 frozen fixtures and nineteen model sources match the preceding Core checkpoint. Core tests are not rerun for this UI-only change. All six affected Swift files pass strict formatting.

Nine original screenshots are retained and visually inspected: three initial phone, three dark-iPad and three final phone captures. Status, Retry, its explanatory footer and the real error disclosure are readable and contained in the native Form. These scoped captures do not establish whole-app visual or accessibility acceptance.

After verifying closed handles, original result readability and exact attachment manifests, cleanup removes five duplicate attachment-export directories, totaling 36,977,593 nominal bytes. Original passing and failing result bundles, manifests and selected captures remain retained. This is not a measurement of physically reclaimed disk space. One closed marked HTTP fixture store is also removed through the existing verifier.

## Remaining gates

Actual Mac recovery interaction, process interruption and additional maintenance failure stages remain open. Protected signed storage, installed Share, CloudKit/account behavior, physical devices and real system Shortcuts retain their separate qualification gates. Missing or partial completion-history delivery, other prepared command families and broader reconciliation remain local implementation work. The final whole-app native UI pass is still required. Signing stays deferred.
