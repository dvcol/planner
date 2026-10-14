# Bounded Maps capture lookup

Narrow research, verified **2026-10-13** against official Apple/Google documentation and installed iPhoneOS 27.0/macOS 27.0 declarations, Xcode **27.0**, build **27A266a**. The [accepted shared command contract](../shared-command-contracts.md) Q18/Q19 remains authoritative. The [native MapItem loading note](native-map-item-loading.md) separately covers incoming typed objects and identifier provenance.

Recommendation within that contract: use documented URL interpretation and application-controlled header/redirect transport. Native MapKit place lookup is a separate higher-level service; its cancellation API does not supply the transport controls needed to demonstrate this contract. No `MKMapItemRequest(mapsURL:)` initializer was found in the inspected SDK or current documentation.

This report selects no new lookup authority, retry policy, production dependency or test-only Planner parameter. No Maps sender lookup or app test was performed. The only execution was an explicitly requested standalone URLProtocol registration probe using a reserved `.invalid` HTTPS URL, described below. No production code, commits or GitHub changes belong to this task.

## Accepted boundary

The contract requires HTTPS originals only, headers/redirect inspection, eight seconds overall and four per request, at most five redirects/six requests, and one selected-link attempt. Add does not wait. Ordinary page bodies, opaque path decoding, keyed Google services and automatic preview retries remain outside the accepted behavior. Obsolete callbacks cannot mutate the current review or a saved Item.

The exact permitted request-host candidate is:

- `maps.apple.com`.
- `maps.apple`, or a hostname ending at the DNS-label boundary `.maps.apple`.
- `maps.app.goo.gl`.
- `maps.google.com`.
- `www.google.com` with path `/maps/` or its descendants.

Each outgoing hop must meet the same scheme/host/path rule. Retaining an original bookmark is separate from authority to request it. `goo.gl/maps`, suffix spoofs and other hosts do not acquire authority through a high-level API. These are human choices from the contract, not a broader allowlist inferred from the provider documentation.

## What the installed native APIs expose

| API | Installed availability | Supported input/control | Contract limit |
| --- | --- | --- | --- |
| MKMapItemRequest with mapItemIdentifier | iOS/iPadOS 18; macOS 15 | Native Apple place identifier; async result and cancel | No caller-supplied URLSession, HEAD method, header-only mode, redirect callback, request/hop counter or per-request timeout |
| MKMapItemRequest with mapFeatureAnnotation | iOS/iPadOS 16; unavailable on native Mac | A selected native map feature | Not a shared-URL parser or transport controller |
| MKMapItemRequest with PlaceDescriptor | iOS/iPadOS/macOS 26 | Address/coordinate representations and optional provider identifiers | A framework lookup, not an observable bounded redirect chain |
| GeoToolbox.PlaceDescriptor | iOS/iPadOS/macOS 26 | Common name, address/coordinate representations and supporting service identifiers | The inspected declaration does not expose a Maps URL constructor |
| URLSession data/task delegates | iOS/iPadOS 7; macOS 10.9 | Request method, response headers, redirect decision, cancellation | Application still owns complete deadline, hop accounting and result generation |

MKMapItemRequest.h declares identifier/feature constructors, getMapItem, cancel, isLoading and isCancelled. Its Swift overlay adds PlaceDescriptor construction. Neither platform's header/overlay contains `mapsURL`; current MKMapItemRequest documentation lists those supported initializers, and the direct `init(mapsurl:)` documentation-data request returned 404. This is evidence about the inspected stable SDK and current public docs, not every future release. [Request class](https://developer.apple.com/documentation/mapkit/mkmapitemrequest), [Descriptor constructor](https://developer.apple.com/documentation/mapkit/mkmapitemrequest/init(placedescriptor:)), [PlaceDescriptor](https://developer.apple.com/documentation/geotoolbox/placedescriptor)

The identifier request returns native MapItem information when lookup succeeds. Native results may provide place coordinates, address, name, associated website and a genuine optional identifier. Initializing a descriptor or identifier does not itself establish a resolved place. Apple explains that PlaceDescriptor lookup may use other representations if an identifier is absent or its lookup fails. One high-level invocation therefore does not expose how many underlying provider operations occur. It cannot demonstrate six-request accounting or the exact permitted hosts. [Native identifier lookup](https://developer.apple.com/documentation/mapkit/mkmapitemrequest/init(mapitemidentifier:)), [Descriptor fallback](https://developer.apple.com/videos/play/wwdc2025/204/), [Place-ID contract](https://developer.apple.com/documentation/mapkit/identifying-unique-locations-with-place-ids)

MapKit.cancel cancels an in-progress request, but no inspected public parameter configures the contract's four-second transport limit or five redirects. An application timer can stop accepting results and request cancellation; that is not proof that the framework avoided disallowed hosts, ordinary bodies, hidden retries or further network work. No MapKit network execution occurred here. [MapKit cancellation](https://developer.apple.com/documentation/mapkit/mkmapitemrequest/cancel())

## Documented provider URL interpretation

Apple's unified Maps URLs distinguish map frames, searches, place cards and directions. For `/place`, documented fields include coordinate, address, name and place-id. A frame center or directions waypoint is not automatically a specific selected place. A URL field is source-provided information, not a native MapKit lookup result; an associated website is also distinct from the original Maps bookmark.

Apple documents shortened hosts ending in `maps.apple` and obtaining the full URL from the server's HTTP 301 redirect response. It does not document decoding the opaque short path. The contract's exact DNS-label checks remain narrower and explicit. The documentation does not promise HEAD support for every short link or complete place metadata in response headers. [Unified Apple URLs](https://developer.apple.com/documentation/mapkit/unified-map-urls)

Google's no-key Maps URLs launch map actions. Their documented parameters include search query/query_place_id, directions origin/destination and display center. `api=1` selects the documented syntax; query_place_id is a Google reference, not an Apple identifier. These URLs are not a no-key place-details retrieval API. No reviewed guarantee supplies complete short-link metadata through HEAD, and no opaque Google path/data-token decoding is established. [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started)

Google's separate Resolution API resolves URLs/names to Google Place IDs, but requires a billing-enabled Cloud project, enabled service and API-key or OAuth credentials. It uses authenticated POST endpoints on another host. Current no-charge pricing does not remove those setup/authentication requirements or make it part of the accepted no-key/header-only lookup. No credential or service was configured. [Google Resolution API](https://developers.google.com/maps/ai/grounding-lite/resolution-api)

## URLSession supports explicit header and redirect control

URLRequest exposes httpMethod and defaults to GET. A HEAD request must therefore set that method explicitly. HTTPURLResponse provides case-insensitive header lookup. The accepted request loop can inspect Location and supported URL parameters without parsing ordinary response bodies. Provider refusal of HEAD does not establish authority for a GET/body fallback. No real provider HEAD response was measured. [Method](https://developer.apple.com/documentation/foundation/urlrequest/httpmethod), [Header lookup](https://developer.apple.com/documentation/foundation/httpurlresponse/value(forhttpheaderfield:))

A default or ephemeral session's redirect delegate receives the original HTTP response and proposed new request. Supplying nil refuses automatic redirection. Apple explicitly says this returns the redirect response's body to the request, so nil alone is not body suppression. Background sessions follow redirects automatically and do not call this delegate. Application-controlled hops can refuse automatic following, validate the next request and budget, and issue the next explicit HEAD only if it remains authorized. [Redirect delegate](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/urlsession(_:task:willperformhttpredirection:newrequest:completionhandler:))

The data delegate's didReceive response callback receives the initial headers and lets the app cancel the transfer at that stage. The SDK says no further messages arrive until its completion handler is called. It also states that data-task factories taking a completion-handler block suppress response/data delegate delivery. A body-returning convenience path must not be assumed to exercise the header-cancellation boundary. Use and prove the actual delegate-driven path before counting it as headers-only evidence. Callback cancellation is not a documented zero-allocation or zero-wire-byte guarantee for every server. [Header disposition](https://developer.apple.com/documentation/foundation/urlsessiondatadelegate/urlsession(_:datatask:didreceive:completionhandler:)), [Data delegate](https://developer.apple.com/documentation/foundation/urlsessiondatadelegate)

## Deadlines, counts and late callbacks

`timeoutIntervalForRequest` is an inactivity timer that resets when additional data arrives. A value of four seconds alone does not enforce a four-second elapsed-request deadline. `timeoutIntervalForResource` measures a whole resource transfer from request initiation, but an eight-second setting on each new task does not create one shared eight-second attempt budget. Account for remaining overall time across manual hops and bound each request independently. The accepted eight/four-second numbers are application choices, not native defaults. [Request timeout](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforrequest), [Resource timeout](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforresource)

Likewise, a native API call count is not the contract's request/hop count. Maintain the selected attempt's five-redirect/six-request accounting around each outgoing request and reject unauthorized next hops before dispatch. A monotonic attempt deadline and obsolete-generation checks must cover input edits, Add/Cancel and explicit retry. These are consequences of the accepted behavior, not a newly selected implementation interface.

URLSessionTask.cancel returns immediately; delegate messages can still arrive before cancellation is acknowledged. Canceling a task does not authorize a late callback to publish stale preview fields. Apple also documents automatic timeout retry for background upload/download tasks, so background transfer behavior is not proof of the accepted no-automatic-preview-retry rule. The report does not claim the app can count TCP-level retries or control every internal networking operation. [Task cancellation](https://developer.apple.com/documentation/foundation/urlsessiontask/cancel()), [Background retry distinction](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforrequest)

## URLProtocol fixture registration boundary

URLProtocol.registerClass registers a subclass with the URL loading system; Apple notes that not all registered classes are guaranteed to be consulted. URLSessionConfiguration.protocolClasses explicitly adds custom protocols to a session. Custom URLProtocol subclasses are unsupported for background sessions. Public URLProtocolClient APIs can report fixture headers and redirects, but their actual delegate delivery still needs execution proof. [Global registration](https://developer.apple.com/documentation/foundation/urlprotocol/registerclass(_:)), [Session protocols](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/protocolclasses), [Fixture redirect notification](https://developer.apple.com/documentation/foundation/urlprotocolclient/urlprotocol(_:wasredirectedto:redirectresponse:))

The explicitly requested standalone probe ran on **macOS 27.0.1**, build **26A434**, Apple Swift **6.4**, using a reserved `https://planner-protocol-probe.invalid/headers` HEAD request. Registration was process-local and removed before exit. It did not contact a real Maps endpoint or modify app/network configuration.

| Probe path | Observation |
| --- | --- |
| Register custom class, then construct ordinary ephemeral URLSession with untouched protocolClasses | registerClass returned true. Custom canInit/startLoading counts were 0/0; request failed with NSURLErrorDomain −1003. |
| Construct ephemeral control with protocolClasses explicitly set to the same subclass | Custom counts advanced to 1/1; response was status 200 with the fixture header. |

Compile and probe exited 0. This observation does **not** establish that global registration intercepts Planner's ordinary ephemeral I/O on this Mac; it establishes the opposite for this tested construction. The explicit-config control verifies the protocol fixture itself, not unchanged Planner execution. iOS behavior and real app request/delegate paths were not executed. No test-only URLSession/factory parameter or production seam is selected by this report.

Probe source `/private/tmp/PlannerURLProtocolRegistrationProbe.swift` SHA-256: `fbf3c64956204ed8ac05ec996febc88112122333eae47fa5843f83c7542eeec7`. Output `/private/tmp/PlannerURLProtocolRegistrationProbe.log` SHA-256: `22f611477bd0f1580e739d9f54afd36325b505ca1ef7b8dc66a8eac2fb7c6575`. The probe used an async Data-returning convenience method solely to inspect registration; it is not header-only production qualification.

## Remaining qualification evidence

The owning prototype must exercise its approved actual I/O boundary, with an interception or controlled transport arrangement shown to reach that boundary rather than only a separately constructed session. Cover exact allowed hosts and suffix spoofs, HTTPS originals and disallowed redirects, missing/relative Location, loops, five/six boundaries, per-request and overall deadlines, HEAD refusal, no body fallback, cancellation and late callbacks. Header/body/callback delivery and physical allocation/lifecycle evidence must be observed; documentation and a callback stub cannot pass those gates.

High-level native place lookup, automatic GET fallback, additional keyed/OAuth services and unsupported URL-path interpretation are not demonstrated substitutes for the accepted bounded contract. Unknown links remain within the accepted partial-bookmark behavior. This report identifies API capabilities and evidence limits without amending that behavior or adding tests.

## SDK reproduction and document validation

Inspect MKMapItemRequest.h, MapKit.swiftinterface, GeoToolbox.swiftinterface and NSURLSession.h under each OS 27 SDK's `System/Library/Frameworks`. Selected fingerprints:

| Declaration | iPhoneOS SHA-256 | macOS SHA-256 |
| --- | --- | --- |
| MKMapItemRequest.h | `4ab56e0db0c4202c722be7e47c454b4a24883e7fbb6465cea678b18dee4f4d38` | Same |
| MapKit interface | `dba903a482e0c3ef4167b3f0b48b519c136ff0e23e086e21c87e012cd4e26db1` | `14da4aa124177bf37caa005057cc2b994c87ed111770dc440d695708981446b6` |
| GeoToolbox interface | `4109a828bcb3e0cb584af831eede5821491c96689355c90cd93b426edcf7fdaf` | `1078d18cf11594da20b927d67246aaa00ac1002e9415fe0dc5cd3a2314aac572` |
| NSURLSession.h | `98337d03056125aea179ff96d0e7d047ded099505f11379f7c7e67b160206711` | Same |

Validate affected Markdown, local references, primary-source destinations and whitespace. The report is the only repository edit from this research task; no app tests, commits or GitHub mutations are claimed.
