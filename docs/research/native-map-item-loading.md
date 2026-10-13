# Native MapItem loading

Narrow fact check, verified **2026-10-13** against Apple documentation and the installed iPhoneOS 27.0/macOS 27.0 SDKs in `/Applications/Xcode.app`, Xcode **27.0**, build **27A266a**. The existing `docs/research` directory was inspected before choosing this path.

Recommendation for the accepted encoded-cap boundary: load the recognized MapItem data representation first, inspect its byte count, then use MKMapItem's public NSItemProviderReading factory on iOS/iPadOS. Native macOS needs a different decoder because that conformance is not publicly declared there. Its MapItem-whitelisted secure decoder remains the bounded native candidate supported by the constructed Mac fixture below. Neither path implies arbitrary binary fallback or complete physical Maps sender compatibility.

This note selects no capture policy, identity schema, sender compatibility promise or production implementation. The researcher ran a scratch iOS SDK signature type-check only, with no native decoder execution or application tests. The root agent supplied a local Mac probe; its source/output were inspected and are explicitly separated from documentary and physical-sender evidence.

## The platform boundary

| Surface | iOS/iPadOS 27 | Native macOS 27 | Evidence |
| --- | --- | --- | --- |
| MKMapItem implements NSItemProviderReading/Writing | Declared under `TARGET_OS_IOS` | Not publicly declared under the native Mac target | `MapKit.framework/Headers/MKMapItem.h:90–93` in both SDKs |
| MKMapItem implements NSSecureCoding | Declared | Declared | `MKMapItem.h:84–85` |
| MKMapItemTypeIdentifier | Available since iOS 11 | Available since macOS 10.13 | `MKMapItem.h:87`; [serialized-item constant](https://developer.apple.com/documentation/mapkit/mkmapitemtypeidentifier) |
| NSItemProvider's typed object APIs | Available since iOS 11 | Available since macOS 10.13 | They require NSItemProviderReading/Writing; availability of the protocols does not confer them on MKMapItem. [Typed load](https://developer.apple.com/documentation/foundation/nsitemprovider/loadobject(ofclass:completionhandler:)-8ak5d), [Object initialization](https://developer.apple.com/documentation/foundation/nsitemprovider/init(object:)) |
| Legacy item/coercion APIs | Still declared, deprecated in OS 27 | Still declared, deprecated in OS 27 | `Foundation.framework/Headers/NSItemProvider.h:295–324`; [item initialization](https://developer.apple.com/documentation/foundation/nsitemprovider/init(item:typeidentifier:)), [item loading](https://developer.apple.com/documentation/foundation/nsitemprovider/loaditem(fortypeidentifier:options:completionhandler:)) |

The same MKMapItem header bytes are present in both SDKs; its conditional compilation creates the difference. A documentation page that lists provider protocols for MKMapItem generally is not evidence of native Mac conformance. `loadObject(ofClass: MKMapItem.self)` and `NSItemProvider(object: mapItem)` require that conformance at the public typed API boundary. No private selector or forced protocol cast is established as a supported substitute. [MKMapItem](https://developer.apple.com/documentation/mapkit/mkmapitem), [Reading protocol](https://developer.apple.com/documentation/foundation/nsitemproviderreading), [Writing protocol](https://developer.apple.com/documentation/foundation/nsitemproviderwriting)

## iOS encoded-size gate before native decoding

Accepted Native Maps Q77 B supplies an **8 MiB encoded MapItem cap**, alongside the existing **1 MiB aggregate decoded metadata limit**. These are human-selected application limits, not MapKit limits. Eight MiB is **8,388,608 bytes**; one MiB is **1,048,576 bytes**. The encoded limit can be checked before the application's native MapItem decoder is invoked.

Apple exposes these public Swift contracts, introduced in iOS/iPadOS 11 and macOS 10.13:

```swift
func loadDataRepresentation(
    forTypeIdentifier typeIdentifier: String,
    completionHandler: @escaping @Sendable (Data?, (any Error)?) -> Void
) -> Progress

static func object(
    withItemProviderData data: Data,
    typeIdentifier: String
) throws -> Self
```

The first method returns typed representation bytes. The second belongs to NSItemProviderReading and constructs the native class from those bytes plus their UTI. On iOS/iPadOS, MKMapItem's declared conformance makes this concrete call public and available:

```swift
try MKMapItem.object(
    withItemProviderData: providerData,
    typeIdentifier: MKMapItemTypeIdentifier
)
```

Request `loadDataRepresentation` with **MKMapItemTypeIdentifier**, reject a returned payload whose `Data.count` exceeds **8,388,608** before calling that factory, then apply the separate aggregate metadata limit after native decoding. Handle provider errors, missing data and thrown native-decoding errors. Supplying a recognized UTI does not make malformed bytes valid. This uses MapKit's own item-provider decoder on iOS; it does not require the app to inspect private archive fields or assume a keyed-archive wire format there. [Typed data load](https://developer.apple.com/documentation/foundation/nsitemprovider/loaddatarepresentation(fortypeidentifier:completionhandler:)), [Native object factory](https://developer.apple.com/documentation/foundation/nsitemproviderreading/object(withitemproviderdata:typeidentifier:)), [MapItem type](https://developer.apple.com/documentation/mapkit/mkmapitemtypeidentifier)

`loadObject(ofClass:)` instead delivers an object that the provider has already loaded. Its callback gives no encoded Data argument or byte-limit parameter, so it cannot implement this application-controlled encoded-size check before MapItem construction. Its general convenience remains valid where such a gate is unnecessary. The data loader also has no maximum-size or streaming argument: its full Data is available when the completion runs. Therefore the accepted gate bounds what this app explicitly decodes; it does not establish a bound on provider-side work, initial Data materialization, decoded object-graph memory or OS-internal allocations. The decoded metadata cap remains a distinct post-decode check. [Object loading](https://developer.apple.com/documentation/foundation/nsitemprovider/loadobject(ofclass:completionhandler:)-8ak5d), [Data loading contract](https://developer.apple.com/documentation/foundation/nsitemprovider/loaddatarepresentation(fortypeidentifier:completionhandler:))

A scratch signature probe at `/private/tmp/PlannerMapItemDecoderSignatureProbe.swift` type-checked all three calls with **exit 0**, using scoped Xcode 27, iPhoneSimulator27.0.sdk and target `arm64-apple-ios27.0-simulator`. The concrete decoder returns MKMapItem. The command used `swiftc -typecheck`, an explicit SDK/target and a scratch module cache; it built no app and executed no provider or decoder. Its source SHA-256 is `1c60e3ae19cc254106183cde1bc48c67f49cd54222652ed7105daeb4b732a284`. The compile result proves public callability for that SDK target, not cap enforcement, representation-array contents, real sender acceptance or runtime decoding. The header's TARGET_OS_IOS boundary still prevents treating this factory as a declared native Mac MKMapItem API.

## Type lanes and URLs

MKMapItemTypeIdentifier identifies a serialized map item. The exact string observed in the supplied Mac probe is **`com.apple.mapkit.map-item`**. Prefer the public constant in implementation rather than infer a type from data shape or hard-code a private payload key. The SDK declares the constant but does not publish the complete built-in iOS readable/writable arrays as literals.

NSItemProviderReading exposes `readableTypeIdentifiersForItemProvider`; Writing exposes class/instance writable arrays. An object-initialized provider uses the object's declared representations; actual providers expose `registeredTypeIdentifiers`. A UTI describes a representation, not an original URL or identifier provenance. The reviewed Apple sources do not guarantee that every MKMapItem provider automatically includes `public.url`, plain text, or an Apple Maps URL. This audit did not execute an iOS provider to establish its current built-in arrays. [Reading types](https://developer.apple.com/documentation/foundation/nsitemproviderreading), [Writable types](https://developer.apple.com/documentation/foundation/nsitemproviderwriting/writabletypeidentifiersforitemprovider-swift.property), [Provider](https://developer.apple.com/documentation/foundation/nsitemprovider)

| Value | What the native contract says | What it does not establish |
| --- | --- | --- |
| MKMapItem.url | A URL associated with the location, for example the business's website | It is not documented as the incoming Apple Maps share URL. |
| A separately registered URL representation | A provider explicitly offers a URL lane | Its presence and exact supplied URL must be observed; a typed map-item lane alone does not prove it. |
| MKMapItem.identifier | An optional Apple place reference | It is not a URL and does not retain the original shared URL. |
| Opening a MapItem in Maps | Native Maps presentation/handoff | It does not recover the exact original sender URL. |

Apple's url documentation explicitly describes associated location/business URLs. Keep that field distinct from an incoming Maps URL and from any newly generated link. No public original-share-URL property appears in the inspected MKMapItem declaration. [Associated URL](https://developer.apple.com/documentation/mapkit/mkmapitem/url), [Opening Maps](https://developer.apple.com/documentation/mapkit/mkmapitem/openinmaps(launchoptions:))

## Audited constructed-Mac-provider observation

The root agent ran `/private/tmp/PlannerNativeMapProviderProbe.swift`; the researcher inspected that source and `/private/tmp/PlannerNativeMapProviderProbe.log`. The source constructs a native MKMapItem from a CLLocation and nil address, assigns the name `Map fixture` and the associated website `https://example.com/business`, then registers it under MKMapItemTypeIdentifier using `NSItemProvider(item:typeIdentifier:)`.

The recorded output is:

- Registered types: only `com.apple.mapkit.map-item`.
- `loadDataRepresentation(forTypeIdentifier: MKMapItemTypeIdentifier)` returned **366 bytes**.
- `NSKeyedUnarchiver.unarchivedObject(ofClass: MKMapItem.self, from:)` returned the constructed name and associated website.

That provider did not advertise a URL lane, despite its MapItem containing a website. Its data load and class-whitelisted decode succeeded for this constructed local fixture. The program performs no native search or place-ID lookup, does not inspect opaque archive keys, and does not establish a positive Apple identifier. The initializer used to construct the provider is deprecated in OS 27; the data loader and class-whitelisted unarchiver are public current APIs.

Probe source SHA-256: `2c254192cff8e4d4c6bfc4f48e7ed9ccac23ca4e6dd2d666418d0de0310f825f`. Output SHA-256: `d35e7d3c9029d7778eaf5666da073b4a8cb8b0edcebf0b08d0a7169dd2a7c58f`.

This is not an iOS protocol-array observation, cross-process Share Extension proof, physical Apple Maps sender capture, or guarantee that all representations with that UTI use the same archive format.

## Native Mac loading choices and the serialization limit

The legacy coercing interface accepts NSSecureCoding objects. The SDK explains that requests for the registered type with the same object class or a superclass return the original object; representations registered through the binary interface appear as NSData to that coercing interface. Thus a native MKMapItem registered as an object and generic NSData bearing a MapItem UTI are different inputs. A returned object must actually be MKMapItem before extracting its fields. The legacy APIs remain documented but are deprecated in OS 27. [Item initialization](https://developer.apple.com/documentation/foundation/nsitemprovider/init(item:typeidentifier:)), [Item loading](https://developer.apple.com/documentation/foundation/nsitemprovider/loaditem(fortypeidentifier:options:completionhandler:)), [Lazy item registration](https://developer.apple.com/documentation/foundation/nsitemprovider/registeritem(fortypeidentifier:loadhandler:))

The supplied alternative loads data only for the recognized native MapItem representation, then calls `unarchivedObject(ofClass: MKMapItem.self, from:)`. MKMapItem declares NSSecureCoding, and this unarchiver API enables secure coding and constrains the expected root class. It reports invalid keyed data as an error and can return nil. This exact boundary uses documented Apple serialization and decoding APIs. It avoids interpreting private fields, unrestricted root-class decoding, or trying unrelated archives until one succeeds. [Typed data load](https://developer.apple.com/documentation/foundation/nsitemprovider/loaddatarepresentation(fortypeidentifier:completionhandler:)), [Class-whitelisted decode](https://developer.apple.com/documentation/foundation/nskeyedunarchiver/unarchivedobject(ofclass:from:)), [Secure coding](https://developer.apple.com/documentation/foundation/nssecurecoding)

The remaining limit is precise: the reviewed MKMapItemTypeIdentifier documentation says "serialized map item" but does not specify a universal NSKeyedArchiver wire format. The successful local probe shows that this constructed Mac provider emitted compatible data. It does not establish that every future/physical sender does. A recognized UTI gate, expected class and failure handling remain necessary; nil/error/wrong-class payloads do not justify generic binary or private-schema fallback. Sender compatibility requires its own actual attachment evidence.

## Genuine Apple place identifiers and provider fixtures

MKMapItem.identifier is nullable and read-only, introduced in iOS 18/macOS 15. MKMapItem.Identifier exposes a raw string, and MKMapItemRequest can retrieve a place using such an identifier on both platforms. Constructing an identifier value from a string is not a lookup, proof that the place exists, or a way to assign the read-only identity of a manually created MapItem. [Identifier property](https://developer.apple.com/documentation/mapkit/mkmapitem/identifier-swift.property), [Identifier type](https://developer.apple.com/documentation/mapkit/mkmapitem/identifier-swift.class), [Native lookup](https://developer.apple.com/documentation/mapkit/mkmapitemrequest/init(mapitemidentifier:))

Apple documents Place IDs as opaque references that may be stored and used to retrieve current information. Genuine sources include native search/lookup results, selecting a Maps place and Apple's interactive Place ID Lookup. A once-valid ID can cease to resolve, and alternate identifiers are nonexhaustive references to the same place. These are provider references, not a replacement for Planner's canonical UUID. The native SDK exposes `identifier` and `alternateIdentifiers`; retain actual values and their real source rather than invent an identifier from coordinates, a business website or a fabricated test expectation. [Place-ID acquisition and persistence](https://developer.apple.com/documentation/mapkit/identifying-unique-locations-with-place-ids), [Alternate IDs](https://developer.apple.com/documentation/mapkit/mkmapitem/alternateidentifiers), [Apple lookup tool](https://developer.apple.com/maps/place-id-lookup/)

Documented ways to construct later registered-provider evidence without fabricating provenance are:

1. Use a manually constructed native MapItem for ordinary location/name/associated-URL behavior. Register the actual object through the applicable provider API. Do not call it a positive Apple-ID fixture merely because an expected identifier was supplied separately.
2. For positive identifier preservation, obtain an actual MapItem through a native Apple lookup/search or a real sender, record its nonnil identifier, then register that exact object. Keep the provider result and supplied ID provenance in the fixture evidence. No network-backed lookup was performed in this research.
3. For a Maps URL lane, explicitly register a supplied NSURL representation through the native provider API. That demonstrates the URL lane intentionally constructed, not automatic URL production by MKMapItem. A constructed URL is not evidence of a physical sender's original URL.
4. When the question is real sender compatibility, inspect that attachment's actual registered types and loaded values. A hand-built provider or synthetic DTO cannot prove what Apple Maps emits across the physical app/extension boundary.

These are fixture-provenance boundaries, not a selected import policy or tests added by this researcher.

## Inspection fingerprints and validation

Headers were read beneath each OS 27 SDK's `System/Library/Frameworks`. Both platforms produced the same SHA-256 for these files; the MapItem conditional remains decisive:

| Header | SHA-256 in both SDKs |
| --- | --- |
| MapKit/MKMapItem.h | `802d1e8fd38c882f3c7dd6a791390708da1d26f1f2e31d7bdaf56887dba58d03` |
| MapKit/MKMapItemIdentifier.h | `358665af6d7f9a91bd503f250091cd3484f4aa22bddb9c41dfcddd31c6653459` |
| Foundation/NSItemProvider.h | `90ff2d9b3eda300aafbe6faf1647380d9a78775221cb1263323eb923feafd339` |
| Foundation/NSKeyedArchiver.h | `fa4a4eca1035350979e48dff89e82eb2460f74f5621742067435603317ecd732` |

The report is the only repository edit from this research. Validate the affected Markdown, source destinations and whitespace. No production code, tests, commit or GitHub mutation belongs to this task. Real sender coverage, current iOS readable/writable arrays, positive identifier preservation and cross-process failure/cancellation behavior remain runtime evidence obligations rather than facts inferred from SDK availability.
