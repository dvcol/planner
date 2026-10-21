# Internally declared known restoration candidates

## Context, starting state and goal

Current Item X has live lifetime B and known candidate C in the same open restoration family. A backup declares X/C and a new List whose membership references C. Skip must preserve current X/B and its complete content while importing the new List against B. The immutable incoming backup must still contain C.

Before this correction, the decoder correctly reports no external bindings, but import only normalizes external paths. Review advertises the new List with its C dependency, then apply rejects the unresolved membership. A second accepted form declares X/B and the known B/C family, with its new List still referencing C. It needs the same result.

Accepted A20 in the [architecture packet](../architecture-review-packet.md) authorizes references within one approved family without an external-only restriction. The [portable contract](../portable-data-contract.md) permits new owners to reference conflicted live sources while Skip retains their current content. Neither rule permits predecessor redirects, new unknown candidates or unreviewed family consolidation. Q128's older-predecessor Overwrite choice remains separate and unanswered.

## Definition of ready

The approved public native Core seam covers decode, review, execute, export, query/read, acknowledged recovery, reopen and exact replay. Use real disposable storage with a current family already containing B and C. The two complete portable inputs differ in which candidate they declare; neither relies on an external binding or introduces new family authority.

## Definition of done and required /tdd

- Reproduce the misleading dependency preview and rejected apply with a valid declared-C backup; repeat it before changing production.
- Import the complete new List using current B, preserving its supplied membership identity, order and local Done state. Keep the current Item's content, lifetime, closure and family graph unchanged.
- Cover the declared-B/sibling-C form as another vertical red/green step. Do not infer its behavior from the declared-C pass.
- Verify preview nonmutation, live title and completion through public rows, acknowledged recovery, immutable input, reopen, exact replay and duplicate-free reimport.
- Rerun affected import/bookmark suites on Mac and actual iPhone Simulator, reconcile function/argument counts and current inputs/products, then check strict affected formatting and safe fixture disposal.
- Keep predecessor, closed-family, foreign-binding and Overwrite/restoration safeguards. Broader incoming-family reconciliation, native administration and physical acceptance remain open.

## Executed diagnosis and correction

The first tracer has compiler errors from using nonexistent query/read names. It is corrected to the existing public `query` and `read` interfaces before behavioral credit. The [valid declared-C run](evidence/navigation/core-native-import-declared-candidate-valid-red/) then fails at its expected B dependency and rejected apply. An [unchanged repeat](evidence/navigation/core-native-import-declared-candidate-repeat-red/) reproduces both issues.

The first production probe normalizes declared source candidates authorized by the current family. Apply, complete graph preservation, recovery, replay and reopen then pass, but the test's default Todo query hides its deliberately completed membership. Making the query explicitly include all completion/archive states corrects that test request; the [declared-C journey passes](evidence/navigation/core-native-import-declared-candidate-query-green/) without another production change.

The next [sibling-reference test](evidence/navigation/core-native-import-declared-family-sibling-red/) runs both declared forms. Declared C still passes; declared B with a C reference fails at the same dependency/apply boundary. Mapping source declarations alone is insufficient because C need not be the declared live source.

The final resolver uses the current graph's existing open-family authority to map its known source candidates to the live source lifetime, then passes the same resolved graph to review and apply. It does not change incoming source values, metadata, fingerprints or paths, and does not add candidate authority from the incoming file. The existing resolver still rejects predecessors and unrelated external lifetimes, while the earlier whole-owner Skip correction handles closed internally declared dependencies.

The [final focused run](evidence/navigation/core-native-import-declared-family-green/) passes both forms, including the complete current graph comparison, exact local completion, public row reads, recovery, immutable input and durable replay/reimport checks. No public form, schema, package, dependency, target or test seam changes.

## Qualification

The [affected Mac run](evidence/navigation/core-native-import-declared-family-affected-mac/) and [actual iPhone Simulator run](evidence/navigation/core-native-import-declared-family-affected-ios/) each pass 59 functions across 25 suites, comprising 231 executions. Both have zero failures, skips or SQLite unlink-while-open diagnostics. The existing safeguards include external predecessor/foreign rejection in both modes, closed internally declared dependent-owner skipping, family-wide deletion, complete-owner retention and recovery failure/replay behavior.

The existing fixture verifier disposes each successful run's 231 marked stores only after host and SQLite closure. The earlier successful declared-C fixture and final two focused fixtures are also disposed. Failed runs retain their original outcomes. The [qualification record](evidence/navigation/core-native-import-declared-family-affected-mac/qualification.json) reconciles every function's argument count, all 740 Core inputs, all 1,062 native inputs and the current native products' hashes.

Strict affected Swift formatting, Markdown lint and Git whitespace checks pass. [Q129](../native-import-new-candidate-skip-decision.md) asks how manual Skip should handle a candidate not yet authorized by the current family; no answer is inferred. Q128, incoming-family identity/provenance consolidation, broader internal forms, native administration, synchronization and physical/system acceptance remain open. These store results supply no native UI or physical-device credit.
