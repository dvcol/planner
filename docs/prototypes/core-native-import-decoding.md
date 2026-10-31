# Native portable import decoding

## Context, before and goal

At `322556e`, Core exports the current supported graph but has no native bytes-only import decoder. The recovery reader requires a closed schema-14 graph and rejects nonempty completion/restoration history. Reusing it would reject approved portable data and file-external dependencies.

The goal is `decodeImport(Data)` returning an immutable complete version-1 value or one useful failure. Decoding selects no dataset, account or session, opens no store and changes no data. Required file-external source bindings and their origin paths remain explicit for later dataset-bound review. Unknown properties, invalid values, duplicate identities and inconsistent internal lineage reject the whole file. There is no MCP/App Intent administration endpoint.

## Definition of ready

- Q33/A21 and the [portable contract](../portable-data-contract.md) approve the native method, immutable backup/binding paths, exact record fields and later bound review.
- Public Core input/output, actual store/export/reopen and actual authenticated HTTP seams are already accepted. Tests do not query private models or inject parser factories.
- The independently authored version-1 fixture is copied byte-for-byte as a native/package test resource. Completion and restoration groups remain in scope, rather than being replaced with an empty-history subset.

## Definition of done

- Foundation resolves repeated properties once. Every validation and projection uses that same immutable decoded value; later byte changes cannot change an earlier result.
- Complete source/reference/Schedule/deletion/completion/restoration records retain IDs, lifetimes, order, native values and state. Required external bindings do not silently shorten containers.
- Supported-version unknown fields fail at escaped JSON Pointers; invalid record values, kinds, ranks, lifetimes, closures and causal cycles reject together. Native syntax/representation failures use Foundation's available location, including the document root when Foundation supplies no field path.
- Actual exports decode in the approved grammar. Historical internal acknowledgements remain readable and byte-preserved; compatibility does not weaken strict user-file validation.
- Large List backups avoid rebuilding the identity graph for each binding. Actual native/package checks, affected lint and scoped HTTP admission pass.

## Required /tdd and executed corrections

The first tracer decodes the independent complete fixture before bootstrap, retaining seven sources, three memberships, two route entries, two expanded states, two Schedules, four label associations, two bookmarks, one deletion marker, one alias and one explicit change. It checks exact Museum content/timestamps/estimate and proves no configured directory is created. The approved method's explicit unavailable body produces executable red; the unchanged tracer then passes.

Admission checks cover thirty invalid inputs, precise paths, external dependencies, canonical completion history, explicit Reopen versus late Done seeds, valid/invalid restoration families and immutable native repeated-property resolution. Two additional failing lineage cases exposed an unjustified new lifetime for a closed identity and a closed membership redirecting history to another Item. Both now reject at their declared paths.

Actual-store round trips exposed prototype writer mismatches: required location nulls were omitted, estimate minutes were native numbers, and membership closures used a nested binding. Writers now emit the approved null/String/flat-target forms. Internal recovery readers retain legacy number/nested-target compatibility. The recovered public projection now also retains complete owned-link records rather than only display links. Native command, export, decode, checkpoint repair and reopen preserve existing content, flags, ranks and acknowledgements.

Three genuine migration tests initially compared legacy and current serialized shapes directly. Their independent expected-value conversion now accounts only for the declared grammar corrections; historical acknowledgement bytes remain compared exactly, and fixture files remain unchanged. An external-binding test corrected its label-association index against the independent fixture. A numeric-overflow observation uses Foundation's actual root-level invalid-JSON error instead of inventing a field path. An initial membership test setup incorrectly requested a review for an already approved direct removal; the corrected setup reaches the genuine format rejection. The first native iOS attempt failed compilation because the new tests referenced another file's private bundle anchor; it contributes zero runtime proof.

The unchanged 5,000-Item/5,000-new-membership fixture passed in 34.802 seconds before indexing and 1.176 seconds after indexing in separate focused Mac package runs. These are controlled measurements, not a general latency guarantee. The fixture still retains all 5,007 sources and 5,003 memberships without store creation or unresolved bindings.

## Qualification and limits

The execution record retains source epochs, logs, native summaries and test trees. Mac package and iOS 27 native Core each qualify 41 functions in 23 suites, 105 invocations, with zero failures/skips. Mac authenticated HTTP qualifies 14 functions in 3 suites, 20 invocations, with zero failures/skips. The native administration attempt includes decodeImport and creates no domain receipt. Eighteen affected Swift files pass strict lint; Mac app/host compilation passes, with zero native Mac UI runtime. Schema 14 and portable format 1 remain unchanged. Current local export/recovery compatibility and bytes-only validation do not prove reviewed import/apply, faithful restore, physical duplicate reconciliation or signed sync/account/Share behavior.

Native file selection/import/export forms, bound external dependency resolution, Skip/Overwrite review/apply, restoration persistence, event/status editor presentation and whole-app polish remain open. Native Mac UI runtime remains zero. The [new Calendar and estimate decisions](../container-estimates-and-calendar.md) have separate readiness and runtime gates; passing current decoder tests does not implement the amended archive-progress semantics.
