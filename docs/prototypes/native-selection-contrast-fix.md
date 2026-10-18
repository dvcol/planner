# Native row and detail contrast correction

Status: Q99 A foreground and detail correction qualified on the represented mobile scenes on 18 October 2026. The [subsequent Q101 Add menu](native-catalog-add-menu.md) resolves the recorded dark iPad Increase Contrast overlap. This historical checkpoint retains its failure and discarded probes; final whole-app UI review remains open.

## Context and goal

The [earlier diagnosis](native-selected-row-accessibility.md) established a dark iPad selected-title contrast failure, including a minimal stock NavigationLink comparison. Q99 A authorizes control of selected foreground/background where needed while retaining native controls. The existing native UI boundary and real saved `list-windows` fixture supply the regression tests.

Before: selected titles and secondary metadata were pale over the native blue highlight. Light-mode qualification also found weak completion guidance, section headings, duration values, row captions and estimate captions. An inactive selected row after local completion made its secondary duration especially hard to read.

After: native List selection, NavigationLink, checkboxes, Form, Section and LabeledContent remain. Shared row styles use an opaque dark foreground over the prominent native iOS selection and a stronger semantic secondary foreground for ordinary iOS captions. Mac row styles retain their existing native primary, secondary and accent colors. Detail guidance, Notes/Activity estimate headings and the saved duration value use explicit semantic text colors. Completion, source/appearance identities, query order, paging and saved data are unchanged.

## Executed red and correction

The fresh baseline fails the unfiltered native contrast audit in 14.667 seconds. Applying `listRowBackground` at either attempted boundary does not resolve it. A content background passes the narrow audit but creates an unwanted blue border in the original capture; that treatment is discarded. The shipped correction keeps the native highlight and changes foreground styles.

The first light-mode runs reveal additional native detail text failures. Hierarchical `.primary` alone does not strengthen a Form footer, so those corrected labels use explicit `Color.primary`. Collecting every issue then identifies repeated weak duration captions and Estimate/Remaining labels. The regression helper records all audit issues without a handler, filter, suppression or expected failure; ordinary journey assertions remain fail-fast.

The selected List journey audits both before and after its real local checkbox action. It requires the same appearance identity, retained notes and full progress changing from 0 to 1 of 193 Items. An audit of a phone's pushed detail supplies no evidence for a persistent selected collection row.

## Qualification and visual review

The [light Item capture](evidence/navigation/native-selection-contrast-fix/q99-tablet-readable-light/EFC4BB92-18AE-45BF-B227-7385BD9B3BF7.png) and [inactive selected List capture after completion](evidence/navigation/native-selection-contrast-fix/q99-tablet-readable-light/C6B056EA-0D7F-4760-A341-782B8766F2B3.png) show the stronger row captions, explicit detail labels and unchanged native selection surfaces. Both unfiltered light iPad journeys pass on the corrected source.

| Destination and appearance | Executed result |
| --- | --- |
| iPad light | Item audit and List audits before/after local completion pass, 33.551 seconds |
| iPad dark | Same two journeys pass, 33.635 seconds |
| iPad light, Increase Contrast | Same two journeys pass, 32.890 seconds |
| iPad dark, Increase Contrast | List journey passes, 21.221 seconds; Item audit flags two bottom-row texts beneath Capture, 12.599 seconds |
| iPhone light | Item/List pushed-detail audits and actual List completion journey pass, 38.958 seconds |
| iPhone dark | Same three journeys pass, 37.711 seconds |
| Mobile and production Mac | Targeted compiler checks pass; Mac supplies no runtime evidence |

The restored checkpoint has exactly the same source hashes as the qualified iPad build. The [comparison](evidence/navigation/native-selection-contrast-fix/restored-source-comparison.json) records no differences. The separate phone runs use the checkpoint build. Phone audits cover pushed details, with no persistent selected-row claim.

The [dark increased-contrast capture](evidence/navigation/native-selection-contrast-fix/q99-tablet-readable-dark-increased/39D4549F-EFDB-4E40-9EA7-445CDBD22DD6.png) shows Capture overlapping Window Item 014 and its duration. Moving Capture to the top removes that audit failure but truncates the Items title. A preferred-column-width probe does not visibly widen that column. A secondary-action probe still crowds the title, and its controller fails while looking for a direct Capture button inside the new native More menu. None of those toolbar probes ships. Original placement and test actions are restored.

Q101 subsequently selects one native Add menu. Its [separate implementation and qualification](native-catalog-add-menu.md) follow this checkpoint and preserve the other choices as discarded alternatives. Approved Q98 itinerary work remains independent.

Literal results, source/product hashes, unsuccessful probes and original captures are retained in the [evidence packet](evidence/navigation/native-selection-contrast-fix/). The [production Mac compiler packet](evidence/navigation/native-scene-appearance/q99-contrast-checkpoint-mac-build/) records the actual app compilation. Runtime freezes source and products and restores Simulator appearance settings. The [visual review](evidence/navigation/native-selection-contrast-fix/visual-review.json) names only inspected originals. Exporting an additional capture does not establish its visual acceptance.

## Completion limits

These audits cover the represented Item/List presentations, not every scene or text state. Mac automation was unavailable at this checkpoint; the later Q101 Capture journey passes and records its own source/products and limits. That supplies no Mac contrast audit or signed-storage credit. Signing, physical devices, VoiceOver, keyboard operation, maximum text size, Reduce Motion/Transparency, other scene states and final human visual acceptance remain separate gates. Broader floating-bar scroll observations remain open. Q98 itinerary window implementation is approved independent work; Q100 B still requires actual signed storage.
