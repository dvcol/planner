# Native Item creation and contextual navigation

Status: implementation is compiled and source-reviewed. Final native runtime qualification is pending; Q88–Q91/Q93 and the Navigation prototype remain open.

## Context and expected state

List creation previously opened Add existing Item from its toolbar and placed text/link capture in another menu. Full New Item used a modal with limited fields. Confirmed deletion could leave an empty detail column despite surviving visible records.

The native Add menu now offers New Item, Add existing Item and From Link or Text. New Item opens a native Form in the detail column on Mac and wide iPad, with compact navigation on iPhone. It includes title, subtitle, notes, native estimate pickers, shared labels, place name/address and authored bookmarks. Existing location/link editors are reused.

A draft holds its operation identity, fields, originating dataset and immutable List identity. List-bound Save uses the [approved ordinary creation command](../create-item-in-list-contract-review.md), creating one local Todo membership atomically and preserving repeated URLs. Capture retains its separate deduplication policy.

The draft retains the original List name-field hash. Save prepares a Core review, compares a fresh source read with that original hash, then applies the reviewed command. Rename or replacement requires explicit Use This List confirmation without losing the fields. Missing or archived destinations reject; they never turn creation into a global action. Failed validation preserves the draft. An applied result closes it even if its independent recovery copy is incomplete.

Edited drafts require Save, Discard or Keep Editing before navigation. An untouched blank draft closes directly. The draft remains the same object when columns adapt. Deletion selection follows [Q89's separate implementation and historical evidence](native-deletion-selection.md), preserving the current query, dataset, source/appearance scope and compact navigation behavior.

## Definition of ready and required runtime checks

The human approved the creation/navigation decisions and the public Core, HTTP and native UI boundaries. Core and HTTP qualification are recorded in their [Core report](core-item-in-list-creation.md) and [MCP report](mcp-item-in-list-creation.md).

The rich-content and dirty-navigation journeys have been extended. Destination-race and resize/collapse journeys still need executable fixtures and qualification. The production native journeys must pass on the final source:

- Cancel a changed List draft without creating a source or membership. Save full content, two separately labeled identical URLs and a local Todo membership; preserve their identities after relaunch and leave another List unchanged.
- Keep Editing, reject an invalid navigation Save, then save successfully before leaving. Preserve fields and destination through column resizing/collapse.
- Rename or restore the originating List while a draft is open. Require explicit refreshed destination review and retain the authored content. Reject an unavailable destination without fallback.
- Retain Add existing and From Link or Text behavior, rich saved details/maps and the affected deletion-survivor journeys.

## Evidence and current limit

The [packet](evidence/navigation/native-rich-creation/) retains historical and current epochs separately. Earlier Mac/phone rich-creation and dirty-navigation journeys passed with the provisional Capture-backed adapter. They establish only those recorded prototype epochs. They do not qualify the final ordinary command or its duplicate-bookmark test.

The new `phone-q93-bookmarks-red` attempt exits 70 before building or starting a test. Xcode reports running CoreSimulator 1171.7.0 versus required 1174.9.2, disables Simulator support and cannot resolve the task iPhone destination. A separate device-list probe hangs and is terminated without restarting the service. This is infrastructure failure, not a behavioral red or native test result. Restarting that service awaits human approval because it can interrupt other open simulators.

`q93-mobile-editor-qualified` and `q93-mac-editor-compile` both complete build-for-testing successfully. They compile the app and native UI test target, with signing disabled, and supply no runtime credit. Their isolated source exports and overlays are recorded. The Mac export also contains the final committed MCP adapter; the earlier mobile export retains the base's inactive Mac-only adapter files. Both contain the same final native editor and Core sources. Strict lint passes all 19 affected native Swift files. Independent Standards and Spec reviews report no confirmed source findings.

The native runtime checks above, current Mac automation availability, physical sync/account/Share, accessibility, performance and whole-app polish remain open. No feature or map completion is inferred from compilation.
