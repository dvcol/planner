# Readable saved Schedule summaries

Saved Item and Itinerary cards now use the picker's readable timezone location
name, matching their editors. The original phone reproduction shows
`Europe/Paris`; the corrected card shows Paris. One computed display expression
changes. Date formatting, saved forms and Core behavior stay unchanged.

Seven final native executions across five functions pass:

- Item and Itinerary cancellation, timezone changes, retained notes, identities
  and relaunch on light iPhone and dark iPad.
- Both Lord Howe half-hour occurrences and a New York clock-change span retain
  their represented instants. Explicit occurrence choices, endpoint offsets and
  invalid end-time rejection remain intact through cancellation and relaunch.
- Calendar retains the same start-only appointment caption after relaunch.

The native test parsers now take their fixture's expected timezone explicitly;
human-readable location labels supply presentation assertions. All 1160 final
native inputs reconcile with the workspace and Mac app/Share/UI-test compilation.
Strict affected Swift and Markdown lint pass. Seven selected final originals
and the before capture are inspected, with the executed function identities
checked against each actual test command.

[Final verification](evidence/native-schedule-summary-zone/final-validation.json)
and the compacted execution records retain the failed reproduction and final
cohorts. These checks cover the represented summaries, not full accessibility
or physical acceptance.

Actual Mac UI remains unqualified. Read-only host checks still show the
14 October boot and 17 October native test-broker start, so an unchanged startup
attempt is not repeated. Signing and physical Share/sync checks remain separate.
Advanced portability stays post-MVP.
