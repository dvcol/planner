# Archived membership progress after global reopen

Status: the focused public Core journey passes with a corrected test expectation. Production behavior is unchanged.

## Context and expected state

The Q93 creation compatibility run found two failures in `listedItemLeavesInboxAndEveryWriterRetainsIndependentMemberships`. Its Item remains Archived when globally reopened. Both Lists retain local Todo memberships, but the old assertions expect partial progress.

Accepted Q68 B and the [finished-appearance definition](../../GLOSSARY.md) require archived children to finish container progress without changing Done flags. Each List must remain Complete with zero Done, one Archived and one total child. The test now states those separate values explicitly.

## Definition of ready

The archive rule is already approved. The existing public Planner command, source/query and recovery boundaries supply the journey; no new interface, fixture injection or product decision is introduced. The original membership test is unchanged on committed base `ebcca9d0cd170aa6367482a5db17bc0e8e7f799a`.

## Required checks and definition of done

Run the exact failing function against an unmodified committed package export before attributing its failure to Q93. Change only the expected progress state and add the archived count. Run that same function with unchanged base production sources, verify the source difference, and run affected Swift and report Markdown lint.

## Results and limits

The unmodified base fails one function with two issues at the partial-state assertion in 0.333 seconds, matching the Q93 working-tree failure. The base export with only this test correction passes one function with zero failures/skips in 0.335 seconds. All production source and resource hashes remain identical between those runs. The corrected test file matches the working-tree file byte for byte.

The [evidence packet](evidence/navigation/core-archived-membership-progress/) records commands, original compressed logs, exact base/overlay source hashes and the tested source. This resolves the stale assertion independently of the uncommitted Q93 implementation. It supplies no new native UI, HTTP, physical-device, CloudKit or whole-map completion evidence.
