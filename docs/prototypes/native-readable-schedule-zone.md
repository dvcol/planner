# Readable time zones in Schedule editors

The Item and Itinerary editors now use the same readable location name as the
native timezone picker. For example, the selected row shows New York rather
than `America/New_York`. This reuses the existing formatter. Saved identifiers,
appointment instants, occurrence choices and Schedule descriptions are unchanged.

A phone reproduction fails on the original editor's `Europe/Paris` value after
selecting Paris. The corrected Item and Itinerary journeys pass on light iPhone
and dark iPad. They cover Paris, New York and Tokyo, staged cancellation, saved
timezone changes, retained notes, Schedule/owner identities and relaunch.

The Lord Howe phone regression also passes: repeated 01:45 requires an explicit
choice, and both half-hour occurrences retain their represented instants and
Schedule identity through relaunch. These are five final native executions
across three functions. Six selected final editor/saved-state originals are
inspected; this is not a full accessibility or appearance audit.

The first tablet cohort passes the Item case but stops before the Itinerary
editor because its old driver expects a visible section button while the
sidebar is closed. The committed base reproduces that same failure. The driver
now uses the existing sidebar-aware navigation helper. Both failed diagnostics
remain separate from the final passing cohorts.

All 1160 final native inputs match the workspace and Mac app/Share/UI-test
compilation. Strict affected Swift and Markdown lint pass.
[Final verification](evidence/native-readable-schedule-zone/final-validation.json)
records the actual cohorts; execution records have read-back hash verification.

Actual Mac interaction, broader scene/assistive review and physical/signed-store
qualification remain open. Signing stays deferred, and advanced portability
stays post-MVP. This checkpoint covers the editor's selected timezone row.
