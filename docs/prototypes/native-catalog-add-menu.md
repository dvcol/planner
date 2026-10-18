# Native catalog Add menu

Status: Q101 A implemented and qualified on the represented Mac, iPad and iPhone journeys on 18 October 2026. Final whole-app UI review remains open.

## Context and goal

Items and Inbox previously showed separate New Item and Capture buttons. On regular iPad, Capture floated at the bottom of the collection and obscured the last visible row. The [contrast checkpoint](native-selection-contrast-fix.md) records the dark Increase Contrast audit failure. Moving both buttons to the top crowded the catalog title. The user selected one native Add menu, matching the accepted List workflow.

Before: four toolbar actions compete for space or Capture overlaps collection text. After: native Filters, Sort and Add remain separate controls. Add offers New Item and From Link or Text. Existing explicit Save/Cancel, draft protection, capture review, shared identities and recovery write restrictions stay unchanged. No new data or service API is required.

## Definition of ready and required validation

Q101 A approves this presentation. The existing public native UI boundary and real saved fixtures supply the tests. No new test-only dependency or runtime switch is introduced. The regression opens both editors from Items and Inbox, cancels them, then checks the existing List after relaunch. The existing selected Item/List contrast journeys exercise the former overlap, including real local completion and the same saved appearance.

Observe the missing-menu regression before implementation. Then qualify the actual menu actions, relevant creation/capture workflows, ordinary light/dark appearance and dark Increase Contrast. Inspect original toolbar captures for an intact title and unobscured rows. Run affected strict Swift lint and mobile/Mac compiler checks. Mac compilation supplies no native runtime credit.

## Implementation

`SavedItemCatalog` now uses native Menu and Button controls. The menu is disabled by the same creation/recovery state as its former direct actions. The obsolete catalog Capture-placement parameter is removed; other scenes retain their existing toolbar placement. Existing native journey controllers open the menu explicitly before selecting its action. Catalog-readiness and disabled-state assertions address the visible Add control rather than a closed menu's child.

No general element lookup gains hidden interaction. The shared native test helper still handles actual system overflow when needed. Completion, sorting, filters, page retention, commands, capture content and saved state retain their existing implementations.

## Executed checks

The first native regression fails because Add is absent, 20.916 seconds. The first implementation run opens New Item and Capture, but the new controller then searches for Capture's input as a Button rather than a TextField. That is a controller error, not evidence that Capture failed to open. The same run passes the unfiltered increased-contrast selected Item and List/local-completion journeys, 12.181 and 20.794 seconds. The input lookup is corrected before further qualification.

The final iPad Add journey passes for Items and Inbox, 53.680 seconds. Selected Item and List/local-completion contrast audits also pass with dark appearance and Increase Contrast, 12.324 and 20.704 seconds. The additional recovery check initially stops at an outdated direct Items-tab lookup before reaching Add. Replacing that lookup with the existing shared native navigation helper preserves its navigation assertion. The recovery journey then passes, 23.678 seconds, including disabled Add, retained readable content, recheck and relaunch. The earlier combined invocation retains exit 65 for that controller failure even though its three Add/contrast journeys pass.

The unlocked Mac now starts native tests. The first attempt opens Capture but uses a mobile label assertion for a native popup's selection; the Mac controller now checks the popup value. The next attempt reaches the saved duration but exposes a real accessibility defect: the displayed 2 days has an empty accessibility value on an Other element. The window-only screenshot and hierarchy retain that diagnosis. Adding the native static-text trait to the shared saved estimate restores its declared accessibility value. Temporary hierarchy diagnostics are removed from the ordinary test, and both Mac popup assertions use native values. The complete Capture journey then passes, 68.643 seconds, including valid Cancel, save, one Inbox Item after relaunch, original link, Weekend duration and retained edit controls. No credential storage, signing-team or permission setting changes occur.

The iPhone Item/List pushed-detail contrast audits pass, 12.155 and 11.743 seconds. Its first menu attempt stops at the wide-layout Cancel lookup; compact New Item correctly uses its declared native Back control. The corrected controller uses Cancel where present and Back otherwise. The iPhone Add journey then passes for Items and Inbox, 48.847 seconds. The earlier combined invocation retains exit 65 for its controller failure. No production navigation change is made for either controller correction.

Commands, literal results, source/product hashes, unsuccessful attempts and original captures are retained in the [evidence packet](evidence/navigation/native-catalog-add-menu/). Mobile runtime freezes source and products and restores appearance/accessibility settings.

The inspected [iPad Items toolbar](evidence/navigation/native-catalog-add-menu/q101-tablet-menu-and-contrast-dark-increased/77C160BF-F85F-46D6-9E22-B9356AA1B121.png) retains the full title and leaves bottom rows unobscured. The [Inbox toolbar](evidence/navigation/native-catalog-add-menu/q101-tablet-final-dark-increased/F5AB0208-3ECF-407B-A408-C43C8C9061B1.png) uses the same native controls. The passing Mac [saved Item](evidence/navigation/native-catalog-add-menu/q101-mac-static-estimate-qualified/299FFCD9-9ED7-4D6A-9E20-E675284A4112.png) and [staged Capture](evidence/navigation/native-catalog-add-menu/q101-mac-static-estimate-qualified/4CB017AE-045C-43EF-ADBD-3B655D8A9FAD.png) show actual native panes, Form controls, readable duration and bookmark. These captures establish those represented presentations only.

## Completion boundary

This slice addresses catalog creation controls and the represented overlap. It does not close all scenes, full accessibility, keyboard operation, physical-device or final human visual acceptance. Q98 itinerary windows remain separate approved work. Q100 B requires actual signed storage and working native Mac journeys; a free signing route must be qualified rather than inferred from ad hoc compilation.
