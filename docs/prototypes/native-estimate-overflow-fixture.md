# Native estimate overflow fixture

## Context and starting state

Catalog estimates are qualified for ordinary budgets, repeated contextual branches and missing finished estimates. Review found a reachable presentation gap. Two valid child estimates of `Int64.max` and one minute overflow their calculated sum. A manual 240-minute budget remains valid, so Core returns exact full and remaining totals while the calculated total is unavailable. The catalog currently hides this unavailable calculation in its warning and accessibility value.

## Goal and expected end state

Keep the valid four-hour manual budget and remaining time. Show the native warning icon and narrate the unavailable calculated estimate. Prove this through an actual rendered catalog using real Core commands, without testing private presentation helpers.

## Definition of ready

- Q52 accepts a dedicated fixture app and Xcode scheme using production views and controlled preview providers.
- The existing /tdd seams include native UI journeys and public Core commands/reads.
- Core already qualifies positive `Int64` estimates and checked arithmetic. No schema, scheduling or backup change is needed.

## Fixture boundary

`PlannerFixtures` is a separate native application target and bundle identity. It compiles the production views and store adapter. Its entry point builds a fresh temporary local dataset through public Core bootstrap/execute commands, then opens it through the production store adapter. The ordinary Planner entry point remains its own app. Neither fixture uses iCloud or a normal Planner dataset.

The fixture's providers implement the existing production external-I/O protocols. This first fixture returns deterministic no-image link content and no address candidates. Q52's image, error, ambiguity and delayed-response journeys remain open. The fixture foundation does not qualify those cases by itself.

## Definition of done and required /tdd

- Execute a phone regression that fails because the native catalog does not narrate unavailable calculation.
- Add the calculated-unavailable warning and narration without changing exact manual totals.
- Pass that same journey on phone and tablet, and inspect the real native warning captures.
- Compile the affected ordinary app and fixture app/test host, including Mac where available. Report native Mac runtime separately.
- Run strict affected Swift lint, project/scheme configuration checks and Markdown lint. Record initial setup failures separately from runtime red evidence.

## Execution

The actual phone runtime red failed because the catalog omitted unavailable-calculation narration. The minimal warning fix passes the same journey on iPhone and iPad. Both native captures show the orange warning icon beside unchanged four-hour full and remaining values. The initial tablet attempt failed with its adaptive sidebar collapsed; the final test explicitly opens that sidebar. Production code did not change for this navigation correction.

The ordinary iOS app/UI host, ordinary Mac app and Mac fixture app/UI host compile. Six affected Swift files pass strict lint; project and scheme references are checked. Parallel Standards and Spec review found no further actionable defects. Zero Mac UI functions are qualified. The regenerated locally signed fixture runner builds, but XCTest again produces no test-start output; the attempt was interrupted and its startup cause remains unestablished.

The first fixture build ran out of disk space before the test executed; it is not runtime red evidence. The completed tablet catalog DerivedData cache was removed while its separate result bundles, logs and captures were retained. The unchanged single fixture regression was then retried. An unsigned Mac UI attempt produced no test-start output for over four minutes and was interrupted. Its ad hoc retry could not overwrite the generated test binary. These attempts are retained separately and do not qualify native runtime.

The [execution record](evidence/navigation/native-estimate-overflow-fixture/) contains exact bundles, commands, source/configuration hashes and inspected captures. Q52 provider scenarios, broader native Mac journeys and the other map gates remain open.
