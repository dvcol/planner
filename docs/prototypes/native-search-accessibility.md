# Native search at maximum text size

The core UI review reproduces the Inbox text-clipping warning on the native
UISearchBarTextField at maximum accessibility text size. Explicit toolbar
placement and Apple's [compact toolbar-search behavior](https://developer.apple.com/documentation/swiftui/searchtoolbarbehavior/minimize)
leave the represented warning unchanged. Both probes are reverted. The earlier
short-prompt probe remains recorded in the Item-title review and is not repeated.

## Functional search checkpoint

A permanent native journey creates one saved Item, enters its complete long
title as a query, verifies the match, then enters a different exact query and
verifies the empty result. Native Clear restores the same public Item identity.
Phone and iPad pass in dark appearance with Increase Contrast at maximum text
size. Four original matching-query and cleared-query captures are inspected.
The complete text remains available through the native field's value while its
visible text scrolls horizontally.

After returning from creation, the phone journey reveals the native search
drawer before editing. On iPad, Clear ends keyboard editing in the represented
scene. The permanent journey explicitly refocuses before typing the next query.
An explicit native search-presentation binding does not remove that observed
focus transition and is also reverted. This checkpoint does not claim continuous
keyboard focus after Clear.

The final phone journey, already-passing iPad journey and Mac compilation share
all 1160 native input hashes. The iPad run is reused only after checking those
hashes against the actual final workspace. Source identity is checked through
filter changes and Clear; no relaunch claim is added. Mac runtime remains
unqualified. Simulator settings are restored and strict affected lint passes.

## Original open review

The native clipping audit still fails. Successful matching and Clear behavior
do not close that warning or establish complete accessibility. The permanent
functional journey has no audit-suppression handler and claims no clipping-audit
pass. Production search, persistence and Core behavior are unchanged.

The execution evidence
separates the failed clipping/presentation probes from final functional checks.
Human/assistive UI review, actual Mac interaction and signed/physical tests
remain open. Signing stays deferred and advanced portability remains post-MVP.

## Responsive native editor

The shared collection-search modifier now uses its existing native Form sheet at
accessibility text sizes. Queries wrap vertically without reducing the chosen
font size. Search lives in the native More menu at those sizes so the narrow
pane title keeps its space beside Filters and Add. Ordinary collection search
retains Apple's search field; ordinary phone Map search retains its existing
sheet. Items, Inbox, List contents and Itinerary contents share the modifier.

Done applies the query through the existing dismissal binding. Native Clear
retains the saved Item/appearance and other filter criteria. No custom keyboard
interception, provider request, Core interface or persistence change is added.
A trial keyboard-submit convenience did not work with the multiline native
field in this runtime and is removed; Done remains the explicit apply action.

The original maximum-text phone audit reproduces the UISearchBarTextField
clipping warning. A directly visible Search-button trial fixes that field but
crowds the iPad pane title. Moving Search into the native overflow menu fixes
that reproduced title issue. The retained diagnostic runs remain separate from
final functional and clipping-audit credit.

The existing Inbox journey now audits the initial catalogue, empty query editor
and entered wrapping queries without a suppression handler. It verifies an
exact long match, an exact no-match result and Clear restoring the same Item.
The existing Itinerary journey verifies the query after switching destinations.
Native test helpers open the real overflow action and query its actual input;
there is no production test control or new test boundary.

The ordinary-text audit probes a different search presentation. Catalogue loading
and cancellation now sit outside the conditional search modifier so presentation
changes do not own the data loader's lifetime. An earlier trial entered the
Opening Items state after Clear; another tried to tap the field after the audit
replaced it. The final ordinary journey edits and clears first, audits afterward,
and verifies the same saved Item remains available. Its native execution passes
in 44.591 seconds, with no failed-audit suppression.

Final qualification on 30–31 October is seven passing native executions across
four existing functions, with zero failures or skips. The light maximum-text
phone and dark maximum-text iPad pass the clipping and exact query/Clear checks.
The iPad also retains its Itinerary query across destinations. Ordinary dark
phone checks cover query/Clear, row completion/relaunch and the existing Map
flow; ordinary iPad retains its native minimized Map search and exact pin.

The compact review packet
separates diagnostic trials from final credit. All production inputs match the
final workspace. A later Map-controller-only adjustment restores the original
non-sheet native-button path and is separately qualified on ordinary iPad.
The inspected phone query
and iPad title
confirm wrapping input and a readable narrow-pane title.

Strict affected Swift lint, whitespace checks, simulator/Mac/signed-mobile
builds and deep/strict app/runner signature checks pass. Mac runtime awaits
manual automation approval for two prepared existing journeys. Actual VoiceOver
and final whole-app/physical acceptance remain open. No additional iCloud test,
account transition or installed Mac replacement is performed by this checkpoint.

## Single overflow owner, 31 October 2026

The accessibility Search modifier's own `ToolbarOverflowMenu` can replace the
collection's existing overflow content. The maximum-text phone route journey
reproduces this: only Search appears, so View cannot open Map. Search now uses a
native secondary toolbar item and joins the collection's overflow menu instead
of declaring another one. This changes one production line and preserves the
query editor, identifiers and dismissal behavior.

The unchanged route journey now reaches Map, calculates all three walking and
driving legs, and opens Public transport. It subsequently fails because the
Museum marker overlaps Garden and opens Garden; that separate layout finding
receives no passing Map credit here. The unchanged Inbox query/Clear journey
passes in 88.761 seconds and Itinerary query retention passes in 51.986 seconds,
both in actual dark mode at the largest accessibility text size. Inspected
captures retain a readable Inbox title and the query editor. The
review packet
separates the original menu failure, partial route progress and passing search
regressions. Simulator compilation, strict affected-file formatting and
whitespace checks pass. Mac runtime, physical use and broader acceptance retain
their separate gates; no iCloud test is added.
