# Owned-location Intents

Status: six actions, 14 location cases, 43 affected adapter cases and Mac/Simulator/unsigned device builds pass locally. Signing and actual system picker invocation remain deferred.

## Context, starting state and goal

At `4f612573`, Item and Itinerary editors can change owned location text or explicitly remove a saved pin. Shortcuts cannot change these ordinary fields. Add typed owner actions for editing place text, explicitly setting a pin from a native location input, and clearing the owned location. Each operation changes only that owner's guarded location field. Shared content, links, independent completion, order, labels, estimates and bookings must survive.

## Definition of ready

Q33 accepts ordinary Intent data edits. Q51 B requires text edits to retain a saved pin unless removal is explicit. Q92 A keeps Maps-link previews temporary, with owned locations taking precedence; clearing an owned location must preserve the original bookmarks. Q112 A approves production Intent calls with Apple's dependency manager and disposable real storage in the existing app-hosted target. Reuse that boundary, current Core commands and whole-location field hashes. No new target, dependency, schema, command or test-only input is needed.

## Input behavior

An omitted place name or address keeps that saved field. Explicit empty text clears that field; supplied text retains its exact characters. Removing a pin preserves any remaining place text. Clearing a location removes the owned name, address and coordinate together while retaining all bookmarks.

Native pin input uses public `PlaceDescriptor` from GeoToolbox, supported by App Intents on the app's existing platforms. Use only explicit coordinate or device-location representations. Require at least one finite, in-range point and require multiple supplied points to agree. Address-only, conflicting or invalid input rejects without lookup or mutation. Ignore address representations and the descriptor's common name when saving a pin. Existing authored text stays intact. Actual system picker resolution is a separate gate.

## Required tests and definition of done

Use vertical missing-action tests followed by real-storage passes for each operation and owner. Verify retained pins, omission, explicit text clearing, pin-only removal, new locations and full clearing. Reopen storage and inspect public source/appearance/schedule reads. Test coordinate bounds, agreeing native representations, device points, constructible address-only input, and preservation of authored text rather than adoption of descriptor metadata. Probe the SDK boundary separately for inputs its constructor cannot represent; do not credit those as Planner invocation tests.

Missing, wrong-kind and deleted selections must not target another source or resurrect data. Precancelled requests and unavailable storage cannot acknowledge changes. Actual recovery-filesystem failure must retain the applied change, block further mutations and permit native acknowledgement without replay. Run affected adapter regressions, strict lint and platform compilation; verify extracted parameter contracts, source hashes and mobile Share embedding. Remove disposable stores only after the host and SQLite handles close. Keep system invocation, physical qualification and the broader map open.

## SDK evidence

Apple documents [supported Intent parameters](https://developer.apple.com/documentation/appintents/adding-parameters-to-an-app-intent), [PlaceDescriptor](https://developer.apple.com/documentation/geotoolbox/placedescriptor) and its [representations](https://developer.apple.com/documentation/geotoolbox/placedescriptor/placerepresentation). Installed public SDK probes accept the native parameter and network-free coordinate construction on Mac and iOS. They do not establish actual picker behavior. Planner validates the representations explicitly because the documentation does not promise a conflict policy for the descriptor's convenience coordinate accessor.

The recorded probe passes Swift 6 strict concurrency with warnings treated as errors for Mac 26 and iOS 27. The first recording attempt omitted the Xcode selection from its SDK-path lookup, so the default command-line toolchain could not find the iPhone SDK. That lookup failure is retained without device compile credit; the corrected run explicitly selects the installed Xcode for both lookup and compilation. No account, entitlement or signing setup changes are involved.

## Executed vertical slices

The Item text-edit test first fails at its missing production action, then passes against reopened storage in 0.628 seconds. The Itinerary text/removal test likewise records its missing action and passes in 0.630 seconds. The fixture retains a locally Done List membership and two independent direct appearances of the same Item, shared Category/Tag identities, exact links, separate Item/Itinerary pins, activity/manual estimates and timed/all-day bookings.

Native Item pin setting records its missing-action red and passes in 0.467 seconds. The selected London point replaces only the coordinate; the descriptor's provider name/address are ignored and authored Tokyo place text remains exact. The Itinerary action records its missing-action red and passes in 0.592 seconds using agreeing device-location and coordinate representations for Sydney. Item location and the route's independent completion stay intact. These are adapter test durations, not physical performance measurements.

Explicit clearing first fails at the two missing actions, then passes in 0.642 seconds. It clears each owner's location while retaining original Maps and ordinary bookmarks, route contexts and bookings. A subsequent test finds that reusing the full-form draft's unchanged-value behavior retains an empty location when explicit Intent text is already blank. Both assertions fail in the retained red. The Intent now merges supplied text explicitly, preserving omitted fields and converting explicit empty strings to absent fields. An all-absent result clears the owned location. That test passes in 0.655 seconds; native full-form draft behavior is unchanged.

## SDK construction limitation

The first safety run passes 13 cases and crashes while constructing an empty `PlaceDescriptor` in the remaining test, before any location Intent is invoked. Its crash frames identify GeoToolbox. An isolated, network-free executable reproduces native constructor traps for empty representations, out-of-range coordinates, nonfinite coordinates and conflicting coordinate representations. Address-only construction succeeds. The failed test/report, crash-frame summary and separate probe commands/results are retained without passing qualification credit.

The corrected adapter test uses constructible address-only input and requires both owner actions to reject it without any mutation. Planner retains defensive finite/range/agreement checks, but this seam does not prove those unreachable malformed-descriptor branches. No constructor swizzling, unsafe value construction, production test hook or private-helper test is added. Actual system picker conversion and malformed system payload behavior remain unqualified. All failed-run fixture stores are removed only after both recorded hosts and their SQLite handles are verified closed.

## Safety and affected regression evidence

The corrected suite passes all 14 location cases in 9.695 seconds. It covers explicit empty and omitted fields, new address-only/pin-only locations, exact coordinate bounds and origin, address-only rejection, missing/wrong-kind/deleted selections, cancellation, unavailable storage and retained global/archive/local states. Three independently completed appearances, original bookmarks and timed/all-day bookings retain their identities and values. Every successful save retains recovery readiness.

Actual post-save recovery obstruction runs separately for each of the six actions. The applied location survives reopening, the next mutation stays blocked, and native recovery acknowledges the same original operation. Field hashes, timestamps and references remain unchanged during acknowledgement. A subsequent explicit edit succeeds. Applied/incomplete and unverified outcomes retain the established truthful result handling without a fallible post-save read. An explicit unverified-operation fault remains a separate open qualification gate.

The combined run passes all 43 affected location, Item, subtitle and Itinerary-editing cases with zero failures/skips in 16.108 seconds. It retains its actual summary and original log without compiler diagnostics or SQLite lifetime warnings. All 48 final fixtures, 19 corrected-safety fixtures, 19 failed-SDK-construction fixtures and seven earlier green/red fixtures are disposed only after verified host exit and closed database handles. Missing-action compiler failures retain no runtime credit. The SDK-only crash is retained as failed qualification rather than relabeled a pass.

## Platform and source qualification

Mac extraction retains the 37 prior actions and adds exactly the six typed location actions, giving 43 actions, seven entities and seven queries. Prior enum cases and captured Item/reset parameter contracts remain unchanged. Text actions have one required typed owner, optional place-name/address strings and an explicit pin-removal Boolean. Pin actions use the required native GeoToolbox location entity. Clear actions have only their required typed owner. The full current parameter catalog is retained for later comparisons.

All 1005 prior source inputs are unchanged; the production/test files bring the verified current epoch to 1007 inputs. Strict affected Swift lint passes. No Core/schema, public command, package, target, entitlement or native UI change is introduced. The runner avoids rewriting identical overlay files while retaining its exact source-hash checks; that orchestration change is recorded in each subsequent packet.

The actual Simulator app/native UI-test target and unsigned generic iOS-device builds pass with matching 43-action catalogs, unchanged entities/queries/enums and identical location parameter contracts. Both platform packets verify all 1007 current source hashes against the Mac-tested epoch. The device app embeds exactly one mobile Share extension; both executables are arm64. Strict affected Swift/Markdown lint, platform type checks and staged whitespace checks pass. These builds do not establish actual system invocation, physical performance or installation; the existing ad hoc Mac setup is reused without signing/account changes.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `app-intent-*-location-*` and `app-intent-owned-location-*` packets with original commands/logs, source hashes, actual exits, summaries, metadata, SDK probes and fixture verification. [Q115](../native-estimate-intent-input-review.md) remains pending for estimate-setting input. Other richer Intent reads/fields, scheduling/capture/bulk actions, actual system invocation, signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical qualification and feature-complete whole-app UI polish remain open. The map is incomplete and signing remains deferred.
