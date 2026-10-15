# Native traversal of every large-catalog List

## Context, starting state and goal

The approved large fixture contains 5,000 Items and 200 Lists, with twenty-five live children per List. The earlier [large collection journey](native-large-collection.md) already reaches List 200, checks its children and preserves the far-end Item after relaunch. The [unfiltered Item scrolling journey](native-large-catalog-scrolling.md) checks Item endpoints and selection. Neither records every intervening List row in both directions.

This slice must observe every expected List title and stable source identity through native scrolling, then return through the same collection. It changes no product behavior, contract or fixture data.

## Definition of ready

Use Q34's production native UI boundary and the existing Q52 dedicated fixture app. The durable fixture validates its exact source and membership counts through public Core queries/export. Each isolated dataset starts with active Todo sources and alphabetical catalog defaults. Native navigation, Item/List reads and the existing touch controller are available on the two simulator form factors. No signing or physical account setup is needed.

## Required checks and definition of done

- Start at Scale List 001 without search. Scroll with overlapping native touch drags, recording hittable List rows whose complete frames fit inside the catalog, together with their source identities.
- Require all 200 expected titles, exactly 200 distinct identities and ascending visible row order. Reobserving a title must retain its identity.
- Open Scale List 200 and require its twenty-five-child progress and expected first child Scale Item 00200.
- Return through the catalog to Scale List 001. The complete backward title/identity map must equal the forward map. Reopen List 001 and require its expected twenty-five-child progress and Scale Item 00001.
- Run the single focused native function on phone and tablet. Retain original commands, logs, results, source/product hashes, observed identities and captures. Inspect the captures, run strict changed-file Swift/Markdown lint and compile the affected Mac test target without claiming Mac runtime.

The result concerns represented native List traversal and stable selection. It does not establish complete intermediate rendering of 5,000 Item rows, retained-data memory bounds, scrolling hitches, physical 300 ms response, all sort/filter combinations or accessibility. Physical sync/account/Share, Mac runtime and final whole-app polish retain their gates.

## Execution

Both simulator qualifications pass. Production sources and the fixture remain unchanged.

The first phone attempt was deliberately interrupted with exit 75 before qualification. It recorded an interrupted/failed test result, rather than a product assertion failure. Its original source, log, summary and first-screen capture remain separate. Source review found that returning from a selected List also needs the native Show Sidebar action on iPad. The corrected controller uses native Back or Show Sidebar and asserts that the far-end catalog row remains reachable. It also snapshots each row's title, identity and vertical position once per observation before sorting those values, reducing repeated XCTest attribute reads. The expected titles, 200-identity requirement, frame containment, hittability and endpoint data assertions remain unchanged.

The corrected phone and tablet journeys pass against the same frozen sources and compiled mobile products. A separate affected Mac fixture/test-host build passes with zero Mac runtime functions. No production, Core or HTTP change requires a new unit test in this slice; their existing qualification is reused, not rerun. These coverage additions make no product red-green claim.

The phone function passes in 868.512 seconds, with zero failures/skips. Its original identity attachment contains all 200 expected names and 200 distinct source identities. All five original phone PNGs were individually viewed. List 200 details show its expected first Item and 0 of 25 done; List 001 details show its expected first Item after the complete return. At the far-end catalog checkpoint, the floating tab bar partly obscures List 200 even though XCTest can hit it and open the correct contents. The frame/hittability oracle is not a pixel-readability guarantee, and this capture does not establish whether an additional scroll could reveal more. Whole-app visual polish remains open.

The tablet function passes in 1,292.805 seconds with zero failures/skips. Its backward identity map equals its complete forward map; the retained original attachment independently lists all 200 names and distinct identities. All five original tablet PNGs were individually viewed. The tablet uses the native sidebar reveal to return from selected List contents, with List 200 retained in the content pane while the catalog is scrolled back to List 001. Both endpoint contents are readable in their captures. Floating toolbar/sidebar overlays remain visible and receive no general adaptive-polish sign-off here.

These elapsed times include fixture preparation, thousands of XCTest attribute reads and touch automation; they are not app response-time measurements. The tablet executes without rebuilding while the phone run uses the same compiled products. Its before/after product hashes match the phone products exactly. All 213 source/configuration hashes per phase are frozen, with the interrupted controller's earlier source recorded separately. The Mac build passes with signing disabled and zero Mac runtime credit.

Strict single-file Swift format lint, report Markdown lint and staged whitespace checks pass. Standards and Spec source reviews have no remaining findings. The [evidence packet](evidence/navigation/native-large-list-traversal/) includes the interrupted attempt, successful original results, ten individually inspected final PNGs, the earlier inspected PNG, observed identities, commands, source/product hashes and verification script. Production/fixture/Core/HTTP sources remain unchanged from 5b3d401. Disposable fixture stores remain retained; no cleanup is claimed.
