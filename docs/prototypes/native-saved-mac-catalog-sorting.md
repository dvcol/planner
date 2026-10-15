# Saved-data Mac catalog sorting

## Context and starting state

Q87 approves shared Core/agent List and Itinerary catalog sorting, estimate-certainty groups, stable ties and per-device/dataset native preferences. Core, real HTTP and phone/tablet qualifications already exist. At bad1718, the canonical catalog UI journey is iOS-only, so Mac compilation supplies no saved-data runtime proof. The earlier [Mac diagnostic handoff](native-mac-container-catalog-sorting.md) retains unsuccessful adapter attempts and their precise limits.

## Goal and definition of ready

Port the existing two public native UI journeys to Mac using the same disposable catalog-sorting fixture and production views. Native sidebar identities, menu titles, toolbar overflow and actual Toggle roles must replace mobile-only controller assumptions. Production behavior, public contracts, saved data and existing mobile interactions remain unchanged. The user confirmed that the Mac is unlocked and idle for this retry; this establishes the requested test condition without proving the cause of earlier foreground failures.

## Required tests and definition of done

- Observe every declared List and Itinerary catalog order through native controls. Verify separate selections, relaunch persistence, new-dataset defaults and restoration of the first dataset's choices.
- Preserve the selected List during catalog sorting. Remove a shared Item's estimate through its native edit form, then observe the corresponding incomplete-estimate placement in both catalogs. Preserve the containers' own Last updated semantics and the final archive/sort result.
- Pass both actual Mac UI functions, inspect original fixture-window captures, record exact source/product hashes and results, and keep failed adapter probes separate.
- Run strict affected Swift/Markdown lint and corresponding focused mobile compatibility checks for shared controller changes. Production Core/HTTP remain unchanged, so their previous tests are reused rather than repeated.

These are coverage and native-controller changes, with no product red-green claim. This slice qualifies the represented Mac workflows. Full Mac accessibility, resizing, account recovery, signed CloudKit/Share, performance and whole-app polish remain open.

## Execution

The following attempts precede final qualification. The first unlocked/idle retry passes persistence and dataset isolation in 119.057 seconds. The live-estimate journey preserves the selected List during sorting, then fails at its initial Toggle-state check in 42.753 seconds. That attempt had not changed the estimate or reached subsequent catalog refresh checks. A separate window-scoped observation distinguished the native control role from a value-format mismatch or unexpected initial form value. No production fix was inferred from this controller failure.

The 43.244-second observation run reproduces the controller failure and identifies the actual control: a Switch with the expected identifier and value 1. The form retains the expected 60-minute estimate. The controller now targets that identified Mac control directly; the mobile child-Switch query remains unchanged. Temporary window logging and the extra diagnostic screenshot are removed. Both Mac functions were rerun on this corrected source. No production data or behavior changes were needed.

## Final runtime result

Both functions pass on the same corrected source and compiled Mac products, with zero failures or skips:

| Journey | Mac function elapsed time |
| --- | --- |
| Catalog order, preferences, relaunch and dataset isolation | 119.001 seconds |
| Selected List, native Item edit, live estimate refresh and archive/sort consistency | 98.358 seconds |

The final source/configuration epoch contains 214 hashes. This is a locally signed fixture/test-host run through the project's existing Sign to Run Locally configuration; it requires no developer-account setup or CloudKit access. All 15 original fixture-window PNG files were individually inspected, including eight from the complete final run and seven from the earlier diagnostic attempts. Their titles, orders, selected content and native edit form agree with the assertions. Narrow sidebar summaries truncate and middle-column summaries wrap; adaptive layout and visual polish remain unqualified. The collector copies only explicitly named fixture-window captures, unchanged. Automatic desktop/failure images remain local. Earlier successful assertions inside failed attempts do not replace this complete two-function pass. The retained result includes a non-failing internal priority-inversion warning. This run provides no latency or responsiveness qualification, and the warning remains available for the performance investigation.

## Compatibility and limits

The final test source differs from the preserved two-function phone compatibility source by exactly one line, inside the macOS-only Toggle branch. Every other source byte is identical. That earlier phone run passes both functions in 121.599 and 108.371 seconds; its original results and the exact comparison are retained. Mobile interactions, the original phone/tablet feature qualifications and production Core/HTTP behavior are reused. This slice credits no additional mobile invocation.

Strict changed-file Swift lint, report Markdown lint and whitespace checks pass. Independent Standards and Spec source reviews found no remaining findings. The packet verifier checks each source epoch, exact mobile compatibility, native role observation, final compiled products and original capture hashes.

The work changes only the native test controller and its report/evidence. It adds no production dependency, public API, schema, data migration or view change. Fixture datasets remain isolated local data, with no cleanup claimed. The earlier foreground failures remain historical and unqualified; this successful idle retry does not establish their root cause. Native resizing/accessibility, other saved Mac workflows, physical sync/account/Share and whole-app polish remain open.
