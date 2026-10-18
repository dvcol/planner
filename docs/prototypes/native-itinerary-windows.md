# Native itinerary presentation windows

Status: implementation checkpoint for accepted Q98 A. The shared loader and native itinerary integration are implemented. Qualification is partial; the navigation map remains open.

## Context, goal and resulting behavior

The previous itinerary reader hydrated every matching and unfiltered child presentation and built a whole nested List inside one outer row. Repeated memberships also could not fit the loader's former single-UUID output.

`SavedItemWindow` now validates complete source, membership, direct-entry and expanded-entry identities. It publishes coherent itinerary metadata with the initial 64-row page. Complete entry descriptors, full progress, duration totals and contextual List summaries remain separate from loaded row presentations. Native DisclosureGroups contain individually lazy rows; visible and neighboring pages load through the shared loader. The old complete-content reader and its child-presentation arrays are removed.

Repeated List entries keep separate local completion and typed selection. Global Done precedence, archived branch completion, full progress and estimates remain unchanged. Filters use matching child identities and matching List headers without changing the full totals. Existing Item, Inbox, List and both Item-picker callers now validate the complete typed identity before constructing an actionable native row.

Metadata reads validate the full Manual query, optional matching List catalog and matching first page against their saved generations. Empty snapshots use positive-limit validation. Cancellation and replacement checks protect each awaited publication. This is primary-agent source inspection, not exhaustive race testing. Core identity sequences and query captures remain resident; there is no measured total-memory or storage-fetch claim.

## Real-Core qualification

The existing app-hosted `PlannerMCPTests/SavedItemWindowTests` boundary uses disposable real local-only Core data and public commands/imports. The [accepted contract](../native-itinerary-window-contract-review.md) defines that boundary and the native UI seam.

| Evidence epoch | Result |
| --- | --- |
| `q98-repeated-itinerary-red` | Genuine red: the former loader rejects an itinerary scope. |
| `q98-typed-row-window-green` | Existing regressions and the repeated 132-appearance first-page case pass. |
| `q98-itinerary-metadata-red` | Genuine red: complete itinerary metadata is missing. |
| `q98-itinerary-metadata-qualified` | Complete headers, literal composite identities, order and contextual summaries pass. |
| `q98-itinerary-filter-qualified` | Header-only, child-only and cumulative filters preserve full metadata. |
| `q98-itinerary-completion-archive-qualified` | Repeated local/global completion, archive/unarchive and page release pass. |
| `q98-native-integration-mac-core-qualified` | All 17 affected loader functions pass with the native integration compiled on Mac. |
| `q98-final-mac-core-checkpoint` | All 17 pass again with the final parent-route correction compiled on Mac. |

Tests include empty itineraries/Lists, source/List migration regressions, stale generation refresh, source/context replacement, visible-plus-neighbor retention and release/revisit. Initial compiler errors and incorrect expectations remain retained: a List source has two incoming itinerary references in addition to its memberships, and Done takes count priority over Archived. Those attempts supply no successful qualification.

## Native qualification and regression correction

The disposable `itinerary-windows` fixture imports 65 Items, one reusable List, and a route containing Item 001, the List twice, then Item 001. Its 132 appearances are independent. Each Item has a five-minute estimate. This uses the existing public import boundary, not a production test flag or initializer seam.

The first native run used individual fixture commands and timed out during preparation. The imported fixture reaches the real native route quickly. Its journey found a production refresh defect: checking the page-boundary appearance rebuilt presentation heights and a visibility callback replaced the intended scroll anchor. Capturing the anchor before awaiting reload keeps the changed row visible.

Some subsequent failures were controller defects. Collection-view hittability did not identify the already visible iPad pane, and a read-only ProgressView label was visibly present without being hittable. The corrected controller uses explicit compact-phone Back navigation, wide-pane browsing and progress geometry; it retains the actual count, exact identity, contextual completion, detail and relaunch assertions. A longer phone readiness wait then exposed a second production defect: canceling the parent window while pushing its Item detail cleared the row identities that native split navigation uses for the parent route. The view now keeps that bounded context alive while its selected detail is open; explicit cancellation and context replacement still clear the loader.

| Native epoch | Result |
| --- | --- |
| `q98-tablet-completion-refresh-diagnostic` | Red: original checkbox refresh loses the changed row from view. |
| `q98-tablet-captured-anchor` | Checkbox correction passes; later controller incorrectly tries compact Back navigation on iPad. |
| `q98-tablet-repeated-pages-detail-qualified` | Details remain selected offscreen; controller's read-only progress hittability check fails. |
| `q98-tablet-repeated-pages-qualified-final` | iPad, dark appearance, 151.071 seconds, pass through paging, local completion, independent repeated appearance, detail retention and relaunch. |
| `q98-phone-repeated-pages-qualified` | Checkbox and second appearance pass; controller initially attempts wide-pane scrolling during a compact transition. |
| `q98-phone-repeated-pages-qualified-final` | Explicit Back returns before the expected contents appear. |
| `q98-phone-return-and-relaunch` | The readiness wait and original capture establish a real return to the catalog, caused by clearing the parent context during the detail push. |
| `q98-phone-parent-context-qualified` | iPhone, light appearance, 152.223 seconds, pass through paging, local completion, independent repeated appearance, native detail/Back and relaunch. |

The selected original inspected captures and findings are in [visual-review.json](evidence/navigation/native-itinerary-windows/visual-review.json). Appearance and Increase Contrast are restored after each Simulator run. Each compiler/runtime epoch retains commands, source/product hashes, source overlays and logs. Source and compiled products remain frozen throughout each native runtime.

## Remaining definition of done

Q98 stays open for Mac runtime, native collapse/reopen and resizing, filtered itinerary drag anchors, remaining entry/membership/order mutation cases, and requalification of both offscreen Item pickers plus the affected Item/Inbox/List journeys. Existing earlier checkpoints are not counted as new runtime evidence for the migrated interface. The final affected strict Swift lint and mobile/Mac compiler checks pass. The passing iPad epoch predates the later parent-route fix; its final lifecycle regression remains to requalify alongside the other iPad interactions.

Provisioned signing, protected Agent Control storage, physical-device performance, CloudKit and whole-app visual acceptance remain separate gates. The user declined a paid subscription; local and Simulator development continue. This change neither enables CloudKit nor changes the accepted sync design. Whole-app UI polish remains required after feature completion.
