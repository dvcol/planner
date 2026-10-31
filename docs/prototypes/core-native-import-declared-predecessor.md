# Skip for internally declared predecessor dependencies

## Context, starting state and goal

An older backup declares Item X and its original lifetime A. Planner has since deleted A and explicitly restored X under live lifetime B. A new List in that backup references X/A and another valid Item; a new Itinerary references the List and that other Item. An independent Tag is also eligible for import.

Before this correction, Skip review advertises the List, Itinerary and Tag as imports. Apply then rejects the operation because the List's predecessor binding cannot resolve. The accepted result is to retain current X/B, skip the complete List and dependent Itinerary, and import the independent Tag. Neither shortening a container nor redirecting X/A to X/B is allowed.

The [portable contract](../portable-data-contract.md) already forbids predecessor redirects and requires complete dependent-owner skipping. Q128 concerns deliberate Overwrite of the current restored source and remains a separate unanswered choice. This change leaves its guard intact.

## Definition of ready

Use the approved native public Core boundary: decode, review, execute, export, acknowledged recovery, reopen and exact replay against disposable real storage. Create, delete and explicitly restore the Item through production commands. Supply a complete valid backup with no external bindings, so external-reference validation cannot stand in for internally declared dependencies.

## Definition of done and required /tdd

- Reproduce the misleading review and failed apply with a valid backup, then repeat the failure before changing production.
- Retain the current Item's complete graph and live binding. Preview must change no data.
- Report both whole dependent owners with `deletedDependency`, with no fabricated before/after summaries or proposed reference additions.
- Import the independent Tag exactly once. Preserve the complete result in acknowledged recovery, reopen, replay and repeated Skip.
- Run the affected import/bookmark suites on Mac and iOS, reconcile actual executed function/argument counts and source inputs, and check fixture closure and strict affected formatting.
- Preserve the current Overwrite/restoration gates. Incoming-family reconciliation, broader native import presentation, physical synchronization and final app acceptance stay open.

## Diagnosis and implementation

The initial test attempts are not behavioral reds. One fails compilation because nested `#require` expansions recurse. After splitting the expressions, the fixture still fails decode because List/Itinerary content copied from the older portable fixture omits the current format's required nullable `manualEstimate` property. Declaring those properties fixes the fixture without changing production decoding.

The valid regression then executes and fails at three review assertions and the rejected apply. Its unchanged repeat reproduces the same four issues. The public decoded backup reports no external bindings. The review proposes both blocked containers, and apply rejects with unresolved membership source bindings.

Projection retains the dependency lifetime, and review/apply share the same resolver. The new-owner availability check only recognizes a source as deleted when no live source with that public identity exists. X/B therefore hides the closure of X/A from this check. The resolver now also asks the existing import graph whether each exact dependency lifetime is closed. Skip marks the complete new owner unavailable and uses the existing transitive pass to skip its dependents.

The same tracer passes after that correction. It verifies preview categories and nonmutation, complete graph preservation plus the exact independent Tag, acknowledged recovery, operation replay, reopen and duplicate-free repeated import. No public form, package, target, persistence schema, dependency or new test seam is added.

## Qualification

The affected Mac run passes 58 functions across 25 suites, comprising 229 executions, with zero failures, skips or SQLite unlink-while-open diagnostics. The existing mixed-import matrix still admits new Lists referencing conflicted live Items while retaining the current owners' complete data. Existing open-family external binding, deletion/restoration, owned-data and recovery safeguards also remain covered.

The successful focused Mac fixture and all 229 affected-run fixtures are disposed by the existing verifier only after their hosts and SQLite handles close. Failed diagnostic runs retain their original outcomes and are not passed to the success-only disposal verifier as successful runs.

The actual iPhone Simulator run also passes all 58 functions and 229 executions, with zero failures, skips or SQLite lifecycle diagnostics. Its 229 marked fixtures are disposed after host and file closure. The qualification record matches every function's argument count across platforms, all 740 Core inputs and all 1,062 native inputs against current workspace bytes, and the retained native products' hashes. A first collection attempt uses an incorrect cleanup-report key; correcting it to the verifier's actual `removedDirectories` field completes this reconciliation without rerunning or changing the tested code.

Affected strict Swift formatting, Markdown lint and Git whitespace checks pass. No current native UI or physical-device acceptance is inferred from these store tests. Broader internally declared open-family references and incoming-family consolidation remain separate map work.
