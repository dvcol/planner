# Local continuation, 19 October 2026

The user requests continued local implementation, deferring signing until it is required. This checkpoint qualifies existing native Undo and diagnoses remaining native interactions. Production behavior, Core schema and portable data are unchanged.

## Context, readiness and intended result

The starting revision is `c49db7b0`. Grouped link/label Undo already passes on simulators; actual Mac window/text Undo remains open. The approved native UI seam, Q108 controller boundary and Q111 compound restoration contract carry forward. The goal is actual native evidence, with test-driver corrections based on observed accessibility traits rather than added production hooks.

## Executed results

| Journey | Surface | Outcome |
| --- | --- | --- |
| Membership Undo, separate windows and ordinary text Undo | Mac, local ad hoc | Pass, 69.255 s |
| Whole Move Undo | Mac, local ad hoc | Pass, 94.714 s |
| Grouped itinerary links/labels, notes retained, relaunch | Mac, local ad hoc | Pass, 70.830 s |
| List creation/cancellation and relaunch | Dark iPhone Simulator | Pass, 28.932 s |
| Filtered Manual reorder with hidden Done membership and relaunch | Dark iPhone Simulator | Pass, 138.383 s |
| Same filtered Manual reorder | Light iPad Simulator | Pass, 152.308 s |

The Mac window query now compares the generated identifier through a predicate. XCTest rejects `matching(identifier:)` for this observed identifier exceeding 128 characters. Native Mac source choices expose text through value; saved labels are Buttons rather than StaticText. Queries now match those actual traits. Grouped editor scrolling targets the active sheet and checks that the control fits inside its viewport before clicking. The previous Add Link failure clicked below the visible Form clip.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains source/product hashes, commands, exit status, actual logs, failing attempts and selected original captures. Inspected passing captures show restored checked membership, grouped itinerary links and notes, and before/after filtered reorder on phone plus the reordered tablet. They also retain the crowded inline phone toolbar title; this is still a local polish issue.

## Remaining local outcomes

The final Mac batch has three functions, one pass and two failures. Repeated-entry setup fails opening the catalog Add menu; grouped Item setup fails an XCTest automatic scroll to its label selector. An exported native recording shows display/window geometry changing during the failed Add interaction. These outcomes do not establish a Core mutation defect, signing failure or successful journey. They remain open; no automatic retry is counted as a fix.

An earlier unchanged filtered drag failed on iPhone. The added before/after captures preserve its gesture unchanged; the diagnostic run passes on both simulators. This is evidence of intermittent behavior, not proof of its cause or permanent test stability.

## Implementation audit

At this checkpoint the project has no Share extension targets/controllers and no App Intents implementation. Storage supports only `localOnly`, and its SwiftData configuration disables CloudKit. These are implementation gaps as well as future qualification gates. Signing alone cannot complete them.

Unsigned Share source/targets and ordinary app-target Intents can proceed against the accepted Core/provider/native seams. Installed extension access, real App Groups, physical CloudKit/account transitions, native Agent Control under Q100 B, selected desktop clients and physical performance retain their separate gates. Existing local data must not silently move to a new directory. No provisioned group, team or cloud identifier is invented. Final whole-app polish follows feature completion.
