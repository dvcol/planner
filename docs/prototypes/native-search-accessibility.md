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

## Open review

The native clipping audit still fails. Successful matching and Clear behavior
do not close that warning or establish complete accessibility. The permanent
functional journey has no audit-suppression handler and claims no clipping-audit
pass. Production search, persistence and Core behavior are unchanged.

[The execution evidence](evidence/native-search-accessibility/final-validation.json)
separates the failed clipping/presentation probes from final functional checks.
Human/assistive UI review, actual Mac interaction and signed/physical tests
remain open. Signing stays deferred and advanced portability remains post-MVP.
