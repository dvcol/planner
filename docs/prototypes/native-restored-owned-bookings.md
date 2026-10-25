# Bookings owned by losing restored sources

## Local Core checkpoint, 26 October 2026

This Q161 slice retains a winning Item or Itinerary's complete booking collection
and retires bookings owned by its proven losing candidate. It follows the
[owned-link checkpoint](native-restored-owned-links.md) through the existing
source-restoration maintenance transaction. It does not transfer or merge
bookings between source versions.

The proposal admits only exact Schedule identities with consistent saved owner
bindings and the correct native owner object. Existing Schedule validation checks
the saved timed/all-day form before retirement. The completeness check excludes
only those admitted native Schedule objects; every other booking remains
required. The same durable transaction deletes the losing bookings and source.

No public interface, format, model, maintenance rule, writer gate, package or test
boundary changes. Portable5/model19/rule3/gate23 and recovery envelope2 remain.

## Verification

The qualified tracer first reproduced the existing live-relationships rejection
for both Item and Itinerary owners, with timed and all-day bookings. The corrected
production path preserves the winning booking's exact form and identity. The
entire public export equals the graph before competing native delivery. Old user
receipts remain unchanged, and replaying the original Create Schedule returns its
exact applied result. The discarded booking's public identity fails rather than
opening the winning booking. Reopen and repeated losing-candidate delivery
preserve the same complete graph.

A real unwritable recovery directory leaves every native booking, its identity,
owner binding and saved form unchanged, along with all recovery bytes and writer
control. Restoring directory access allows the normal export to retry. An empty
winning booking collection stays empty for both owner kinds.

| Boundary | Final result |
| --- | --- |
| Mac Core storage | 28 functions in three suites, no failures or skips |
| iPhone Simulator Core storage | 26 functions in three suites, no failures or skips |
| Inputs | 813 Mac and 1,160 phone inputs match the workspace; all 813 shared inputs match |
| Products | Both recorded test products per platform match their executed files |
| Static checks | Strict Swift formatting and whitespace checks pass |

Neither final cohort has SQLite unlink diagnostics. The affected suites retain
the owned-link, Q162 label collision, direct-entry, independent target and existing
generic maintenance failure/interruption checks. Counts describe test functions,
including parameterized functions, rather than individual assertions.

Evidence under
[`native-membership-consolidation`](evidence/native-membership-consolidation/)
uses the `native-owned-booking-*` prefix. The
[validation record](evidence/native-membership-consolidation/native-owned-booking-validation.json)
reconciles final inputs/products and lossless source-manifest compression. The
initial test comparison compile error and wrong creation-result selection are
retained separately from the qualified behavioral red run. Neither establishes a
production failure. The qualified red run and all passing packets remain intact.

Verified cleanup removed four passing Mac tracer fixtures and 150 passing phone
fixtures after hosts and database handles closed. Failed/interrupted datasets
and original result bundles remain preserved.

## Remaining scope

Losing-source label selections now have a separate
[local checkpoint](native-restored-owned-labels.md). Q161 still requires losing
Itinerary-owned entries. List memberships and their expanded rows have a
[local checkpoint](native-restored-owned-memberships.md). The current owned-link/booking slices retire
native losing-owner records under the proven source-family authority. Individual
owned-identity closure and manual-import restoration histories still need
qualification. Booking-specific native-save/publication/interruption and native
Calendar interaction remain open; generic passing checks do not establish every
booking-specific outcome. Broader restoration, HTTP, actual Mac/system, cloud,
physical and whole-app acceptance remain separate gates. Signing stays deferred.
