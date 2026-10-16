# Atomic ordinary Item creation in a List

Status: the Core portion of approved Q93 A passes focused qualification. Native creation and MCP adoption remain required.

## Context and expected state

Ordinary Item creation previously saved no List membership. Following it with a separate membership command could leave a partially completed user action. Capture is unsuitable for authored creation because it deliberately deduplicates repeated URLs.

The [approved contract](../create-item-in-list-contract-review.md) adds an optional `listId` to ordinary creation. A supplied active List receives one local Todo membership at its saved end, in the same transaction as the Item, authored links, label associations and operation receipt. Omission preserves the original payload representation and historical receipt replay. No schema change is required.

The destination lifetime joins the operation binding. An optional creation review additionally binds its name-field hash and the complete command. Rename, replacement, changed content or removal of the reviewed destination rejects that review; unrelated membership edits remain valid. Replay retains generated identities and never restores a subsequently removed membership.

## Definition of ready and required checks

The human approved the public command/read, real persistence I/O, HTTP and native UI test boundaries. This slice uses the first two boundaries. Tests cover rich ordinary content and duplicate bookmarks, ordered membership insertion, stale destination review, invalid content and labels, absent/archived/deleted destinations, same-identity restoration with a new lifetime, replay after removal, actual save failure and incomplete recovery after commit.

## Results

The [evidence packet](evidence/navigation/core-item-in-list-creation/) retains each source epoch and its original output. `membership-red` fails because the accepted destination produces no membership; `membership-green` passes after atomic membership creation. `destination-review-red` rejects the missing review capability; `destination-review-green` passes after adding it. `review-command-red` exposes a reviewed creation becoming global when its destination is omitted; the final implementation rejects that changed command.

`file-limit-rollback-red` uses a process-local file-growth limit at the real native save boundary and records SQLite I/O error 778. The database rolls back, but prepared recovery evidence incorrectly prevents an unchanged retry. `file-limit-rollback-green` passes after removing that proposal on a known failed save. The limit exists only inside an isolated test child and is restored before verification. Postcommit recovery obstruction separately proves that an applied graph remains applied and can repair its independent recovery copy without creating duplicates.

The final `core-review-qualified` run passes 28 functions in nine suites in 2.030 seconds, with zero failures or skips. It includes eight new Q93 functions, an additional isolated child invocation, existing creation/labels/membership/Capture compatibility and genuine V1–V5 migration/receipt journeys. Strict Swift lint passes all nine affected Core/test files.

Earlier `api-red` and `replay-qualification` epochs contain compiler failures and receive no runtime credit. An attempted SQLite trigger caused native optimistic-lock recovery to terminate in `sqlite-rollback-red`; that injection was discarded. The earlier `core-qualified` batch exposed an independently verified stale archived-progress expectation, corrected in [its own report](core-archived-membership-progress.md). Only the final passing batch receives complete compatibility credit.

## Review and limits

Standards review found fixture teardown unlinking stores while cached native containers could remain alive. Named test stores now remain on disk until external cleanup after process exit. Spec review found a throwing fetch after preparing recovery evidence; all throwing preparation now precedes proposal creation, and the native save remains inside rollback/proposal cleanup. Both reviewers rechecked their corrections and report no remaining confirmed findings in this Core slice.

This evidence does not qualify HTTP adoption, native creation/navigation, physical devices, CloudKit, Share signing, performance, accessibility or final UI polish. Q93's complete definition of done remains open until its adapters and native journeys pass.
