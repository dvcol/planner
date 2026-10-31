# Saved Maps link previews

Status: Q92 has a working native presentation with focused simulator qualification. The [lifecycle follow-up](native-saved-maps-lifecycle.md) adds controlled native Retry, stale-response and edit/removal evidence. Ordinary creation Q93 and final Mac UI qualification remain open.

## Context and goal

Maps capture could show a temporary place preview, and owned Item addresses/pins could show maps. A saved Maps bookmark alone supplied no map in Item details. Q92 adds a temporary native map card while retaining the exact bookmark and keeping provider results outside owned fields and backups.

Owned coordinates or an owned address take precedence. Google coordinate searches remain search locations, with provider attribution and uncertainty text. A name or address without coordinates remains useful text with the saved-link fallback. It does not become an invented business or a saved pin.

## Definition of ready

Q50 approves the production native provider/cache test boundary. Q78 approves the controlled HTTP transport used by Core's existing bounded Maps lookup. Q92 approves the read-only saved-link presentation. No new domain command, schema or provider-data adoption is introduced. The existing Maps parser and redirect/deadline restrictions are reused.

## Required tests and definition of done

- Resolve supplied coordinates and supported redirected links through the public read-only resolver. Preserve provider uncertainty and avoid HTTP for complete supplied coordinates.
- Cache only the exact dataset, source lifetime, link identity and URL bytes. Retry is explicit. Cancelled or superseded requests cannot publish old results or start another lookup.
- Exercise Google Maps capture, Save and relaunch through production native UI. Verify the native map and original bookmark identity/value. Qualify Apple compatibility, owned-location precedence and unavailable results separately.
- Inspect original own-app captures. Run affected compiler and strict lint checks. Keep simulator evidence separate from live-provider, Mac runtime, physical-device and final polish gates.

## Implementation and test findings

For eligible links without directly readable place fields, the public resolver reuses the existing HTTP transport and parser without creating a Capture draft. The native cache uses the existing exact-byte link request identity, remains in memory, and gives each caller its own cancellable provider await. Complete supplied coordinates need no HTTP lookup.

The initial boundary test fails to compile before the resolver/cache APIs exist, then passes after implementation. A later review identifies an old-response-before-Retry race. The focused test witnesses an unintended third lookup; returning an obsolete result instead of recursively loading fixes both response orderings. Cancellation of one window leaves another window's request available.

Review also identifies a retained Retry token that could repeat I/O when a detail reappears. The view consumes each token once. Address-only Maps candidates use text/fallback rather than entering an address loader that drops the selected link identity.

The initial native run fails at the missing saved map. The first integrated run exposes a test-controller error: its button-only helper cannot identify MapKit's accessibility container. The captured own-app hierarchy contains the map, Google attribution and search uncertainty. A subsequent run reaches the bookmark check but swipes inside the map; the controller now scrolls through the native Form gutter. One intermediate controller build fails because XCTest has no `lastMatch` query member; using the observed collection's last element fixes that compile error. These controller failures are retained separately from product behavior.

## Evidence and remaining work

The evidence directory records commands, source hashes, compressed logs and actual exits. The read-only resolver/cache and unit evidence are committed in `50516fb`.

| Boundary / phase | Represented result |
| --- | --- |
| Public Core resolver, `resolver-final` | Four functions pass, including a two-case ineligible-URL test |
| Affected preview package, `affected-preview-package` | Sixteen functions pass; two opt-in live SDK functions are skipped. Six passing Maps functions include six request-identity cases |
| iPad, `tablet-complete-native-controls` | Three functions pass: Apple owned-address precedence/relaunch, Google coordinate preview/relaunch and text-search fallback |
| iPhone, `phone-complete-native-controls` | The same three functions pass with zero failures/skips |
| iPhone capture compatibility, `phone-capture-compatibility-qualified` | Nine functions pass with zero failures/skips in 394.833 seconds |
| Mac, `mac-preview-build` | Native app and UI-test targets compile without signing; no UI journey is executed |

The final iPad functions take 159.538, 85.222 and 32.319 seconds respectively, with zero failures/skips. The final iPhone functions take 52.497, 51.990 and 23.107 seconds. Earlier tablet setup failures are isolated to the controller selecting the background Form and treating a native Link as a Button. The corrected queries use observed component identifiers and element types. Original named captures show the temporary Google pin, the independently authored Cupertino address taking precedence, and the text-search fallback. Live tiles in these captures do not qualify provider availability or every Maps URL format.

The fourteen affected Swift files pass strict lint. Standards and Spec reviews report no remaining material production-source findings after the Retry, address-lookup and duplicate-name corrections. Source hashes remain checked for each represented build/test phase. These native epochs include unfinished creation/selection work; no Q88/Q93 writer completion is credited.

The older capture suite used whole-screen absence of provider names as its retention check. Q92 intentionally makes that text visible in a temporary saved map. A witnessed failure in `phone-capture-assertion-red` confirms the mismatch. The replacement inspects the saved editor's authored title, blank place/address and absence of an owned pin after Save and relaunch; its focused run passes in 49.841 seconds. It establishes those native observations, rather than a complete portable-backup exclusion matrix.

The first nine-function compatibility run passes seven functions and fails two checks for bookmarks below the visible Form. Scrolling through the Form gutter fixes those controller failures. The final run passes all nine functions in 394.833 seconds. These journeys cover capture-side cancellation, edits, removal, source selection, explicit Retry and saved owned fields. The saved-link Picker assertion proves Museum appears and Cafe is absent before switching, then Cafe appears and Museum is absent afterward.

At this slice's commit, saved-card controlled-delay, edit/delete during a pending lookup and Retry-reappearance journeys remain unqualified in native UI. The [lifecycle follow-up](native-saved-maps-lifecycle.md) records their subsequent native qualification and Retry fix. Mac UI runtime, physical sync, signed Share, accessibility, performance and final whole-app polish remain open. No map gate is closed by this slice.
