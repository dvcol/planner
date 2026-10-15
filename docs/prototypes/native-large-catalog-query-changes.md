# Native large-catalog query changes

## Context and starting state

The accepted Navigation prototype requires native search, sort, valid selection and complete query refresh on a 5,000-Item/200-List dataset. The existing large journey finds Item 05000 and preserves completion after relaunch. Core separately qualifies full ordered paging and refresh after another writer. Those checks do not exercise replacing native search text, switching native sort and revisiting the same source at this size.

## Goal and expected end state

Use the existing production Item catalog with the large fixture. Replace a broad search with Item 04999, then replace a nonmatching search with Item 05000. Each final search must show exactly its intended source. Read their independently seeded notes and unchanged Todo state. Hide the selected far-end source using the Done filter and restore it with Todo, retaining its identity and valid details on layouts that show details alongside the catalog. Search for Scale Item 0499. Literal substring matching includes 00499 and 04990 through 04999. Created descending must show 04998 above 04997 above 04999, while Title ascending must show 04997 above 04998 above 04999. Each simultaneous three-row predicate distinguishes the selected field/direction and requires an observable transition between modes. Return to the far-end search with the same source identity. This small result permits inspecting order without assuming that changing sort resets a saved scroll anchor.

## Definition of ready

Use the already accepted production-view XCTest seam, native search/filter/Menu/Picker controls and the public Core-seeded disposable large fixture. Expected titles and notes retain their existing fixture values. Give Item 04999 creation offset 4997 while Item 04998 retains 4998, so Created descending must differ from Title descending. Their last-update dates remain unchanged and at least as late as creation. No new production parameter, mock or public query contract is required. Q86 does not affect existing Item sorts.

The three observed sources have distinct ordering under every field/direction combination. Created-date ties use the existing ascending Title tie-break.

| Mode | Relative order of the three sources |
| --- | --- |
| Title ascending | 04997, 04998, 04999 |
| Title descending | 04999, 04998, 04997 |
| Created ascending | 04997, 04999, 04998 |
| Created descending | 04998, 04997, 04999 |

## Required tests and definition of done

Run one focused native journey on phone and tablet. Require a sole final search row, absent prior search rows, the same source identity when revisited, expected notes and Todo state. Native Created descending and Title ascending must show the independently expected visible three-row sequences. Capture original native screenshots and observed identities, retain source/product hashes and raw outputs, and run affected Swift/Markdown checks. If existing behavior fails, retain the failing run before changing production and rerun the focused journey.

## Execution and limits

The first phone run fails in the controller because a Button-only helper queries a native completion Toggle. The controller now uses the established any-role query for that Toggle. This is a test setup failure, not a functional red. Source review also found that the original fixture's Created and Title orders coincided. The revised creation date above makes an ignored sort field observable.

Two intermediate phone passes retain their earlier pair-only assertions and receive no final transition-proof credit. Review then required the simultaneous three-row predicates and an order-aware reveal loop. A run of the superseded reveal controller was deliberately interrupted; its result says Testing was canceled. That interrupted invocation is retained as diagnostic history, with no product-failure or completed-qualification claim.

The next phone run fails when the controller tries to reopen Sort after selecting Created. Its captured hierarchy still contains the open native menu's choices. The controller now handles an already-open menu and dismisses it through the existing Search field when necessary, rather than assuming every picker action immediately closes the menu. The same hierarchy establishes that substring 0499 also matches Item 00499; the expected search scope above reflects that literal behavior. Production remains unchanged.

That revised phone journey passes in 153.609 seconds. The first tablet run then stops when typing after Clear because the native field has lost keyboard focus. The controller now explicitly reactivates Search before typing and verifies its final value. The earlier phone pass and tablet focus observation remain separate from final qualification. This interaction does not establish a no-focus-loss guarantee for native Clear.

The final source passes one focused function on each iOS 27.0 simulator, two final invocations, with zero failures/skips. The iPhone 18 Pro run takes 171.116 seconds; the iPad Air 11-inch M4 run takes 163.062 seconds. Each final search has exactly its intended source row. Both runs retain Item 05000's identity, notes and Todo state after query changes. The tablet additionally retains its selected detail when Done filtering hides that Todo row. The Created and Title three-row sequences match their independent expectations.

Five original screenshots per final run, ten total, were individually inspected. Native captures show the different row orders, the selected source's notes/completion and tablet detail retention. The [evidence packet](evidence/navigation/native-large-catalog-query-changes/execution.json) retains raw logs, result summaries/trees, observed identities, source/product hashes and earlier revisions. Exported text attachments and their original manifests are preserved losslessly in compressed archives. The affected Mac fixture app/test host compiles with one build job and signing disabled; no Mac UI test runs. Strict formatting passes two Swift files and the report passes Markdown lint.

Production behavior is unchanged. This adds a native qualification and one adversarial fixture date, without a manufactured functional red, a new Core contract or a unit seam for private controller helpers. Existing Core paging, store and HTTP qualifications retain their separate scope.

This tests observable native query changes at XCTest input speed. It does not prove that two storage queries overlap or that an executing query is interrupted. Deterministic in-flight cancellation, full native traversal, bounded row-data memory, scrolling hitches, Mac runtime and physical 300 ms latency remain separate gates. The system search-empty hint still suggests checking spelling when a completion filter hides a known match, and the tablet keyboard limits lower-row preview space. Whole-app keyboard/layout and empty-state polish remain open. Q84 C and the pending Q86 choice are unchanged.
