# Native creation, selection and saved Maps links

Status: Q88-Q92 accepted by the user on 2026-10-15. Implementation and qualification remain open under Navigation prototype and the final native UI polish gate.

## Context and starting state

The List toolbar's plus button adds an existing Item. Capture Text or Link is a separate actions-menu entry. The ordinary New Item sheet has only Title, Notes and activity estimate, while Edit Item and capture review expose richer authored fields. The user could not create an ordinary Item directly inside a List or enter its address during ordinary creation.

Confirmed deletion clears invalid Item/List selections and shows an explanation. That preserves identity and action scope, but leaves an empty detail pane even when visible survivors exist. The accepted A3 rule still preserves a valid selection when filters hide its row.

Maps capture has temporary Apple previews and simulator evidence. Google coordinate/text-search parsing has controlled Core coverage, but no native Google creation journey. Saved address/pin maps exist. A Maps bookmark alone currently supplies no map in saved details because provider results remain temporary under C1/C10/C12.

## Goal and expected end state

Q88 A replaces the List plus action with one native Add menu containing New Item, Add existing Item and From Link or Text. New Item saves one shared source Item and its originating-List appearance together. Cancel creates neither. The originating List identity remains explicit and cannot change silently while the draft is open.

Q90 A presents the unsaved editor in the detail column on Mac and wide iPad, and in a native pushed page on compact layouts. Use native NavigationSplitView, NavigationStack, Form, fields, pickers and toolbars. Creation offers the existing authored content controls for title, subtitle, notes, activity estimate, Category/Tag identities, place name/address and ordered bookmarks. Existing shared editor components should supply these fields. Native scheduling retains its own command and validation rules.

Q91 A guards navigation away from an edited draft with native Save, Discard and Keep Editing choices. Save validates normally; invalid data keeps the draft and useful errors. Discard creates nothing; Keep Editing cancels navigation. An untouched blank draft can close without a prompt. Resizing or collapsing navigation retains the same draft, operation identity and original destination. A saving operation disables repeated submission and conflicting navigation until its result is known.

Q89 A selects the first visible surviving row, using the current context's filters and sort, when confirmed deletion removes the selected identity. After deleting a selected List, regular Mac/iPad layouts select the first visible List and its first visible Item when available. Compact iPhone returns to the containing list without pushing an unrelated Item detail. Empty results retain a real empty state. Deleting an unselected row preserves the valid selection. Filtering a still-valid selection out retains A3 behavior. A replacement uses its own source/appearance identity; it never turns a contextual command into a global command.

Q92 A adds a temporary map card derived from a saved Maps bookmark. Owned location takes precedence. Preserve the exact bookmark and keep provider results outside owned fields and backups. Load only when needed, reuse the production preview boundary, cancel obsolete requests and reject late responses for changed/deleted links or sources. Unavailable or ambiguous lookup retains a useful link/fallback. Google search intent must not be represented as a resolved business. Relaunch may require another lookup. This does not adopt provider fields or introduce a new saved pin.

## Definition of ready

- Q88-Q92 and the existing completion, archive, capture provenance, recovery and selection policies are read together. This document changes deletion replacement and creation presentation while retaining valid-selection and scope rules.
- Inspect the production native editor, capture, query and preview boundaries before writing tests. The initial Capture reuse proposal is superseded by [the atomic ordinary creation contract](create-item-in-list-contract-review.md): Capture exact-URL deduplication cannot preserve distinct ordinary authored bookmarks.
- The ordinary creation writer must insert content, labels, optional membership and receipt before one local save. Independent recovery publication has its existing separate outcome; never misreport an applied local operation as unapplied when recovery publication fails.
- Select literal fixtures, native actions and expected values before each /tdd slice. Keep provider I/O tests at the accepted production boundary rather than adding test-only production parameters.
- Native Mac and both simulator form factors are available. Signing/physical sync and Share remain deferred and cannot be credited by these local tests.

## Required tests in /tdd

1. Start with List A, another List B and no matching source Item. From A's native Add menu, open New Item. Enter rich authored content, then Cancel. Neither a new source nor an A appearance exists. Repeat and Save; exactly one source and A appearance exist with the entered fields, stable identities and local Todo. B remains unchanged. Repeated submission does not duplicate the receipt or graph. Reopen/relaunch and verify the values.
2. Verify every Add-menu branch, including existing-Item reuse and Maps/text capture, still targets the originating List. Changed/deleted/archived destinations require explicit refreshed review or correction and never silently create elsewhere. Save failure preserves the draft and reports its actual local/recovery outcome.
3. Open an edited draft, attempt Back, another row and another destination, then exercise Save, Discard and Keep Editing. Invalid Save retains the entered data and destination. An untouched blank draft closes without a prompt. Resize/collapse the regular layout while editing and retain the same draft. Inspect real column/page presentation and keyboard focus on Mac, phone and tablet.
4. Build a nonalphabetical sorted/filtered fixture. Cancel deletion and retain the selection. Confirm selected Item deletion and select the first visible survivor in the same scope. Delete an unselected Item and retain the selected identity. Delete the selected List and select the first visible surviving List/child on regular layouts. Verify compact back navigation and actual empty results. Delayed refresh must not overwrite a newer user selection or use an obsolete dataset/query.
5. Demonstrate native Google Maps capture and its exact retained bookmark, then show the saved-link map card. Cover Apple Maps compatibility, owned-location precedence, unresolved/ambiguous/error results, Retry, changed/deleted source/link, delayed responses, relaunch and provider-cache exclusion from backup. Controlled results qualify deterministic behavior; live-service availability and tile/offline behavior remain separate evidence.
6. Rerun affected native completion, live-reference, Add-existing/capture, deletion, rich-editor and preview journeys. Use focused Core/preview/real HTTP checks only where those production boundaries change. Run strict affected lint and compiler checks. Record function counts, source epochs and actual native captures separately for each platform.

## Definition of done

Each slice has a witnessed failing public-boundary test before its implementation, followed by passing affected checks and inspected actual layouts. The completed graph, query, draft and preview states match the literal before/action/after fixtures. Required compatibility remains intact. The map links the conventional implementation commits and evidence; incomplete physical, accessibility, performance and whole-app polish gates remain explicit.

Apple's [sheet guidance](https://developer.apple.com/design/human-interface-guidelines/sheets) supports scoped temporary tasks, while [adaptive split navigation](https://developer.apple.com/documentation/technotes/tn3154-adopting-swiftui-navigation-split-view) supports column/stack presentation. Q90 chooses the latter for Planner creation; native sheets remain valid for other scoped tasks.
