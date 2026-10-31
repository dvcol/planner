# Item containing plans

Item details now have a native Plans disclosure beside the saved List count.
Opening it shows the containing List and Itinerary names. An Itinerary reached
through a containing List also appears, and repeated stops show its name once.
Lists sort before Itineraries, then by name and identity. The labels wrap within
the pane and expose their plan kind to accessibility.

Names load only while the disclosure is open, using existing Core source reads.
Dataset, source lifetime, reference and change-revision checks prevent obsolete
reads from replacing the current names. A failed read offers Try again instead
of reporting that no plans exist. The disclosure is read-only and adds no
navigation or completion action, persistence, public interface or test boundary.

The existing independent-writer native fixture supplies one Item, one List and
an Itinerary containing the Item directly and the same List twice. Its new
journey checks that each plan appears once, removes the direct stop and still
finds the Itinerary through the List, then renames both plans through the real
writer. Removing the remaining membership hides the names. The Item's exact
identity, notes and unfinished global state survive relaunch.

The initial red stops at the missing Plans disclosure. The first implementation
renders both names but the parent accessibility identifier overrides their row
identifiers. Moving the disclosure identifier to its label corrects that native
accessibility propagation. The fixture's initial formatting correction and the
later icon-branch style correction have their own retained source epochs.

The final-source journey passes on iPhone and dark iPad with no failures, skips
or SQLite-unlink diagnostics. Both original captures are inspected and retained.
All 1160 native inputs match the workspace and both Mac compiler roots. Mac app,
Share and native-test compilation verifies nine products; the actual fixture app
and its tests additionally compile with four verified products. Strict affected
Swift formatting, Markdown lint and whitespace checks pass.

The validation packet
keeps the earlier failures and passing source epochs separate from these final
executions. The iPad appearance is restored after each dark-mode run.
Actual Mac interaction, broader accessibility and physical/cloud acceptance keep
their existing gates. Signing stays deferred. Optional export/import and advanced
manual import recovery remain outside MVP.
