# Exact estimate setting in Shortcuts

Status: Q115 A is implemented at the approved local production boundaries. Seven setting tests, ten reset regressions and affected Mac/Simulator/unsigned device builds pass. Actual Shortcuts input and system execution remain open.

## Context, starting state and goal

At `46c51922`, Core and native editors support exact estimates and the adapter has explicit reset actions. Shortcuts cannot set an Item estimate or a List/Itinerary manual total. Q115 A approves Quantity, six-unit selection and Additional minutes, preserving the complete positive Int64 minute range and mixed values.

## Resulting behavior

Three focused actions set an Item activity estimate, List manual estimate or Itinerary manual estimate. Quantity and Additional minutes are native integer fields; Unit defaults to Minutes and additional minutes default to zero. Values must be nonnegative and produce a positive total. Checked multiplication and addition reject overflow with a useful error before any mutation.

Units retain the accepted fixed minute factors. Two Hours plus five minutes saves exactly 125 minutes displayed in Hours. Both Int64.max Minutes and 17,548,272,520,652 Years plus 84,607 minutes retain 9,223,372,036,854,775,807 exactly. No floating-point conversion, calendar arithmetic or duration-string parser is used.

Each action reads the current source and field guards, then uses its ordinary Core estimate edit. Other fields, source lifetimes, reference identities, saved order, local/global completion, archive state and bookings survive. Existing clear/calculated actions remain the explicit reset workflow. Core still derives totals and remaining time; these adapters add no aggregation formula.

Applied/incomplete recovery returns a truthful warning and blocks further mutations. Native checkpoint retry acknowledges the original operation without replaying its edit. Unverified outcomes direct the user to recovery rather than claiming a saved estimate. Missing, wrong-kind and deleted selections cannot redirect a change or resurrect data.

## Readiness and tests

Q115 A and Q112 authorize production Intent invocation through Apple's dependency manager with disposable real storage in PlannerMCPTests. Tests exercise `callAsFunction(donate: false)` and public Core reads, not the private conversion helper. Existing reset fixture builders/assertions are shared between the two test files; their only changes are test-helper visibility, with no new production test hook or module.

The first Item case fails compilation for the absent action and passes after implementation. The first plan case also exposed an incorrect test enum spelling, `.todo`; that failed attempt remains recorded. Correcting it to the public `.partial` state leaves only the absent List/Itinerary actions failing. Both pass after implementation.

The final run passes 17 tests with zero failures/skips: seven estimate-setting cases and ten existing reset cases. They cover every unit, mixed/remainder-only input, both upper-bound representations, negative/zero/overflow rejection, unchanged whole graphs on invalid input, unavailable storage, cancellation, archived/Done acceptance, deletion-wins, source/reference/completion/booking preservation, reopening and actual post-save recovery-filesystem faults for all three owners. Existing reset cases cover explicit clearing and calculated budgets independently. This slice does not claim a new precommit-fault mechanism or actual system picker coverage.

The final 22 marked fixtures are disposed only after the host exits and SQLite handles are verified closed. Earlier successful runs dispose another 25 marked fixtures with separate reports. Compiler-only red attempts have no runtime credit. Original commands, exits, compressed logs, overlays, summaries and lifecycle reports remain in the evidence packets.

## Platform validation and definition of done

Mac app-hosted execution, the Simulator app/native UI-target build and unsigned generic-device app build pass with the same 1,045 frozen inputs. Strict affected Swift and Markdown lint and Git whitespace checks pass. There is no schema, Core/MCP result, package, target, entitlement or signing/account change.

All three extracted catalogs contain 72 actions, the prior 69 action contracts, ten entities and ten queries, plus the six-case estimate-unit enum. Required owner/Quantity/Unit/Additional minutes fields, native integer types and defaults match. Prior contracts compare equal after treating only `resolvableInputTypes` alternatives as an unordered set; parameter order, enum cases, properties and query metadata remain exact. An initial raw comparison rejected nondeterministic alternative ordering; its correction changes the verifier, not production metadata or policy.

The evidence directory retains the `app-intent-estimate-setting-*` packets. Real Shortcuts field rendering, full-range system entry/round-trip, discovery, background/locked invocation, physical performance and signed/shared storage remain distinct gates. This local slice closes none of the broader map issues; signing stays deferred.
