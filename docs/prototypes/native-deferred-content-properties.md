# Live saved-content properties in Shortcuts

Status: Q117 A is implemented locally. Seven getter cases and 69 affected native adapter regressions pass. Actual system property fetching remains a separate gate.

## Context, starting state and goal

At `0a458a62`, Item/List/Itinerary entities carry identity, title/name and state. Lightweight query rows do not contain Notes. Q117 A approves deferred properties and tests at their real production getter boundary, preserving the distinction between unloaded content, an absent value and a failed read.

## Expected and resulting behavior

Item gains Subtitle, Notes, Location name, Address, Pin, Created and Last updated. List gains Notes, Created and Last updated. Itinerary gains Notes, Location name, Address, Pin, Created and Last updated. These are sixteen native DeferredProperty declarations on existing entities, with optional text/PlaceDescriptor and required Date values.

Each request reads the current saved source of the declared kind/UUID through the registered SavedPlannerStore. Text is retained exactly, including empty strings, absence, multiline Unicode and surrounding spaces. Pins contain only owned coordinates with no invented provider name/address. A Maps bookmark, name-only location or address-only location does not become a Pin. No lookup, geocoding, provider cache or data mutation is involved.

Missing/deleted sources, unavailable storage and cancellation throw rather than return nil. Archived and globally Done sources stay readable. Created/Last updated return saved timestamps without rewriting them. A previously returned entity reads later content changes; its existing stored title/state properties keep their original snapshot meaning. Separate property requests can observe different data generations. Estimates, labels and schedules retain their separate read contracts.

## Definition of ready and required tests

Q117 A approves production getters; Q112 supplies the real SDK dependency manager, disposable storage and existing app-hosted target. Tests use entities returned by actual creation and identity/search/suggestion queries. No test-only constructor, resolver, manager, private-helper test, package or target is introduced.

The first Notes case fails for the absent property, then passes after implementation. The remaining-property case likewise fails for missing fields and passes after their addition. An expanded fixture initially used nonexistent owned-location initializer defaults; the corrected attempt retains that compiler failure separately.

Two later invocations expose unsupported SDK dependency setups. Arbitrary hand-constructed entities have not gone through native creation/query setup, and replacing an unresolved manager registration outside SDK execution also raises Apple's dependency precondition. The final tests retain real production-returned entities and establish the new unavailable dependency through the existing production Get Item invocation before testing its getters. No production bypass or test hook is added. Those failed invocations keep failed credit and original logs. Actual cold system property fetching still needs separate qualification.

The final run passes 76 tests with zero failures/skips. Seven getter cases cover live text, all sixteen values, exact optional absence versus empty text, name/address-only and pin-only locations, zero/boundary coordinates, saved Maps links without pins, source timestamps, archive/Done, deletion, kind-isolated queries, cancellation, an actual bootstrap obstruction and reads through actual incomplete recovery. Public whole-backup comparisons and reopening prove content, identities, references, order, completion and timestamps survive reads. Explicit checkpoint retry alone acknowledges incomplete recovery. The other 69 cases exercise affected Item/List/Itinerary create/get/find and owned-location adapters.

All 84 final marked fixtures and five earlier passing fixtures are disposed only after host/SQLite closure. Sixteen fixtures from the two failed runtime invocations are separately disposed after the same closure checks; neither invocation is counted as passing. Compiler-only failures have no runtime credit.

## Validation and definition of done

Mac app-hosted execution, Simulator app/native UI-target compilation and unsigned device compilation pass with the same 1,049 frozen inputs. The final runner avoids rewriting unchanged overlay files before building; it records the same complete source hashes and original recipe. Strict affected Swift/Markdown lint and Git whitespace checks pass.

All platform catalogs contain the sixteen exact deferred properties with native optional String/PlaceDescriptor and required Date types. All 72 action contracts, prior properties, ten queries, enum cases and four App Shortcuts remain intact. Only the ordering of alternate resolvable input types is normalized in comparisons.

The evidence directory retains `app-intent-deferred-*` packets, commands/exits, frozen inputs, logs, summaries, metadata and fixture dispositions. There is no schema, Core/MCP, backup, entitlement, target or signing/account change. Actual property discovery/fetching, cold dependency initialization, system invocation, background/locked behavior, physical performance and shared/account-bound storage remain open. This local slice closes no broader map issue.
