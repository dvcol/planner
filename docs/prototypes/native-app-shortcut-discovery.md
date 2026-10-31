# Initial native App Shortcuts

Status: Q123 A is implemented as native discovery metadata. Actual system discovery, prompting and Siri execution remain unqualified.

## Context, starting state and goal

At `76fda43e`, Planner has 72 ordinary App Intents and no AppShortcutsProvider. The user accepted four initial discoverable shortcuts in Q123 A, independently of the pending concrete Open workflow. Add native discovery entries for the existing Create Item, Find Items, Find Lists and Find Itineraries actions while retaining their data authority, typed results and prompted fields.

## Expected and resulting behavior

One native AppShortcutsProvider declares exactly those four actions. Each has one simple phrase containing the application name, a sentence-case short title and a system symbol. Other actions remain available in the ordinary library. No Open, global completion, backup, export or recovery shortcut is added. The provider changes no action implementation, default filter, parameter, permission or storage operation.

## Definition of ready and required tests

Q123 A accepts this set; Q112's production action boundary already covers its underlying commands and reads. Static metadata is verified against the actual extracted app artifact, not by duplicating the provider implementation in unit tests. The initial red artifact has zero shortcuts where four are required.

After adding the provider, actual Mac metadata has the four exact action identifiers, phrases, titles and symbols. The 18 existing Item/List/Itinerary Find tests pass. An initially mistyped creation selector matches no case and receives no creation credit; a separately verified existing Create Item test then passes with its exact saved identity and reopened content/recovery. The two successful invocations total 19 tests, zero failures/skips, with 21 marked fixtures disposed only after host/SQLite closure. These are production adapter checks, not Siri invocations.

## Validation and definition of done

Mac, Simulator app/native UI-target and unsigned device products compile with the same 1,047 frozen inputs. Each extracted catalog contains exactly four create/find shortcuts while preserving all 72 ordinary action contracts, entity/query properties and enum cases. Comparisons normalize only the ordering of alternate resolvable input types. Strict affected Swift/Markdown lint and Git whitespace checks pass.

The evidence directory retains `app-shortcut-discovery-*` packets with the original red artifact, commands/exits, logs, summaries, metadata, source hashes and fixture dispositions. No target, package, entitlement, signing/account or device-install change is made. Actual installation/discovery, voice phrases, required-title prompting, system picker injection and background/locked invocation retain their separate gates. The broader map remains open.
