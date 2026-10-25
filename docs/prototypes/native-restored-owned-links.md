# Restored source owned links

## Local checkpoint, 25 October 2026

Q161 A keeps a winning source's complete owned contents. This first slice handles
bookmarks owned by losing Item and Itinerary candidates. It does not merge links
or change the winning source's fields, lifetime, links or edit timestamp.

The existing source-restoration maintenance projection now admits exact native
links belonging to a proven losing source. It validates their saved binding and
native owner relationship before excluding them from the proposed graph. The
same durable maintenance transaction deletes those links and their losing owner.
Every other stored reference must still appear in the complete proposed graph or
qualify through an existing rebinding rule. Unsupported owned contents reject
without modifying storage.

This reuses rule3, writer gate23, portable5, physical model19 and recovery
envelope2. No public interface, package, target or test seam changes.

## Verification

The new real-store tracer first failed with the original live-relationships
guard. With the correction, an Item keeps Guide A, loses the competing Guide B,
and retains its complete original source/link/family graph. Unrelated sources and
old command receipts remain unchanged. Recovery preparation contains the actual
projected graph; reopen and repeated delivery preserve the same public result.
The equivalent losing-Itinerary case preserves independent Items and leaves an
empty winning link collection empty.

A real unwritable recovery directory prevents preparation. Both candidate
lifetimes, every native link and all recovery bytes remain unchanged. Restoring
directory access allows the ordinary export to retry successfully.

The final affected cohorts pass:

| Boundary | Result |
| --- | --- |
| Mac Core storage | 23 functions in three suites, no failures or skips |
| iPhone Simulator Core storage | 21 functions in three suites, no failures or skips |
| Source provenance | 813 Mac inputs and 1,160 phone inputs match the workspace; all 813 shared inputs match |
| Products | Both recorded products per platform match their executed files |
| Static checks | Strict Swift formatting and whitespace checks pass |

The existing affected suites also retain direct-entry and target-rebinding,
recovery-failure and Mac process-interruption coverage. Neither final cohort has
SQLite unlink diagnostics. These counts describe test functions, including
parameterized functions, rather than an inflated count of their assertions.

Evidence is under
[`native-membership-consolidation`](evidence/native-membership-consolidation/),
in `native-owned-content-link-*` and `native-owned-content-links-*` packets.
The [validation record](evidence/native-membership-consolidation/native-owned-content-links-validation.json)
reconciles final inputs/products and records lossless manifest compression.
The first green attempt retained one faulty fixture expectation about unrelated
Item lifetimes; the corrected expectation compares the entire original set.
The original red and that failed attempt remain retained.

Verified cleanup removed one passing Mac fixture and 64 passing phone fixtures
after their hosts and database handles closed. Failed and interrupted datasets
remain preserved. No original result bundle was removed.

## Remaining scope

Q161 is not complete. Schedules now have a separate
[local checkpoint](native-restored-owned-bookings.md). Owned label selections have
their [own checkpoint](native-restored-owned-labels.md). Losing List memberships,
losing Itinerary entries and their expanded completion
still need implementation and qualification. Broader owned restoration histories and link-specific native
save/publication/interruption outcomes remain open. Q162 label collision handling
is also still open. HTTP, native interaction, actual Mac/system, cloud and physical
acceptance keep their separate gates. Signing remains deferred.
