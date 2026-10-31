# Shared Maps title suggestion

31 October 2026. The user expects a shared Maps place to prefill its Item
title. Core deliberately keeps provider descriptions outside owned content;
the native review previously copied only Core's blank or Saved link title.

The review now suggests a nonempty Maps preview name for a shared draft with
an empty/fallback title. Initial native MapKit input and later link preview
results use the same existing adoption path. A different edited title stays
unchanged. Saving applies the reviewed title through the existing capture edit;
it does not copy provider addresses or coordinates into owned location fields.
An unnamed/unavailable preview keeps the existing fallback. Original links
and Core/MCP/backup contracts are unchanged.

The native map preview is also shown when a sender supplies a map item without
a separate URL. This uses the existing preview and map controls; no new module,
dependency, target, production test hook or data format is added.

## Verification

One existing-target native UI regression passes in 102.207 seconds, using real
`MKMapItem`/`NSItemProvider` loading and disposable Planner storage. It exercises
Cancel, the suggested Nezu Museum title, a custom title, Save and exact Item
identity after relaunch. Both cases inspect the saved editor's empty owned
location fields and absent owned pin. Three original captures are inspected.

The initial attempt reaches the saved Item but queries its completion Switch
as a Button. That failed attempt is retained separately. The corrected driver
uses the actual descendant control and reads the real saved location fields.
The review record includes
commands, source hashes, failed/passing logs and four original PNGs, including
the suggested title
and edited title after relaunch.

Affected strict Swift formatting and whitespace checks pass. The fixture and
signed mobile app/Share/UI-runner builds succeed. The shared Mac app/Share
compiler check also passes. Physical iPhone capture has not been reached by
automation: the first run used an English Maps control name on the French
device, and the corrected identifier reaches the sheet but its app-row swipe
fails. The user then opens a
named place manually on the iPhone and confirms the actual review title fills
correctly; Cancel is requested afterward. The iPad is in use and
must remain untouched. Release archives from the privacy checkpoint predate
this UI change; final distribution archives must use the accepted final source.
